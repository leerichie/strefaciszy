/* eslint-disable no-console */
const admin = require("firebase-admin");
const path = require("path");

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.resolve("/Users/ashleyrichards/development/strefa_ciszy/strefaciszy/serviceAccountKey.json"))
  ),
});


const db = admin.firestore();

const CUSTOMER_ID = "ZMKVMtV3qnFPJC62EskY";

// SOURCE (original project that “lost” UI data)
const SOURCE_PROJECT_ID = "jQgkVCPBhsdKcfidncB8";

// TARGET (your safe test project)
const TARGET_PROJECT_ID = "UzUOqfo6bSqmL9bXJdbf";

function asDate(raw) {
  if (!raw) return null;
  if (raw.toDate) return raw.toDate();
  if (typeof raw === "string") {
    const d = new Date(raw);
    return isNaN(d.getTime()) ? null : d;
  }
  if (raw instanceof Date) return raw;
  return null;
}

function makeId() {
  // Simple unique-ish id without extra deps
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}

(async () => {
  const sourceProjRef = db
    .collection("customers")
    .doc(CUSTOMER_ID)
    .collection("projects")
    .doc(SOURCE_PROJECT_ID);

  const targetProjRef = db
    .collection("customers")
    .doc(CUSTOMER_ID)
    .collection("projects")
    .doc(TARGET_PROJECT_ID);

  // --- sanity checks ---
  const [sSnap, tSnap] = await Promise.all([sourceProjRef.get(), targetProjRef.get()]);
  if (!sSnap.exists) throw new Error("SOURCE project not found");
  if (!tSnap.exists) throw new Error("TARGET project not found");

  console.log("✅ SOURCE:", sourceProjRef.path);
  console.log("✅ TARGET:", targetProjRef.path);

  // --- pull all RW docs for source project ---
  const rwSnap = await sourceProjRef.collection("rw_documents").get();
  console.log("RW DOCS:", rwSnap.size);

  const allNotes = [];

  rwSnap.forEach((doc) => {
    const d = doc.data() || {};
    const notes = Array.isArray(d.notesList) ? d.notesList : [];
    notes.forEach((n) => {
      if (!n || typeof n !== "object") return;

      const createdAt = asDate(n.createdAt);
      const text = (n.text || "").toString().trim();
      const userName = (n.userName || "").toString().trim();

      if (!createdAt || !text) return;

      allNotes.push({
        createdAt,
        text,
        userName,
      });
    });
  });

  allNotes.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());

  console.log("Total notes recovered:", allNotes.length);
  if (!allNotes.length) {
    console.log("Nothing to write. Exiting.");
    process.exit(0);
  }

  // --- convert into currentChangesNotes format (PLAIN TEXT entries) ---
  // These are NOT tasks. We set isTask=false so they render as normal notes.
  const recovered = allNotes.map((n) => ({
    id: makeId(),
    text: n.text,
    color: "black",
    isTask: false,
    done: false,
    createdAt: admin.firestore.Timestamp.fromDate(n.createdAt),
    createdBy: "",                 // unknown from rw note
    createdByName: n.userName || "—",
  }));

  // Preview
  console.log("\n--- PREVIEW first 3 ---");
  recovered.slice(0, 3).forEach((x, i) => {
    console.log(`${i + 1}. [${x.createdAt.toDate().toISOString()}] ${x.createdByName}: ${x.text.slice(0, 120)}`);
  });

  // --- IMPORTANT SAFETY: overwrite ONLY currentChangesNotes on the test project ---
  await targetProjRef.set(
    {
      currentChangesNotes: recovered,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  console.log("\n✅ WROTE currentChangesNotes to RECOVERED TEST project.");
  console.log("Target currentChangesNotes length:", recovered.length);

  process.exit(0);
})().catch((e) => {
  console.error("❌ ERROR:", e);
  process.exit(1);
});