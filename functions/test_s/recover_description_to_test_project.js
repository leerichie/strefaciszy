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

// SOURCE (old/broken project)
const SOURCE_PROJECT_ID = "jQgkVCPBhsdKcfidncB8";

// TARGET (RECOVERED TEST project)
const TARGET_PROJECT_ID = "UzUOqfo6bSqmL9bXJdbf";

// ---- behaviour toggles ----
// If true: target.description/address/location/etc get replaced by source if present.
const OVERWRITE_SIMPLE_FIELDS = true;

// If true: do NOT overwrite the whole files/photos arrays; we only append missing.
const APPEND_FILES = true;
const APPEND_PHOTOS = true;

// If true: also copy your “current tabs” arrays (installer/coordination/changes notes/tasks).
// (You already wrote currentChangesNotes via RW recovery; leave false if you don't want to touch it.)
const COPY_CURRENT_TABS = false;

function cleanString(v) {
  if (typeof v !== "string") return null;
  const t = v.trim();
  return t.length ? t : "";
}

function isGeoPoint(v) {
  return v && typeof v.latitude === "number" && typeof v.longitude === "number";
}

function normalisePhotos(raw) {
  if (!Array.isArray(raw)) return [];
  return raw
    .filter((x) => typeof x === "string")
    .map((x) => x.trim())
    .filter(Boolean);
}

function normaliseFiles(raw) {
  if (!Array.isArray(raw)) return [];
  const out = [];
  for (const e of raw) {
    if (!e || typeof e !== "object") continue;
    const url = typeof e.url === "string" ? e.url.trim() : "";
    const name = typeof e.name === "string" ? e.name.trim() : "";
    if (!url || !name) continue;
    const bucket = typeof e.bucket === "string" ? e.bucket.trim() : "";
    const m = { url, name };
    if (bucket) m.bucket = bucket;
    out.push(m);
  }
  return out;
}

function fileKey(f) {
  // dedupe ignoring token=... changes
  // keep "path in storage" as key if possible
  try {
    const u = new URL(f.url);
    const p = u.pathname || "";
    // e.g. /v0/b/<bucket>/o/project_files%2F<proj>%2Ffile.jpg
    return (p + "|" + (f.name || "")).toLowerCase();
  } catch (_) {
    return ((f.url || "") + "|" + (f.name || "")).toLowerCase();
  }
}

function urlKey(u) {
  // dedupe photos ignoring token=...
  try {
    const x = new URL(u);
    return (x.pathname || "").toLowerCase();
  } catch (_) {
    return u.toLowerCase();
  }
}

(async () => {
  const sourceProjRef = db
    .collection("customers")
    .doc(CUSTOMER_ID)
    .collection("projects")
    .doc(SOURCE_PROJECT_ID);

  const targetProjRef = db
    .collection("customers")
    .doc(CUSTOMER_ID)
    .collection("projects")
    .doc(TARGET_PROJECT_ID);

  const [sSnap, tSnap] = await Promise.all([
    sourceProjRef.get(),
    targetProjRef.get(),
  ]);

  if (!sSnap.exists) throw new Error("SOURCE project not found");
  if (!tSnap.exists) throw new Error("TARGET project not found");

  const s = sSnap.data() || {};
  const t = tSnap.data() || {};

  console.log("✅ SOURCE:", sourceProjRef.path);
  console.log("✅ TARGET:", targetProjRef.path);

  // ---- Build payload ----
  const payload = {};

  // Description text (legacy fallback keys included)
  const srcDesc =
    (typeof s.description === "string" && s.description) ||
    (typeof s.desc === "string" && s.desc) ||
    (typeof s.projectDescription === "string" && s.projectDescription) ||
    null;

  if (OVERWRITE_SIMPLE_FIELDS && srcDesc !== null) {
    payload.description = srcDesc.trim();
  }

  // Address
  if (OVERWRITE_SIMPLE_FIELDS && typeof s.address === "string") {
    payload.address = s.address;
  }

  // Location (GeoPoint)
  if (OVERWRITE_SIMPLE_FIELDS && isGeoPoint(s.location)) {
    payload.location = new admin.firestore.GeoPoint(
      s.location.latitude,
      s.location.longitude
    );
  }

  // OneDrive URL
  if (OVERWRITE_SIMPLE_FIELDS && typeof s.oneDriveUrl === "string") {
    const od = s.oneDriveUrl.trim();
    payload.oneDriveUrl = od.length ? od : admin.firestore.FieldValue.delete();
  }

  // Archived flag (so editability matches)
  if (OVERWRITE_SIMPLE_FIELDS && (s.archived === true || s.archived === false)) {
    payload.archived = s.archived;
  }

  // DescriptionUpdatedAt
  if (OVERWRITE_SIMPLE_FIELDS && s.descriptionUpdatedAt && s.descriptionUpdatedAt.toDate) {
    payload.descriptionUpdatedAt = s.descriptionUpdatedAt;
  }

  // Photos array
  const srcPhotos = normalisePhotos(s.photos);
  const tgtPhotos = normalisePhotos(t.photos);

  if (srcPhotos.length) {
    if (APPEND_PHOTOS) {
      const tgtSet = new Set(tgtPhotos.map(urlKey));
      const merged = [...tgtPhotos];
      for (const u of srcPhotos) {
        if (!tgtSet.has(urlKey(u))) merged.push(u);
      }
      payload.photos = merged;
    } else {
      payload.photos = srcPhotos;
    }
  }

  // Files array
  const srcFiles = normaliseFiles(s.files);
  const tgtFiles = normaliseFiles(t.files);

  if (srcFiles.length) {
    if (APPEND_FILES) {
      const tgtSet = new Set(tgtFiles.map(fileKey));
      const merged = [...tgtFiles];
      for (const f of srcFiles) {
        if (!tgtSet.has(fileKey(f))) merged.push(f);
      }
      payload.files = merged;
    } else {
      payload.files = srcFiles;
    }
  }

  // Optional: also copy current tabs arrays
  if (COPY_CURRENT_TABS) {
    if (Array.isArray(s.currentInstaller)) payload.currentInstaller = s.currentInstaller;
    if (Array.isArray(s.currentCoordination)) payload.currentCoordination = s.currentCoordination;
    if (Array.isArray(s.currentChangesNotes)) payload.currentChangesNotes = s.currentChangesNotes;
    if (Array.isArray(s.currentChangesTasks)) payload.currentChangesTasks = s.currentChangesTasks;
  }

  // Safety: show what we will write
  const keys = Object.keys(payload);
  console.log("\n--- WILL WRITE KEYS ---");
  keys.forEach((k) => console.log("•", k));

  if (!keys.length) {
    console.log("\nNothing found to copy (source has no description/map/files/photos fields).");
    process.exit(0);
  }

  // Write (merge)
  await targetProjRef.set(
    {
      ...payload,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  console.log("\n✅ WROTE description/map/files/photos to RECOVERED TEST project.");
  process.exit(0);
})().catch((e) => {
  console.error("❌ ERROR:", e);
  process.exit(1);
});