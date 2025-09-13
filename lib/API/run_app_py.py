from flask import Flask, jsonify, request
from uuid import uuid4 
from flask_cors import CORS
import pyodbc
import os, json, datetime, logging, re, decimal
from typing import Optional, Tuple

import firebase_admin
from firebase_admin import auth as fb_auth, credentials, firestore

# CORS / Flask

ALLOWED_ORIGINS = [
    "https://strefa-ciszy.web.app",
    "https://strefa-ciszy.firebaseapp.com",
    re.compile(r"http://localhost:\d+$"),
    re.compile(r"http://127\.0\.0\.1:\d+$"),
]

app = Flask(__name__)
CORS(
    app,
    resources={
        r"/api/*": {
            "origins": ALLOWED_ORIGINS,                
            "methods": ["GET","POST","PUT","PATCH","DELETE","OPTIONS"],
            "allow_headers": ["*"],                    
            "expose_headers": ["Content-Type","Authorization"],
            "supports_credentials": False,
        }
    },
    max_age=600,
)

@app.route("/api/<path:_>", methods=["OPTIONS"])
def _cors_preflight(_):
    return ("", 204)
app.logger.setLevel(logging.INFO)

# SQL Server 
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
    "Encrypt=no;TrustServerCertificate=yes;Connection Timeout=5;"
)

def get_conn():
    return pyodbc.connect(CONN_STR)

def fetch_all(sql: str, params=()):
    """Run SELECT and return list[dict]."""
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(sql, params)
        cols = [d[0] for d in cur.description]
        rows = cur.fetchall()
        out = []
        for r in rows:
            d = {}
            for c, v in zip(cols, r):
                if isinstance(v, decimal.Decimal):
                    v = float(v)
                d[c] = v
            out.append(d)
        return out

def exec_nonquery(sql: str, params=()):
    """Run non-SELECT (INSERT/UPDATE/MERGE)."""
    with get_conn() as conn:
        cur = conn.cursor()
        cur.execute(sql, params)
        conn.commit()

# Firebase helpers

_FIREBASE_APP = None
_FS = None

def _init_firebase():
    global _FIREBASE_APP, _FS
    if _FIREBASE_APP is not None and _FS is not None:
        return
    try:
        sa_path = os.getenv("SC_FIREBASE_SA") or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if sa_path and os.path.exists(sa_path):
            cred = credentials.Certificate(sa_path)
        else:
            cred = credentials.ApplicationDefault()
        _FIREBASE_APP = firebase_admin.initialize_app(cred)
    except Exception:
        _FIREBASE_APP = firebase_admin.get_app()
    _FS = firestore.client()


# def _init_firebase():
#     global _FIREBASE_APP, _FS
#     if _FIREBASE_APP is not None and _FS is not None:
#         return
#     try:
#         cred = credentials.ApplicationDefault()
#         _FIREBASE_APP = firebase_admin.initialize_app(cred)
#     except Exception:
#         _FIREBASE_APP = firebase_admin.get_app()
#     _FS = firestore.client()

def _is_approver(email: Optional[str], uid: Optional[str]) -> bool:
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

# Health

@app.get("/api/health")
def health_plain():
    return jsonify({"ok": True, "service": "strefa-admin", "ts": datetime.datetime.utcnow().isoformat() + "Z"}), 200

@app.get("/api/admin/health")
def health_admin():
    return jsonify({"status": "ok"}), 200



@app.get("/api/catalog")
def catalog():
    q = (request.args.get("q") or "").strip()
    try:
        top = int(request.args.get("top", "100"))
    except Exception:
        top = 100
    sql = """
        SELECT TOP (?) *
        FROM app.v_AppCatalog
        WHERE (? = '' 
               OR INDEKS_KATALOGOWY LIKE '%' + ? + '%' 
               OR NAZWA LIKE '%' + ? + '%' 
               OR NAZWA_ORYG LIKE '%' + ? + '%')
        ORDER BY AppAvailable ASC, NAZWA
    """
    with get_conn() as cn, cn.cursor() as cur:
        cur.execute(sql, (top, q, q, q, q))
        cols = [d[0] for d in cur.description]
        rows = cur.fetchall()
        return jsonify([dict(zip(cols, r)) for r in rows])

# RESERVATIONS (compat+legacy)

@app.post("/api/reservations/upsert1")
def _legacy_public_upsert1():
    return reservations_upsert_compat()

@app.post("/api/reservations/upsert")
def _legacy_public_upsert():
    return reservations_upsert_compat()

@app.post("/api/admin/reservations/upsert1")
def _legacy_admin_upsert1():
    return reservations_upsert_compat()

@app.get("/api/admin/reservations/active_for_item/<int:item_id>")
def admin_active_reservations_for_item(item_id: int):
    """
    Returns active reservations (Status in (1,2), not invoiced) for a given item_id.
    [
      { "reservationId": "...", "projectId": "...", "qty": 3 }
    ]
    """
    sql = """
    SELECT r.ReservationId, r.ProjectId, SUM(rl.Qty) AS qty
    FROM app.Reservations r
    JOIN app.ReservationLines rl ON rl.ReservationId = r.ReservationId
    WHERE rl.InvoiceNo IS NULL
      AND r.Status IN (1,2)
      AND rl.ID_ARTYKULU = ?
    GROUP BY r.ReservationId, r.ProjectId
    ORDER BY r.CreatedAt DESC
    """
    rows = fetch_all(sql, (item_id,))
    out = [
      {
        "reservationId": str(r.get("ReservationId")),
        "projectId": r.get("ProjectId"),
        "qty": int(r.get("qty") or 0),
      }
      for r in rows
    ]
    return jsonify(out), 200

@app.post("/api/admin/reservations/reset_item")
def admin_reset_item_reservations():
    """
    Body: { "itemId": 1536, "projectId": "optional" }
    If projectId is omitted/empty -> releases ALL active reservations for that item.
    """
    data = request.get_json(force=True) or {}
    try:
        item_id = int(str(data.get("itemId") or "").strip())
    except Exception:
        return jsonify({"ok": False, "error": "bad-itemId"}), 400
    project_id = (data.get("projectId") or "").strip()

    try:
        with get_conn() as cn:
            cn.autocommit = False
            cur = cn.cursor()

            if project_id:
                # How much is reserved on this project?
                cur.execute("""
                    SELECT ISNULL(SUM(rl.Qty),0)
                    FROM app.ReservationLines rl
                    JOIN app.Reservations r ON r.ReservationId = rl.ReservationId
                    WHERE rl.InvoiceNo IS NULL
                      AND r.Status IN (1,2)
                      AND r.ProjectId = ?
                      AND rl.ID_ARTYKULU = ?
                """, (project_id, item_id))
                row = cur.fetchone()
                qty = float(row[0] if row and row[0] is not None else 0.0)
                if qty > 0:
                    cur.execute("{CALL app.sp_UnreserveStock(?,?,?)}",
                                (project_id, item_id, qty))
            else:
                # Release ALL projects that hold this item
                cur.execute("""
                    SELECT r.ProjectId, SUM(rl.Qty) AS qty
                    FROM app.Reservations r
                    JOIN app.ReservationLines rl ON rl.ReservationId = r.ReservationId
                    WHERE rl.InvoiceNo IS NULL
                      AND r.Status IN (1,2)
                      AND rl.ID_ARTYKULU = ?
                    GROUP BY r.ProjectId
                """, (item_id,))
                for proj_id, qty in cur.fetchall():
                    q = float(qty or 0.0)
                    if q > 0 and proj_id:
                        cur.execute("{CALL app.sp_UnreserveStock(?,?,?)}",
                                    (proj_id, item_id, q))

            cn.commit()
            return jsonify({"ok": True}), 200

    except pyodbc.Error as e:
        try:
            if cn: cn.rollback()
        except Exception:
            pass
        return jsonify({"ok": False, "error": str(e)}), 500


@app.get("/api/admin/reservations/summary")
def reservations_summary():
    project_id = (request.args.get("projectId") or "").strip()
    item_id    = (request.args.get("itemId") or "").strip()
    if not item_id:
        return jsonify({"ok": False, "error": "missing-itemId"}), 400
    try:
        id_artykulu = int(item_id)
    except Exception:
        return jsonify({"ok": False, "error": "bad-itemId"}), 400

    with get_conn() as cn, cn.cursor() as cur:
        # reserved on this project (if given)
        reserved_on_project = 0
        if project_id:
            cur.execute("""
                SELECT ISNULL(SUM(rl.Qty), 0)
                FROM app.ReservationLines rl
                JOIN app.Reservations r ON r.ReservationId = rl.ReservationId
                WHERE r.ProjectId = ? AND r.Status IN (1,2)
                  AND rl.InvoiceNo IS NULL
                  AND rl.ID_ARTYKULU = ?
            """, (project_id, id_artykulu))
            row = cur.fetchone()
            reserved_on_project = float(row[0] or 0)

        # reserved overall (all projects)
        cur.execute("""
            SELECT ISNULL(SUM(rl.Qty), 0)
            FROM app.ReservationLines rl
            JOIN app.Reservations r ON r.ReservationId = rl.ReservationId
            WHERE r.Status IN (1,2)
              AND rl.InvoiceNo IS NULL
              AND rl.ID_ARTYKULU = ?
        """, (id_artykulu,))
        row = cur.fetchone()
        reserved_total = float(row[0] or 0)

        # stock snapshot
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
              COALESCE(sm.unit, NULLIF(wa.JednostkaSprzedazy,''), '') AS unit,
              CAST(a.NAZWA AS NVARCHAR(100)) AS name
            FROM dbo.ARTYKUL a
            LEFT JOIN sm ON sm.id_artykulu = a.ID_ARTYKULU
            LEFT JOIN dbo.WIDOK_ARTYKUL wa ON wa.IdArtykulu = a.ID_ARTYKULU
            WHERE a.ID_ARTYKULU = CAST(? AS NUMERIC(18,0))
        """, (id_artykulu, id_artykulu))
        row = cur.fetchone()
        stock_qty = float(row[0] or 0)
        unit = (row[1] or '')
        name = (row[2] or '')

    available_after = stock_qty - reserved_total

    return jsonify({
        "ok": True,
        "itemId": str(id_artykulu),
        "name": name,
        "stock": stock_qty,
        "reserved_on_project": reserved_on_project,
        "reserved_total": reserved_total,
        "available_after_if_reset": available_after,
        "unit": unit,
    }), 200



@app.post("/api/admin/reservations/upsert")
def reservations_upsert_compat():
    """
    Compatibility shim for old clients.
    Body:  { projectId, customerId?, itemId, qty, warehouseId?, actorEmail }
    Reply: {
      ok, projectId, itemId, qty, delta, reservationId?, note?,
      stock, reserved_total, available_after, unit
    }
    """
    data = request.get_json(force=True) or {}
    app.logger.info("UPsert payload: %s", data)

    project_id  = (data.get("projectId") or "").strip()
    actor_email = (data.get("actorEmail") or "api").strip()

    try:
        id_artykulu = int(str(data.get("itemId") or "").strip())
    except Exception:
        return jsonify({"ok": False, "error": "bad-itemId"}), 400

    try:
        desired_qty = float(data.get("qty"))
    except Exception:
        return jsonify({"ok": False, "error": "bad-qty"}), 400

    if not project_id or desired_qty < 0:
        return jsonify({"ok": False, "error": "bad-payload"}), 400

    try:
        with get_conn() as cn:
            cn.autocommit = False
            with cn.cursor() as cur:
                cur.execute("""
                    SELECT ISNULL(SUM(rl.Qty), 0)
                    FROM app.ReservationLines rl WITH (UPDLOCK, ROWLOCK)
                    JOIN app.Reservations r ON r.ReservationId = rl.ReservationId
                    WHERE r.ProjectId = ? AND r.Status IN (1,2)
                      AND rl.InvoiceNo IS NULL
                      AND rl.ID_ARTYKULU = ?
                """, (project_id, id_artykulu))
                row = cur.fetchone()
                current_qty = float(row[0] if row and row[0] is not None else 0.0)

                cur.execute("""
                    SELECT ISNULL(SUM(rl.Qty), 0)
                    FROM app.ReservationLines rl WITH (UPDLOCK)
                    JOIN app.Reservations r ON r.ReservationId = rl.ReservationId
                    WHERE rl.ID_ARTYKULU = ?
                      AND rl.InvoiceNo IS NULL
                      AND NOT (r.ProjectId = ? AND r.Status IN (1,2))
                """, (id_artykulu, project_id))
                row = cur.fetchone()
                reserved_other = float(row[0] if row and row[0] is not None else 0.0)

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
                """, (id_artykulu, id_artykulu))
                row = cur.fetchone()
                stock_qty = float(row[0] if row and row[0] is not None else 0.0)
                unit = (row[1] if row and row[1] is not None else '')

                delta = desired_qty - current_qty
                new_reserved_total = reserved_other + desired_qty
                available_after = stock_qty - new_reserved_total

                if delta < -1e-9:
                    try:
                        cur.execute("{CALL app.sp_UnreserveStock(?,?,?)}",
                                    (project_id, id_artykulu, -delta))
                        cn.commit()
                        return jsonify({
                            "ok": True,
                            "projectId": project_id,
                            "itemId": str(id_artykulu),
                            "qty": desired_qty,
                            "delta": float(delta),
                            "reservationId": None,
                            "note": "decreased",
                            "stock": stock_qty,
                            "reserved_total": new_reserved_total,
                            "available_after": available_after,
                            "unit": unit,
                        }), 200
                    except pyodbc.Error as e:
                        cn.rollback()
                        return jsonify({
                            "ok": False,
                            "error": str(e),
                            "stock": stock_qty,
                            "reserved_total": new_reserved_total,
                            "available_after": available_after,
                            "unit": unit,
                        }), 409

                if abs(delta) <= 1e-9:
                    cn.commit()
                    return jsonify({
                        "ok": True,
                        "projectId": project_id,
                        "itemId": str(id_artykulu),
                        "qty": desired_qty,
                        "delta": 0.0,
                        "reservationId": None,
                        "note": "no-op",
                        "stock": stock_qty,
                        "reserved_total": new_reserved_total,
                        "available_after": available_after,
                        "unit": unit,
                    }), 200

                try:
                    cur.execute("{CALL app.sp_ReserveStock(?,?,?,?,?)}",
                                (project_id, id_artykulu, delta, actor_email, None))
                    row = cur.fetchone()
                    res_id = str(row[0]) if row and row[0] else None
                    cn.commit()
                    return jsonify({
                        "ok": True,
                        "projectId": project_id,
                        "itemId": str(id_artykulu),
                        "qty": desired_qty,
                        "delta": float(delta),
                        "reservationId": res_id,
                        "stock": stock_qty,
                        "reserved_total": new_reserved_total,
                        "available_after": available_after,
                        "unit": unit,
                    }), 200
                except pyodbc.Error as e:
                    cn.rollback()
                    return jsonify({
                        "ok": False,
                        "error": str(e),
                        "stock": stock_qty,
                        "reserved_total": new_reserved_total,
                        "available_after": available_after,
                        "unit": unit,
                    }), 409

    except Exception as e:
        app.logger.exception("reservations_upsert_compat failed")
        return jsonify({"ok": False, "error": f"exception: {e}"}), 500


@app.post("/api/reserve")
def api_reserve():
    data = request.get_json(force=True) or {}
    project = (data.get("projectId") or "").strip()
    try:
        item_id = int(data.get("idArtykulu"))
    except Exception:
        return jsonify({"ok": False, "error": "bad-idArtykulu"}), 400
    try:
        qty = float(data.get("qty"))
    except Exception:
        return jsonify({"ok": False, "error": "bad-qty"}), 400
    user = (data.get("user") or "api").strip()
    comment = (data.get("comment") or None)

    if not project or qty <= 0:
        return jsonify({"ok": False, "error": "bad-payload"}), 400

    with get_conn() as cn, cn.cursor() as cur:
        try:
            cur.execute("{CALL app.sp_ReserveStock(?,?,?,?,?)}",
                        (project, item_id, qty, user, comment))
            row = cur.fetchone()
            return jsonify({"ok": True, "reservationId": str(row[0]) if row else None})
        except pyodbc.Error as e:
            return jsonify({"ok": False, "error": str(e)}), 409
        
@app.post("/api/confirm")
def api_confirm():
    """
    Body: { reservationId, lockAll?: true }
    """
    data = request.get_json(force=True) or {}
    rid = (data.get("reservationId") or "").strip()
    lock_all = 1 if data.get("lockAll", True) else 0
    if not rid:
        return jsonify({"ok": False, "error": "missing-reservationId"}), 400
    with get_conn() as cn, cn.cursor() as cur:
        cur.execute("{CALL app.sp_ConfirmForInvoice(?,?)}", (rid, lock_all))
        return jsonify({"ok": True})
    

@app.post("/api/invoiced_partial")
def api_invoiced_partial():
    """
    Body:
    {
      "projectId": "o6Un75ted6w390YaZ6rt",
      "invoiceNo": "",                 # optional; auto-generated if blank
      "lines": [ { "itemId": 3029, "qty": 1 }, ... ]
    }
    """
    data = request.get_json(force=True) or {}
    project = (data.get("projectId") or "").strip()
    invoice = (data.get("invoiceNo") or "").strip()
    lines   = data.get("lines") or []

    if not project or not isinstance(lines, list) or not lines:
        return jsonify({"ok": False, "error": "bad-payload"}), 400

    if not invoice:
        invoice = f"APP-{datetime.datetime.utcnow().strftime('%Y%m%dT%H%M%S')}-{uuid4().hex[:6]}"

    clean = []
    for l in lines:
        try:
            item_id = int(str(l.get("itemId")).strip())
            qty     = float(l.get("qty"))
        except Exception:
            continue
        if qty > 0:
            clean.append({"itemId": item_id, "qty": qty})

    if not clean:
        return jsonify({"ok": False, "error": "no-valid-lines"}), 400

    conn = None
    try:
        conn = get_conn()
        conn.autocommit = False
        cur = conn.cursor()

        for l in clean:
            cur.execute("{CALL app.sp_MarkInvoicedLine(?,?,?,?)}",
                        (project, invoice, l["itemId"], l["qty"]))

        conn.commit()
        return jsonify({"ok": True, "invoiceTag": invoice}), 200

    except pyodbc.Error as e:
        try:
            if conn: conn.rollback()
        except Exception:
            pass
        return jsonify({"ok": False, "error": str(e)}), 409
    except Exception as e:
        try:
            if conn: conn.rollback()
        except Exception:
            pass
        return jsonify({"ok": False, "error": f"exception: {e}"}), 500
    finally:
        try:
            if conn: conn.close()
        except Exception:
            pass


@app.post("/api/invoiced")
def api_invoiced():
    """
    Body: { reservationId, invoiceNo }
    """
    data = request.get_json(force=True) or {}
    rid = (data.get("reservationId") or "").strip()
    invoice = (data.get("invoiceNo") or "").strip()
    if not rid or not invoice:
        return jsonify({"ok": False, "error": "missing-fields"}), 400
    with get_conn() as cn, cn.cursor() as cur:
        cur.execute("{CALL app.sp_MarkInvoiced(?,?)}", (rid, invoice))
        return jsonify({"ok": True})

@app.post("/api/release")
def api_release():
    """
    Body: { reservationId }
    Releases non-invoiced lines and sets header to Status=4.
    """
    data = request.get_json(force=True) or {}
    rid = (data.get("reservationId") or "").strip()
    if not rid:
        return jsonify({"ok": False, "error": "missing-reservationId"}), 400
    with get_conn() as cn, cn.cursor() as cur:
        cur.execute("{CALL app.sp_ReleaseReservation(?)}", (rid,))
        return jsonify({"ok": True})


# /api/commit (approver-gated log)
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
    app.logger.info("COMMIT start: project=%s items=%s", project_id, len(items))

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

    if dry_run or os.getenv("SC_DRYRUN") == "1":
        doc_id = f"DRYRUN-{project_id[:6]}-{int(datetime.datetime.utcnow().timestamp())}"
        return jsonify({"ok": True, "docId": doc_id, "dryRun": True}), 200

    conn = None
    try:
        conn = get_conn()
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
        conn.commit()
        new_id = row[0] if row else None
        doc_id = f"LOG-{new_id}" if new_id is not None else f"LOG-{int(datetime.datetime.utcnow().timestamp())}"
        return jsonify({"ok": True, "docId": doc_id}), 200
    except Exception as e:
        app.logger.exception("commit_project_items failed")
        try:
            if conn: conn.rollback()
        except Exception:
            pass
        return jsonify({"ok": False, "error": f"commit-failed: {e}"}), 500
    finally:
        try:
            if conn: conn.close()
        except Exception:
            pass

# Normalisation

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
    with get_conn() as conn:
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

# ---- EAN endpoints (unchanged) ----
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
""", (ean, str(exclude_id)),
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

@app.post("/api/admin/ean/setup")
def admin_ean_setup():
    ensure_override_table()
    return jsonify({"ok": True, "table": "APP_EAN_OVERRIDE"}), 200

@app.get("/api/admin/products/<pid>/ean")
def admin_get_ean(pid):
    wapro_ean = get_wapro_ean_for_id(pid)
    try:
        rows = fetch_all("""
SELECT COALESCE(override_ean,'') AS override_ean,
       COALESCE(updated_by,'')   AS updated_by,
       CONVERT(VARCHAR(19), updated_at, 126) AS updated_at
FROM dbo.APP_EAN_OVERRIDE
WHERE id_artykulu = ?
""", (pid,))
        r = rows[0] if rows else {}
        override_ean = r.get("override_ean") or ""
        updated_by   = r.get("updated_by") or None
        updated_at   = r.get("updated_at") or None
    except Exception:
        override_ean, updated_by, updated_at = ("", None, None)
    effective = wapro_ean or override_ean or ""
    status = "LOCKED_WAPRO" if wapro_ean else ("OVERRIDDEN" if override_ean else "EMPTY")
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
        return jsonify({"ok": False, "error": "ean-managed-by-wapro", "wapro_ean": wapro_ean}), 409
    ensure_override_table()
    norm = digits_only(raw)
    with get_conn() as conn:
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
    rows = fetch_all("""
SELECT COALESCE(override_ean,'') AS override_ean,
       COALESCE(updated_by,'')   AS updated_by,
       CONVERT(VARCHAR(19), updated_at, 126) AS updated_at
FROM dbo.APP_EAN_OVERRIDE
WHERE id_artykulu = ?
""", (pid,))
    r = rows[0] if rows else {}
    override_ean = r.get("override_ean") or ""
    effective = override_ean
    status = "OVERRIDDEN" if override_ean else "EMPTY"
    return jsonify({
        "ok": True,
        "id": pid,
        "override_ean": override_ean,
        "effective_ean": effective,
        "status": status,
        "updated_by": r.get("updated_by") or None,
        "updated_at": r.get("updated_at") or None,
    }), 200

# ---- Products ----
@app.get("/api/products")
def list_products():
    q = request.args.get("q") or request.args.get("name") or request.args.get("search")
    category = request.args.get("category")
    try:    limit = int(request.args.get("limit", 100))
    except: limit = 100
    try:    offset = int(request.args.get("offset", 0))
    except: offset = 0

    sql = """
    SET LOCK_TIMEOUT 3000;
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    WITH base AS (
        SELECT
            A.ID_ARTYKULU AS id,
            COALESCE(NULLIF(WA.Nazwa1, ''), A.NAZWA, '') AS name,
            COALESCE(NULLIF(WA.Nazwa2, ''), '')          AS description,
            COALESCE(NULLIF(WA.Producent, ''), '')       AS producent,
            COALESCE(
                NULLIF(WA.NrKatalogowy, ''),
                NULLIF(A.INDEKS_KATALOGOWY, ''),
                NULLIF(A.INDEKS_HANDLOWY, ''),
                ''
            ) AS sku
        FROM dbo.ARTYKUL A WITH (NOLOCK)
        LEFT JOIN dbo.WIDOK_ARTYKUL WA WITH (NOLOCK)
               ON WA.IdArtykulu = A.ID_ARTYKULU
    ),
    qty AS (
        SELECT SM.id_artykulu AS id,
               SUM(CASE WHEN ISNUMERIC(SM.stan) = 1 THEN CAST(SM.stan AS DECIMAL(18,3)) ELSE 0 END) AS quantity,
               MAX(COALESCE(NULLIF(SM.skrot, ''), '')) AS unit
        FROM dbo.JLVIEW_STANMAGAZYNU_RAP SM WITH (NOLOCK)
        GROUP BY SM.id_artykulu
    ),
    bar AS (
        SELECT E.ID_ARTYKULU AS id,
               MAX(COALESCE(NULLIF(E.KOD_KRESKOWY, ''), '')) AS barcode
        FROM dbo.ART_ECR_MAG_V E WITH (NOLOCK)
        GROUP BY E.ID_ARTYKULU
    )
    SELECT
        CAST(B.id AS nvarchar(50)) AS id,
        B.name, B.description,
        CAST(COALESCE(Q.quantity, 0) AS int) AS quantity,
        B.sku, COALESCE(Bar.barcode, '') AS barcode,
        COALESCE(Q.unit, '') AS unit,
        B.producent,
        NULL AS imageUrl
    FROM base B
    LEFT JOIN qty  Q   WITH (NOLOCK) ON Q.id   = B.id
    LEFT JOIN bar  Bar WITH (NOLOCK) ON Bar.id = B.id
    WHERE
        ( ? IS NULL OR ? = '' OR
          B.name LIKE ? OR B.sku LIKE ? OR COALESCE(Bar.barcode,'') LIKE ? OR
          B.description LIKE ? OR B.producent LIKE ?
        )
        AND ( ? IS NULL OR LTRIM(RTRIM(B.description)) = LTRIM(RTRIM(?)) )
    ORDER BY B.name
    OFFSET ? ROWS FETCH NEXT ? ROWS ONLY;
    """

    like = f"%{q}%" if q else None
    params = [q, q, like, like, like, like, like, category, category, offset, limit]
    rows = fetch_all(sql, params)

    out = []
    for r in rows:
        out.append({
            "id":         str(r.get("id") or ""),
            "name":       r.get("name") or "",
            "description":r.get("description") or "",
            "quantity":   int(r.get("quantity") or 0),
            "sku":        r.get("sku") or "",
            "barcode":    r.get("barcode") or "",
            "unit":       r.get("unit") or "",
            "producent":  r.get("producent") or "",
            "imageUrl":   r.get("imageUrl") or None,
            "category":   (r.get("description") or "")
        })
    return jsonify(out), 200

@app.get("/api/products/<id>")
def get_product(id):
    sql = """
    WITH base AS (
        SELECT
            A.ID_ARTYKULU AS id,
            COALESCE(NULLIF(WA.Nazwa1, ''), A.NAZWA, '') AS name,
            COALESCE(NULLIF(WA.Nazwa2, ''), '')          AS description,
            COALESCE(NULLIF(WA.Producent, ''), '')       AS producent,
            COALESCE(
                NULLIF(WA.NrKatalogowy, ''),
                NULLIF(A.INDEKS_KATALOGOWY, ''),
                NULLIF(A.INDEKS_HANDLOWY, ''),
                ''
            ) AS sku
        FROM dbo.ARTYKUL A
        LEFT JOIN dbo.WIDOK_ARTYKUL WA ON WA.IdArtykulu = A.ID_ARTYKULU
    ),
    qty AS (
        SELECT SM.id_artykulu AS id,
               SUM(CASE WHEN ISNUMERIC(SM.stan) = 1 THEN CAST(SM.stan AS DECIMAL(18,3)) ELSE 0 END) AS quantity,
               MAX(COALESCE(NULLIF(SM.skrot, ''), '')) AS unit
        FROM dbo.JLVIEW_STANMAGAZYNU_RAP SM
        GROUP BY SM.id_artykulu
    ),
    bar AS (
        SELECT E.ID_ARTYKULU AS id,
               MAX(COALESCE(NULLIF(E.KOD_KRESKOWY, ''), '')) AS barcode
        FROM dbo.ART_ECR_MAG_V E
        GROUP BY E.ID_ARTYKULU
    )
    SELECT TOP 1
        CAST(B.id AS nvarchar(50)) AS id, B.name, B.description,
        CAST(COALESCE(Q.quantity, 0) AS int) AS quantity,
        B.sku, COALESCE(Bar.barcode, '') AS barcode,
        COALESCE(Q.unit, '') AS unit, B.producent, NULL AS imageUrl
    FROM base B
    LEFT JOIN qty  Q   ON Q.id   = B.id
    LEFT JOIN bar  Bar ON Bar.id = B.id
    WHERE CAST(B.id AS nvarchar(50)) = ? OR COALESCE(Bar.barcode,'') = ? OR B.sku = ?;
    """
    rows = fetch_all(sql, (id, id, id))
    if not rows:
        return jsonify({}), 404
    r = rows[0]
    return jsonify({
        "id":         str(r.get("id") or ""),
        "name":       r.get("name") or "",
        "description":r.get("description") or "",
        "quantity":   int(r.get("quantity") or 0),
        "sku":        r.get("sku") or "",
        "barcode":    r.get("barcode") or "",
        "unit":       r.get("unit") or "",
        "producent":  r.get("producent") or "",
        "imageUrl":   r.get("imageUrl") or None,
        "category":   (r.get("description") or "")
    }), 200

# ---- Legacy reservations_upsert kept (DO NOT DELETE ) ----
# /api/reservations/upsert is left out on purpose to avoid mixing
# two reservation systems. Keep old service running if still use.
# If want it here too, can copy it verbatim under a /api/legacy/... path.

if __name__ == "__main__":
    # waitress:  python -m waitress --listen=0.0.0.0:9132 app:app
    app.run(host="0.0.0.0", port=9103, debug=False)
