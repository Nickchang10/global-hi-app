import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = getFirestore();

export const scheduledPublishAnnouncements = onSchedule(
  "every 5 minutes",
  async () => {
    const now = Timestamp.now();

    const snap = await db
      .collection("announcements")
      .where("published", "==", false)
      .where("scheduledAt", "<=", now)
      .get();

    const batch = db.batch();

    for (const doc of snap.docs) {
      batch.update(doc.ref, {
        published: true,
        updatedAt: now,
      });
    }

    if (!snap.empty) {
      await batch.commit();
    }
  }
);
