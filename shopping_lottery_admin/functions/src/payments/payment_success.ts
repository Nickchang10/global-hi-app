import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

export const paymentSuccess = functions.https.onRequest(
  async (req, res) => {
    try {
      const payload = req.body;
      if (!payload || payload.status !== "SUCCESS") {
        res.status(400).send("invalid payment");
        return;
      }

      const {
        transactionId,
        userId,
        userEmail,
        items, // [{ productId, qty, price, name }]
        finalAmount,
        paymentMethod,
      } = payload;

      const lockRef = db.collection("payment_locks").doc(transactionId);

      const result = await db.runTransaction(async (tx) => {
        const lockSnap = await tx.get(lockRef);
        if (lockSnap.exists) {
          return { duplicated: true, orderId: lockSnap.data()!.orderId };
        }

        // ===== 訂單建立 =====
        const orderNo = await generateOrderNo(tx);
        const orderRef = db.collection("orders").doc();

        tx.set(orderRef, {
          orderNo,
          userId,
          userEmail,
          status: "paid",
          items,
          finalAmount,
          payment: {
            method: paymentMethod,
            transactionId,
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // ===== 防重複鎖 =====
        tx.set(lockRef, {
          orderId: orderRef.id,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // ===== 扣庫存 + sold =====
        for (const item of items) {
          const pRef = db.collection("products").doc(item.productId);
          const pSnap = await tx.get(pRef);

          if (!pSnap.exists) throw new Error("product not found");

          const stock = pSnap.data()!.stock ?? 0;
          if (stock < item.qty) {
            throw new Error("out of stock");
          }

          tx.update(pRef, {
            stock: admin.firestore.FieldValue.increment(-item.qty),
            sold: admin.firestore.FieldValue.increment(item.qty),
          });
        }

        // ===== 寫銷售報表（日）=====
        const day = new Date().toISOString().slice(0, 10);
        const reportRef = db.collection("reports_sales").doc(day);

        tx.set(
          reportRef,
          {
            date: day,
            totalRevenue: admin.firestore.FieldValue.increment(finalAmount),
            orderCount: admin.firestore.FieldValue.increment(1),
            itemsSold: admin.firestore.FieldValue.increment(
              items.reduce((s: number, i: any) => s + i.qty, 0)
            ),
          },
          { merge: true }
        );

        return { duplicated: false, orderId: orderRef.id };
      });

      // =========================
      // 🔔 通知（Transaction 外）
      // =========================
      await Promise.all([
        // 用戶通知
        db.collection("notifications").add({
          userId,
          title: "付款成功",
          body: "您的訂單已付款成功，我們將盡快出貨",
          orderId: result.orderId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }),

        // Admin 通知
        db.collection("notifications").add({
          role: "admin",
          title: "新訂單成立",
          body: `訂單 ${result.orderId} 已付款`,
          orderId: result.orderId,
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }),
      ]);

      res.json({ ok: true, ...result });
    } catch (e: any) {
      console.error(e);
      res.status(500).send(e.message);
    }
  }
);

// ===== 訂單編號 =====
async function generateOrderNo(tx: FirebaseFirestore.Transaction) {
  const ymd = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  const ref = db.doc(`counters/orders_${ymd}`);
  const snap = await tx.get(ref);
  const next = snap.exists ? snap.data()!.seq + 1 : 1;
  tx.set(ref, { seq: next }, { merge: true });
  return `OS${ymd}${String(next).padStart(4, "0")}`;
}
