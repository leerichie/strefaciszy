// backfill.js
const admin = require('firebase-admin');
const db = admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountKey.json'))
}).firestore();

async function backfill() {
  const customers = await db.collection('customers').get();
  for (const cust of customers.docs) {
    const custId = cust.id;
    const projectsSnap = await cust.ref.collection('projects').get();
    for (const proj of projectsSnap.docs) {
      const data = proj.data();
      if (!('contactId' in data) || !('customerId' in data)) {
        await proj.ref.update({
          customerId: custId,
          contactId: custId
        });
        console.log(`Patched project ${proj.id} → customer/contact = ${custId}`);
      }
    }
  }
  console.log('✅ Backfill complete');
  process.exit(0);
}

backfill().catch(err => {
  console.error(err);
  process.exit(1);
});
