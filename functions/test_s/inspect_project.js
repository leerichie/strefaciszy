const admin = require("firebase-admin");

const path = require("path");

admin.initializeApp({
  credential: admin.credential.cert(
    require(path.resolve("/Users/ashleyrichards/development/strefa_ciszy/strefaciszy/serviceAccountKey.json"))
  ),
});

const db = admin.firestore();

const CUSTOMER_ID = "ZMKVMtV3qnFPJC62EskY";
const PROJECT_ID  = "jQgkVCPBhsdKcfidncB8";

function asDate(raw) {
  if (!raw) return null;
  if (raw.toDate) return raw.toDate();
  const d = new Date(raw);
  return isNaN(d.getTime()) ? null : d;
}

(async () => {
  const projRef = db
    .collection("customers")
    .doc(CUSTOMER_ID)
    .collection("projects")
    .doc(PROJECT_ID);

  const rwCol = projRef.collection("rw_documents");
  const snap = await rwCol.orderBy("createdAt", "asc").get();

  console.log(`RW DOCS: ${snap.size}`);

  let withNotes = 0;
  let totalNotes = 0;
  let totalItems = 0;

  const latestNotes = []; // collect last ~15 across all docs

  for (const doc of snap.docs) {
    const d = doc.data() || {};
    const notes = Array.isArray(d.notesList) ? d.notesList : [];
    const items = Array.isArray(d.items) ? d.items : [];

    if (notes.length) withNotes++;
    totalNotes += notes.length;
    totalItems += items.length;

    // pick newest few notes from this doc
    const sorted = [...notes].sort((a, b) => {
      const da = asDate(a?.createdAt)?.getTime() ?? 0;
      const dbb = asDate(b?.createdAt)?.getTime() ?? 0;
      return da - dbb;
    });

    for (const m of sorted.slice(-3)) {
      latestNotes.push({
        rwId: doc.id,
        when: asDate(m?.createdAt),
        user: (m?.userName || m?.createdByName || "").toString(),
        text: (m?.text || "").toString(),
        keys: Object.keys(m || {}),
      });
    }

    // quick sniff: see if RW doc has any obvious file/photo fields
    const topKeys = Object.keys(d);
    const suspicious = topKeys.filter((k) =>
      /file|photo|image|attach|storage|url/i.test(k)
    );
    if (suspicious.length) {
      console.log(`⚠️ RW ${doc.id} has suspicious top-level keys:`, suspicious);
    }
  }

  latestNotes.sort((a, b) => (a.when?.getTime() ?? 0) - (b.when?.getTime() ?? 0));

  console.log("RW with notesList:", withNotes);
  console.log("Total notes entries:", totalNotes);
  console.log("Total items rows:", totalItems);

  console.log("\nLATEST NOTES (last ~15 entries):");
  for (const n of latestNotes.slice(-15)) {
    const ts = n.when ? n.when.toISOString() : "—";
    const preview = n.text.replace(/\s+/g, " ").slice(0, 160);
    console.log(`- [${ts}] ${n.user} (${n.rwId}): ${preview}`);
  }

  process.exit(0);
})().catch((e) => {
  console.error("❌ ERROR:", e);
  process.exit(1);
});