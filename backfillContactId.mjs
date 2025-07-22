// backfillContactId.js
import admin from 'firebase-admin';
admin.initializeApp();
const db = admin.firestore();

async function backfill() {
  const snaps = await db.collectionGroup('projects').get();
  for (const doc of snaps.docs) {
    const data = doc.data();
    // Skip if already set:
    if (data.contactId) continue;

    // Assuming you stored the contact’s name on the project:
    const name = data.contactName;
    if (!name) continue;

    const contactSnap = await db.collection('contacts')
      .where('name', '==', name)
      .limit(1)
      .get();

    if (contactSnap.empty) {
      console.warn(`No contact found named "${name}" for project ${doc.id}`);
      continue;
    }

    const contactId = contactSnap.docs[0].id;
    await doc.ref.update({ contactId });
    console.log(`✔️  Set contactId for project ${doc.id}`);
  }
  console.log('✅ Done back-filling');
}

backfill().catch(console.error);
