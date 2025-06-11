const admin = require('firebase-admin');
const serviceAccount = require('../service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function main() {
  // 🚨 Replace with your admin user’s UID from Authentication → Users
  const uid = 'xaqvUgZBSlUUxdV0k8mWtBDDA7v2';
  await admin.auth().setCustomUserClaims(uid, { admin: true });
  console.log(`✅ Admin claim set for UID=${uid}`);
  process.exit(0);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
