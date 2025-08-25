from flask import Flask, jsonify, request
from flask_cors import CORS
import pyodbc


app = Flask(__name__)
CORS(app) 


SERVER   = r"KASIA-BIURO\SQLEXPRESS"
DATABASE = "WAPRO"
USER     = "sc_app_test"
PWD      = "admin1234"
DRIVER   = "ODBC Driver 17 for SQL Server"

CONN_STR = (
    f"Driver={{{DRIVER}}};"
    f"Server={SERVER};"
    f"Database={DATABASE};"
    f"UID={USER};PWD={PWD};"
    "Encrypt=no;TrustServerCertificate=yes;"
)

def fetch_all(sql: str, params=()):
    """Run a SELECT and return a list of dicts."""
    with pyodbc.connect(CONN_STR) as conn:
        cur = conn.cursor()
        cur.execute(sql, params)
        cols = [d[0] for d in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]


@app.get("/api/health")
def health():
    return jsonify({"status": "ok"}), 200


@app.get("/api/products")
def list_products():
    """
    Pull products directly from WAPRO tables.
    Accepts:
      ?q= / ?name= / ?search=   (free-text across name, sku, barcode, desc, producent)
      ?category=                (exact match to Nazwa2; dropdown)
      ?limit= (default 100)
      ?offset= (default 0)

    Returns JSON array with keys:
      id, name, description, quantity, sku, barcode, unit, producent, imageUrl, category
      (category mirrors description for UI parity)
    """
    q = request.args.get("q") or request.args.get("name") or request.args.get("search")
    category = request.args.get("category")

    try:
        limit = int(request.args.get("limit", 100))
    except Exception:
        limit = 100
    try:
        offset = int(request.args.get("offset", 0))
    except Exception:
        offset = 0

    sql = """
    WITH base AS (
        SELECT
            A.ID_ARTYKULU                                         AS id,
            COALESCE(NULLIF(WA.Nazwa1, ''), A.NAZWA, '')          AS name,
            COALESCE(NULLIF(WA.Nazwa2, ''), '')                   AS description,  
            COALESCE(NULLIF(WA.Producent, ''), '')                AS producent,
            COALESCE(
                NULLIF(WA.NrKatalogowy, ''),
                NULLIF(A.INDEKS_KATALOGOWY, ''),
                NULLIF(A.INDEKS_HANDLOWY, ''),
                ''
            )                                                     AS sku
        FROM dbo.ARTYKUL A
        LEFT JOIN dbo.WIDOK_ARTYKUL WA
               ON WA.IdArtykulu = A.ID_ARTYKULU
    ),
    qty AS (
        SELECT
            SM.id_artykulu                                        AS id,
            SUM(
                CASE
                    WHEN ISNUMERIC(SM.stan) = 1
                        THEN CAST(SM.stan AS DECIMAL(18,3))
                    ELSE 0
                END
            )                                                      AS quantity,
            MAX(COALESCE(NULLIF(SM.skrot, ''), ''))               AS unit
        FROM dbo.JLVIEW_STANMAGAZYNU_RAP SM
        GROUP BY SM.id_artykulu
    ),
    bar AS (
        SELECT
            E.ID_ARTYKULU                                         AS id,
            MAX(COALESCE(NULLIF(E.KOD_KRESKOWY, ''), ''))         AS barcode
        FROM dbo.ART_ECR_MAG_V E
        GROUP BY E.ID_ARTYKULU
    )
    SELECT
        CAST(B.id AS nvarchar(50))                                AS id,
        B.name,
        B.description,
        CAST(COALESCE(Q.quantity, 0) AS int)                      AS quantity,
        B.sku,
        COALESCE(Bar.barcode, '')                                 AS barcode,
        COALESCE(Q.unit, '')                                      AS unit,
        B.producent,
        NULL                                                      AS imageUrl
    FROM base B
    LEFT JOIN qty  Q   ON Q.id   = B.id
    LEFT JOIN bar  Bar ON Bar.id = B.id
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
    params = [
        q, q,               
        like, like, like, like, like,
        category, category,  # exact category match (Nazwa2)
        offset, limit
    ]

    rows = fetch_all(sql, params)

    out = []
    for r in rows:
        item = {
            "id":         str(r.get("id") or ""),
            "name":       r.get("name") or "",
            "description":r.get("description") or "",
            "quantity":   int(r.get("quantity") or 0),
            "sku":        r.get("sku") or "",
            "barcode":    r.get("barcode") or "",
            "unit":       r.get("unit") or "",
            "producent":  r.get("producent") or "",
            "imageUrl":   r.get("imageUrl") or None,
            # UI parity: category mirrors description
            "category":   (r.get("description") or "")
        }
        out.append(item)
    return jsonify(out), 200


@app.get("/api/products/<id>")
def get_product(id):
    """
    Robust single fetch against the same tables:
      - match by ID_ARTYKULU (string compare)
      - or by exact BARCODE (ART_ECR_MAG_V.KOD_KRESKOWY)
      - or by exact SKU (NrKatalogowy / INDEKS_KATALOGOWY / INDEKS_HANDLOWY)
    """
    sql = """
    WITH base AS (
        SELECT
            A.ID_ARTYKULU                                         AS id,
            COALESCE(NULLIF(WA.Nazwa1, ''), A.NAZWA, '')          AS name,
            COALESCE(NULLIF(WA.Nazwa2, ''), '')                   AS description,
            COALESCE(NULLIF(WA.Producent, ''), '')                AS producent,
            COALESCE(
                NULLIF(WA.NrKatalogowy, ''),
                NULLIF(A.INDEKS_KATALOGOWY, ''),
                NULLIF(A.INDEKS_HANDLOWY, ''),
                ''
            )                                                     AS sku
        FROM dbo.ARTYKUL A
        LEFT JOIN dbo.WIDOK_ARTYKUL WA
               ON WA.IdArtykulu = A.ID_ARTYKULU
    ),
    qty AS (
        SELECT
            SM.id_artykulu                                        AS id,
            SUM(
                CASE
                    WHEN ISNUMERIC(SM.stan) = 1
                        THEN CAST(SM.stan AS DECIMAL(18,3))
                    ELSE 0
                END
            )                                                      AS quantity,
            MAX(COALESCE(NULLIF(SM.skrot, ''), ''))               AS unit
        FROM dbo.JLVIEW_STANMAGAZYNU_RAP SM
        GROUP BY SM.id_artykulu
    ),
    bar AS (
        SELECT
            E.ID_ARTYKULU                                         AS id,
            MAX(COALESCE(NULLIF(E.KOD_KRESKOWY, ''), ''))         AS barcode
        FROM dbo.ART_ECR_MAG_V E
        GROUP BY E.ID_ARTYKULU
    )
    SELECT TOP 1
        CAST(B.id AS nvarchar(50))                                AS id,
        B.name,
        B.description,
        CAST(COALESCE(Q.quantity, 0) AS int)                      AS quantity,
        B.sku,
        COALESCE(Bar.barcode, '')                                 AS barcode,
        COALESCE(Q.unit, '')                                      AS unit,
        B.producent,
        NULL                                                      AS imageUrl
    FROM base B
    LEFT JOIN qty  Q   ON Q.id   = B.id
    LEFT JOIN bar  Bar ON Bar.id = B.id
    WHERE
        CAST(B.id AS nvarchar(50)) = ?          -- by ID
        OR COALESCE(Bar.barcode,'') = ?         -- by barcode
        OR B.sku = ?;                           -- by SKU
    """
    rows = fetch_all(sql, (id, id, id))
    if not rows:
        return jsonify({}), 404

    r = rows[0]
    item = {
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
    }
    return jsonify(item), 200


@app.get("/api/categories")
def list_categories():
    """
    Distinct categories from WIDOK_ARTYKUL.Nazwa2 (used as 'description' in the app).
    """
    sql = """
      SELECT DISTINCT
        COALESCE(NULLIF(WA.Nazwa2, ''), '') AS category
      FROM dbo.ARTYKUL A
      LEFT JOIN dbo.WIDOK_ARTYKUL WA
             ON WA.IdArtykulu = A.ID_ARTYKULU
      WHERE COALESCE(NULLIF(WA.Nazwa2, ''), '') <> ''
      ORDER BY category;
    """
    rows = fetch_all(sql)
    cats = [(r.get("category") or "").strip()
            for r in rows
            if (r.get("category") or "").strip()]
    return jsonify(cats), 200


if __name__ == "__main__":
    #   python -m waitress --listen=0.0.0.0:9103 app:app
    app.run(host="0.0.0.0", port=9103, debug=False)
