const admin = require('firebase-admin');
const path = require('path');

// Path to your service account key JSON
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function main() {
  // Replace with the IDs from your screenshots
  const customerId = 'NjfBqWaT5Er8WcKBU7Fj';
  const projectId = 'Y2Heymcx1ohVhGQ7rpQk';
  const stockItemId = '21OZtc4RwIkmGl4as06y';

  // References
  const customerRef = db.collection('customers').doc(customerId);
  const projectRef = customerRef.collection('projects').doc(projectId);
  const stockRef = db.collection('stock_items').doc(stockItemId);

  // Fetch stock item to confirm exists and current quantity
  const stockSnap = await stockRef.get();
  if (!stockSnap.exists) {
    throw new Error('Stock item does not exist');
  }
  const stockData = stockSnap.data();
  const currentQty = (stockData?.quantity || 0);
  if (currentQty < 5) {
    console.warn(`Warning: stock only has ${currentQty}, still proceeding.`);
  }

  // Ensure project exists with minimal fields
  const projectSnap = await projectRef.get();
  if (!projectSnap.exists) {
    await projectRef.set({
      customerId,
      title: 'Injected Test Project',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      items: [],
    });
    console.log('Created missing project document.');
  }

  // Build RW document
  const rwCollection = projectRef.collection('rw_documents');
  const newRwRef = rwCollection.doc(); // auto ID

  // Past date, e.g., 30 July 2025
  const createdAt = new Date(Date.UTC(2025, 6, 30, 10, 0, 0)); // months 0-based

  // Minimal stock item info for RW line
  const line = {
    itemId: stockItemId,
    name: stockData?.name || '',
    description: stockData?.description || '',
    quantity: 5,
    unit: stockData?.unit || '',
    producent: stockData?.producent || '',
  };

  const rwDoc = {
    id: newRwRef.id,
    projectId,
    projectName: (await projectRef.get()).data()?.title || '',
    customerId,
    customerName: '', // fill if needed
    createdBy: 'test-script', // or real user id if desired
    createdAt: admin.firestore.Timestamp.fromDate(createdAt),
    createdDay: admin.firestore.Timestamp.fromDate(new Date(Date.UTC(2025, 6, 30))), // day bucket
    type: 'ZWROT/ZAMIANA (test)', // or whatever type you want
    items: [line],
    notesList: [
      {
        createdAt: admin.firestore.Timestamp.fromDate(createdAt),
        userName: 'script',
        text: 'Initial injected line with qty 5',
        action: 'Zainstalowano',
      },
    ],
  };

  // Batch write: create RW, decrement stock, update project
  const batch = db.batch();

  batch.set(newRwRef, rwDoc);

  batch.update(stockRef, {
    quantity: admin.firestore.FieldValue.increment(-5),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  batch.update(projectRef, {
    items: [
      {
        itemId: stockItemId,
        quantity: 5,
        unit: stockData?.unit || '',
        name: stockData?.name || '',
      },
    ],
    lastRwDate: admin.firestore.FieldValue.serverTimestamp(),
  });

  await batch.commit();
  console.log('Injected RW document with 5 units of stock item.');
}

main().catch((e) => {
  console.error('Failed:', e);
  process.exit(1);
});
