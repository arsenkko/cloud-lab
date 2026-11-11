import os
import threading
import time

import psycopg
from flask import Flask, g, jsonify, request
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

app = Flask(__name__)
DATABASE_URL = os.environ["DATABASE_URL"]

# Кеш для GET /posts. 0 = вимкнено.
CACHE_TTL = float(os.environ.get("CACHE_TTL_SECONDS", "0"))
_cache = {"value": None, "expires": 0.0}
_cache_lock = threading.Lock()


def init_db():
    for _ in range(30):
        try:
            with psycopg.connect(DATABASE_URL) as conn:
                conn.execute(
                    "CREATE TABLE IF NOT EXISTS users ("
                    "id SERIAL PRIMARY KEY, name TEXT NOT NULL)"
                )
                conn.execute(
                    "CREATE TABLE IF NOT EXISTS posts ("
                    "id SERIAL PRIMARY KEY, "
                    "author_id INTEGER NOT NULL REFERENCES users(id), "
                    "title TEXT NOT NULL, body TEXT NOT NULL, "
                    "created_at TIMESTAMPTZ NOT NULL DEFAULT now())"
                )
            return
        except psycopg.OperationalError:
            time.sleep(1)
    raise RuntimeError("database is not available")


init_db()

pool = ConnectionPool(
    DATABASE_URL,
    min_size=2,
    max_size=16,
    kwargs={"row_factory": dict_row},
)


@app.before_request
def start_timer():
    g.start = time.perf_counter()


@app.after_request
def log_request(response):
    if request.path != "/health":
        ms = (time.perf_counter() - g.start) * 1000
        rule = request.url_rule.rule if request.url_rule else request.path
        cache = g.get("cache", "-")
        print(
            f"REQ {request.method} {rule} {response.status_code} {ms:.1f} {cache}",
            flush=True,
        )
    return response


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.post("/users")
def create_user():
    data = request.get_json()
    with pool.connection() as conn:
        row = conn.execute(
            "INSERT INTO users (name) VALUES (%s) RETURNING id, name",
            (data["name"],),
        ).fetchone()
    return jsonify(row), 201


@app.get("/users/<int:user_id>")
def get_user(user_id):
    with pool.connection() as conn:
        row = conn.execute(
            "SELECT id, name FROM users WHERE id = %s", (user_id,)
        ).fetchone()
    if row is None:
        return jsonify(error="not found"), 404
    return jsonify(row)


@app.post("/posts")
def create_post():
    data = request.get_json()
    with pool.connection() as conn:
        row = conn.execute(
            "INSERT INTO posts (author_id, title, body) "
            "VALUES (%s, %s, %s) RETURNING id, author_id, title, body",
            (data["author_id"], data["title"], data["body"]),
        ).fetchone()
    return jsonify(row), 201


def fetch_posts():
    with pool.connection() as conn:
        return conn.execute(
            "SELECT id, author_id, title FROM posts "
            "ORDER BY id DESC LIMIT 50"
        ).fetchall()


@app.get("/posts")
def list_posts():
    # Cache-aside: спершу дивимось у кеш, при промаху йдемо в базу і кладемо в кеш.
    if CACHE_TTL <= 0:
        g.cache = "off"
        return jsonify(fetch_posts())

    with _cache_lock:
        if _cache["value"] is not None and time.monotonic() < _cache["expires"]:
            g.cache = "hit"
            return jsonify(_cache["value"])

    rows = fetch_posts()
    with _cache_lock:
        _cache["value"] = rows
        _cache["expires"] = time.monotonic() + CACHE_TTL
    g.cache = "miss"
    return jsonify(rows)


@app.get("/posts/<int:post_id>")
def get_post(post_id):
    with pool.connection() as conn:
        row = conn.execute(
            "SELECT id, author_id, title, body FROM posts WHERE id = %s",
            (post_id,),
        ).fetchone()
    if row is None:
        return jsonify(error="not found"), 404
    return jsonify(row)