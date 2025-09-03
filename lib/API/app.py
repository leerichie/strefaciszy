# from flask import Flask, jsonify, request
# from flask_cors import CORS
# import pyodbc
# import re


# ALLOWED_ORIGINS = [
#     "https://strefa-ciszy.web.app",
#     "https://strefa-ciszy.firebaseapp.com",
#     re.compile(r"http://localhost:\d+$"),
#     re.compile(r"http://127\.0\.0\.1:\d+$"),
# ]

# app = Flask(__name__)
# CORS(
#     app,
#     resources={r"/api/*": {"origins": ALLOWED_ORIGINS}},
#     supports_credentials=False,
#     allow_headers=["Content-Type", "Authorization", "Cache-Control", "X-Requested-With"],
#     methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
# )

# SERVER   = r"KASIA-BIURO\SQLEXPRESS"
# DATABASE = "WAPRO"
# USER     = "sc_app_test"
# PWD      = "admin1234"
# DRIVER   = "ODBC Driver 17 for SQL Server"

# CONN_STR = (
#     f"Driver={{{DRIVER}}};"
#     f"Server={SERVER};"
#     f"Database={DATABASE};"
#     f"UID={USER};PWD={PWD};"
#     "Encrypt=no;TrustServerCertificate=yes;Connection Timeout=5;"
# )


# def fetch_all(sql: str, params=()):
#     with pyodbc.connect(CONN_STR) as conn:
#         cur = conn.cursor()
#         cur.execute(sql, params)
#         cols = [d[0] for d in cur.description]
#         return [dict(zip(cols, row)) for row in cur.fetchall()]


# @app.get("/api/health")
# def health():
#     return jsonify({"status": "ok"}), 200


# @app.get("/api/dbping")
# def dbping():
#     try:
#         with pyodbc.connect(CONN_STR, timeout=5) as conn:
#             cur = conn.cursor()
#             cur.execute("SELECT 1 AS ok")
#             row = cur.fetchone()
#         return jsonify({"db": "ok", "value": int(row.ok)}), 200
#     except Exception as e:
#         return jsonify({"db": "error", "error": str(e)}), 500


# @app.get("/api/dbping_qty")
# def dbping_qty():
#     try:
#         with pyodbc.connect(CONN_STR, timeout=5) as conn:
#             cur = conn.cursor()
#             cur.execute("SET LOCK_TIMEOUT 3000; SELECT TOP 1 id_artykulu, stan, skrot FROM dbo.JLVIEW_STANMAGAZYNU_RAP")
#             row = cur.fetchone()
#         return jsonify({"qty": "ok", "id": row[0] if row else None}), 200
#     except Exception as e:
#         return jsonify({"qty": "error", "error": str(e)}), 500


# @app.get("/api/dbping_bar")
# def dbping_bar():
#     try:
#         with pyodbc.connect(CONN_STR, timeout=5) as conn:
#             cur = conn.cursor()
#             cur.execute("SET LOCK_TIMEOUT 3000; SELECT TOP 1 ID_ARTYKULU, KOD_KRESKOWY FROM dbo.ART_ECR_MAG_V")
#             row = cur.fetchone()
#         return jsonify({"bar": "ok", "id": row[0] if row else None}), 200
#     except Exception as e:
#         return jsonify({"bar": "error", "error": str(e)}), 500


# @app.get("/api/products_lite")
# def products_lite():
#     q = request.args.get("q")
#     try:
#         limit = int(request.args.get("limit", 50))
#     except Exception:
#         limit = 50

#     like = f"%{q}%" if q else None

#     sql = """
#     SET LOCK_TIMEOUT 3000;
#     WITH base AS (
#         SELECT
#             A.ID_ARTYKULU                               AS id,
#             COALESCE(NULLIF(WA.Nazwa1,''), A.NAZWA,'')  AS name,
#             COALESCE(NULLIF(WA.Nazwa2,''), '')          AS description,
#             COALESCE(NULLIF(WA.Producent,''), '')       AS producent,
#             COALESCE(
#               NULLIF(WA.NrKatalogowy,''),
#               NULLIF(A.INDEKS_KATALOGOWY,''),
#               NULLIF(A.INDEKS_HANDLOWY,''),
#               ''
#             )                                           AS sku
#         FROM dbo.ARTYKUL A
#         LEFT JOIN dbo.WIDOK_ARTYKUL WA
#                ON WA.IdArtykulu = A.ID_ARTYKULU
#     )
#     SELECT
#         CAST(id AS nvarchar(50)) AS id,
#         name,
#         description,
#         producent,
#         sku
#     FROM base
#     WHERE
#         (? IS NULL OR ? = '' OR
#          name LIKE ? OR description LIKE ? OR producent LIKE ? OR sku LIKE ?
#         )
#     ORDER BY name
#     OFFSET 0 ROWS FETCH NEXT ? ROWS ONLY;
#     """

#     params = [q, q, like, like, like, like, limit]

#     try:
#         rows = fetch_all(sql, params)
#         return jsonify(rows), 200
#     except Exception as e:
#         return jsonify({"error": str(e)}), 500


# @app.get("/api/dbping_base")
# def dbping_base():
#     try:
#         with pyodbc.connect(CONN_STR, timeout=5) as conn:
#             cur = conn.cursor()
#             cur.execute("""
#                 SET LOCK_TIMEOUT 3000;
#                 SELECT TOP 1 A.ID_ARTYKULU
#                 FROM dbo.ARTYKUL A
#                 LEFT JOIN dbo.WIDOK_ARTYKUL WA ON WA.IdArtykulu = A.ID_ARTYKULU
#             """)
#             row = cur.fetchone()
#         return jsonify({"base": "ok", "id": row[0] if row else None}), 200
#     except Exception as e:
#         return jsonify({"base": "error", "error": str(e)}), 500


# @app.get("/api/dbping_base_nolock")
# def dbping_base_nolock():
#     try:
#         with pyodbc.connect(CONN_STR, timeout=5) as conn:
#             cur = conn.cursor()
#             cur.execute("""
#                 SET LOCK_TIMEOUT 3000;
#                 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
#                 SELECT TOP 1 A.ID_ARTYKULU
#                 FROM dbo.ARTYKUL A WITH (NOLOCK)
#                 LEFT JOIN dbo.WIDOK_ARTYKUL WA WITH (NOLOCK) ON WA.IdArtykulu = A.ID_ARTYKULU
#             """)
#             row = cur.fetchone()
#         return jsonify({"base_nolock": "ok", "id": row[0] if row else None}), 200
#     except Exception as e:
#         return jsonify({"base_nolock": "error", "error": str(e)}), 500


# @app.get("/api/products")
# def list_products():
#     q = request.args.get("q") or request.args.get("name") or request.args.get("search")
#     category = request.args.get("category")

#     try:
#         limit = int(request.args.get("limit", 100))
#     except Exception:
#         limit = 100
#     try:
#         offset = int(request.args.get("offset", 0))
#     except Exception:
#         offset = 0

#     sql = """
#     SET LOCK_TIMEOUT 3000;
#     SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

#     WITH base AS (
#         SELECT
#             A.ID_ARTYKULU                                         AS id,
#             COALESCE(NULLIF(WA.Nazwa1, ''), A.NAZWA, '')          AS name,
#             COALESCE(NULLIF(WA.Nazwa2, ''), '')                   AS description,
#             COALESCE(NULLIF(WA.Producent, ''), '')                AS producent,
#             COALESCE(
#                 NULLIF(WA.NrKatalogowy, ''),
#                 NULLIF(A.INDEKS_KATALOGOWY, ''),
#                 NULLIF(A.INDEKS_HANDLOWY, ''),
#                 ''
#             )                                                     AS sku
#         FROM dbo.ARTYKUL A WITH (NOLOCK)
#         LEFT JOIN dbo.WIDOK_ARTYKUL WA WITH (NOLOCK)
#                ON WA.IdArtykulu = A.ID_ARTYKULU
#     ),
#     qty AS (
#         SELECT
#             SM.id_artykulu                                        AS id,
#             SUM(
#                 CASE
#                     WHEN ISNUMERIC(SM.stan) = 1
#                         THEN CAST(SM.stan AS DECIMAL(18,3))
#                     ELSE 0
#                 END
#             )                                                     AS quantity,
#             MAX(COALESCE(NULLIF(SM.skrot, ''), ''))               AS unit
#         FROM dbo.JLVIEW_STANMAGAZYNU_RAP SM WITH (NOLOCK)
#         GROUP BY SM.id_artykulu
#     ),
#     bar AS (
#         SELECT
#             E.ID_ARTYKULU                                         AS id,
#             MAX(COALESCE(NULLIF(E.KOD_KRESKOWY, ''), ''))         AS barcode
#         FROM dbo.ART_ECR_MAG_V E WITH (NOLOCK)
#         GROUP BY E.ID_ARTYKULU
#     )
#     SELECT
#         CAST(B.id AS nvarchar(50))                                AS id,
#         B.name,
#         B.description,
#         CAST(COALESCE(Q.quantity, 0) AS int)                      AS quantity,
#         B.sku,
#         COALESCE(Bar.barcode, '')                                 AS barcode,
#         COALESCE(Q.unit, '')                                      AS unit,
#         B.producent,
#         NULL                                                      AS imageUrl
#     FROM base B
#     LEFT JOIN qty  Q   WITH (NOLOCK) ON Q.id   = B.id
#     LEFT JOIN bar  Bar WITH (NOLOCK) ON Bar.id = B.id
#     WHERE
#         ( ? IS NULL OR ? = '' OR
#           B.name LIKE ? OR B.sku LIKE ? OR COALESCE(Bar.barcode,'') LIKE ? OR
#           B.description LIKE ? OR B.producent LIKE ?
#         )
#         AND ( ? IS NULL OR LTRIM(RTRIM(B.description)) = LTRIM(RTRIM(?)) )
#     ORDER BY B.name
#     OFFSET ? ROWS FETCH NEXT ? ROWS ONLY;
#     """

#     like = f"%{q}%" if q else None
#     params = [q, q, like, like, like, like, like, category, category, offset, limit]

#     rows = fetch_all(sql, params)

#     out = []
#     for r in rows:
#         item = {
#             "id":         str(r.get("id") or ""),
#             "name":       r.get("name") or "",
#             "description":r.get("description") or "",
#             "quantity":   int(r.get("quantity") or 0),
#             "sku":        r.get("sku") or "",
#             "barcode":    r.get("barcode") or "",
#             "unit":       r.get("unit") or "",
#             "producent":  r.get("producent") or "",
#             "imageUrl":   r.get("imageUrl") or None,
#             "category":   (r.get("description") or "")
#         }
#         out.append(item)
#     return jsonify(out), 200


# @app.get("/api/products/<id>")
# def get_product(id):
#     sql = """
#     WITH base AS (
#         SELECT
#             A.ID_ARTYKULU                                         AS id,
#             COALESCE(NULLIF(WA.Nazwa1, ''), A.NAZWA, '')          AS name,
#             COALESCE(NULLIF(WA.Nazwa2, ''), '')                   AS description,
#             COALESCE(NULLIF(WA.Producent, ''), '')                AS producent,
#             COALESCE(
#                 NULLIF(WA.NrKatalogowy, ''),
#                 NULLIF(A.INDEKS_KATALOGOWY, ''),
#                 NULLIF(A.INDEKS_HANDLOWY, ''),
#                 ''
#             )                                                     AS sku
#         FROM dbo.ARTYKUL A
#         LEFT JOIN dbo.WIDOK_ARTYKUL WA
#                ON WA.IdArtykulu = A.ID_ARTYKULU
#     ),
#     qty AS (
#         SELECT
#             SM.id_artykulu                                        AS id,
#             SUM(
#                 CASE
#                     WHEN ISNUMERIC(SM.stan) = 1
#                         THEN CAST(SM.stan AS DECIMAL(18,3))
#                     ELSE 0
#                 END
#             )                                                     AS quantity,
#             MAX(COALESCE(NULLIF(SM.skrot, ''), ''))               AS unit
#         FROM dbo.JLVIEW_STANMAGAZYNU_RAP SM
#         GROUP BY SM.id_artykulu
#     ),
#     bar AS (
#         SELECT
#             E.ID_ARTYKULU                                         AS id,
#             MAX(COALESCE(NULLIF(E.KOD_KRESKOWY, ''), ''))         AS barcode
#         FROM dbo.ART_ECR_MAG_V E
#         GROUP BY E.ID_ARTYKULU
#     )
#     SELECT TOP 1
#         CAST(B.id AS nvarchar(50))                                AS id,
#         B.name,
#         B.description,
#         CAST(COALESCE(Q.quantity, 0) AS int)                      AS quantity,
#         B.sku,
#         COALESCE(Bar.barcode, '')                                 AS barcode,
#         COALESCE(Q.unit, '')                                      AS unit,
#         B.producent,
#         NULL                                                      AS imageUrl
#     FROM base B
#     LEFT JOIN qty  Q   ON Q.id   = B.id
#     LEFT JOIN bar  Bar ON Bar.id = B.id
#     WHERE
#         CAST(B.id AS nvarchar(50)) = ?
#         OR COALESCE(Bar.barcode,'') = ?
#         OR B.sku = ?;
#     """
#     rows = fetch_all(sql, (id, id, id))
#     if not rows:
#         return jsonify({}), 404

#     r = rows[0]
#     item = {
#         "id":         str(r.get("id") or ""),
#         "name":       r.get("name") or "",
#         "description":r.get("description") or "",
#         "quantity":   int(r.get("quantity") or 0),
#         "sku":        r.get("sku") or "",
#         "barcode":    r.get("barcode") or "",
#         "unit":       r.get("unit") or "",
#         "producent":  r.get("producent") or "",
#         "imageUrl":   r.get("imageUrl") or None,
#         "category":   (r.get("description") or "")
#     }
#     return jsonify(item), 200


# @app.get("/api/categories")
# def list_categories():
#     sql = """
#       SELECT DISTINCT
#         COALESCE(NULLIF(WA.Nazwa2, ''), '') AS category
#       FROM dbo.ARTYKUL A
#       LEFT JOIN dbo.WIDOK_ARTYKUL WA
#              ON WA.IdArtykulu = A.ID_ARTYKULU
#       WHERE COALESCE(NULLIF(WA.Nazwa2, ''), '') <> ''
#       ORDER BY category;
#     """
#     rows = fetch_all(sql)
#     cats = [(r.get("category") or "").strip()
#             for r in rows
#             if (r.get("category") or "").strip()]
#     return jsonify(cats), 200


# if __name__ == "__main__":
#     app.run(host="0.0.0.0", port=9103, debug=False)
