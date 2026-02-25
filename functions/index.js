/* eslint-disable quotes, no-multi-spaces, require-jsdoc, max-len */

const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");

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
const reportsBcc = process.env.REPORTS_BCC || null;

console.log('[SMTP config]', {
  host: smtpHost,
  user: smtpUser,
  passLen: smtpPass ? smtpPass.length : 0,
  reportsTo,
  reportsBcc,
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

//  TODO tasks

function _asDate(raw) {
  if (!raw) return null;
  if (raw.toDate) return raw.toDate();
  if (typeof raw === 'string') {
    const d = new Date(raw);
    return isNaN(d.getTime()) ? null : d;
  }
  if (raw instanceof Date) return raw;
  return null;
}

function _buildNotesCellValue(lines) {
  const needsRich = lines.some((l) => {
    const c = (l.color || "").toLowerCase();
    const isTodo = (l.text || "").toString().startsWith("TODO");
    return c === "red" || c === "blue" || (isTodo && (c === "black" || c === "" || c == null));
  });

  if (!needsRich) {
    return lines.map((l) => l.text).join("\n");
  }

  const richText = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const text = (line.text || "").toString();
    const color = (line.color || "").toLowerCase();
    const isTodo = text.startsWith("TODO");

    let font;

    if (isTodo) {
      if (color === "red") {
        font = {color: {argb: "FFFF0000"}, bold: true};
      } else if (color === "blue") {
        font = {color: {argb: "FF0000FF"}, bold: true};
      } else {
        font = {bold: true};
      }
    }

    richText.push({
      text: text + (i === lines.length - 1 ? "" : "\n"),
      font,
    });
  }

  return {richText};
}

async function _getDoneTasksForDayFromProject({
  projectRef,
  dayStartUtc,
  dayEndUtc,
}) {
  try {
    const snap = await projectRef.get();
    if (!snap.exists) return [];

    const data = snap.data() || {};
    const raw = Array.isArray(data.currentChangesNotes) ? data.currentChangesNotes : [];

    const out = [];
    for (const e of raw) {
      if (!e || typeof e !== 'object') continue;
      if (e.isTask !== true) continue;
      if (e.done !== true) continue;

      const doneAt = _asDate(e.updatedAt) || _asDate(e.createdAt);
      if (!doneAt) continue;

      if (doneAt >= dayStartUtc && doneAt <= dayEndUtc) {
        out.push({
          id: (e.id || '').toString(),
          text: (e.text || '').toString().trim(),
          createdByName: (e.createdByName || '').toString().trim(),
          color: (e.color || '').toString().toLowerCase(),
          doneAt,
        });
      }
    }

    out.sort((a, b) => a.doneAt.getTime() - b.doneAt.getTime());
    return out;
  } catch (e) {
    console.error('[RW] failed to read currentChangesNotes for project:', projectRef.path, e);
    return [];
  }
}

// 6) End-of-day RW report -> Excel -> email
exports.sendDailyRwReportHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === "OPTIONS") {
    return res.status(204).set(corsHeaders).send("");
  }
  res.set(corsHeaders);

  const adminUid = await verifyAdmin(req, res);
  if (!adminUid) return;

  const body = (req.body && typeof req.body === "object") ? req.body : {};
  let {dayKey, to} = body;

  const overrideTo = (typeof to === "string" ? to.trim() : "");

  // decide final recipient
  const mainTo = overrideTo || reportsTo;

  if (!mailTransporter || !reportsTo) {
    console.error("SMTP or reports.to not configured in .env");
    return res.status(500).json({error: "SMTP not configured"});
  }

  // ---- 1) Which day? (yyyy-MM-dd) ----
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
      "to:", mainTo,
      "overrideTo?", !!overrideTo,
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

    // OLD block
    //  3) Build Excel workbook
    // const workbook = new ExcelJS.Workbook();
    // const sheet = workbook.addWorksheet(`RW ${dayKey}`);

    // sheet.columns = [
    //   {header: "Data",       key: "date",     width: 19},
    //   {header: "Typ",        key: "type",     width: 8},
    //   {header: "Klient",     key: "customer", width: 26},
    //   {header: "Projekt",    key: "project",  width: 30},
    //   {header: "Użytkownik", key: "user",     width: 20},
    //   {header: "Opis",       key: "desc",     width: 30},
    //   {header: "Producent",  key: "producer", width: 18},
    //   {header: "Model",      key: "name",     width: 24},
    //   {header: "Ilość",      key: "qty",      width: 10},
    //   {header: "Jm",         key: "unit",     width: 6},
    //   {header: "Notatki",    key: "notes",    width: 45},
    // ];
    // sheet.getRow(1).font = {bold: true};
    // sheet.getColumn("qty").alignment  = {horizontal: "right"};
    // sheet.getColumn("unit").alignment = {horizontal: "center"};

    // const polish = new Intl.DateTimeFormat("pl-PL", {
    //   day: "2-digit",
    //   month: "2-digit",
    //   year: "numeric",
    //   hour: "2-digit",
    //   minute: "2-digit",
    // });

    // docsForDay.forEach(({data: dData, createdAt}) => {
    //   const items    = Array.isArray(dData.items) ? dData.items : [];
    //   const notesRaw = Array.isArray(dData.notesList) ? dData.notesList : [];

    //   if (items.length === 0 && notesRaw.length === 0) {
    //     console.log("[RW] skipping empty doc", dData.id || "(no id)");
    //     return;
    //   }

    //   const dateStr  = polish.format(createdAt);
    //   const type     = dData.type || "RW";
    //   const customer = dData.customerName || "";
    //   const project  = dData.projectName || "";
    //   const creator  = dData.createdBy || "";
    //   const userName = userNames[creator] || creator;

    //   const notesList = [...notesRaw];
    //   notesList.sort((a, b) => {
    //     const ta = a.createdAt && a.createdAt.toDate ? a.createdAt.toDate() : null;
    //     const tb = b.createdAt && b.createdAt.toDate ? b.createdAt.toDate() : null;
    //     if (!ta || !tb) return 0;
    //     return ta.getTime() - tb.getTime();
    //   });

    //   const notesText = notesList
    //       .map((m) => {
    //         let noteDateStr = "";
    //         if (m.createdAt && m.createdAt.toDate) {
    //           noteDateStr = polish.format(m.createdAt.toDate());
    //         }
    //         const user   = (m.userName || "").toString();
    //         const action = (m.action || "").toString().trim();
    //         const text   = (m.text || "").toString();
    //         const actionPart = action ? `: ${action}` : "";
    //         return `[${noteDateStr}] ${user}${actionPart}: ${text}`;
    //       })
    //       .join("\n");

    //   if (items.length > 0) {
    //     let first = true;
    //     items.forEach((it) => {
    //       sheet.addRow({
    //         date: dateStr,
    //         type,
    //         customer,
    //         project,
    //         user: userName,
    //         desc: (it.description || "").toString(),
    //         producer: (it.producent  || "").toString(),
    //         name: (it.name       || "").toString(),
    //         qty: it.quantity != null ? Number(it.quantity) : "",
    //         unit: (it.unit       || "").toString(),
    //         notes: first ? notesText : "",
    //       });
    //       first = false;
    //     });
    //   } else {
    //     sheet.addRow({
    //       date: dateStr,
    //       type,
    //       customer,
    //       project,
    //       user: userName,
    //       desc: "",
    //       producer: "",
    //       name: "",
    //       qty: "",
    //       unit: "",
    //       notes: notesText,
    //     });
    //   }
    // });

    // TEST block

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

    const projectTasksCache = new Map();

    for (const {ref, data: dData, createdAt} of docsForDay) {
      const items    = Array.isArray(dData.items) ? dData.items : [];
      const notesRaw = Array.isArray(dData.notesList) ? dData.notesList : [];

      if (items.length === 0 && notesRaw.length === 0) {
        console.log("[RW] skipping empty doc", dData.id || "(no id)");
        continue;
      }

      const dateStr  = polish.format(createdAt);
      const type     = dData.type || "RW";
      const customer = dData.customerName || "";
      const project  = dData.projectName || "";
      const creator  = dData.createdBy || "";
      const userName = userNames[creator] || creator;

      const projectRef = ref.parent.parent;
      const cacheKey = projectRef.path;

      let doneTasks = projectTasksCache.get(cacheKey);
      if (!doneTasks) {
        doneTasks = await _getDoneTasksForDayFromProject({
          projectRef,
          dayStartUtc,
          dayEndUtc,
        });
        projectTasksCache.set(cacheKey, doneTasks);
      }

      const notesList = [...notesRaw];
      notesList.sort((a, b) => {
        const ta = a.createdAt && a.createdAt.toDate ? a.createdAt.toDate() : null;
        const tb = b.createdAt && b.createdAt.toDate ? b.createdAt.toDate() : null;
        if (!ta || !tb) return 0;
        return ta.getTime() - tb.getTime();
      });

      const exportLines = [];

      for (const t of doneTasks) {
        const who = t.createdByName ? ` • ${t.createdByName}` : "";
        exportLines.push({
          text: `TODO${who}: ${t.text}`,
          color: t.color || null,
        });
      }

      // for (const m of notesList) {
      //     let noteDateStr = "";
      //     if (m.createdAt && m.createdAt.toDate) {
      //       noteDateStr = polish.format(m.createdAt.toDate());
      //     }
      //     const user   = (m.userName || "").toString();
      //     const action = (m.action || "").toString().trim();
      //     const text   = (m.text || "").toString();
      //     const actionPart = action ? `: ${action}` : "";

      //     exportLines.push({
      //       text: `[${noteDateStr}] ${user}${actionPart}: ${text}`,
      //       color: null,
      //     });
      //   }

      const notesCellValue = _buildNotesCellValue(exportLines);

      if (items.length > 0) {
        let first = true;
        for (const it of items) {
          const row = sheet.addRow({
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
            notes: "",
          });

          if (first) {
            row.getCell(11).value = notesCellValue;
            row.getCell(11).alignment = {wrapText: true, vertical: "top"};
          }
          first = false;
        }
      } else {
        const row = sheet.addRow({
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
          notes: "",
        });

        row.getCell(11).value = notesCellValue;
        row.getCell(11).alignment = {wrapText: true, vertical: "top"};
      }
    }
    // end test
    const buffer   = await workbook.xlsx.writeBuffer();
    const fileName = `rw_raport_${dayKey}.xlsx`;

    await mailTransporter.sendMail({
      from: `"RAPORTY Strefa Ciszy" <${smtpUser}>`,
      to: mainTo,
      bcc: overrideTo ? undefined : (reportsBcc || undefined),
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
      sentTo: mainTo,
      usedOverride: !!overrideTo,
      count: docsForDay.length,
      dayKey,
    });
  } catch (err) {
    console.error("sendDailyRwReportHttp error", err);

    return res.status(500).json({
      error: "Internal error",
      details: (err && err.message) ? err.message : String(err),
    });
  }
});

// 7) Scheduled - runs every day at 23:55 (Europe/Warsaw)
exports.sendDailyRwReportScheduled = onSchedule(
    {
      schedule: "55 23 * * *",
      timeZone: "Europe/Warsaw",
    },
    async (event) => {
      if (!mailTransporter || !reportsTo) {
        console.error("sendDailyRwReportScheduled: SMTP or REPORTS_TO not configured in .env");
        return;
      }

      const dayKey = new Date().toISOString().slice(0, 10);

      let y; let m; let d;
      try {
        [y, m, d] = dayKey.split("-").map((p) => parseInt(p, 10));
        if (!y || !m || !d) throw new Error("bad dayKey");
      } catch (e) {
        console.error("sendDailyRwReportScheduled – Bad dayKey:", dayKey, e);
        return;
      }

      const dayStartUtc = new Date(Date.UTC(y, m - 1, d, 0, 0, 0, 0));
      const dayEndUtc   = new Date(Date.UTC(y, m - 1, d, 23, 59, 59, 999));

      console.log(
          "[RW scheduled] Daily report – scanning createdAt between",
          dayStartUtc.toISOString(),
          "and",
          dayEndUtc.toISOString(),
          "to:", reportsTo,
          "bcc:", reportsBcc,
      );

      try {
        const db = admin.firestore();

        // Build users map
        const usersSnap = await db.collection("users").get();
        const userNames = {};
        usersSnap.forEach((doc) => {
          const u = doc.data() || {};
          userNames[doc.id] = u.name || u.username || u.email || doc.id;
        });

        // Fetch ALL rw_documents
        const allSnap = await db.collectionGroup("rw_documents").get();
        console.log("[RW scheduled] total rw_documents in DB:", allSnap.size);

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

        console.log("[RW scheduled] rw_documents matching day:", docsForDay.length);

        if (docsForDay.length === 0) {
          console.log(`[RW scheduled] Brak zapisanych dokumentów RW ${dayKey} – nie wysyłam maila.`);
          return;
        }

        docsForDay.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());

        // OLD block
        // Build Excel
        // const workbook = new ExcelJS.Workbook();
        // const sheet = workbook.addWorksheet(`RW ${dayKey}`);

        // sheet.columns = [
        //   {header: "Data",       key: "date",     width: 19},
        //   {header: "Typ",        key: "type",     width: 8},
        //   {header: "Klient",     key: "customer", width: 26},
        //   {header: "Projekt",    key: "project",  width: 30},
        //   {header: "Użytkownik", key: "user",     width: 20},
        //   {header: "Opis",       key: "desc",     width: 30},
        //   {header: "Producent",  key: "producer", width: 18},
        //   {header: "Model",      key: "name",     width: 24},
        //   {header: "Ilość",      key: "qty",      width: 10},
        //   {header: "Jm",         key: "unit",     width: 6},
        //   {header: "Notatki",    key: "notes",    width: 45},
        // ];
        // sheet.getRow(1).font = {bold: true};
        // sheet.getColumn("qty").alignment  = {horizontal: "right"};
        // sheet.getColumn("unit").alignment = {horizontal: "center"};

        // const polish = new Intl.DateTimeFormat("pl-PL", {
        //   day: "2-digit",
        //   month: "2-digit",
        //   year: "numeric",
        //   hour: "2-digit",
        //   minute: "2-digit",
        // });

        // docsForDay.forEach(({data: dData, createdAt}) => {
        //   const items    = Array.isArray(dData.items) ? dData.items : [];
        //   const notesRaw = Array.isArray(dData.notesList) ? dData.notesList : [];

        //   if (items.length === 0 && notesRaw.length === 0) {
        //     console.log("[RW scheduled] skipping empty doc", dData.id || "(no id)");
        //     return;
        //   }

        //   const dateStr  = polish.format(createdAt);
        //   const type     = dData.type || "RW";
        //   const customer = dData.customerName || "";
        //   const project  = dData.projectName || "";
        //   const creator  = dData.createdBy || "";
        //   const userName = userNames[creator] || creator;

        //   const notesList = [...notesRaw];
        //   notesList.sort((a, b) => {
        //     const ta = a.createdAt && a.createdAt.toDate ? a.createdAt.toDate() : null;
        //     const tb = b.createdAt && b.createdAt.toDate ? b.createdAt.toDate() : null;
        //     if (!ta || !tb) return 0;
        //     return ta.getTime() - tb.getTime();
        //   });

        //   const notesText = notesList
        //       .map((m) => {
        //         let noteDateStr = "";
        //         if (m.createdAt && m.createdAt.toDate) {
        //           noteDateStr = polish.format(m.createdAt.toDate());
        //         }
        //         const user   = (m.userName || "").toString();
        //         const action = (m.action || "").toString().trim();
        //         const text   = (m.text || "").toString();
        //         const actionPart = action ? `: ${action}` : "";
        //         return `[${noteDateStr}] ${user}${actionPart}: ${text}`;
        //       })
        //       .join("\n");

        //   if (items.length > 0) {
        //     let first = true;
        //     items.forEach((it) => {
        //       sheet.addRow({
        //         date: dateStr,
        //         type,
        //         customer,
        //         project,
        //         user: userName,
        //         desc: (it.description || "").toString(),
        //         producer: (it.producent  || "").toString(),
        //         name: (it.name       || "").toString(),
        //         qty: it.quantity != null ? Number(it.quantity) : "",
        //         unit: (it.unit       || "").toString(),
        //         notes: first ? notesText : "",
        //       });
        //       first = false;
        //     });
        //   } else {
        //     sheet.addRow({
        //       date: dateStr,
        //       type,
        //       customer,
        //       project,
        //       user: userName,
        //       desc: "",
        //       producer: "",
        //       name: "",
        //       qty: "",
        //       unit: "",
        //       notes: notesText,
        //     });
        //   }
        // });

        // test block scheduled
        // Build Excel
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

        const projectTasksCache = new Map();

        for (const {ref, data: dData, createdAt} of docsForDay) {
          const items    = Array.isArray(dData.items) ? dData.items : [];
          const notesRaw = Array.isArray(dData.notesList) ? dData.notesList : [];

          if (items.length === 0 && notesRaw.length === 0) {
            console.log("[RW scheduled] skipping empty doc", dData.id || "(no id)");
            continue;
          }

          const dateStr  = polish.format(createdAt);
          const type     = dData.type || "RW";
          const customer = dData.customerName || "";
          const project  = dData.projectName || "";
          const creator  = dData.createdBy || "";
          const userName = userNames[creator] || creator;

          const projectRef = ref.parent.parent;
          const cacheKey = projectRef.path;

          let doneTasks = projectTasksCache.get(cacheKey);
          if (!doneTasks) {
            doneTasks = await _getDoneTasksForDayFromProject({
              projectRef,
              dayStartUtc,
              dayEndUtc,
            });
            projectTasksCache.set(cacheKey, doneTasks);
          }

          const notesList = [...notesRaw];
          notesList.sort((a, b) => {
            const ta = a.createdAt && a.createdAt.toDate ? a.createdAt.toDate() : null;
            const tb = b.createdAt && b.createdAt.toDate ? b.createdAt.toDate() : null;
            if (!ta || !tb) return 0;
            return ta.getTime() - tb.getTime();
          });

          const exportLines = [];

          for (const t of doneTasks) {
            const who = t.createdByName ? ` • ${t.createdByName}` : "";
            exportLines.push({
              text: `TODO${who}: ${t.text}`,
              color: t.color || null,
            });
          }

          for (const m of notesList) {
            let noteDateStr = "";
            if (m.createdAt && m.createdAt.toDate) {
              noteDateStr = polish.format(m.createdAt.toDate());
            }
            const user   = (m.userName || "").toString();
            const action = (m.action || "").toString().trim();
            const text   = (m.text || "").toString();
            const actionPart = action ? `: ${action}` : "";

            exportLines.push({
              text: `[${noteDateStr}] ${user}${actionPart}: ${text}`,
              color: null,
            });
          }

          const notesCellValue = _buildNotesCellValue(exportLines);

          if (items.length > 0) {
            let first = true;
            for (const it of items) {
              const row = sheet.addRow({
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
                notes: "",
              });

              if (first) {
                row.getCell(11).value = notesCellValue;
                row.getCell(11).alignment = {wrapText: true, vertical: "top"};
              }
              first = false;
            }
          } else {
            const row = sheet.addRow({
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
              notes: "",
            });
            row.getCell(11).value = notesCellValue;
            row.getCell(11).alignment = {wrapText: true, vertical: "top"};
          }
        }

        // end test

        const buffer   = await workbook.xlsx.writeBuffer();
        const fileName = `rw_raport_${dayKey}.xlsx`;

        await mailTransporter.sendMail({
          from: `"RAPORTY Strefa Ciszy" <${smtpUser}>`,
          to: reportsTo,
          bcc: reportsBcc || undefined,
          subject: `Raport dzienny RW – ${dayKey}`,
          text: `W załączniku raport dzienny RW: ${dayKey}.`,
          attachments: [
            {
              filename: fileName,
              content: buffer,
            },
          ],
        });

        console.log(
            "[RW scheduled] Report sent OK",
            {dayKey, to: reportsTo, bcc: reportsBcc, count: docsForDay.length},
        );
      } catch (err) {
        console.error("sendDailyRwReportScheduled error", err);
      }
    },
);

// PUSH - chat -> FCM

async function getUserTokens(uid) {
  const snap = await admin.firestore()
      .collection("users")
      .doc(uid)
      .collection("push_tokens")
      .get();

  return snap.docs.map((d) => d.id).filter(Boolean);
}

function uniq(arr) {
  return [...new Set(arr)];
}

// mentioned users
function extractMentionUids(msg) {
  const m = msg.mentions;
  if (Array.isArray(m)) {
    const uids = m
        .map((x) => (x && (x.uid || x.userId)) ? String(x.uid || x.userId) : null)
        .filter(Boolean);
    return uniq(uids);
  }
  return [];
}

exports.pushOnChatMessageCreate = onDocumentCreated(
    "chats/{chatId}/messages/{messageId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const {chatId, messageId} = event.params;
      const msg = snap.data() || {};

      const senderId = msg.senderId ? String(msg.senderId) : "";
      const text = (msg.text || "").toString().trim();

      const chatRef = admin.firestore().collection("chats").doc(chatId);
      const chatSnap = await chatRef.get();
      if (!chatSnap.exists) return;

      const chat = chatSnap.data() || {};
      const members = Array.isArray(chat.members) ? chat.members.map(String) : [];
      const type = (chat.type || (chatId === "global" ? "group" : "dm")).toString();

      // Decide recipients
      let recipients = [];

      if (type === "dm") {
        recipients = members.filter((uid) => uid && uid !== senderId);
      } else {
        const mentioned = extractMentionUids(msg);
        recipients = mentioned.filter((uid) => uid && uid !== senderId);
      }

      recipients = uniq(recipients);
      if (!recipients.length) return;

      // Collect tokens
      const tokenLists = await Promise.all(recipients.map(getUserTokens));
      const tokens = uniq(tokenLists.flat());
      if (!tokens.length) return;

      const title = "Strefa Ciszy";
      const body = text.length ? text : "📩 Nowa wiadomość";

      const multicast = {
        tokens,
        notification: {title, body},
        data: {
          eventType: "chat.message",
          chatId: String(chatId),
          messageId: String(messageId),
          senderId: senderId,
          chatType: type,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "chat",
            tag: String(chatId), // group notify
          },
        },
        apns: {
          headers: {
            "apns-thread-id": String(chatId), // groups iOS
          },
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        webpush: {
          headers: {Urgency: "high"},
          notification: {
            title,
            body,
            tag: String(chatId), // organised PUSH
            renotify: true,
          },
        },
      };

      // debug
      let resp;
      try {
        resp = await admin.messaging().sendEachForMulticast(multicast);
      } catch (e) {
        console.error("[PUSH] FCM send failed:", e);
        console.error("[PUSH] payload keys:", Object.keys(multicast));
        console.error("[PUSH] tokenCount:", (multicast.tokens || []).length);
        return;
      }

      // Cleanup invalid tokens
      const badTokens = [];
      resp.responses.forEach((r, i) => {
        if (!r.success) {
          const code = r.error && r.error.code ? String(r.error.code) : "";
          if (code.includes("registration-token-not-registered") ||
              code.includes("invalid-argument")) {
            badTokens.push(tokens[i]);
          }
        }
      });

      if (badTokens.length) {
        // Remove invalid tokens
        await Promise.all(recipients.map(async (uid) => {
          const batch = admin.firestore().batch();
          badTokens.forEach((t) => {
            const ref = admin.firestore()
                .collection("users").doc(uid)
                .collection("push_tokens").doc(t);
            batch.delete(ref);
          });
          await batch.commit();
        }));
      }

      console.log("[PUSH] chat message sent", {
        chatId,
        messageId,
        type,
        recipients: recipients.length,
        tokens: tokens.length,
        success: resp.successCount,
        fail: resp.failureCount,
      });
    },
);

