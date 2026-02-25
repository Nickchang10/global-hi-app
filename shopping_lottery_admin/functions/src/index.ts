import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

admin.initializeApp();
const db = admin.firestore();

type OrderItemInput = { productId: string; qty: number };

function assert(condition: any, message: string) {
  if (!condition) throw new functions.https.HttpsError("invalid-argument", message);
}

export const createOrder = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "請先登入");

  const items = (data?.items ?? []) as OrderItemInput[];
  const receiver = data?.receiver ?? {};
  const shipping = data?.shipping ?? {};

  assert(Array.isArray(items) && items.length > 0, "購物車是空的");
  for (const it of items) {
    assert(typeof it.productId === "string" && it.productId.length > 0, "商品ID錯誤");
    assert(Number.isInteger(it.qty) && it.qty > 0 && it.qty <= 99, "數量錯誤");
  }

  // receiver minimal validation (你要更嚴格也可再加)
  assert(typeof receiver.name === "string" && receiver.name.length >= 1, "收件人姓名必填");
  assert(typeof receiver.phone === "string" && receiver.phone.length >= 6, "收件人電話必填");
  assert(typeof receiver.address === "string" && receiver.address.length >= 3, "收件地址必填");

  // Prepare refs
  const orderRef = db.collection("orders").doc();
  const lotteryRef = db.collection("lotteries").doc("current");
  const entryRef = lotteryRef.collection("entries").doc();

  const result = await db.runTransaction(async (tx) => {
    // ensure current lottery exists
    const lotterySnap = await tx.get(lotteryRef);
    if (!lotterySnap.exists) {
      tx.set(lotteryRef, {
        title: "當期抽獎",
        active: true,
        drawn: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    let subtotal = 0;
    const orderItems: any[] = [];

    // read + validate + decrement stock
    for (const it of items) {
      const pRef = db.collection("products").doc(it.productId);
      const pSnap = await tx.get(pRef);
      assert(pSnap.exists, `商品不存在：${it.productId}`);
      const p = pSnap.data() as any;

      assert(p.active === true, `商品未上架：${p.name ?? it.productId}`);
      const stock = Number(p.stock ?? 0);
      const price = Number(p.price ?? 0);
      assert(Number.isFinite(price) && price >= 0, "商品價格錯誤");
      assert(stock >= it.qty, `庫存不足：${p.name ?? it.productId}`);

      // decrement
      tx.update(pRef, {
        stock: stock - it.qty,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      subtotal += price * it.qty;
      orderItems.push({
        productId: it.productId,
        nameSnapshot: p.name ?? "",
        priceSnapshot: price,
        qty: it.qty,
      });
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    tx.set(orderRef, {
      uid,
      items: orderItems,
      subtotal,
      status: "created",
      receiver: {
        name: receiver.name,
        phone: receiver.phone,
        address: receiver.address,
        note: receiver.note ?? "",
      },
      shipping: {
        method: shipping.method ?? "",
        carrier: shipping.carrier ?? "",
        trackingNumber: shipping.trackingNumber ?? "",
        trackingUrl: shipping.trackingUrl ?? "",
        shippingStatus: "pending",
      },
      createdAt: now,
    });

    // 1 order = 1 entry
    tx.set(entryRef, {
      uid,
      orderId: orderRef.id,
      createdAt: now,
    });

    return { orderId: orderRef.id, entryId: entryRef.id, subtotal };
  });

  return result;
});

// Admin-only draw winner (pick 1)
export const drawWinner = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) throw new functions.https.HttpsError("unauthenticated", "請先登入");

  // admin check: admins/{uid} exists
  const adminSnap = await db.doc(`admins/${uid}`).get();
  if (!adminSnap.exists) throw new functions.https.HttpsError("permission-denied", "需要管理員權限");

  const lotteryId = (data?.lotteryId ?? "current") as string;
  const lotteryRef = db.doc(`lotteries/${lotteryId}`);
  const entriesRef = lotteryRef.collection("entries");

  const entriesSnap = await entriesRef.get();
  if (entriesSnap.empty) throw new functions.https.HttpsError("failed-precondition", "沒有抽獎券");

  const pool = entriesSnap.docs.map(d => ({ id: d.id, ...d.data() })) as any[];
  const pick = pool[Math.floor(Math.random() * pool.length)];

  await lotteryRef.set({ drawn: true, drawnAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  await lotteryRef.collection("winners").doc(pick.uid).set({
    uid: pick.uid,
    entryId: pick.id,
    orderId: pick.orderId,
    pickedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return { winnerUid: pick.uid, entryId: pick.id, orderId: pick.orderId };
});