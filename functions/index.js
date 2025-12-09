/* eslint-disable quotes, no-multi-spaces, require-jsdoc, max-len */

const {onDocumentWritten} = require("firebase-functions/v2/firestore");

const functions = require('firebase-functions');
const admin     = require('firebase-admin');
admin.initializeApp();

const ExcelJS   = require('exceljs');
const nodemailer = require('nodemailer');

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

// daily report
const smtpHost  = process.env.SMTP_HOST || null;
const smtpUser  = process.env.SMTP_USER || null;
const smtpPass  = process.env.SMTP_PASS || null;
const reportsTo = process.env.REPORTS_TO || null;

console.log('[SMTP config]', {
  host: smtpHost,
  user: smtpUser,
  passLen: smtpPass ? smtpPass.length : 0,
  reportsTo,
});

const mailTransporter =
  smtpHost && smtpUser && smtpPass ?
    nodemailer.createTransport({
      host: smtpHost,
      port: 465,
      secure: true,
      auth: {user: smtpUser, pass: smtpPass},
    }) :
    null;


// 1) List users
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

// 2) Create a new user + Firestore role doc + set custom claim
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

    await admin.firestore().collection('users').doc(user.uid)
        .set({name, email, role});

    await admin.auth().setCustomUserClaims(
        user.uid,
      role === 'admin' ? {admin: true} : {},
    );

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

exports.backfillProjects = onDocumentWritten(
    "contacts/{contactId}",
    async (event) => {
      const before = event.data.before.data() || {};
      const after  = event.data.after.data()  || {};

      if (!before.linkedCustomerId && after.linkedCustomerId) {
        const custId = after.linkedCustomerId;
        const db     = admin.firestore();
        const projsSnap = await db
            .collection("customers")
            .doc(custId)
            .collection("projects")
            .where("customerId", "==", custId)
            .get();

        const batch = db.batch();
        projsSnap.docs.forEach((doc) => {
          batch.update(doc.ref, {contactId: event.params.contactId});
        });
        await batch.commit();
      }
    },
);

// 6) End-of-day RW report -> Excel -> email
exports.sendDailyRwReportHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === "OPTIONS") {
    return res.status(204).set(corsHeaders).send("");
  }
  res.set(corsHeaders);

  const adminUid = await verifyAdmin(req, res);
  if (!adminUid) return;

  if (!mailTransporter || !reportsTo) {
    console.error("SMTP or reports.to not configured in .env");
    return res.status(500).json({error: "SMTP not configured"});
  }

  // ---- 1) Which day? (yyyy-MM-dd) ----
  let dayKey = req.body.dayKey;
  if (!dayKey || typeof dayKey !== "string") {
    dayKey = new Date().toISOString().slice(0, 10); // today
  }

  let y; let m; let d;
  try {
    [y, m, d] = dayKey.split("-").map((p) => parseInt(p, 10));
    if (!y || !m || !d) throw new Error("bad dayKey");
  } catch (e) {
    console.error("Bad dayKey:", dayKey, e);
    return res.status(400).json({error: "Invalid dayKey"});
  }

  const dayStartUtc = new Date(Date.UTC(y, m - 1, d, 0, 0, 0, 0));
  const dayEndUtc   = new Date(Date.UTC(y, m - 1, d, 23, 59, 59, 999));

  console.log(
      "[RW] Daily report – scanning createdAt between",
      dayStartUtc.toISOString(),
      "and",
      dayEndUtc.toISOString(),
  );

  try {
    const db = admin.firestore();

    const usersSnap = await db.collection("users").get();
    const userNames = {};
    usersSnap.forEach((doc) => {
      const u = doc.data() || {};
      userNames[doc.id] = u.name || u.username || u.email || doc.id;
    });

    // ---- 2) Fetch ALL rw_documents,
    const allSnap = await db.collectionGroup("rw_documents").get();
    console.log("[RW] total rw_documents in DB:", allSnap.size);

    const docsForDay = [];

    allSnap.forEach((doc) => {
      const dData = doc.data() || {};
      const rawCreated = dData.createdAt;

      let createdAt = null;
      if (rawCreated && rawCreated.toDate) {
        createdAt = rawCreated.toDate();
      } else if (typeof rawCreated === "string") {
        createdAt = new Date(rawCreated);
      }

      if (!createdAt) return;

      if (createdAt >= dayStartUtc && createdAt <= dayEndUtc) {
        docsForDay.push({
          ref: doc.ref,
          data: dData,
          createdAt,
        });
      }
    });

    console.log("[RW] rw_documents matching day:", docsForDay.length);

    if (docsForDay.length === 0) {
      return res.status(404).json({
        error: `Brak zapisanych dokumentów RW ${dayKey}`,
      });
    }

    docsForDay.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());

    //  3) Build Excel workbook
    const workbook = new ExcelJS.Workbook();
    const sheet = workbook.addWorksheet(`RW ${dayKey}`);

    sheet.columns = [
      {header: "Data",       key: "date",     width: 19},
      {header: "Typ",        key: "type",     width: 8},
      {header: "Klient",     key: "customer", width: 26},
      {header: "Projekt",    key: "project",  width: 30},
      {header: "Użytkownik", key: "user",     width: 20},
      {header: "Opis",       key: "desc",     width: 30},
      {header: "Producent",  key: "producer", width: 18},
      {header: "Model",      key: "name",     width: 24},
      {header: "Ilość",      key: "qty",      width: 10},
      {header: "Jm",         key: "unit",     width: 6},
      {header: "Notatki",    key: "notes",    width: 45},
    ];
    sheet.getRow(1).font = {bold: true};
    sheet.getColumn("qty").alignment  = {horizontal: "right"};
    sheet.getColumn("unit").alignment = {horizontal: "center"};

    const polish = new Intl.DateTimeFormat("pl-PL", {
      day: "2-digit",
      month: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

    docsForDay.forEach(({data: dData, createdAt}) => {
      const items    = Array.isArray(dData.items) ? dData.items : [];
      const notesRaw = Array.isArray(dData.notesList) ? dData.notesList : [];

      if (items.length === 0 && notesRaw.length === 0) {
        console.log("[RW] skipping empty doc", dData.id || "(no id)");
        return;
      }

      const dateStr  = polish.format(createdAt);
      const type     = dData.type || "RW";
      const customer = dData.customerName || "";
      const project  = dData.projectName || "";
      const creator  = dData.createdBy || "";
      const userName = userNames[creator] || creator;

      const notesList = [...notesRaw];
      notesList.sort((a, b) => {
        const ta = a.createdAt && a.createdAt.toDate ? a.createdAt.toDate() : null;
        const tb = b.createdAt && b.createdAt.toDate ? b.createdAt.toDate() : null;
        if (!ta || !tb) return 0;
        return ta.getTime() - tb.getTime();
      });

      const notesText = notesList
          .map((m) => {
            let noteDateStr = "";
            if (m.createdAt && m.createdAt.toDate) {
              noteDateStr = polish.format(m.createdAt.toDate());
            }
            const user   = (m.userName || "").toString();
            const action = (m.action || "").toString().trim();
            const text   = (m.text || "").toString();
            const actionPart = action ? `: ${action}` : "";
            return `[${noteDateStr}] ${user}${actionPart}: ${text}`;
          })
          .join("\n");

      if (items.length > 0) {
        let first = true;
        items.forEach((it) => {
          sheet.addRow({
            date: dateStr,
            type,
            customer,
            project,
            user: userName,
            desc: (it.description || "").toString(),
            producer: (it.producent  || "").toString(),
            name: (it.name       || "").toString(),
            qty: it.quantity != null ? Number(it.quantity) : "",
            unit: (it.unit       || "").toString(),
            notes: first ? notesText : "",
          });
          first = false;
        });
      } else {
        sheet.addRow({
          date: dateStr,
          type,
          customer,
          project,
          user: userName,
          desc: "",
          producer: "",
          name: "",
          qty: "",
          unit: "",
          notes: notesText,
        });
      }
    });

    const buffer   = await workbook.xlsx.writeBuffer();
    const fileName = `rw_raport_${dayKey}.xlsx`;

    await mailTransporter.sendMail({
      from: `"RAPORTY Strefa Ciszy" <${smtpUser}>`,
      to: reportsTo,
      subject: `Raport dzienny RW – ${dayKey}`,
      text: `W załączniku raport dzienny RW: ${dayKey}.`,
      attachments: [
        {
          filename: fileName,
          content: buffer,
        },
      ],
    });

    return res.json({
      ok: true,
      sentTo: reportsTo,
      count: docsForDay.length,
      dayKey,
    });
  } catch (err) {
    console.error("sendDailyRwReportHttp error", err);
    return res.status(500).json({error: "Internal error"});
  }
});
