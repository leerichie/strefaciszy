// migrate.js
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function backfill() {
  const customers = await db.collection('customers').get();

  for (const custDoc of customers.docs) {
    const custId = custDoc.id;
    const q = await db.collection('contacts')
                    .where('linkedCustomerId', '==', custId)
                    .limit(1)
                    .get();
    if (!q.empty) {
      const contactId = q.docs[0].id;
      await db.collection('customers')
              .doc(custId)
              .update({ contactId });
      console.log(`✔️  ${custId} → ${contactId}`);
    } else {
      console.log(`⚠️  no contact for customer ${custId}`);
    }
  }
}

backfill().catch(console.error);
