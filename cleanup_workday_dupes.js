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

function getCreatedAtMillis(data) {
  const v = data.createdAt;

  if (v && typeof v.toDate === 'function') {
    return v.toDate().getTime();
  }

  if (v instanceof Date) {
    return v.getTime();
  }

  if (typeof v === 'string') {
    const d = new Date(v);
    if (!Number.isNaN(d.getTime())) return d.getTime();
  }

  return 0;
}

function buildDupKey(data) {
  const userId = String(data.userId || '').trim();
  const dayKey = String(data.dayKey || '').trim();
  const startMinutes = Number.isFinite(Number(data.startMinutes))
    ? String(Number(data.startMinutes))
    : '-1';
  const endMinutes = Number.isFinite(Number(data.endMinutes))
    ? String(Number(data.endMinutes))
    : '-1';

  return `${userId}|${dayKey}|${startMinutes}|${endMinutes}`;
}

async function main() {
  const mode = (process.argv[2] || 'preview').trim().toLowerCase();

  if (!['preview', 'delete'].includes(mode)) {
    throw new Error('Mode must be either "preview" or "delete".');
  }

  initFirebase();

  const db = admin.firestore();

  console.log(`\n[START] work_day_logs duplicate cleanup mode = ${mode}\n`);

  const snap = await db.collection('work_day_logs').get();
  console.log(`[INFO] Total work_day_logs docs: ${snap.size}`);

  const groups = new Map();

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const key = buildDupKey(data);

    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(doc);
  }

  let duplicateGroups = 0;
  let duplicateDocs = 0;

  const deletions = [];

  for (const [key, docs] of groups.entries()) {
    if (docs.length <= 1) continue;

    duplicateGroups += 1;
    duplicateDocs += docs.length - 1;

    docs.sort((a, b) => {
      const aMs = getCreatedAtMillis(a.data() || {});
      const bMs = getCreatedAtMillis(b.data() || {});
      if (aMs != bMs) return aMs - bMs;
      return a.id.localeCompare(b.id);
    });

    const keeper = docs[0];
    const toDelete = docs.slice(1);

    console.log(`\n[DUPLICATE GROUP] ${key}`);
    console.log(`  KEEP   ${keeper.id}`);

    for (const d of toDelete) {
      console.log(`  DELETE ${d.id}`);
      deletions.push(d.ref);
    }
  }

  console.log(`\n[SUMMARY] Duplicate groups: ${duplicateGroups}`);
  console.log(`[SUMMARY] Duplicate docs to remove: ${duplicateDocs}`);

  if (mode === 'preview') {
    console.log('\n[PREVIEW ONLY] No documents were deleted.\n');
    return;
  }

  if (deletions.length === 0) {
    console.log('\n[DELETE] Nothing to delete.\n');
    return;
  }

  let batch = db.batch();
  let ops = 0;
  let committedDeletes = 0;

  for (const ref of deletions) {
    batch.delete(ref);
    ops += 1;
    committedDeletes += 1;

    if (ops >= 450) {
      await batch.commit();
      console.log(`[DELETE] Committed batch, deleted so far: ${committedDeletes}`);
      batch = db.batch();
      ops = 0;
    }
  }

  if (ops > 0) {
    await batch.commit();
  }

  console.log(`\n[DONE] Deleted duplicate docs: ${committedDeletes}\n`);
}

main().catch((err) => {
  console.error('\n[ERROR]', err);
  process.exit(1);
});