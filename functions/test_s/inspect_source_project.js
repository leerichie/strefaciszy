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
const SOURCE_PROJECT_ID = "jQgkVCPBhsdKcfidncB8";

(async () => {
  const ref = db
    .collection("customers")
    .doc(CUSTOMER_ID)
    .collection("projects")
    .doc(SOURCE_PROJECT_ID);

  const snap = await ref.get();

  if (!snap.exists) {
    console.log("❌ SOURCE NOT FOUND");
    process.exit(0);
  }

  const data = snap.data() || {};

  console.log("\n=== SOURCE PROJECT KEYS ===");
  Object.keys(data).forEach(k => console.log(k));

  console.log("\n=== RAW DATA ===");
  console.log(JSON.stringify(data, null, 2));

  process.exit(0);
})();