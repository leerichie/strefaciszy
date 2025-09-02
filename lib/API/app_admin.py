from flask import Flask, jsonify, request
from flask_cors import CORS
import pyodbc

import os, json, datetime, logging, re
from typing import Optional, Tuple

import firebase_admin
from firebase_admin import auth as fb_auth, credentials, firestore

# -----------------------------------------------------------------------------
# Flask + CORS
# -----------------------------------------------------------------------------
ALLOWED_ORIGINS = [
    "https://strefa-ciszy.web.app",
    "https://strefa-ciszy.firebaseapp.com",
    r"http://localhost:\d+",
    r"http://127\.0\.0\.1:\d+",
]

app = Flask(__name__)
CORS(
    app,
    resources={r"/api/*": {"origins": ALLOWED_ORIGINS}},  # covers /api/admin/* too
    supports_credentials=False,
    allow_headers=["Content-Type","Authorization","Cache-Control","X-Requested-With"],
    methods=["GET","POST","PUT","PATCH","DELETE","OPTIONS"],
)

app.logger.setLevel(logging.INFO)

# -----------------------------------------------------------------------------
# SQL Server connection
# -----------------------------------------------------------------------------
SERVER   = r"KASIA-BIURO\SQLEXPRESS"
DATABASE = "WAPRO"
USER     = "sc_app_admin"
PWD      = "Strefa1928!"
DRIVER   = "ODBC Driver 17 for SQL Server"

CONN_STR = (
    f"Driver={{{DRIVER}}};"
    f"Server={SERVER};"
    f"Database={DATABASE};"
    f"UID={USER};PWD={PWD};"
    "Encrypt=no;TrustServerCertificate=yes;"
)

def fetch_all(sql: str, params=()):
    """Run SELECT and return list[dict]."""
    with pyodbc.connect(CONN_STR) as conn:
        cur = conn.cursor()
        cur.execute(sql, params)
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]

def exec_nonquery(sql: str, params=()):
    """Run non-SELECT (INSERT/UPDATE/MERGE)."""
    with pyodbc.connect(CONN_STR) as conn:
        cur = conn.cursor()
        cur.execute(sql, params)
        conn.commit()

# -----------------------------------------------------------------------------
# Firebase Admin + approver check
# -----------------------------------------------------------------------------
_FIREBASE_APP = None
_FS = None

def _init_firebase():
    """Initialize Firebase Admin + Firestore once (uses ADC/service account)."""
    global _FIREBASE_APP, _FS
    if _FIREBASE_APP is not None and _FS is not None:
        return
    try:
        cred = credentials.ApplicationDefault()
        _FIREBASE_APP = firebase_admin.initialize_app(cred)
    except Exception:
        _FIREBASE_APP = firebase_admin.get_app()
    _FS = firestore.client()

def _is_approver(email: Optional[str], uid: Optional[str]) -> bool:
    """Check config/security for approverEmails / approverUids / approverDomains."""
    if _FS is None:
        _init_firebase()

    doc = _FS.collection("config").document("security").get()
    data = doc.to_dict() or {}

    emails  = {str(e).lower().strip() for e in (data.get("approverEmails")  or []) if isinstance(e, str)}
    uids    = {str(u).strip()          for u in (data.get("approverUids")    or []) if isinstance(u, str)}
    domains = {str(d).lower().strip()  for d in (data.get("approverDomains") or []) if isinstance(d, str)}

    ok_email = False
    if email:
        em = email.lower()
        ok_email = (em in emails) or any(dom and em.endswith(dom) for dom in domains)

    ok_uid = bool(uid and uid in uids)
    return ok_email or ok_uid

# -----------------------------------------------------------------------------
# Health
# -----------------------------------------------------------------------------
@app.get("/api/admin/health")
def health_admin():
    return jsonify({"status": "ok"}), 200

@app.get("/api/health")
def health_plain():
    return jsonify({"ok": True, "service": "admin", "ts": datetime.datetime.utcnow().isoformat() + "Z"}), 200

# -----------------------------------------------------------------------------
# /api/commit (unchanged functional behavior)
# -----------------------------------------------------------------------------
@app.post("/api/commit")
def commit_project_items():
    auth_header = request.headers.get("Authorization") or request.headers.get("authorization") or ""
    token = ""
    if auth_header.lower().startswith("bearer "):
        token = auth_header.split(" ", 1)[1].strip()
    if not token:
        return jsonify({"ok": False, "error": "missing-token"}), 401

    try:
        _init_firebase()
        decoded = fb_auth.verify_id_token(token)
    except Exception as e:
        app.logger.exception("verify_id_token failed")
        return jsonify({"ok": False, "error": f"invalid-token: {e}"}), 401

    email = (decoded.get("email") or "").lower()
    uid   = decoded.get("uid")

    if not _is_approver(email, uid):
        return jsonify({"ok": False, "error": "not-approver"}), 403

    data = request.get_json(force=True) or {}
    customer_id = (data.get("customerId") or "").strip()
    project_id  = (data.get("projectId")  or "").strip()
    items       = data.get("items") or []
    dry_run     = bool(data.get("dryRun", False))

    if not project_id or not isinstance(items, list) or not items:
        return jsonify({"ok": False, "error": "bad-payload"}), 400

    lines = []
    for it in items:
        if not isinstance(it, dict):
            continue
        try:
            qty = int(it.get("qty") or 0)
        except Exception:
            qty = 0
        if qty <= 0:
            continue
        lines.append({
            "itemId":   (it.get("itemId") or "").strip(),
            "qty":      qty,
            "unit":     (it.get("unit") or "szt"),
            "name":     (it.get("name") or ""),
            "producer": (it.get("producer") or ""),
        })

    if not lines:
        return jsonify({"ok": False, "error": "no-valid-lines"}), 400

    # DRY RUN
    if dry_run or os.getenv("SC_DRYRUN") == "1":
        doc_id = f"DRYRUN-{project_id[:6]}-{int(datetime.datetime.utcnow().timestamp())}"
        return jsonify({"ok": True, "docId": doc_id, "dryRun": True}), 200

    conn = None
    try:
        conn = pyodbc.connect(CONN_STR)
        conn.autocommit = False
        cur = conn.cursor()

        try:
            cur.execute("""
IF OBJECT_ID('dbo.APP_COMMIT_LOG') IS NULL
BEGIN
  CREATE TABLE dbo.APP_COMMIT_LOG(
    id           INT IDENTITY(1,1) PRIMARY KEY,
    project_id   NVARCHAR(64),
    customer_id  NVARCHAR(64),
    actor_email  NVARCHAR(256),
    created_at   DATETIME2(0) DEFAULT SYSUTCDATETIME(),
    payload      NVARCHAR(MAX)
  );
END
""")
        except Exception:
            pass

        payload_str = json.dumps(lines, ensure_ascii=False)

        cur.execute("""
INSERT INTO dbo.APP_COMMIT_LOG(project_id, customer_id, actor_email, payload)
OUTPUT INSERTED.id
VALUES (?, ?, ?, ?)
""", project_id, customer_id, email, payload_str)
        row = cur.fetchone()
        new_id = row[0] if row else None

        conn.commit()

        doc_id = f"LOG-{new_id}" if new_id is not None else f"LOG-{int(datetime.datetime.utcnow().timestamp())}"
        return jsonify({"ok": True, "docId": doc_id}), 200

    except Exception as e:
        app.logger.exception("commit_project_items failed")
        try:
            if conn:
                conn.rollback()
        except Exception:
            pass
        return jsonify({"ok": False, "error": f"commit-failed: {e}"}), 500
    finally:
        try:
            if conn:
                conn.close()
        except Exception:
            pass

# -----------------------------------------------------------------------------
# Normalization (unchanged)
# -----------------------------------------------------------------------------
@app.post("/api/sync/preview")
def sync_preview():
    data = request.get_json(force=True) or {}
    pid = data.get("id")
    if not pid:
        return {"error": "id required"}, 400

    sql = """
MERGE dbo.APP_PRODUCT_NORMALIZED AS T
USING (SELECT CAST(? AS NUMERIC(18,0)) AS id_artykulu) AS S
ON (T.id_artykulu = S.id_artykulu)
WHEN MATCHED THEN UPDATE SET
  normalized_name        = ?,
  normalized_producent   = ?,
  normalized_category    = ?,
  normalized_description = ?,
  proposed_by            = ?,
  proposed_at            = SYSUTCDATETIME(),
  approved               = 0,
  approved_by            = NULL,
  approved_at            = NULL
WHEN NOT MATCHED THEN
INSERT (id_artykulu, normalized_name, normalized_producent, normalized_category,
        normalized_description, proposed_by)
VALUES (S.id_artykulu, ?, ?, ?, ?, ?);
"""
    params = [
        pid,
        data.get("normalized_name"),
        data.get("normalized_producent"),
        data.get("normalized_category"),
        data.get("normalized_description"),
        data.get("proposed_by"),
        data.get("normalized_name"),
        data.get("normalized_producent"),
        data.get("normalized_category"),
        data.get("normalized_description"),
        data.get("proposed_by"),
    ]
    exec_nonquery(sql, params)
    return {"status": "staged"}, 200

@app.get("/api/sync/diff/<pid>")
def sync_diff(pid):
    current_sql = """
IF OBJECT_ID('dbo.APP_PRODUCTS_SNAPSHOT','V') IS NOT NULL
BEGIN
  SELECT * FROM dbo.APP_PRODUCTS_SNAPSHOT WHERE id_artykulu = ?
END
ELSE
BEGIN
  WITH base AS (
    SELECT
      A.ID_ARTYKULU                               AS id_artykulu,
      COALESCE(NULLIF(WA.Nazwa1,''), A.NAZWA, '') AS name,
      COALESCE(NULLIF(WA.Nazwa2,''), '')          AS cat_desc,
      COALESCE(NULLIF(WA.Producent,''), A.PRODUCENT, '') AS producent,
      COALESCE(
        NULLIF(WA.NrKatalogowy,''), NULLIF(A.INDEKS_KATALOGOWY,''), NULLIF(A.INDEKS_HANDLOWY,''),
        ''
      )                                           AS sku,
      A.KOD_KRESKOWY                              AS barcode_fallback,
      WA.JednostkaSprzedazy                       AS unit_fallback
    FROM dbo.ARTYKUL A
    LEFT JOIN dbo.WIDOK_ARTYKUL WA
      ON WA.IdArtykulu = A.ID_ARTYKULU
  ),
  qty AS (
    SELECT
      SM.id_artykulu,
      SUM(CASE WHEN SM.stan IS NULL THEN 0 ELSE CAST(SM.stan AS DECIMAL(18,3)) END) AS quantity,
      MAX(NULLIF(SM.skrot,'')) AS unit
    FROM dbo.JLVIEW_STANMAGAZYNU_RAP AS SM
    GROUP BY SM.id_artykulu
  ),
  bar AS (
    SELECT
      E.ID_ARTYKULU AS id_artykulu,
      MAX(NULLIF(E.KOD_KRESKOWY,'')) AS barcode
    FROM dbo.ART_ECR_MAG_V AS E
    GROUP BY E.ID_ARTYKULU
  )
  SELECT TOP 1
    B.id_artykulu,
    CAST(B.name AS VARCHAR(100))       AS name,
    CAST(B.cat_desc AS VARCHAR(100))   AS cat_desc,
    CAST(B.producent AS VARCHAR(50))   AS producent,
    CAST(B.sku AS VARCHAR(20))         AS sku,
    COALESCE(CAST(Bar.barcode AS VARCHAR(20)), CAST(B.barcode_fallback AS VARCHAR(20)), '') AS barcode,
    CAST(COALESCE(Q.quantity, CAST(0 AS DECIMAL(18,3))) AS DECIMAL(18,3)) AS quantity,
    COALESCE(CAST(Q.unit AS VARCHAR(10)), CAST(B.unit_fallback AS VARCHAR(10)), '') AS unit
  FROM base AS B
  LEFT JOIN qty  AS Q   ON Q.id_artykulu = B.id_artykulu
  LEFT JOIN bar  AS Bar ON Bar.id_artykulu = B.id_artykulu
  WHERE B.id_artykulu = ?
END
"""
    current_rows = fetch_all(current_sql, (pid, pid))
    current = current_rows[0] if current_rows else {}

    proposed_sql = """
SELECT id_artykulu, normalized_name, normalized_producent, normalized_category,
       normalized_description, approved, proposed_by, proposed_at,
       approved_by, approved_at
FROM dbo.APP_PRODUCT_NORMALIZED
WHERE id_artykulu = ?
"""
    proposed_rows = fetch_all(proposed_sql, (pid,))
    proposed = proposed_rows[0] if proposed_rows else {}

    return {
        "id": pid,
        "current": {
            "name": current.get("name"),
            "producent": current.get("producent"),
            "category": current.get("cat_desc"),
            "description": current.get("cat_desc"),
            "sku": current.get("sku"),
            "barcode": current.get("barcode"),
        },
        "proposed": {
            "name": proposed.get("normalized_name"),
            "producent": proposed.get("normalized_producent"),
            "category": proposed.get("normalized_category"),
            "description": proposed.get("normalized_description"),
            "approved": proposed.get("approved"),
            "proposed_by": proposed.get("proposed_by"),
            "proposed_at": str(proposed.get("proposed_at")) if proposed.get("proposed_at") else None,
        }
    }, 200

@app.post("/api/sync/apply")
def sync_apply():
    data = request.get_json(force=True) or {}
    ids = data.get("ids") or []
    approved_by = data.get("approved_by") or "system"

    if not ids:
        return {"error": "ids required"}, 400

    placeholders = ",".join("?" for _ in ids)

    approve_sql = f"""
UPDATE dbo.APP_PRODUCT_NORMALIZED
SET approved = 1, approved_by = ?, approved_at = SYSUTCDATETIME()
WHERE id_artykulu IN ({placeholders})
"""
    exec_nonquery(approve_sql, [approved_by, *ids])

    with pyodbc.connect(CONN_STR) as conn:
        cur = conn.cursor()
        cur.execute("EXEC dbo.APP_APPLY_NORMALIZED @approvedBy = ?", (approved_by,))
        conn.commit()

    return {"status": "applied", "count": len(ids)}, 200

@app.get("/api/sync/pending")
def sync_pending():
    sql = """
SELECT id_artykulu, normalized_name, normalized_producent, normalized_category,
       normalized_description, proposed_by, proposed_at, approved
FROM dbo.APP_PRODUCT_NORMALIZED
WHERE approved = 0
ORDER BY proposed_at DESC
"""
    return jsonify(fetch_all(sql))

# -----------------------------------------------------------------------------
# Minimal product create (unchanged)
# -----------------------------------------------------------------------------
@app.post("/api/products")
def create_product():
    data = request.get_json(force=True) or {}

    name      = (data.get("name") or "TEST PRODUCT DO NOT USE").strip()
    producent = (data.get("producent") or "TEST").strip()
    sku       = (data.get("sku") or "TESTSKU").strip()
    barcode   = (data.get("barcode") or "9999999999999").strip()

    try:
        with pyodbc.connect(CONN_STR) as conn:
            conn.autocommit = False
            cur = conn.cursor()

            cur.execute("""
SELECT ISNULL(MAX(ID_ARTYKULU), 0) + 1
FROM dbo.ARTYKUL WITH (TABLOCKX, HOLDLOCK)
""")
            new_id = int(cur.fetchone()[0])

            cur.execute("""
INSERT INTO dbo.ARTYKUL (ID_ARTYKULU, NAZWA, PRODUCENT, INDEKS_HANDLOWY, KOD_KRESKOWY)
VALUES (?, ?, ?, ?, ?)
""", (new_id, name, producent, sku, barcode))

            conn.commit()

        return {
            "status": "created",
            "id": new_id,
            "name": name,
            "producent": producent,
            "sku": sku,
            "barcode": barcode,
            "quantity": 0
        }, 201

    except Exception as e:
        app.logger.exception("create_product failed")
        return {"error": "insert failed", "detail": str(e)}, 500

# -----------------------------------------------------------------------------
# EAN helpers + endpoints (unchanged)
# -----------------------------------------------------------------------------
def _ean_digits(s: str) -> str:
    return re.sub(r"\D+", "", s or "")

def _ean_checksum_ok(ean: str) -> bool:
    d = _ean_digits(ean)
    if len(d) not in (8, 13):
        return False
    nums = [int(c) for c in d]
    check = nums[-1]
    body = nums[:-1]
    if len(d) == 13:
        s = sum((n if i % 2 == 0 else n * 3) for i, n in enumerate(body))
    else:
        s = sum((n * 3 if i % 2 == 0 else n) for i, n in enumerate(body))
    return (10 - (s % 10)) % 10 == check

def _ean_valid(ean: str) -> bool:
    d = _ean_digits(ean)
    return d in ("",) or _ean_checksum_ok(d)

def _ean_in_use(cur, ean: str, exclude_id: str) -> Optional[str]:
    cur.execute(
        """
WITH all_eans AS (
  SELECT CAST(A.ID_ARTYKULU AS NVARCHAR(50)) AS id, LTRIM(RTRIM(COALESCE(NULLIF(A.KOD_KRESKOWY,''), ''))) AS e
  FROM dbo.ARTYKUL AS A
  UNION ALL
  SELECT CAST(E.ID_ARTYKULU AS NVARCHAR(50)) AS id, LTRIM(RTRIM(COALESCE(NULLIF(E.KOD_KRESKOWY,''), ''))) AS e
  FROM dbo.ART_ECR_MAG_V AS E
)
SELECT TOP 1 id
FROM all_eans
WHERE e = ? AND id <> ?
""",
        (ean, str(exclude_id)),
    )
    row = cur.fetchone()
    return (row[0] if row and row[0] else None)

def digits_only(s: Optional[str]) -> str:
    return ''.join(ch for ch in (s or '') if ch.isdigit())

def ensure_override_table():
    exec_nonquery("""
IF OBJECT_ID('dbo.APP_EAN_OVERRIDE') IS NULL
BEGIN
  CREATE TABLE dbo.APP_EAN_OVERRIDE(
    id_artykulu  NVARCHAR(50) NOT NULL PRIMARY KEY,
    override_ean NVARCHAR(20) NULL,
    updated_by   NVARCHAR(256) NULL,
    updated_at   DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
  );
END
""")

def get_wapro_ean_for_id(pid: str) -> str:
    rows = fetch_all("""
SELECT TOP 1
  COALESCE(
    NULLIF((
      SELECT MAX(COALESCE(NULLIF(E.KOD_KRESKOWY,''), ''))
      FROM dbo.ART_ECR_MAG_V E WHERE E.ID_ARTYKULU = A.ID_ARTYKULU
    ), ''),
    NULLIF(A.KOD_KRESKOWY, ''),
    ''
  ) AS wapro_ean
FROM dbo.ARTYKUL A
WHERE CAST(A.ID_ARTYKULU AS NVARCHAR(50)) = ?
""", (pid,))
    return (rows[0].get("wapro_ean") if rows else "") or ""

def get_override_row(pid: str) -> Tuple[str, Optional[str], Optional[str]]:
    rows = fetch_all("""
SELECT
  COALESCE(override_ean,'') AS override_ean,
  COALESCE(updated_by,'')   AS updated_by,
  CONVERT(VARCHAR(19), updated_at, 126) AS updated_at
FROM dbo.APP_EAN_OVERRIDE
WHERE id_artykulu = ?
""", (pid,))
    if not rows:
        return ("", None, None)
    r = rows[0]
    return (r.get("override_ean") or "", r.get("updated_by") or None, r.get("updated_at") or None)

def compute_status(wapro_ean: str, override_ean: str) -> Tuple[str, str]:
    if (wapro_ean or "").strip():
        return (wapro_ean, "LOCKED_WAPRO")
    if (override_ean or "").strip():
        return (override_ean, "OVERRIDDEN")
    return ("", "EMPTY")

@app.post("/api/admin/ean/setup")
def admin_ean_setup():
    ensure_override_table()
    return jsonify({"ok": True, "table": "APP_EAN_OVERRIDE"}), 200

@app.get("/api/admin/products/<pid>/ean")
def admin_get_ean(pid):
    wapro_ean = get_wapro_ean_for_id(pid)
    try:
        override_ean, updated_by, updated_at = get_override_row(pid)
    except Exception:
        override_ean, updated_by, updated_at = ("", None, None)

    effective, status = compute_status(wapro_ean, override_ean)
    return jsonify({
        "id": pid,
        "wapro_ean": wapro_ean,
        "override_ean": override_ean,
        "effective_ean": effective,
        "status": status,
        "updated_by": updated_by,
        "updated_at": updated_at,
    }), 200

@app.get("/api/products/<pid>/ean")
def get_product_ean_plain(pid):
    ean = get_wapro_ean_for_id(pid)
    return jsonify({"id": str(pid), "ean": ean}), 200

@app.patch("/api/admin/products/<pid>/ean")
def admin_set_override_ean(pid):
    data = request.get_json(force=True) or {}
    raw = (data.get("ean") or data.get("barcode") or "").strip()
    updated_by = (data.get("updated_by") or "api").strip()

    wapro_ean = get_wapro_ean_for_id(pid)
    if wapro_ean:
        return jsonify({
            "ok": False,
            "error": "ean-managed-by-wapro",
            "wapro_ean": wapro_ean
        }), 409

    ensure_override_table()

    norm = digits_only(raw)
    with pyodbc.connect(CONN_STR) as conn:
        cur = conn.cursor()
        if norm == "":
            cur.execute("""
MERGE dbo.APP_EAN_OVERRIDE AS T
USING (SELECT CAST(? AS NVARCHAR(50)) AS id_artykulu) AS S
ON (T.id_artykulu = S.id_artykulu)
WHEN MATCHED THEN UPDATE SET override_ean = NULL, updated_by = ?, updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
  INSERT (id_artykulu, override_ean, updated_by)
  VALUES (S.id_artykulu, NULL, ?);
""", (pid, updated_by, updated_by))
        else:
            cur.execute("""
MERGE dbo.APP_EAN_OVERRIDE AS T
USING (SELECT CAST(? AS NVARCHAR(50)) AS id_artykulu) AS S
ON (T.id_artykulu = S.id_artykulu)
WHEN MATCHED THEN UPDATE SET override_ean = ?, updated_by = ?, updated_at = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
  INSERT (id_artykulu, override_ean, updated_by)
  VALUES (S.id_artykulu, ?, ?);
""", (pid, norm, updated_by, norm, updated_by))
        conn.commit()

    override_ean, upd_by, upd_at = get_override_row(pid)
    effective, status = compute_status("", override_ean)
    return jsonify({
        "ok": True,
        "id": pid,
        "override_ean": override_ean,
        "effective_ean": effective,
        "status": status,
        "updated_by": upd_by,
        "updated_at": upd_at,
    }), 200

@app.post("/api/admin/commit")
def _alias_admin_commit():
    return commit_project_items()

@app.post("/api/admin/sync/preview")
def _alias_admin_sync_preview():
    return sync_preview()

@app.post("/api/admin/sync/apply")
def _alias_admin_sync_apply():
    return sync_apply()

@app.get("/api/admin/sync/pending")
def _alias_admin_sync_pending():
    return sync_pending()

@app.post("/api/admin/reservations/upsert")
def _alias_admin_res_upsert():
    return reservations_upsert()

@app.put("/api/admin/products/<pid>/ean")
def admin_put_ean(pid):
    return set_product_ean(pid)

@app.put("/api/products/<pid>/ean")
def set_product_ean(pid):
    data = request.get_json(force=True) or {}
    raw = (data.get("ean") or "").strip()
    ean = _ean_digits(raw)

    if not ean:
        return jsonify({"ok": False, "error": "missing-ean"}), 400
    if not _ean_checksum_ok(ean):
        return jsonify({"ok": False, "error": "bad-ean"}), 400

    conn = None
    try:
        conn = pyodbc.connect(CONN_STR)
        conn.autocommit = False
        cur = conn.cursor()

        cur.execute(
            """
SELECT TOP 1
  LTRIM(RTRIM(
    COALESCE(
      NULLIF(E.KOD_KRESKOWY,''), NULLIF(A.KOD_KRESKOWY,''), ''
    )
  )) AS current_ean
FROM dbo.ARTYKUL AS A
LEFT JOIN dbo.ART_ECR_MAG_V AS E
  ON E.ID_ARTYKULU = A.ID_ARTYKULU
WHERE A.ID_ARTYKULU = ?
""",
            (pid,),
        )
        row = cur.fetchone()
        current = (row[0] if row else "") or ""
        if current:
            conn.rollback()
            return jsonify({"ok": False, "error": "already-set", "current": current}), 409

        conflict_id = _ean_in_use(cur, ean, str(pid))
        if conflict_id:
            conn.rollback()
            return jsonify({"ok": False, "error": "duplicate-ean", "conflictId": str(conflict_id)}), 409

        cur.execute(
            """
UPDATE dbo.ARTYKUL
   SET KOD_KRESKOWY = ?
 WHERE ID_ARTYKULU = ?
   AND (KOD_KRESKOWY IS NULL OR LTRIM(RTRIM(KOD_KRESKOWY)) = '')
""",
            (ean, pid),
        )
        if cur.rowcount != 1:
            conn.rollback()
            return jsonify({"ok": False, "error": "already-set-race"}), 409

        conn.commit()
        return jsonify({"ok": True, "id": str(pid), "ean": ean}), 200

    except Exception as e:
        if conn:
            try:
                conn.rollback()
            except Exception:
                pass
        return jsonify({"ok": False, "error": f"exception: {e}"}), 500
    finally:
        if conn:
            try:
                conn.close()
            except Exception:
                pass

# -----------------------------------------------------------------------------
# RESERVATIONS (this is where the bug fix is)
# -----------------------------------------------------------------------------
#  RESERVATIONS
def ensure_reservations_table():
    exec_nonquery("""
IF OBJECT_ID('dbo.APP_RESERVATIONS') IS NULL
BEGIN
  CREATE TABLE dbo.APP_RESERVATIONS(
    id            INT IDENTITY(1,1) PRIMARY KEY,
    project_id    NVARCHAR(64) NOT NULL,
    customer_id   NVARCHAR(64) NULL,
    item_id       NVARCHAR(50) NOT NULL,     -- maps to WAPRO IdArtykulu as string
    warehouse_id  NVARCHAR(32) NULL,         -- optional, if you split by magazyn
    qty           DECIMAL(18,3) NOT NULL DEFAULT(0),
    actor_email   NVARCHAR(256) NULL,
    updated_at    DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_APP_RES UNIQUE(project_id, item_id, warehouse_id)
  );
END
""")

    # helpful indexes (idempotent)
    exec_nonquery("""
IF NOT EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE name = 'IX_APP_RES_item'
    AND object_id = OBJECT_ID('dbo.APP_RESERVATIONS')
)
BEGIN
  CREATE INDEX IX_APP_RES_item ON dbo.APP_RESERVATIONS(item_id);
END;

IF NOT EXISTS (
  SELECT 1 FROM sys.indexes
  WHERE name = 'IX_APP_RES_proj_item_wh'
    AND object_id = OBJECT_ID('dbo.APP_RESERVATIONS')
)
BEGIN
  CREATE UNIQUE INDEX IX_APP_RES_proj_item_wh
    ON dbo.APP_RESERVATIONS(project_id, item_id, warehouse_id);
END;
""")


def _get_app_reserved_others_cur(cur, item_id: str, project_id: str, warehouse_id: Optional[str]) -> float:
    """Sum of reservations for this item by ALL OTHER projects (excludes current project row)."""
    cur.execute("""
        SELECT COALESCE(SUM(qty), 0)
        FROM dbo.APP_RESERVATIONS WITH (UPDLOCK)
        WHERE item_id = ?
          AND NOT (project_id = ? AND ISNULL(warehouse_id,'') = ISNULL(?, ''))
    """, (item_id, project_id, warehouse_id))
    row = cur.fetchone()
    return float(row[0] if row and row[0] is not None else 0.0)


def _get_wapro_stock_and_unit_cur(cur, item_id: str) -> Tuple[float, str]:
    """
    Stock + unit using a safe fallback:
      1) SUM from JLVIEW_STANMAGAZYNU_RAP (if present)
      2) fallback to ARTYKUL.STAN and WIDOK_ARTYKUL.JednostkaSprzedazy
    """
    cur.execute("""
WITH sm AS (
  SELECT id_artykulu,
         SUM(CASE WHEN stan IS NULL THEN 0 ELSE CAST(stan AS DECIMAL(18,3)) END) AS qty,
         MAX(NULLIF(skrot,'')) AS unit
  FROM dbo.JLVIEW_STANMAGAZYNU_RAP WITH (NOLOCK)
  WHERE id_artykulu = CAST(? AS NUMERIC(18,0))
  GROUP BY id_artykulu
)
SELECT
  CAST(COALESCE(sm.qty, a.STAN, 0) AS DECIMAL(18,3)) AS quantity,
  COALESCE(sm.unit, NULLIF(wa.JednostkaSprzedazy,''), '') AS unit
FROM dbo.ARTYKUL a
LEFT JOIN sm ON sm.id_artykulu = a.ID_ARTYKULU
LEFT JOIN dbo.WIDOK_ARTYKUL wa ON wa.IdArtykulu = a.ID_ARTYKULU
WHERE a.ID_ARTYKULU = CAST(? AS NUMERIC(18,0))
    """, (item_id, item_id))
    row = cur.fetchone()
    qty = float(row[0] if row and row[0] is not None else 0.0)
    unit = (row[1] if row and row[1] is not None else '')
    return (qty, unit)


def _apply_reserved_to_wapro(cur, item_id: str):
    """
    Mirror total app reservations into WAPRO:
      ARTYKUL.ZAREZERWOWANO = SUM(APP_RESERVATIONS.qty) for this item.
    """
    cur.execute("""
        SELECT COALESCE(SUM(qty), 0)
        FROM dbo.APP_RESERVATIONS
        WHERE item_id = ?
    """, (item_id,))
    total = float(cur.fetchone()[0] or 0.0)

    cur.execute("""
        UPDATE dbo.ARTYKUL
           SET ZAREZERWOWANO = CAST(? AS DECIMAL(18,3))
         WHERE ID_ARTYKULU = CAST(? AS NUMERIC(18,0))
    """, (total, item_id))
    print(f"[RES] item {item_id} -> ZAREZERWOWANO set to {total:.3f}; rows={cur.rowcount}")


@app.post("/api/reservations/upsert")
def reservations_upsert():
    """
    Upsert a reservation line for (projectId, itemId[, warehouseId]).
    Body JSON:
      {
        "projectId": "proj123",
        "customerId": "cust456",        # optional
        "itemId": "1188",
        "qty": 2,                        # absolute reserved qty for this project line
        "warehouseId": null,             # optional
        "actorEmail": "user@company.com" # optional
      }
    Behavior:
      - Creates/updates row to the *absolute* qty for this project/item.
      - Prevents over-reservation: (sum of all project reservations) <= stock.
      - Mirrors the total into ARTYKUL.ZAREZERWOWANO.
    """
    ensure_reservations_table()

    data = request.get_json(force=True) or {}
    project_id   = (data.get("projectId") or "").strip()
    customer_id  = (data.get("customerId") or "").strip()
    item_id      = (data.get("itemId") or "").strip()
    warehouse_id = (data.get("warehouseId") or None)
    actor_email  = (data.get("actorEmail") or "app").strip()

    try:
        qty = float(data.get("qty"))
    except Exception:
        return jsonify({"ok": False, "error": "bad-qty"}), 400

    if not project_id or not item_id:
        return jsonify({"ok": False, "error": "missing-keys"}), 400
    if qty < 0:
        return jsonify({"ok": False, "error": "qty-negative"}), 400

    conn = None
    try:
        conn = pyodbc.connect(CONN_STR)
        conn.autocommit = False
        cur = conn.cursor()

        # Ensure the row exists (and lock the key)
        cur.execute("""
DECLARE @p NVARCHAR(64) = ?;
DECLARE @i NVARCHAR(50) = ?;
DECLARE @w NVARCHAR(32) = ?;

MERGE dbo.APP_RESERVATIONS WITH (HOLDLOCK) AS T
USING (SELECT @p AS project_id, @i AS item_id, @w AS warehouse_id) AS S
ON (T.project_id = S.project_id AND T.item_id = S.item_id AND ISNULL(T.warehouse_id,'') = ISNULL(S.warehouse_id,''))
WHEN MATCHED THEN UPDATE SET project_id = T.project_id
WHEN NOT MATCHED THEN INSERT(project_id,item_id,warehouse_id,qty) VALUES (S.project_id,S.item_id,S.warehouse_id,0);
        """, (project_id, item_id, warehouse_id))

        # Current qty for this project row
        cur.execute("""
SELECT qty
FROM dbo.APP_RESERVATIONS WITH (UPDLOCK, ROWLOCK)
WHERE project_id = ? AND item_id = ? AND ISNULL(warehouse_id,'') = ISNULL(?, '')
        """, (project_id, item_id, warehouse_id))
        row = cur.fetchone()
        current_project_qty = float(row[0] if row else 0.0)

        # Totals using the SAME cursor/transaction
        total_reserved_others = _get_app_reserved_others_cur(cur, item_id, project_id, warehouse_id)
        stock_qty, unit = _get_wapro_stock_and_unit_cur(cur, item_id)

        new_total_reserved = total_reserved_others + qty
        available_after = stock_qty - new_total_reserved

        if available_after < -1e-6:
            conn.rollback()
            return jsonify({
                "ok": False,
                "error": "insufficient-available",
                "stock": stock_qty,
                "reserved_other": total_reserved_others,
                "requested_project_qty": qty,
                "available_after": available_after,
                "unit": unit,
            }), 409

        # Write the absolute qty for this project line
        cur.execute("""
UPDATE dbo.APP_RESERVATIONS
   SET qty = ?, actor_email = ?, updated_at = SYSUTCDATETIME(),
       customer_id = COALESCE(NULLIF(?,''), customer_id)
 WHERE project_id = ? AND item_id = ? AND ISNULL(warehouse_id,'') = ISNULL(?, '')
        """, (qty, actor_email, customer_id, project_id, item_id, warehouse_id))

        # Mirror to WAPRO
        _apply_reserved_to_wapro(cur, item_id)

        conn.commit()

        return jsonify({
            "ok": True,
            "projectId": project_id,
            "itemId": item_id,
            "warehouseId": warehouse_id,
            "qty": qty,
            "stock": stock_qty,
            "reserved_total": new_total_reserved,
            "available_after": stock_qty - new_total_reserved,
            "unit": unit,
        }), 200

    except Exception as e:
        if conn:
            try: conn.rollback()
            except Exception: pass
        app.logger.exception("reservations_upsert failed")
        return jsonify({"ok": False, "error": f"exception: {e}"}), 500
    finally:
        if conn:
            try: conn.close()
            except Exception: pass


if __name__ == "__main__":
    # python -m waitress --listen=0.0.0.0:9104 app_admin:app
    app.run(host="0.0.0.0", port=9104, debug=False)

