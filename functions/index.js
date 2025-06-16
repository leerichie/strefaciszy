/* eslint-disable quotes, no-multi-spaces, require-jsdoc, max-len */

const functions = require('firebase-functions');
const admin     = require('firebase-admin');
admin.initializeApp();

<<<<<<< HEAD
// Helper: parse & verify the bearer token, and enforce admin
=======
>>>>>>> 027e8f4f7a9b33da39b80636990a8c0971b810ed
async function verifyAdmin(req, res) {
  const auth = req.header('Authorization') || '';
  const match = auth.match(/^Bearer (.+)$/);
  if (!match) {
    res.status(401).json({error: 'Unauthenticated'});
    return null;
  }

  let decoded;
  try {
    decoded = await admin.auth().verifyIdToken(match[1]);
  } catch (e) {
    res.status(401).json({error: 'Invalid token'});
    return null;
  }

  if (!decoded.admin) {
    res.status(403).json({error: 'Admin only'});
    return null;
  }

  return decoded.uid;
}

<<<<<<< HEAD
=======

>>>>>>> 027e8f4f7a9b33da39b80636990a8c0971b810ed
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
};

// 1) List users (up to 1000)
exports.listUsersHttp = functions.https.onRequest(async (req, res) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return res.status(204).set(corsHeaders).send('');
  }
  res.set(corsHeaders);

  const adminUid = await verifyAdmin(req, res);
  if (!adminUid) return;

  try {
    const list = await admin.auth().listUsers(1000);
    const results = await Promise.all(
        list.users.map(async (u) => {
          const snap = await admin.firestore().collection('users').doc(u.uid).get();
          return {
            uid: u.uid,
            email: u.email,
            role: snap.exists ? snap.data().role : 'user',
          };
        }),
    );
    return res.json(results);
  } catch (e) {
    console.error('Error listing users:', e);
    return res.status(500).json({error: 'Internal error'});
  }
});

// 2) Create a new user + Firestore role doc
exports.createUserHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    return res.status(204).set(corsHeaders).send('');
  }
  res.set(corsHeaders);

  const adminUid = await verifyAdmin(req, res);
  if (!adminUid) return;

<<<<<<< HEAD
  const {email, password, role} = req.body;
=======
  const {name, email, password, role} = req.body;
>>>>>>> 027e8f4f7a9b33da39b80636990a8c0971b810ed
  if (!email || !password || !role) {
    return res.status(400).json({error: 'Missing parameters'});
  }

  try {
<<<<<<< HEAD
    const user = await admin.auth().createUser({email, password});
    await admin.firestore().collection('users').doc(user.uid).set({role});
=======
    const user = await admin.auth().createUser({displayName: name, email, password});
    await admin.firestore().collection('users').doc(user.uid).set({name, role});
>>>>>>> 027e8f4f7a9b33da39b80636990a8c0971b810ed
    return res.json({uid: user.uid, email: user.email, role});
  } catch (e) {
    console.error('Error creating user:', e);
    return res.status(500).json({error: 'Internal error'});
  }
});

// 3) Update a user’s role
exports.updateUserRoleHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    return res.status(204).set(corsHeaders).send('');
  }
  res.set(corsHeaders);

  const adminUid = await verifyAdmin(req, res);
  if (!adminUid) return;

  const {uid, role} = req.body;
  if (!uid || !role) {
    return res.status(400).json({error: 'Missing parameters'});
  }

  try {
    await admin.firestore().collection('users').doc(uid).update({role});
    await admin.auth().setCustomUserClaims(uid, {admin: role === 'admin'});
    return res.json({uid, role});
  } catch (e) {
    console.error('Error updating role:', e);
    return res.status(500).json({error: 'Internal error'});
  }
});

// 4) Delete a user (Auth + Firestore)
exports.deleteUserHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    return res.status(204).set(corsHeaders).send('');
  }
  res.set(corsHeaders);

  const adminUid = await verifyAdmin(req, res);
  if (!adminUid) return;

  const {uid} = req.body;
  if (!uid) {
    return res.status(400).json({error: 'Missing uid'});
  }

  try {
    await admin.auth().deleteUser(uid);
    await admin.firestore().collection('users').doc(uid).delete();
    return res.json({uid});
  } catch (e) {
    console.error('Error deleting user:', e);
    return res.status(500).json({error: 'Internal error'});
  }
});
