import * as admin from "firebase-admin";

const db = admin.firestore();

/**
 * 發送 FCM 推播
 * - 指定 userId 或 role
 * - 自動清理失效 token
 */
export async function sendFCMToUser(params: {
  userId?: string;
  role?: "admin" | "vendor";
  title: string;
  body: string;
  data?: Record<string, string>;
}) {
  const { userId, role, title, body, data } = params;

  let query;

  if (userId) {
    query = db
      .collection("users")
      .where(admin.firestore.FieldPath.documentId(), "==", userId);
  } else if (role) {
    query = db.collection("users").where("role", "==", role);
  } else {
    return;
  }

  const snaps = await query.get();
  if (snaps.empty) return;

  const tokens: string[] = [];

  snaps.docs.forEach((doc) => {
    const arr = doc.data().fcmTokens;
    if (Array.isArray(arr)) {
      arr.forEach((t) => tokens.push(t));
    }
  });

  if (tokens.length === 0) return;

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
  });

  // 清理失效 token
  const invalidTokens: string[] = [];
  res.responses.forEach((r, i) => {
    if (!r.success) invalidTokens.push(tokens[i]);
  });

  if (invalidTokens.length > 0) {
    const batch = db.batch();
    snaps.docs.forEach((doc) => {
      batch.update(doc.ref, {
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
    });
    await batch.commit();
  }
}
