/* eslint-disable quotes, no-multi-spaces, require-jsdoc, max-len */

const functions = require('firebase-functions');
const admin     = require('firebase-admin');
admin.initializeApp();

// Helper: check if caller is admin
async function assertAdmin(context) {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be signed in");
  }
  const token = await admin.auth().verifyIdToken(context.auth.token);
  if (!token.admin) {
    throw new functions.https.HttpsError("permission-denied", "Admin only");
  }
}

// 1) List users (up to 1000)
exports.listUsers = functions.https.onCall(async (data, context) => {
  console.log("🔥 listUsers invoked");
  console.log("🔥 context.auth:", context.auth);
  console.log("🔥 context.auth.token:", context.auth && context.auth.token);
  await assertAdmin(context);


  const list = await admin.auth().listUsers(1000);
  const results = await Promise.all(list.users.map(async (u) => {
    const snap = await admin.firestore().collection("users").doc(u.uid).get();
    return {
      uid: u.uid,
      email: u.email,
      role: (snap.exists && snap.data().role) || "user",
    };
  }));
  return results;
});

// 2) Create a new user + Firestore role doc
exports.createUser = functions.https.onCall(async (data, context) => {
  await assertAdmin(context);
  const {email, password, role} = data;
  const user = await admin.auth().createUser({email, password});
  await admin.firestore().collection("users").doc(user.uid).set({role});
  return {uid: user.uid, email: user.email, role};
});

// 3) Update a user’s role
exports.updateUserRole = functions.https.onCall(async (data, context) => {
  await assertAdmin(context);
  const {uid, role} = data;
  await admin.firestore().collection("users").doc(uid).update({role});
  await admin.auth().setCustomUserClaims(uid, {admin: role === "admin"});
  return {uid, role};
});

// 4) Delete a user (Auth + Firestore)
exports.deleteUser = functions.https.onCall(async (data, context) => {
  await assertAdmin(context);
  const {uid} = data;
  await admin.auth().deleteUser(uid);
  await admin.firestore().collection("users").doc(uid).delete();
  return {uid};
});
