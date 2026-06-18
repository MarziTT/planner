#!/usr/bin/env python3
"""
Pixel Planner v3.2 — Python + SQLite Backend
Flask REST API server for event/tag/user management.

Run:
    python server.py
Default port: 5000
Database: data/pixel_planner.db (auto-created on first run)
"""

import json
import os
import sqlite3
import uuid
from datetime import datetime
from pathlib import Path

from flask import Flask, g, jsonify, request
from flask_cors import CORS

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
DB_PATH = DATA_DIR / "pixel_planner.db"
PORT = int(os.environ.get("PORT", 5000))

# Ensure data directory exists
DATA_DIR.mkdir(parents=True, exist_ok=True)

app = Flask(__name__)
CORS(app)

app.config["DB_PATH"] = str(DB_PATH)

# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

def get_db():
    """Get a thread-local SQLite connection with row_factory."""
    if "db" not in g:
        g.db = sqlite3.connect(str(DB_PATH))
        g.db.row_factory = sqlite3.Row
        g.db.execute("PRAGMA journal_mode=WAL")
        g.db.execute("PRAGMA foreign_keys=ON")
    return g.db


@app.teardown_appcontext
def close_db(exception):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db():
    """Create tables if they don't exist."""
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
    """)
    db.commit()


# Initialize DB on first request
@app.before_request
def before_request():
    init_db()


# ---------------------------------------------------------------------------
# Simple auth helper  (no JWT — local app, user_id passed as param)
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

    db = get_db()
    try:
        cur = db.execute(
            "INSERT INTO users (username, password) VALUES (?, ?)",
            (username, password),
        )
        user_id = cur.lastrowid
        db.commit()
        return jsonify({"ok": True, "user_id": user_id, "username": username})
    except sqlite3.IntegrityError:
        return jsonify({"ok": False, "error": "用户名已存在"}), 409


@app.route("/api/login", methods=["POST"])
def login():
    data = request.get_json(force=True)
    username = data.get("username", "").strip()
    password = data.get("password", "").strip()

    db = get_db()
    row = db.execute(
        "SELECT id, username FROM users WHERE username = ? AND password = ?",
        (username, password),
    ).fetchone()

    if not row:
        return jsonify({"ok": False, "error": "用户名或密码错误"}), 401

    return jsonify({"ok": True, "user_id": row["id"], "username": row["username"]})


# ---------------------------------------------------------------------------
# Events CRUD
# ---------------------------------------------------------------------------

@app.route("/api/events", methods=["GET"])
def get_events():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    date = request.args.get("date", "")  # optional: filter by YYYY-MM-DD

    db = get_db()
    if date:
        rows = db.execute(
            "SELECT * FROM events WHERE user_id = ? AND date = ? ORDER BY time",
            (user_id, date),
        ).fetchall()
    else:
        rows = db.execute(
            "SELECT * FROM events WHERE user_id = ? ORDER BY date, time",
            (user_id,),
        ).fetchall()

    events = []
    for r in rows:
        e = dict(r)
        # Parse JSON fields
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

    db = get_db()
    cur = db.execute(
        """INSERT INTO events (user_id, title, date, time, end_time, tags, completed, notes)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        (user_id, title, date, time, end_time, tags, completed, notes),
    )
    db.commit()

    new_id = cur.lastrowid
    row = db.execute("SELECT * FROM events WHERE id = ?", (new_id,)).fetchone()
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
    db = get_db()

    # Verify ownership
    row = db.execute(
        "SELECT id FROM events WHERE id = ? AND user_id = ?", (event_id, user_id)
    ).fetchone()
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
    db.execute(
        f"UPDATE events SET {', '.join(fields)} WHERE id = ?", values
    )
    db.commit()

    row = db.execute("SELECT * FROM events WHERE id = ?", (event_id,)).fetchone()
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

    db = get_db()
    row = db.execute(
        "SELECT id FROM events WHERE id = ? AND user_id = ?", (event_id, user_id)
    ).fetchone()
    if not row:
        return jsonify({"ok": False, "error": "事件不存在"}), 404

    db.execute("DELETE FROM events WHERE id = ?", (event_id,))
    db.commit()
    return jsonify({"ok": True, "deleted_id": event_id})


# ---------------------------------------------------------------------------
# Tags CRUD
# ---------------------------------------------------------------------------

@app.route("/api/tags", methods=["GET"])
def get_tags():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    db = get_db()
    rows = db.execute(
        "SELECT * FROM tags WHERE user_id = ? ORDER BY name", (user_id,)
    ).fetchall()

    tags = [dict(r) for r in rows]
    return jsonify({"ok": True, "tags": tags})


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

    db = get_db()
    try:
        cur = db.execute(
            "INSERT INTO tags (user_id, name, color, emoji) VALUES (?, ?, ?, ?)",
            (user_id, name, color, emoji),
        )
        tag_id = cur.lastrowid
        db.commit()
        return jsonify(
            {"ok": True, "tag": {"id": tag_id, "user_id": user_id, "name": name, "color": color, "emoji": emoji}}
        )
    except sqlite3.IntegrityError:
        return jsonify({"ok": False, "error": "标签名已存在"}), 409


@app.route("/api/tags/<int:tag_id>", methods=["PUT"])
def update_tag(tag_id):
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    data = request.get_json(force=True)
    db = get_db()

    row = db.execute(
        "SELECT id FROM tags WHERE id = ? AND user_id = ?", (tag_id, user_id)
    ).fetchone()
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
        db.execute(f"UPDATE tags SET {', '.join(fields)} WHERE id = ?", values)
        db.commit()
    except sqlite3.IntegrityError:
        return jsonify({"ok": False, "error": "标签名已存在"}), 409

    row = db.execute("SELECT * FROM tags WHERE id = ?", (tag_id,)).fetchone()
    return jsonify({"ok": True, "tag": dict(row)})


@app.route("/api/tags/<int:tag_id>", methods=["DELETE"])
def delete_tag(tag_id):
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    db = get_db()
    row = db.execute(
        "SELECT id FROM tags WHERE id = ? AND user_id = ?", (tag_id, user_id)
    ).fetchone()
    if not row:
        return jsonify({"ok": False, "error": "标签不存在"}), 404

    db.execute("DELETE FROM tags WHERE id = ?", (tag_id,))
    db.commit()
    return jsonify({"ok": True, "deleted_id": tag_id})


# ---------------------------------------------------------------------------
# User Profile
# ---------------------------------------------------------------------------

@app.route("/api/profile", methods=["GET"])
def get_profile():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    db = get_db()
    row = db.execute(
        "SELECT * FROM user_profiles WHERE user_id = ?", (user_id,)
    ).fetchone()

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
    db = get_db()

    identity = data.get("identity", "")
    goal = data.get("goal", "")
    preferred_tags = json.dumps(data.get("preferred_tags", []), ensure_ascii=False)
    recommended_theme = data.get("recommended_theme", "dark")

    db.execute(
        """INSERT INTO user_profiles (user_id, identity, goal, preferred_tags, recommended_theme)
           VALUES (?, ?, ?, ?, ?)
           ON CONFLICT(user_id) DO UPDATE SET
               identity = excluded.identity,
               goal = excluded.goal,
               preferred_tags = excluded.preferred_tags,
               recommended_theme = excluded.recommended_theme""",
        (user_id, identity, goal, preferred_tags, recommended_theme),
    )
    db.commit()
    return jsonify({"ok": True})


# ---------------------------------------------------------------------------
# User Settings
# ---------------------------------------------------------------------------

@app.route("/api/settings", methods=["GET"])
def get_settings():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    db = get_db()
    row = db.execute(
        "SELECT * FROM user_settings WHERE user_id = ?", (user_id,)
    ).fetchone()

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

    db = get_db()
    db.execute(
        """INSERT INTO user_settings (user_id, theme) VALUES (?, ?)
           ON CONFLICT(user_id) DO UPDATE SET theme = excluded.theme""",
        (user_id, theme),
    )
    db.commit()
    return jsonify({"ok": True, "settings": {"user_id": user_id, "theme": theme}})


# ---------------------------------------------------------------------------
# Stats (monthly)
# ---------------------------------------------------------------------------

@app.route("/api/stats", methods=["GET"])
def get_stats():
    user_id = get_user()
    if not user_id:
        return jsonify({"ok": False, "error": "缺少 user_id"}), 400

    month = request.args.get("month", "")  # YYYY-MM
    if not month:
        now = datetime.now()
        month = f"{now.year}-{now.month:02d}"

    db = get_db()
    rows = db.execute(
        """SELECT * FROM events
           WHERE user_id = ? AND date LIKE ?
           ORDER BY date, time""",
        (user_id, f"{month}%"),
    ).fetchall()

    total = len(rows)
    completed = sum(1 for r in rows if r["completed"])

    # Per-day breakdown
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
    return jsonify({"ok": True, "message": "Pixel Planner API v3.2"})


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print(f"[PixelPlanner] Database: {DB_PATH}")
    print(f"[PixelPlanner] Starting server on http://localhost:{PORT}")
    app.run(host="0.0.0.0", port=PORT, debug=True)
