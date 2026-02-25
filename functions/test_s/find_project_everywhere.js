/* eslint-disable no-console */
const admin = require("firebase-admin");
const path = require("path");

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.resolve("/Users/ashleyrichards/development/strefa_ciszy/strefaciszy/serviceAccountKey.json"))
  ),
});

const db = admin.firestore();

const PROJECT_ID = "jQgkVCPBhsdKcfidncB8";

// collection groups to probe (safe + common names)
const GROUPS = [
  "project_files",
  "projectPhotos",
  "project_photos",
  "photos",
  "files",
  "attachments",
  "uploads",
  "notes",
  "tasks",
  "todos",
  "events",
];

async function probeGroup(name) {
  try {
    const q = db.collectionGroup(name).where("projectId", "==", PROJECT_ID).limit(50);
    const snap = await q.get();
    if (snap.empty) return { name, count: 0 };

    const sample = snap.docs.slice(0, 5).map(d => ({
      path: d.ref.path,
      keys: Object.keys(d.data() || {}),
    }));

    return { name, count: snap.size, sample };
  } catch (e) {
    // if group doesn't exist, Firestore still returns empty;
    // errors usually mean index needed or permission/invalid query
    return { name, error: String(e.message || e) };
  }
}

(async () => {
  console.log("Searching for projectId across common collectionGroups...");
  const results = [];
  for (const g of GROUPS) {
    const r = await probeGroup(g);
    results.push(r);
  }

  // print only interesting groups
  for (const r of results) {
    if (r.error) {
      console.log(`- ${r.name}: ERROR: ${r.error}`);
      continue;
    }
    if (r.count > 0) {
      console.log(`\n✅ FOUND in collectionGroup "${r.name}": count=${r.count}`);
      for (const s of r.sample) {
        console.log(`  • ${s.path}`);
        console.log(`    keys: ${s.keys.join(", ")}`);
      }
    } else {
      console.log(`- ${r.name}: 0`);
    }
  }

  console.log("\nDone.");
  process.exit(0);
})().catch((e) => {
  console.error("❌ ERROR:", e);
  process.exit(1);
});