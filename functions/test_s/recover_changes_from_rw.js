/* eslint-disable no-console */
const admin = require("firebase-admin");
const path = require("path");
const crypto = require("crypto");

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.resolve("/Users/ashleyrichards/development/strefa_ciszy/strefaciszy/serviceAccountKey.json"))
  ),
});

const db = admin.firestore();

const CUSTOMER_ID = "ZMKVMtV3qnFPJC62EskY";
const PROJECT_ID  = "jQgkVCPBhsdKcfidncB8";

function sha1(s) {
  return crypto.createHash("sha1").update(String(s)).digest("hex");
}

function asDate(raw) {
  if (!raw) return null;
  if (raw.toDate) return raw.toDate();
  if (raw instanceof Date) return raw;
  if (typeof raw === "string") {
    const d = new Date(raw);
    return isNaN(d.getTime()) ? null : d;
  }
  return null;
}

function fmt(d) {
  if (!d) return "";
  return d.toISOString().replace("T", " ").replace("Z", "Z");
}

(async () => {
  const projRef = db
    .collection("customers").doc(CUSTOMER_ID)
    .collection("projects").doc(PROJECT_ID);

  const projSnap = await projRef.get();
  if (!projSnap.exists) {
    console.log("❌ Project not found:", projRef.path);
    process.exit(1);
  }

  const proj = projSnap.data() || {};
  const existing = Array.isArray(proj.currentChangesNotes) ? proj.currentChangesNotes : [];
  console.log("✅ PROJECT:", projRef.path);
  console.log("Existing currentChangesNotes:", existing.length);

  // Read rw_documents under this project
  const rwSnap = await projRef.collection("rw_documents").orderBy("createdAt", "asc").get();
  console.log("RW DOCS:", rwSnap.size);

  // Collect all notesList entries
  const rawNotes = [];
  rwSnap.docs.forEach((doc) => {
    const d = doc.data() || {};
    const notes = Array.isArray(d.notesList) ? d.notesList : [];
    notes.forEach((n) => {
      if (!n || typeof n !== "object") return;
      const text = (n.text || "").toString().trim();
      if (!text) return;
      rawNotes.push({
        text,
        userName: (n.userName || n.createdByName || "").toString().trim(),
        createdAt: asDate(n.createdAt) || asDate(d.createdAt),
        sourceRwId: doc.id,
      });
    });
  });

  rawNotes.sort((a, b) => (a.createdAt?.getTime() || 0) - (b.createdAt?.getTime() || 0));

  console.log("Total notesList entries found:", rawNotes.length);

  // Build recovered "plain text" entries for Zmiana tab
  // We store each RW note as ONE entry with text prefixed by [date] user:
  const seen = new Set();
  const recovered = [];

  for (const n of rawNotes) {
    const when = n.createdAt ? n.createdAt.toISOString() : "";
    const who = n.userName || "—";
    const line = `[${when}] ${who}: ${n.text}`;

    const key = sha1(`${when}||${who}||${n.text}`);
    if (seen.has(key)) continue;
    seen.add(key);

    recovered.push({
      id: `recovered_${key.slice(0, 12)}`,
      text: line,
      isTask: false,
      done: false,
      color: null,
      createdAt: n.createdAt ? admin.firestore.Timestamp.fromDate(n.createdAt) : null,
      updatedAt: n.createdAt ? admin.firestore.Timestamp.fromDate(n.createdAt) : null,
      createdByName: who,
      source: "rw_documents.notesList",
      sourceRwId: n.sourceRwId,
    });
  }

  console.log("Recovered entries to write into currentChangesNotes:", recovered.length);

  // Preview first + last
  console.log("\n--- PREVIEW (first 5) ---");
  recovered.slice(0, 5).forEach((e, i) => console.log(`${i + 1}. ${e.text.slice(0, 180)}`));

  console.log("\n--- PREVIEW (last 5) ---");
  recovered.slice(-5).forEach((e, i) => console.log(`${recovered.length - 4 + i}. ${e.text.slice(0, 180)}`));

  // Also show the newest timestamp we used (sanity check)
  const firstTs = recovered[0]?.createdAt?.toDate?.();
  const lastTs  = recovered[recovered.length - 1]?.createdAt?.toDate?.();
  console.log("\nRange:", fmt(firstTs), "->", fmt(lastTs));

  process.exit(0);
})().catch((e) => {
  console.error("❌ ERROR:", e);
  process.exit(1);
});