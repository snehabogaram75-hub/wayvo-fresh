import os
import psycopg2
import psycopg2.extras


class Result:
    def __init__(self, cur, lastrowid=None):
        self.cur = cur
        self.lastrowid = lastrowid

    def fetchone(self):
        return self.cur.fetchone()

    def fetchall(self):
        return self.cur.fetchall()


class Conn:
    def __init__(self, conn):
        self.conn = conn

    def execute(self, sql, params=()):
        sql = sql.replace("?", "%s")
        is_chat_insert = sql.strip().upper().startswith("INSERT INTO CHATS")
        if is_chat_insert:
            sql = sql.rstrip().rstrip(";") + " RETURNING id"
        cur = self.conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        try:
            cur.execute(sql, params)
        except Exception:
            self.conn.rollback()
            raise
        lastrowid = cur.fetchone()["id"] if is_chat_insert else None
        return Result(cur, lastrowid)

    def commit(self):
        self.conn.commit()

    def rollback(self):
        self.conn.rollback()

    def close(self):
        self.conn.close()


def get_db():
    return Conn(psycopg2.connect(os.environ["DATABASE_URL"]))


def init_db():
    conn = get_db()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS chats (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id),
            title TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("ALTER TABLE chats ADD COLUMN IF NOT EXISTS pinned BOOLEAN NOT NULL DEFAULT FALSE")
    conn.execute("ALTER TABLE chats ADD COLUMN IF NOT EXISTS archived BOOLEAN NOT NULL DEFAULT FALSE")
    conn.execute("ALTER TABLE chats ADD COLUMN IF NOT EXISTS locked BOOLEAN NOT NULL DEFAULT FALSE")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS one_time_items (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL,
            chat_id INTEGER,
            kind TEXT NOT NULL,
            filename TEXT DEFAULT '',
            mime TEXT DEFAULT '',
            content_text TEXT,
            data BYTEA,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            viewed_at TIMESTAMP
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            id SERIAL PRIMARY KEY,
            chat_id INTEGER NOT NULL REFERENCES chats(id),
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    conn.close()
