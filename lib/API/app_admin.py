from flask import Flask, jsonify, request
from flask_cors import CORS
import pyodbc

import os, json, datetime, logging
from typing import Optional
import firebase_admin
from firebase_admin import auth as fb_auth, credentials, firestore

app = Flask(__name__)
CORS(app)
app.logger.setLevel(logging.INFO)

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

# ---------- NEW: Firebase Admin bootstrap + approver check ----------
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
# -------------------------------------------------------------------

@app.get("/api/admin/health")
def health_admin():
    return jsonify({"status": "ok"}), 200

@app.get("/api/health")
def health_plain():
    return jsonify({"ok": True, "service": "admin", "ts": datetime.datetime.utcnow().isoformat() + "Z"}), 200

# ------------------------ /api/commit --------------------------
@app.post("/api/commit")
def commit_project_items():
    """
    Finalize selected project items (accountant-only).
    - Verifies Firebase ID token (Authorization: Bearer <idToken>)
    - Checks approvers in Firestore (config/security)
    - DRY RUN (if 'dryRun' true or env SC_DRYRUN=1) => no DB writes
    - LIVE (safe for now): logs into dbo.APP_COMMIT_LOG and returns docId
    """
    auth_header = request.headers.get("Authorization") or request.headers.get("authorization") or ""
    token = ""
    if auth_header.lower().startswith("bearer "):
        token = auth_header.split(" ", 1)[1].strip()
    if not token:
        return jsonify({"ok": False, "error": "missing-token"}), 401

    # Verify ID token
    try:
        _init_firebase()
        decoded = fb_auth.verify_id_token(token)
    except Exception as e:
        app.logger.exception("verify_id_token failed")
        return jsonify({"ok": False, "error": f"invalid-token: {e}"}), 401

    email = (decoded.get("email") or "").lower()
    uid   = decoded.get("uid")

    # Approver gate
    if not _is_approver(email, uid):
        return jsonify({"ok": False, "error": "not-approver"}), 403

    # Parse payload
    data = request.get_json(force=True) or {}
    customer_id = (data.get("customerId") or "").strip()
    project_id  = (data.get("projectId")  or "").strip()
    items       = data.get("items") or []
    dry_run     = bool(data.get("dryRun", False))

    if not project_id or not isinstance(items, list) or not items:
        return jsonify({"ok": False, "error": "bad-payload"}), 400

    # Normalize lines
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
            # keep for logs/debug
            "name":     (it.get("name") or ""),
            "producer": (it.get("producer") or ""),
        })

    if not lines:
        return jsonify({"ok": False, "error": "no-valid-lines"}), 400

    # DRY RUN
    if dry_run or os.getenv("SC_DRYRUN") == "1":
        doc_id = f"DRYRUN-{project_id[:6]}-{int(datetime.datetime.utcnow().timestamp())}"
        return jsonify({"ok": True, "docId": doc_id, "dryRun": True}), 200

    # LIVE: safe log into SQL (create table if missing)
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
# -------------------------------------------------------------------

@app.post("/api/sync/preview")
def sync_preview():
    """
    Body JSON:
    {
      "id": "1047",
      "normalized_name": "klawiatury cyfrowej",
      "normalized_producent": "ABB",
      "normalized_category": "Moduł",
      "normalized_description": "Moduł",     # optional
      "proposed_by": "user@company"          # optional
    }
    """
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
          SUM(CASE WHEN SM.stan IS NULL
                   THEN CAST(0 AS DECIMAL(18,3))
                   ELSE CAST(SM.stan AS DECIMAL(18,3)) END) AS quantity,
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
    """
    Body: { "ids": ["1047","..."], "approved_by": "admin" }
    1) mark selected rows as approved=1
    2) run stored procedure to update ARTYKUL.* and log changes
    """
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

@app.post("/api/products")
def create_product():
    """
    Minimal, safe insert to WAPRO (no pricing, no stock).
    We generate ID_ARTYKULU because the column is NOT IDENTITY.
    """
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

if __name__ == "__main__":
    # Example: python -m waitress --listen=0.0.0.0:9104 app_admin:app
    app.run(host="0.0.0.0", port=9104, debug=False)
