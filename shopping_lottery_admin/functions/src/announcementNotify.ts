import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = getFirestore();
const fcm = admin.messaging();

export const onAnnouncementPublished = onDocumentUpdated(
  "announcements/{id}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // ✅ 必須是「未上架 → 上架」
    if (before.published === true || after.published !== true) return;

    // ✅ 防止重複發送
    if (after.publishedAt) return;

    const announcementId = event.params.id;
    const title = after.title ?? "新公告";
    const body = after.content ?? "";
    const targetRoles: string[] = after.targetRoles ?? ["user"];

    const usersSnap = await db
      .collection("users")
      .where("role", "in", targetRoles)
      .get();

    const batch = db.batch();
    const tokens: string[] = [];

    for (const user of usersSnap.docs) {
      const data = user.data();

      // Firestore 通知
      const notifRef = db
        .collection("notifications")
        .doc(user.id)
        .collection("items")
        .doc();

      batch.set(notifRef, {
        type: "announcement",
        title,
        body,
        announcementId,
        read: false,
        createdAt: Timestamp.now(),
      });

      // 收集 FCM token
      if (Array.isArray(data.fcmTokens)) {
        tokens.push(...data.fcmTokens);
      }
    }

    // 標記已發送
    batch.update(event.data!.after.ref, {
      publishedAt: Timestamp.now(),
    });

    await batch.commit();

    // FCM 推播
    if (tokens.length > 0) {
      await fcm.sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: {
          type: "announcement",
          announcementId,
        },
      });
    }
  }
);
