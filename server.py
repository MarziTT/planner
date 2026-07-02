#!/usr/bin/env python3
"""
Pixel Planner v3.2 — Python Backend (SQLite / PostgreSQL)
Flask REST API server for event/tag/user management.

Local dev (SQLite):
    python server.py
    → uses data/pixel_planner.db

Railway / Cloud (PostgreSQL):
    Set DATABASE_URL env var → uses PostgreSQL via psycopg2

Default port: 5000 (local) or $PORT (Railway)
"""

import base64
import hashlib
import hmac
import json
import os
import sqlite3
import time as time_mod
from datetime import datetime
from pathlib import Path

import requests
from flask import Flask, g, jsonify, request, send_file
from flask_cors import CORS

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
DB_PATH = DATA_DIR / "pixel_planner.db"
PORT = int(os.environ.get("PORT", 5000))
DATABASE_URL = os.environ.get("DATABASE_URL", "")

# Ensure data directory exists (for SQLite)
DATA_DIR.mkdir(parents=True, exist_ok=True)

app = Flask(__name__)
CORS(app)

# ---------------------------------------------------------------------------
# Database adapter — unified SQLite / PostgreSQL interface
# ---------------------------------------------------------------------------

USE_PG = bool(DATABASE_URL and "postgres" in DATABASE_URL)

if USE_PG:
    import psycopg2
    import psycopg2.extras

    PG_CONNECTED = False
    PG_CONNECT_ERROR = ""

    def get_db():
        if "db" not in g:
            try:
                g.db = psycopg2.connect(DATABASE_URL, connect_timeout=5)
                g.db.autocommit = False
            except Exception as e:
                g.db = None
                g.db_error = str(e)
                raise RuntimeError(f"PostgreSQL connection failed: {e}")
        return g.db

    def get_cursor():
        db = get_db()
        return db.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    @app.teardown_appcontext
    def close_db(exception):
        db = g.pop("db", None)
        if db is not None:
            try:
                db.close()
            except Exception:
                pass

    def init_db():
        global PG_CONNECTED, PG_CONNECT_ERROR
        try:
            db = get_db()
            cur = db.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    username TEXT UNIQUE NOT NULL,
                    password TEXT NOT NULL,
                    created_at TIMESTAMP DEFAULT NOW()
                );
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS user_profiles (
                    user_id INTEGER PRIMARY KEY,
                    identity TEXT,
                    goal TEXT,
                    preferred_tags TEXT,
                    recommended_theme TEXT DEFAULT 'dark',
                    FOREIGN KEY (user_id) REFERENCES users(id)
                );
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS events (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    title TEXT NOT NULL,
                    date TEXT NOT NULL,
                    time TEXT NOT NULL,
                    end_time TEXT,
                    tags TEXT,
                    completed INTEGER DEFAULT 0,
                    notes TEXT DEFAULT '',
                    created_at TIMESTAMP DEFAULT NOW(),
                    FOREIGN KEY (user_id) REFERENCES users(id)
                );
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS tags (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    name TEXT NOT NULL,
                    color TEXT DEFAULT '#3b82f6',
                    emoji TEXT DEFAULT '📌',
                    UNIQUE(user_id, name),
                    FOREIGN KEY (user_id) REFERENCES users(id)
                );
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS user_settings (
                    user_id INTEGER PRIMARY KEY,
                    theme TEXT DEFAULT 'dark',
                    FOREIGN KEY (user_id) REFERENCES users(id)
                );
                CREATE TABLE IF NOT EXISTS todolist (
                    id SERIAL PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    todos TEXT DEFAULT '[]',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """)
            db.commit()
            PG_CONNECTED = True
            print("[PixelPlanner] PostgreSQL connected & tables ready")
        except Exception as e:
            PG_CONNECTED = False
            PG_CONNECT_ERROR = str(e)
            print(f"[PixelPlanner] WARNING: PostgreSQL init failed: {e}")
            print("[PixelPlanner] Server will start but DB operations will fail until fixed")

else:
    # SQLite fallback
    def get_db():
        if "db" not in g:
            g.db = sqlite3.connect(str(DB_PATH))
            g.db.row_factory = sqlite3.Row
            g.db.execute("PRAGMA journal_mode=WAL")
            g.db.execute("PRAGMA foreign_keys=ON")
        return g.db

    def get_cursor():
        return get_db()

    @app.teardown_appcontext
    def close_db(exception):
        db = g.pop("db", None)
        if db is not None:
            db.close()

    def init_db():
        db = get_db()
        db.executescript("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS user_profiles (
                user_id INTEGER PRIMARY KEY,
                identity TEXT,
                goal TEXT,
                preferred_tags TEXT,
                recommended_theme TEXT DEFAULT 'dark',
                FOREIGN KEY (user_id) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                date TEXT NOT NULL,
                time TEXT NOT NULL,
                end_time TEXT,
                tags TEXT,
                completed INTEGER DEFAULT 0,
                notes TEXT DEFAULT '',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS tags (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                name TEXT NOT NULL,
                color TEXT DEFAULT '#3b82f6',
                emoji TEXT DEFAULT '📌',
                UNIQUE(user_id, name),
                FOREIGN KEY (user_id) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS user_settings (
                user_id INTEGER PRIMARY KEY,
                theme TEXT DEFAULT 'dark',
                FOREIGN KEY (user_id) REFERENCES users(id)
            );

            CREATE TABLE IF NOT EXISTS todolist (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                todos TEXT DEFAULT '[]',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        db.commit()


# ---------------------------------------------------------------------------
# Unified query helpers
# ---------------------------------------------------------------------------

def db_execute(sql, params=None, fetch=False, fetchone=False):
    """Execute SQL and optionally return results. Handles ? → %s for PG."""
    if USE_PG:
        sql = sql.replace("?", "%s")
    cur = get_cursor()
    cur.execute(sql, params or ())
    if fetch:
        return cur.fetchall()
    if fetchone:
        return cur.fetchone()
    return cur


def db_commit():
    get_db().commit()


def db_lastrowid(cur):
    """Return last inserted row id. PG: use RETURNING; SQLite: cur.lastrowid."""
    if USE_PG:
        row = cur.fetchone()
        return row["id"] if row else None
    return cur.lastrowid


def db_row_to_dict(row):
    """Convert a DB row to a plain dict. PG already RealDict; SQLite needs conversion."""
    if USE_PG:
        return dict(row) if row else None
    return dict(row) if row else None


def db_rows_to_list(rows):
    """Convert list of rows to list of dicts."""
    return [dict(r) for r in rows]


# Initialize DB on first request (safe: won't crash worker on PG failure)
_DB_INITIALIZED = False


@app.before_request
def before_request():
    global _DB_INITIALIZED
    if not _DB_INITIALIZED:
        _DB_INITIALIZED = True
        try:
            init_db()
        except Exception as e:
            print(f"[PixelPlanner] init_db error (server still running): {e}")


# ---------------------------------------------------------------------------
# Auth helper
# ---------------------------------------------------------------------------

def get_user():
    """Return user_id from request args or JSON body, or None."""
    user_id = request.args.get("user_id") or (
        request.json.get("user_id") if request.is_json else None
    )
    if user_id is not None:
        return int(user_id)
    return None


# ---------------------------------------------------------------------------
# Auth endpoints
# ---------------------------------------------------------------------------

@app.route("/api/register", methods=["POST"])
def register():
    data = request.get_json(force=True)
    username = data.get("username", "").strip()
    password = data.get("password", "").strip()

    if not username or not password:
        return jsonify({"ok": False, "error": "用户名和密码不能为空"}), 400

    if len(password) < 4:
        return jsonify({"ok": False, "error": "密码至少4位"}), 400

    try:
        if USE_PG:
            cur = db_execute(
                "INSERT INTO users (username, password) VALUES (?, ?) RETURNING id",
                (username, password),
            )
            user_id = db_lastrowid(cur)
        else:
            cur = db_execute(
                "INSERT INTO users (username, password) VALUES (?, ?)",
                (username, password),
            )
            user_id = cur.lastrowid
        db_commit()
        return jsonify({"ok": True, "user_id": user_id, "username": username})
    except Exception as e:
        if USE_PG:
            db_commit()  # rollback on error handled by psycopg2
        if "UNIQUE" in str(e).upper() or "unique" in str(e).lower() or "IntegrityError" in str(type(e).__name__):
            return jsonify({"ok": False, "error": "用户名已存在"}), 409
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/api/login", methods=["POST"])
def login():
    data = request.get_json(force=True)
    username = data.get("username", "").strip()
    password = data.get("password", "").strip()

    row = db_execute(
        "SELECT id, username FROM users WHERE username = ? AND password = ?",
        (username, password),
        fetchone=True,
    )

    if not row:
        return jsonify({"ok": False, "error": "用户名或密码错误"}), 401

    r = dict(row)
    return jsonify({"ok": True, "user_id": r["id"], "username": r["username"]})


# ---------------------------------------------------------------------------
# Events CRUD
# ---------------------------------------------------------------------------

@app.route("/api/events", methods=["GET"])
def get_events():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    date = request.args.get("date", "")

    if date:
        rows = db_execute(
            "SELECT * FROM events WHERE user_id = ? AND date = ? ORDER BY time",
            (user_id, date),
            fetch=True,
        )
    else:
        rows = db_execute(
            "SELECT * FROM events WHERE user_id = ? ORDER BY date, time",
            (user_id,),
            fetch=True,
        )

    events = []
    for r in rows:
        e = dict(r)
        try:
            e["tags"] = json.loads(e["tags"]) if e["tags"] else []
        except (json.JSONDecodeError, TypeError):
            e["tags"] = []
        e["completed"] = bool(e["completed"])
        events.append(e)

    return jsonify({"ok": True, "events": events})


@app.route("/api/events", methods=["POST"])
def create_event():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    data = request.get_json(force=True)
    title = data.get("title", "").strip()
    date = data.get("date", "").strip()
    time = data.get("time", "").strip()
    end_time = data.get("end_time", "").strip()
    tags = json.dumps(data.get("tags", []), ensure_ascii=False)
    completed = 1 if data.get("completed") else 0
    notes = data.get("notes", "")

    if not title or not date or not time:
        return jsonify({"ok": False, "error": "title/date/time 为必填项"}), 400

    if USE_PG:
        cur = db_execute(
            """INSERT INTO events (user_id, title, date, time, end_time, tags, completed, notes)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id""",
            (user_id, title, date, time, end_time, tags, completed, notes),
        )
        new_id = db_lastrowid(cur)
    else:
        cur = db_execute(
            """INSERT INTO events (user_id, title, date, time, end_time, tags, completed, notes)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            (user_id, title, date, time, end_time, tags, completed, notes),
        )
        new_id = cur.lastrowid
    db_commit()

    row = db_execute("SELECT * FROM events WHERE id = ?", (new_id,), fetchone=True)
    e = dict(row)
    try:
        e["tags"] = json.loads(e["tags"]) if e["tags"] else []
    except (json.JSONDecodeError, TypeError):
        e["tags"] = []
    e["completed"] = bool(e["completed"])

    return jsonify({"ok": True, "event": e})


@app.route("/api/events/<int:event_id>", methods=["PUT"])
def update_event(event_id):
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    data = request.get_json(force=True)

    row = db_execute(
        "SELECT id FROM events WHERE id = ? AND user_id = ?",
        (event_id, user_id),
        fetchone=True,
    )
    if not row:
        return jsonify({"ok": False, "error": "事件不存在"}), 404

    fields = []
    values = []

    for key in ["title", "date", "time", "end_time", "notes"]:
        if key in data:
            fields.append(f"{key} = ?")
            values.append(data[key])

    if "tags" in data:
        fields.append("tags = ?")
        values.append(json.dumps(data["tags"], ensure_ascii=False))

    if "completed" in data:
        fields.append("completed = ?")
        values.append(1 if data["completed"] else 0)

    if not fields:
        return jsonify({"ok": False, "error": "无更新字段"}), 400

    values.append(event_id)

    sql = f"UPDATE events SET {', '.join(fields)} WHERE id = ?"
    if USE_PG:
        sql = sql.replace("?", "%s")
    cur = get_cursor()
    cur.execute(sql, values)
    db_commit()

    row = db_execute("SELECT * FROM events WHERE id = ?", (event_id,), fetchone=True)
    e = dict(row)
    try:
        e["tags"] = json.loads(e["tags"]) if e["tags"] else []
    except (json.JSONDecodeError, TypeError):
        e["tags"] = []
    e["completed"] = bool(e["completed"])

    return jsonify({"ok": True, "event": e})


@app.route("/api/events/<int:event_id>", methods=["DELETE"])
def delete_event(event_id):
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    row = db_execute(
        "SELECT id FROM events WHERE id = ? AND user_id = ?",
        (event_id, user_id),
        fetchone=True,
    )
    if not row:
        return jsonify({"ok": False, "error": "事件不存在"}), 404

    db_execute("DELETE FROM events WHERE id = ?", (event_id,))
    db_commit()
    return jsonify({"ok": True, "deleted_id": event_id})


# ---------------------------------------------------------------------------
# Tags CRUD
# ---------------------------------------------------------------------------

@app.route("/api/tags", methods=["GET"])
def get_tags():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    rows = db_execute(
        "SELECT * FROM tags WHERE user_id = ? ORDER BY name", (user_id,), fetch=True
    )
    return jsonify({"ok": True, "tags": db_rows_to_list(rows)})


@app.route("/api/tags", methods=["POST"])
def create_tag():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    data = request.get_json(force=True)
    name = data.get("name", "").strip()
    color = data.get("color", "#3b82f6")
    emoji = data.get("emoji", "📌")

    if not name:
        return jsonify({"ok": False, "error": "标签名不能为空"}), 400

    try:
        if USE_PG:
            cur = db_execute(
                "INSERT INTO tags (user_id, name, color, emoji) VALUES (?, ?, ?, ?) RETURNING id",
                (user_id, name, color, emoji),
            )
            tag_id = db_lastrowid(cur)
        else:
            cur = db_execute(
                "INSERT INTO tags (user_id, name, color, emoji) VALUES (?, ?, ?, ?)",
                (user_id, name, color, emoji),
            )
            tag_id = cur.lastrowid
        db_commit()
        return jsonify({
            "ok": True,
            "tag": {"id": tag_id, "user_id": user_id, "name": name, "color": color, "emoji": emoji},
        })
    except Exception:
        if USE_PG:
            try:
                get_db().rollback()
            except Exception:
                pass
        return jsonify({"ok": False, "error": "标签名已存在"}), 409


@app.route("/api/tags/<int:tag_id>", methods=["PUT"])
def update_tag(tag_id):
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    data = request.get_json(force=True)

    row = db_execute(
        "SELECT id FROM tags WHERE id = ? AND user_id = ?",
        (tag_id, user_id),
        fetchone=True,
    )
    if not row:
        return jsonify({"ok": False, "error": "标签不存在"}), 404

    fields = []
    values = []

    if "name" in data:
        fields.append("name = ?")
        values.append(data["name"])
    if "color" in data:
        fields.append("color = ?")
        values.append(data["color"])
    if "emoji" in data:
        fields.append("emoji = ?")
        values.append(data["emoji"])

    if not fields:
        return jsonify({"ok": False, "error": "无更新字段"}), 400

    values.append(tag_id)

    try:
        sql = f"UPDATE tags SET {', '.join(fields)} WHERE id = ?"
        if USE_PG:
            sql = sql.replace("?", "%s")
        cur = get_cursor()
        cur.execute(sql, values)
        db_commit()
    except Exception:
        if USE_PG:
            try:
                get_db().rollback()
            except Exception:
                pass
        return jsonify({"ok": False, "error": "标签名已存在"}), 409

    row = db_execute("SELECT * FROM tags WHERE id = ?", (tag_id,), fetchone=True)
    return jsonify({"ok": True, "tag": dict(row)})


@app.route("/api/tags/<int:tag_id>", methods=["DELETE"])
def delete_tag(tag_id):
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    row = db_execute(
        "SELECT id FROM tags WHERE id = ? AND user_id = ?",
        (tag_id, user_id),
        fetchone=True,
    )
    if not row:
        return jsonify({"ok": False, "error": "标签不存在"}), 404

    db_execute("DELETE FROM tags WHERE id = ?", (tag_id,))
    db_commit()
    return jsonify({"ok": True, "deleted_id": tag_id})


# ---------------------------------------------------------------------------
# User Profile
# ---------------------------------------------------------------------------

@app.route("/api/profile", methods=["GET"])
def get_profile():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    row = db_execute(
        "SELECT * FROM user_profiles WHERE user_id = ?", (user_id,), fetchone=True
    )

    if not row:
        return jsonify({"ok": True, "profile": None})

    p = dict(row)
    try:
        p["preferred_tags"] = json.loads(p["preferred_tags"]) if p["preferred_tags"] else []
    except (json.JSONDecodeError, TypeError):
        p["preferred_tags"] = []
    return jsonify({"ok": True, "profile": p})


@app.route("/api/profile", methods=["PUT"])
def update_profile():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    data = request.get_json(force=True)
    identity = data.get("identity", "")
    goal = data.get("goal", "")
    preferred_tags = json.dumps(data.get("preferred_tags", []), ensure_ascii=False)
    recommended_theme = data.get("recommended_theme", "dark")

    # UPSERT: works on both SQLite (3.24+) and PostgreSQL (9.5+)
    db_execute(
        """INSERT INTO user_profiles (user_id, identity, goal, preferred_tags, recommended_theme)
           VALUES (?, ?, ?, ?, ?)
           ON CONFLICT (user_id) DO UPDATE SET
               identity = EXCLUDED.identity,
               goal = EXCLUDED.goal,
               preferred_tags = EXCLUDED.preferred_tags,
               recommended_theme = EXCLUDED.recommended_theme""",
        (user_id, identity, goal, preferred_tags, recommended_theme),
    )
    db_commit()
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# User Settings
# ---------------------------------------------------------------------------

@app.route("/api/settings", methods=["GET"])
def get_settings():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    row = db_execute(
        "SELECT * FROM user_settings WHERE user_id = ?", (user_id,), fetchone=True
    )

    if not row:
        return jsonify({"ok": True, "settings": {"theme": "dark"}})

    return jsonify({"ok": True, "settings": dict(row)})


@app.route("/api/settings", methods=["PUT"])
def update_settings():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    data = request.get_json(force=True)
    theme = data.get("theme", "dark")

    db_execute(
        """INSERT INTO user_settings (user_id, theme) VALUES (?, ?)
           ON CONFLICT (user_id) DO UPDATE SET theme = EXCLUDED.theme""",
        (user_id, theme),
    )
    db_commit()
    return jsonify({"ok": True, "settings": {"user_id": user_id, "theme": theme}})


# ---------------------------------------------------------------------------
# Stats (monthly)
# ---------------------------------------------------------------------------

@app.route("/api/stats", methods=["GET"])
def get_stats():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    month = request.args.get("month", "")
    if not month:
        now = datetime.now()
        month = f"{now.year}-{now.month:02d}"

    rows = db_execute(
        "SELECT * FROM events WHERE user_id = ? AND date LIKE ? ORDER BY date, time",
        (user_id, f"{month}%"),
        fetch=True,
    )

    total = len(rows)
    completed = sum(1 for r in rows if r["completed"])

    per_day = {}
    for r in rows:
        d = r["date"]
        if d not in per_day:
            per_day[d] = {"total": 0, "completed": 0}
        per_day[d]["total"] += 1
        if r["completed"]:
            per_day[d]["completed"] += 1

    return jsonify({
        "ok": True,
        "stats": {
            "month": month,
            "total_events": total,
            "completed": completed,
            "completion_rate": round(completed / total * 100, 1) if total else 0,
            "per_day": per_day,
        },
    })


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

@app.route("/api/ping", methods=["GET"])
def ping():
    db_type = "PostgreSQL" if USE_PG else "SQLite"
    extra = {}
    if USE_PG:
        extra["pg_connected"] = PG_CONNECTED
        if not PG_CONNECTED:
            extra["pg_error"] = PG_CONNECT_ERROR
    else:
        # Debug: is DATABASE_URL set but not detected?
        raw_url = os.environ.get("DATABASE_URL", "")
        extra["DATABASE_URL_set"] = bool(raw_url)
        if raw_url:
            extra["DATABASE_URL_preview"] = raw_url[:30] + "..."
            extra["contains_postgres"] = "postgres" in raw_url
    return jsonify({"ok": True, "message": f"Pixel Planner API v3.2 ({db_type})", **extra})


# ---------------------------------------------------------------------------
# Hot Update — Version & File Serving
# ---------------------------------------------------------------------------

WWW_DIR = BASE_DIR / "www"


def _compute_md5(file_path):
    """Compute MD5 hash of a file."""
    hash_md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


@app.route("/api/version", methods=["GET"])
def api_version():
    """Return current project version and all www/ file paths with MD5 hashes."""
    # Read version from package.json
    pkg_path = BASE_DIR / "package.json"
    try:
        with open(pkg_path, "r", encoding="utf-8") as f:
            pkg = json.load(f)
        version = pkg.get("version", "0.0.0")
    except Exception:
        version = "0.0.0"

    # Scan www/ directory recursively
    files = []
    if WWW_DIR.exists():
        for file_path in sorted(WWW_DIR.rglob("*")):
            if file_path.is_file():
                rel_path = str(file_path.relative_to(WWW_DIR)).replace("\\", "/")
                md5 = _compute_md5(file_path)
                files.append({"path": rel_path, "md5": md5})

    return jsonify({"version": version, "files": files})


@app.route("/api/update/<path:file_path>", methods=["GET"])
def api_update(file_path):
    """Serve a file from www/ directory."""
    safe_path = (WWW_DIR / file_path).resolve()

    # Security: prevent path traversal outside www/
    if not str(safe_path).startswith(str(WWW_DIR.resolve())):
        return jsonify({"ok": False, "error": "Invalid path"}), 403

    if not safe_path.is_file():
        return jsonify({"ok": False, "error": "File not found"}), 404

    return send_file(str(safe_path))


@app.route("/<path:filename>")
def serve_www_file(filename):
    """Serve any file from www/ directory at root path (for APK download etc)."""
    safe_path = (WWW_DIR / filename).resolve()
    if not str(safe_path).startswith(str(WWW_DIR.resolve())):
        return jsonify({"ok": False, "error": "Invalid path"}), 403
    if not safe_path.is_file():
        return jsonify({"ok": False, "error": "Not found"}), 404
    return send_file(str(safe_path))


# ---------------------------------------------------------------------------
# Tencent Cloud ASR — Voice Recognition Proxy
# ---------------------------------------------------------------------------

TENCENT_SECRET_ID = os.environ.get("TENCENT_SECRET_ID", "")
TENCENT_SECRET_KEY = os.environ.get("TENCENT_SECRET_KEY", "")


def _tc3_sign(secret_id, secret_key, service, host, action, payload, region="ap-guangzhou"):
    """Generate TC3-HMAC-SHA256 signature headers for Tencent Cloud API."""
    algorithm = "TC3-HMAC-SHA256"
    timestamp = int(time_mod.time())
    date_str = datetime.utcfromtimestamp(timestamp).strftime("%Y-%m-%d")

    # Step 1: Canonical Request
    http_method = "POST"
    canonical_uri = "/"
    canonical_querystring = ""
    ct = "application/json; charset=utf-8"
    canonical_headers = f"content-type:{ct}\nhost:{host}\nx-tc-action:{action.lower()}\n"
    signed_headers = "content-type;host;x-tc-action"
    hashed_payload = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    canonical_request = (
        f"{http_method}\n{canonical_uri}\n{canonical_querystring}\n"
        f"{canonical_headers}\n{signed_headers}\n{hashed_payload}"
    )

    # Step 2: String to Sign
    credential_scope = f"{date_str}/{service}/tc3_request"
    hashed_canonical = hashlib.sha256(canonical_request.encode("utf-8")).hexdigest()
    string_to_sign = f"{algorithm}\n{timestamp}\n{credential_scope}\n{hashed_canonical}"

    # Step 3: Signature
    def _sign(key, msg):
        return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()

    secret_date = _sign(("TC3" + secret_key).encode("utf-8"), date_str)
    secret_service = _sign(secret_date, service)
    secret_signing = _sign(secret_service, "tc3_request")
    signature = hmac.new(secret_signing, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()

    # Step 4: Authorization
    authorization = (
        f"{algorithm} Credential={secret_id}/{credential_scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}"
    )

    return {
        "Authorization": authorization,
        "Content-Type": ct,
        "Host": host,
        "X-TC-Action": action,
        "X-TC-Timestamp": str(timestamp),
        "X-TC-Version": "2019-06-14",
        "X-TC-Region": region,
    }


# ---------------------------------------------------------------------------
# TodoList API
# ---------------------------------------------------------------------------

@app.route("/api/todolist", methods=["GET"])
def get_todolist():
    """Get user's todolist items."""
    user_id = request.args.get("user_id", "")
    if not user_id:
        return jsonify({"ok": False, "error": "user_id required"}), 400
    try:
        with get_db() as conn:
            row = conn.execute(
                "SELECT todos FROM todolist WHERE user_id = ?", (user_id,)
            ).fetchone()
            if row:
                import json
                todos = json.loads(row["todos"])
                return jsonify({"ok": True, "todos": todos})
            return jsonify({"ok": True, "todos": []})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/api/todolist", methods=["POST"])
def save_todolist():
    """Save user's todolist items (full replace)."""
    user_id = request.args.get("user_id", "")
    if not user_id:
        return jsonify({"ok": False, "error": "user_id required"}), 400
    data = request.get_json(force=True, silent=True) or {}
    todos = data.get("todos", [])
    import json
    todos_json = json.dumps(todos, ensure_ascii=False)
    try:
        with get_db() as conn:
            existing = conn.execute(
                "SELECT id FROM todolist WHERE user_id = ?", (user_id,)
            ).fetchone()
            if existing:
                conn.execute(
                    "UPDATE todolist SET todos = ?, updated_at = CURRENT_TIMESTAMP WHERE user_id = ?",
                    (todos_json, user_id)
                )
            else:
                conn.execute(
                    "INSERT INTO todolist (user_id, todos) VALUES (?, ?)",
                    (user_id, todos_json)
                )
        return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/api/asr", methods=["POST"])
def asr_recognize():
    """Proxy: receive audio from client, forward to Tencent Cloud ASR."""
    if not TENCENT_SECRET_ID or not TENCENT_SECRET_KEY:
        return jsonify({"ok": False, "error": "ASR credentials not configured"}), 500

    audio_data = request.data
    if not audio_data:
        return jsonify({"ok": False, "error": "No audio data received"}), 400

    # Detect audio format from Content-Type header
    content_type = request.headers.get("Content-Type", "audio/webm")
    fmt_map = {
        "audio/webm": "webm",
        "audio/wav": "wav",
        "audio/mpeg": "mp3",
        "audio/mp4": "m4a",
        "audio/ogg": "ogg-opus",
    }
    voice_format = fmt_map.get(content_type.split(";")[0].strip(), "webm")

    audio_b64 = base64.b64encode(audio_data).decode("utf-8")

    req_body = json.dumps({
        "EngSerViceType": "16k_zh",
        "SourceType": 1,
        "VoiceFormat": voice_format,
        "Data": audio_b64,
        "DataLen": len(audio_data),
    })

    host = "asr.tencentcloudapi.com"
    headers = _tc3_sign(TENCENT_SECRET_ID, TENCENT_SECRET_KEY, "asr", host, "SentenceRecognition", req_body)

    try:
        resp = requests.post(f"https://{host}", headers=headers, data=req_body, timeout=15)
        result = resp.json()
        if "Response" in result:
            if "Result" in result["Response"]:
                return jsonify({"ok": True, "text": result["Response"]["Result"]})
            if "Error" in result["Response"]:
                return jsonify({"ok": False, "error": result["Response"]["Error"].get("Message", "Unknown error")})
        return jsonify({"ok": False, "error": "Unexpected response from Tencent Cloud"}), 502
    except requests.exceptions.Timeout:
        return jsonify({"ok": False, "error": "ASR request timed out"}), 504
    except requests.exceptions.ConnectionError:
        return jsonify({"ok": False, "error": "Cannot connect to Tencent Cloud ASR"}), 502
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    db_type = "PostgreSQL" if USE_PG else "SQLite"
    db_info = DATABASE_URL.split("@")[-1].split("/")[-1] if USE_PG else str(DB_PATH)
    print(f"[PixelPlanner] Mode: {db_type}")
    print(f"[PixelPlanner] Database: {db_info}")
    print(f"[PixelPlanner] Starting server on http://localhost:{PORT}")
    app.run(host="0.0.0.0", port=PORT, debug=not USE_PG)
