import * as functions from 'firebase-functions/v2/firestore';
import * as admin from 'firebase-admin';

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * 公告上架 → 自動：
 * 1. 寫入 notifications/{uid}/items
 * 2. 發送 FCM 推播
 */
export const onAnnouncementPublished = functions.onDocumentUpdated(
  'announcements/{announcementId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const announcementId = event.params.announcementId;

    if (!before || !after) return;

    // ✅ 只在「false → true」時觸發
    if (before.published === true || after.published !== true) {
      return;
    }

    const title = (after.title ?? '').toString().trim();
    const content = (after.content ?? '').toString().trim();

    if (!title && !content) {
      console.log('公告內容為空，略過通知');
      return;
    }

    // --------------------------------------------------
    // 1️⃣ 取得所有要通知的使用者
    // （你可在這裡加條件，例如 role）
    // --------------------------------------------------
    const usersSnap = await db
      .collection('users')
      .where('fcmTokens', '!=', null)
      .get();

    if (usersSnap.empty) {
      console.log('沒有可通知的使用者');
      return;
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    const writeBatch = db.batch();
    const fcmTokens: string[] = [];

    for (const doc of usersSnap.docs) {
      const uid = doc.id;
      const data = doc.data();

      // 寫 notifications
      const notifRef = db
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .doc();

      writeBatch.set(notifRef, {
        title: title || '📢 內部公告',
        body: content,
        type: 'announcement',
        route: '/announcements',
        extra: { announcementId },
        isRead: false,
        createdAt: now,
        updatedAt: now,
      });

      // 收集 FCM tokens
      const tokens = Array.isArray(data.fcmTokens)
        ? data.fcmTokens.filter((t) => typeof t === 'string')
        : [];

      fcmTokens.push(...tokens);
    }

    // --------------------------------------------------
    // 2️⃣ 寫入 Firestore（一次 batch）
    // --------------------------------------------------
    await writeBatch.commit();

    // --------------------------------------------------
    // 3️⃣ 發送 FCM（最多 500 tokens / 次）
    // --------------------------------------------------
    const chunks = chunkArray(fcmTokens, 500);

    for (const tokens of chunks) {
      await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: title || '📢 內部公告',
          body: content,
        },
        data: {
          type: 'announcement',
          announcementId,
          route: '/announcements',
        },
      });
    }

    console.log(`公告 ${announcementId} 已通知 ${usersSnap.size} 位使用者`);
  }
);

// --------------------------------------------------
// utils
// --------------------------------------------------
function chunkArray<T>(arr: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    result.push(arr.slice(i, i + size));
  }
  return result;
}
