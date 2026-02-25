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

(async () => {
  const snap = await db
    .collection("customers")
    .doc(CUSTOMER_ID)
    .collection("projects")
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();

  const hits = [];
  for (const doc of snap.docs) {
    const d = doc.data() || {};
    const title = (d.title || d.name || "").toString();
    if (title.toLowerCase().includes("awaria")) {
      hits.push({
        id: doc.id,
        title,
        createdAt: d.createdAt?.toDate?.()?.toISOString?.() || d.createdAt || null,
        status: d.status || null,
      });
    }
  }

  if (!hits.length) {
    console.log("❌ No AWARIA project found in latest 50 projects.");
    console.log("Try increasing limit or search manually in Firebase Console.");
    process.exit(1);
  }

  console.log("✅ AWARIA candidates:");
  hits.forEach((h, i) => {
    console.log(`${i + 1}. projectId=${h.id} | title="${h.title}" | createdAt=${h.createdAt} | status=${h.status}`);
  });

  process.exit(0);
})().catch((e) => {
  console.error("❌ ERROR:", e);
  process.exit(1);
});