import os
import time

import psycopg
from flask import Flask, jsonify, request
from psycopg.rows import dict_row

app = Flask(__name__)
DATABASE_URL = os.environ["DATABASE_URL"]


def get_conn():
    return psycopg.connect(DATABASE_URL, row_factory=dict_row)


def init_db():
    for _ in range(30):
        try:
            with get_conn() as conn:
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


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.post("/users")
def create_user():
    data = request.get_json()
    with get_conn() as conn:
        row = conn.execute(
            "INSERT INTO users (name) VALUES (%s) RETURNING id, name",
            (data["name"],),
        ).fetchone()
    return jsonify(row), 201


@app.get("/users/<int:user_id>")
def get_user(user_id):
    with get_conn() as conn:
        row = conn.execute(
            "SELECT id, name FROM users WHERE id = %s", (user_id,)
        ).fetchone()
    if row is None:
        return jsonify(error="not found"), 404
    return jsonify(row)


@app.post("/posts")
def create_post():
    data = request.get_json()
    with get_conn() as conn:
        row = conn.execute(
            "INSERT INTO posts (author_id, title, body) "
            "VALUES (%s, %s, %s) RETURNING id, author_id, title, body",
            (data["author_id"], data["title"], data["body"]),
        ).fetchone()
    return jsonify(row), 201


@app.get("/posts")
def list_posts():
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT id, author_id, title FROM posts "
            "ORDER BY id DESC LIMIT 50"
        ).fetchall()
    return jsonify(rows)


@app.get("/posts/<int:post_id>")
def get_post(post_id):
    with get_conn() as conn:
        row = conn.execute(
            "SELECT id, author_id, title, body FROM posts WHERE id = %s",
            (post_id,),
        ).fetchone()
    if row is None:
        return jsonify(error="not found"), 404
    return jsonify(row)