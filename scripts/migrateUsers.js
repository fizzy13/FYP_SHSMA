/**
 * Firebase Firestore migration script
 *
 * This script migrates existing Firestore user documents in the `Users`
 * collection into documents keyed by Firebase Auth UID.
 * It also writes the `uid` field into the Firestore document.
 *
 * Usage:
 *   1. Install dependencies: npm install firebase-admin
 *   2. Set service account credentials:
 *      export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
 *      (Windows PowerShell: $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\serviceAccountKey.json")
 *   3. Run: node scripts/migrateUsers.js
 *
 * Notes:
 * - This script assumes Firestore collection name is `Users`.
 * - Existing docs can be keyed by email, random ID, or old IDs.
 * - If a matching Auth user is found by email, the script writes a UID-keyed document.
 * - Optional: keep old docs as backup by commenting out deletion.
 */

const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const USERS_COLLECTION = 'Users';

async function migrateUsers() {
  const usersSnapshot = await db.collection(USERS_COLLECTION).get();
  console.log(`Found ${usersSnapshot.size} documents in ${USERS_COLLECTION}`);

  for (const doc of usersSnapshot.docs) {
    const data = doc.data();
    const email = (data.email || '').toString().trim().toLowerCase();

    if (!email) {
      console.warn(`Skipping doc ${doc.id}: missing or empty email field.`);
      continue;
    }

    try {
      const userRecord = await auth.getUserByEmail(email);
      const uid = userRecord.uid;
      const targetRef = db.collection(USERS_COLLECTION).doc(uid);

      // Keep all existing fields and add uid. Use merge so we don't lose any fields.
      await targetRef.set({ ...data, uid }, { merge: true });
      console.log(`Migrated ${email} -> Users/${uid}`);

      // Delete the old doc if it uses a different ID than the UID.
      if (doc.id !== uid) {
        await doc.ref.delete();
        console.log(`Deleted old document ${doc.id}`);
      }
    } catch (error) {
      if (error.code === 'auth/user-not-found' || error.code === 'USER_NOT_FOUND') {
        console.warn(`No Auth user found for ${email} (doc ${doc.id}). Skipping.`);
      } else {
        console.error(`Error migrating doc ${doc.id} (${email}):`, error);
      }
    }
  }

  console.log('Migration finished.');
}

migrateUsers().catch((error) => {
  console.error('Migration failed:', error);
  process.exit(1);
});
