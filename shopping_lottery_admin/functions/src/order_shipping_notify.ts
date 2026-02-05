import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import { sendFCMToUser } from "./fcm";

const db = admin.firestore();

/**
 * Vendor / Admin 出貨後 → 自動通知 + FCM 推播
 *
 * 條件：
 * - shipping 從「沒有」→「有」
 * - 只觸發一次
 */
export const orderShippingNotify = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (!before || !after) return null;

    // --------------------------------------------------
    // 1️⃣ 只在「第一次出貨」時觸發
    // --------------------------------------------------
    const beforeShipping = before.shipping ?? null;
    const afterShipping = after.shipping ?? null;

    if (!afterShipping) return null; // 尚未出貨
    if (beforeShipping) return null; // 已出貨過（避免重複）

    const orderId = context.params.orderId;

    const {
      orderNo,
      userId,
      vendorIds = [],
      shipping,
    } = after as {
      orderNo?: string;
      userId?: string;
      vendorIds?: string[];
      shipping?: {
        carrier?: string;
        trackingNo?: string;
      };
    };

    if (!orderNo || !shipping?.carrier) return null;

    // --------------------------------------------------
    // 2️⃣ 防重複鎖（保險，避免 race condition）
    // --------------------------------------------------
    const lockRef = db
      .collection("order_notify_locks")
      .doc(`shipping_${orderId}`);

    const lockSnap = await lockRef.get();
    if (lockSnap.exists) return null;

    // --------------------------------------------------
    // 3️⃣ Firestore 通知
    // --------------------------------------------------
    const batch = db.batch();

    // 🧑‍💼 買家通知
    if (userId) {
      batch.set(db.collection("notifications").doc(), {
        userId,
        title: "訂單已出貨",
        body: `訂單 ${orderNo} 已出貨（${shipping.carrier}）`,
        orderId,
        type: "order_shipping",
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // 👨‍💼 Admin 通知
    batch.set(db.collection("notifications").doc(), {
      role: "admin",
      title: "訂單出貨完成",
      body: `訂單 ${orderNo} 已出貨`,
      orderId,
      vendorIds,
      type: "order_shipping_admin",
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 🔒 鎖定
    batch.set(lockRef, {
      orderId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // --------------------------------------------------
    // 4️⃣ FCM 推播（Transaction 外）
    // --------------------------------------------------

    // 🔔 推播給買家
    if (userId) {
      await sendFCMToUser({
        userId,
        title: "訂單已出貨",
        body: `訂單 ${orderNo} 已由 ${shipping.carrier} 寄出`,
        data: {
          type: "order_shipping",
          orderId,
        },
      });
    }

    // 🔔 推播給 Admin
    await sendFCMToUser({
      role: "admin",
      title: "訂單出貨完成",
      body: `訂單 ${orderNo} 已完成出貨`,
      data: {
        type: "order_shipping_admin",
        orderId,
      },
    });

    return null;
  });
