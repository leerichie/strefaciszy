/* eslint-disable quotes, no-multi-spaces, require-jsdoc, max-len */

const functions = require('firebase-functions');
const admin     = require('firebase-admin');
admin.initializeApp();

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

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
};

// 1) List users (up to 1000)
exports.listUsersHttp = functions.https.onRequest(async (req, res) => {
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
          const data = snap.data() || {};
          return {
            uid: u.uid,
            email: u.email,
            role: data.role || 'user',
            name: data.name || '—',
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

  const {name, email, password, role} = req.body;
  if (!name || !email || !password || !role) {
    return res.status(400).json({error: 'Missing parameters'});
  }

  try {
    const user = await admin.auth().createUser({displayName: name, email, password});
    await admin.firestore().collection('users').doc(user.uid).set({name, role});


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

// 5) Update user email and/or password
exports.updateUserDetailsHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    return res.status(204).set(corsHeaders).send('');
  }
  res.set(corsHeaders);

  const adminUid = await verifyAdmin(req, res);
  if (!adminUid) return;

  const {uid, name, email, password, role} = req.body;
  if (!uid) {
    return res.status(400).json({error: 'Missing uid'});
  }

  try {
    if (name) {
      await admin.firestore().collection('users').doc(uid).update({name});
    }
    if (email) {
      await admin.auth().updateUser(uid, {email});
    }
    if (password) {
      await admin.auth().updateUser(uid, {password});
    }
    if (role) {
      await admin.firestore().collection('users').doc(uid).update({role});
      await admin.auth().setCustomUserClaims(uid, {admin: role === 'admin'});
    }

    return res.json({uid, name, email, role});
  } catch (e) {
    console.error('Error updating user details:', e);
    return res.status(500).json({error: 'Internal error'});
  }
});
