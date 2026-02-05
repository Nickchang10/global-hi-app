import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import { sendFCMToUser } from "./fcm";

admin.initializeApp();
const db = admin.firestore();

/* ============================================================
 * Webhook 驗證
 * ============================================================ */

function verifyLinePay(req: functions.https.Request): boolean {
  const secret = functions.config().linepay?.secret;
  const signature = req.headers["x-line-authorization"] as string | undefined;
  const nonce = req.headers["x-line-authorization-nonce"] as string | undefined;
  if (!secret || !signature || !nonce) return false;

  const body = JSON.stringify(req.body);
  const raw = secret + nonce + body;

  const hash = crypto
    .createHmac("sha256", secret)
    .update(raw)
    .digest("base64");

  return hash === signature;
}

function verifyECPay(payload: any): boolean {
  const key = functions.config().ecpay?.hash_key;
  const iv = functions.config().ecpay?.hash_iv;
  if (!key || !iv || !payload?.CheckMacValue) return false;

  const sorted = Object.keys(payload)
    .filter((k) => k !== "CheckMacValue")
    .sort()
    .map((k) => `${k}=${payload[k]}`)
    .join("&");

  const raw = `HashKey=${key}&${sorted}&HashIV=${iv}`;
  const encoded = encodeURIComponent(raw).toLowerCase();
  const hash = crypto
    .createHash("sha256")
    .update(encoded)
    .digest("hex")
    .toUpperCase();

  return hash === payload.CheckMacValue;
}

function verifyTapPay(req: functions.https.Request): boolean {
  const key = functions.config().tappay?.partner_key;
  const signature = req.headers["x-tappay-signature"] as string | undefined;
  if (!key || !signature) return false;

  const body = JSON.stringify(req.body);
  const hash = crypto
    .createHmac("sha256", key)
    .update(body)
    .digest("hex");

  return hash === signature;
}

/* ============================================================
 * paymentSuccess（付款成功）
 * ============================================================ */

export const paymentSuccess = functions.https.onRequest(async (req, res) => {
  try {
    const provider = String(req.headers["x-payment-provider"] || "");

    if (
      (provider === "linepay" && !verifyLinePay(req)) ||
      (provider === "ecpay" && !verifyECPay(req.body)) ||
      (provider === "tappay" && !verifyTapPay(req))
    ) {
      res.status(403).send("invalid webhook signature");
      return;
    }

    const {
      status,
      transactionId,
      userId,
      userEmail,
      items,
      finalAmount,
      paymentMethod,
    } = req.body;

    if (
      status !== "SUCCESS" ||
      !transactionId ||
      !userId ||
      !Array.isArray(items)
    ) {
      res.status(400).send("invalid payload");
      return;
    }

    const lockRef = db.collection("payment_locks").doc(transactionId);

    const result = await db.runTransaction(async (tx) => {
      if ((await tx.get(lockRef)).exists) {
        return { duplicated: true };
      }

      const vendorIds = Array.from(
        new Set(items.map((i: any) => i.vendorId).filter(Boolean))
      );

      const orderNo = await generateOrderNo(tx);
      const orderRef = db.collection("orders").doc();

      tx.set(orderRef, {
        orderNo,
        userId,
        userEmail,
        vendorIds,
        status: "paid",
        items,
        finalAmount,
        currency: "TWD",
        payment: {
          method: paymentMethod,
          transactionId,
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        logs: [
          {
            action: "payment_success",
            by: "system",
            note: paymentMethod,
            at: admin.firestore.Timestamp.now(),
          },
        ],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      for (const item of items) {
        tx.update(db.collection("products").doc(item.productId), {
          stock: admin.firestore.FieldValue.increment(-item.qty),
          sold: admin.firestore.FieldValue.increment(item.qty),
        });
      }

      tx.set(lockRef, {
        orderId: orderRef.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { orderId: orderRef.id };
    });

    // 🔔 推播給買家
    await sendFCMToUser({
      userId,
      title: "付款成功",
      body: "您的訂單已付款成功",
      data: { type: "payment_success" },
    });

    res.json({ ok: true, ...result });
  } catch (e: any) {
    console.error(e);
    res.status(500).send(e.message);
  }
});

/* ============================================================
 * 出貨（Vendor / Admin）
 * ============================================================ */

export const shipOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "login required");
  }

  const userSnap = await db.doc(`users/${context.auth.uid}`).get();
  const role = userSnap.data()?.role;

  if (!["admin", "vendor"].includes(role)) {
    throw new functions.https.HttpsError("permission-denied", "no permission");
  }

  const { orderId, carrier, trackingNo } = data;
  if (!orderId || !carrier || !trackingNo) {
    throw new functions.https.HttpsError("invalid-argument", "missing data");
  }

  await db.doc(`orders/${orderId}`).update({
    status: "shipping",
    shipping: {
      carrier,
      trackingNo,
      shippedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    logs: admin.firestore.FieldValue.arrayUnion({
      action: "shipping",
      by: context.auth.uid,
      note: `${carrier}｜${trackingNo}`,
      at: admin.firestore.Timestamp.now(),
    }),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

/* ============================================================
 * 出貨後通知 + FCM
 * ============================================================ */

export const orderShippingNotify = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before?.shipping || !after?.shipping) return null;

    const { orderNo, userId } = after;
    const orderId = context.params.orderId;

    // Firestore 通知
    await db.collection("notifications").add({
      userId,
      title: "訂單已出貨",
      body: `訂單 ${orderNo} 已出貨`,
      orderId,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 🔔 FCM 推播
    await sendFCMToUser({
      userId,
      title: "訂單已出貨",
      body: `訂單 ${orderNo} 已寄出`,
      data: { type: "order_shipping", orderId },
    });

    await sendFCMToUser({
      role: "admin",
      title: "訂單出貨完成",
      body: `訂單 ${orderNo} 已出貨`,
      data: { type: "order_shipping_admin", orderId },
    });

    return null;
  });

/* ============================================================
 * 訂單編號
 * ============================================================ */

async function generateOrderNo(
  tx: FirebaseFirestore.Transaction
): Promise<string> {
  const ymd = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  const ref = db.doc(`counters/orders_${ymd}`);
  const snap = await tx.get(ref);
  const next = snap.exists ? (snap.data()!.seq ?? 0) + 1 : 1;
  tx.set(ref, { seq: next }, { merge: true });
  return `OS${ymd}${String(next).padStart(4, "0")}`;
}
