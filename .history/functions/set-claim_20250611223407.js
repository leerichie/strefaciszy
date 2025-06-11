// functions/set-claim.js

const admin = require('firebase-admin');

// This will use the same default service account your Functions use:
admin.initializeApp();

async function main() {
  // Replace with your user’s UID
  const uid = 'xaqvUgZBSlUUxdV0k8mWtBDDA7v2';
  await admin.auth().setCustomUserClaims(uid, { admin: true });
  console.log(`✅ Admin claim set for UID=${uid}`);
  process.exit(0);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
