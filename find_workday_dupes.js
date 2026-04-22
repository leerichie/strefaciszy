const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

function initFirebase() {
  if (admin.apps.length) return;

  const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

  if (!serviceAccountPath) {
    throw new Error(
      'Missing GOOGLE_APPLICATION_CREDENTIALS environment variable.'
    );
  }

  const resolved = path.resolve(serviceAccountPath);
  if (!fs.existsSync(resolved)) {
    throw new Error(`Service account file not found: ${resolved}`);
  }

  const serviceAccount = require(resolved);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

function tsToMillis(value) {
  if (!value) return 0;

  if (typeof value.toDate === 'function') {
    return value.toDate().getTime();
  }

  if (value instanceof Date) {
    return value.getTime();
  }

  if (typeof value === 'string') {
    const d = new Date(value);
    if (!Number.isNaN(d.getTime())) return d.getTime();
  }

  return 0;
}

function formatMillis(ms) {
  if (!ms) return '-';
  const d = new Date(ms);
  if (Number.isNaN(d.getTime())) return '-';

  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  const hh = String(d.getHours()).padStart(2, '0');
  const mi = String(d.getMinutes()).padStart(2, '0');
  const ss = String(d.getSeconds()).padStart(2, '0');

  return `${yyyy}-${mm}-${dd} ${hh}:${mi}:${ss}`;
}

function norm(value) {
  return String(value || '').trim();
}

function buildSlotKey(data) {
  const userId = norm(data.userId);
  const dayKey = norm(data.dayKey);
  const startMinutes = Number.isFinite(Number(data.startMinutes))
    ? String(Number(data.startMinutes))
    : '-1';
  const endMinutes = Number.isFinite(Number(data.endMinutes))
    ? String(Number(data.endMinutes))
    : '-1';

  return `${userId}|${dayKey}|${startMinutes}|${endMinutes}`;
}

function buildLooseContentKey(data) {
  const userId = norm(data.userId);
  const dayKey = norm(data.dayKey);
  const startTime = norm(data.startTime);
  const endTime = norm(data.endTime);
  const projectName = norm(data.projectName).toLowerCase();
  const description = norm(data.description).toLowerCase();

  return `${userId}|${dayKey}|${startTime}|${endTime}|${projectName}|${description}`;
}

function printDoc(prefix, doc) {
  const data = doc.data() || {};
  const createdAtMs = tsToMillis(data.createdAt);
  const updatedAtMs = tsToMillis(data.updatedAt);

  console.log(
    `${prefix} id=${doc.id}` +
      ` | user=${norm(data.userName) || norm(data.userId)}` +
      ` | dayKey=${norm(data.dayKey)}` +
      ` | ${norm(data.startTime)}-${norm(data.endTime)}` +
      ` | startMin=${data.startMinutes ?? '-'} endMin=${data.endMinutes ?? '-'}` +
      ` | project=${JSON.stringify(norm(data.projectName))}` +
      ` | desc=${JSON.stringify(norm(data.description))}` +
      ` | createdAt=${formatMillis(createdAtMs)}` +
      ` | updatedAt=${formatMillis(updatedAtMs)}`
  );
}

async function main() {
  initFirebase();

  const db = admin.firestore();

  console.log('\n[START] Auditing work_day_logs duplicates\n');

  const snap = await db.collection('work_day_logs').get();
  console.log(`[INFO] Total work_day_logs docs: ${snap.size}`);

  const bySlot = new Map();
  const byLooseContent = new Map();

  for (const doc of snap.docs) {
    const data = doc.data() || {};

    const slotKey = buildSlotKey(data);
    if (!bySlot.has(slotKey)) bySlot.set(slotKey, []);
    bySlot.get(slotKey).push(doc);

    const looseKey = buildLooseContentKey(data);
    if (!byLooseContent.has(looseKey)) byLooseContent.set(looseKey, []);
    byLooseContent.get(looseKey).push(doc);
  }

  let slotDuplicateGroups = 0;
  let slotDuplicateDocs = 0;

  console.log('\n================ SLOT DUPLICATES ================\n');

  for (const [key, docs] of bySlot.entries()) {
    if (docs.length <= 1) continue;

    slotDuplicateGroups += 1;
    slotDuplicateDocs += docs.length - 1;

    docs.sort((a, b) => {
      const aMs = tsToMillis(a.data()?.createdAt);
      const bMs = tsToMillis(b.data()?.createdAt);
      if (aMs !== bMs) return aMs - bMs;
      return a.id.localeCompare(b.id);
    });

    console.log(`[DUPLICATE SLOT] ${key} | count=${docs.length}`);
    for (const doc of docs) {
      printDoc('  ', doc);
    }
    console.log('');
  }

  let looseDuplicateGroups = 0;
  let looseDuplicateDocs = 0;

  console.log('\n============= SAME CONTENT DUPLICATES =============\n');

  for (const [key, docs] of byLooseContent.entries()) {
    if (docs.length <= 1) continue;

    looseDuplicateGroups += 1;
    looseDuplicateDocs += docs.length - 1;

    docs.sort((a, b) => {
      const aMs = tsToMillis(a.data()?.createdAt);
      const bMs = tsToMillis(b.data()?.createdAt);
      if (aMs !== bMs) return aMs - bMs;
      return a.id.localeCompare(b.id);
    });

    console.log(`[DUPLICATE CONTENT] ${key} | count=${docs.length}`);
    for (const doc of docs) {
      printDoc('  ', doc);
    }
    console.log('');
  }

  console.log('\n==================== SUMMARY ====================\n');
  console.log(`[SUMMARY] Duplicate slot groups: ${slotDuplicateGroups}`);
  console.log(`[SUMMARY] Duplicate slot extra docs: ${slotDuplicateDocs}`);
  console.log(`[SUMMARY] Duplicate content groups: ${looseDuplicateGroups}`);
  console.log(`[SUMMARY] Duplicate content extra docs: ${looseDuplicateDocs}`);
  console.log('\n[DONE] No documents changed.\n');
}

main().catch((err) => {
  console.error('\n[ERROR]', err);
  process.exit(1);
});