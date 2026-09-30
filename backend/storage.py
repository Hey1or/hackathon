"""Supabase persistence with a zero-setup SQLite fallback for local demos."""
from __future__ import annotations

import json
import hashlib
import os
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4

from dotenv import load_dotenv

from .sample_data import seed_responses, seed_tasks

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / ".env")
DB_PATH = Path(os.getenv("SQLITE_PATH", str(ROOT / "backend" / "data" / "hub.sqlite3")))


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _new_id(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex[:16]}"


class Store:
    def __init__(self) -> None:
        self.url = os.getenv("SUPABASE_URL", "").strip()
        self.key = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "").strip()
        self.client = None
        self.mode = "sqlite"
        if self.url and self.key:
            from supabase import create_client

            self.client = create_client(self.url, self.key)
            self.mode = "supabase"
        else:
            DB_PATH.parent.mkdir(parents=True, exist_ok=True)
            self._init_sqlite()
        # Sample records are opt-in. A normal launch must show only records
        # entered by users, so database statistics are based on real activity.
        if os.getenv("DEMO_SEED", "false").strip().lower() in {"1", "true", "yes", "on"}:
            self._seed_if_empty()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(DB_PATH, timeout=10)
        conn.row_factory = sqlite3.Row
        conn.execute("pragma foreign_keys = on")
        return conn

    def _init_sqlite(self) -> None:
        with self._connect() as conn:
            conn.executescript(
                """
                create table if not exists tasks (
                  id text primary key, data text not null, created_at text not null
                );
                create table if not exists responses (
                  id text primary key, task_id text not null, data text not null,
                  created_at text not null,
                  foreign key(task_id) references tasks(id) on delete cascade
                );
                create table if not exists notifications (
                  id text primary key, audience text not null, data text not null,
                  is_read integer not null default 0, created_at text not null
                );
                create table if not exists users (
                  id text primary key, email text not null unique, name text not null,
                  role text not null check(role in ('business', 'student')),
                  password_hash text not null, created_at text not null,
                  email_verified integer not null default 0,
                  verification_token_hash text, verification_expires_at text,
                  consent_at text not null default '', consent_version text not null default 'v1',
                  is_active integer not null default 1, session_version integer not null default 0,
                  is_owner integer not null default 0
                );
                create table if not exists page_views (
                  id text primary key, viewer_key text not null, page_key text not null,
                  view_date text not null, viewed_at text not null,
                  unique(viewer_key, page_key, view_date)
                );
                """
            )
            columns = {row[1] for row in conn.execute("pragma table_info(users)").fetchall()}
            migrations = {
                "email_verified": "integer not null default 0",
                "verification_token_hash": "text",
                "verification_expires_at": "text",
                "consent_at": "text not null default ''",
                "consent_version": "text not null default 'v1'",
                "is_active": "integer not null default 1",
                "session_version": "integer not null default 0",
                "is_owner": "integer not null default 0",
            }
            for column, definition in migrations.items():
                if column not in columns:
                    conn.execute(f"alter table users add column {column} {definition}")

    def _seed_if_empty(self) -> None:
        if self.mode == "supabase":
            existing = self.client.table("tasks").select("id").limit(1).execute().data
            if existing:
                return
            for task in seed_tasks():
                self.client.table("tasks").insert(
                    {"id": task["id"], "data": task, "created_at": task["created_at"]}
                ).execute()
            for seed in seed_responses():
                self.add_response(seed["task_id"], seed)
            return
        with self._connect() as conn:
            count = conn.execute("select count(*) from tasks").fetchone()[0]
            if count:
                return
            for task in seed_tasks():
                conn.execute(
                    "insert into tasks(id, data, created_at) values (?, ?, ?)",
                    (task["id"], json.dumps(task, ensure_ascii=False), task["created_at"]),
                )
        for seed in seed_responses():
            self.add_response(seed["task_id"], seed)

    @staticmethod
    def _public_user(row: dict[str, Any]) -> dict[str, Any]:
        return {"id": row["id"], "email": row["email"], "name": row["name"], "role": row["role"], "email_verified": bool(row.get("email_verified", False)), "consent_version": row.get("consent_version", "v1"), "created_at": row["created_at"], "is_active": bool(row.get("is_active", True)), "session_version": int(row.get("session_version", 0)), "is_owner": bool(row.get("is_owner", False))}

    def get_user_by_email(self, email: str) -> dict[str, Any] | None:
        email = email.strip().lower()
        if self.mode == "supabase":
            rows = self.client.table("users").select("id,email,name,role,password_hash,created_at,email_verified,verification_token_hash,verification_expires_at,consent_at,consent_version,is_active,session_version,is_owner").eq("email", email).limit(1).execute().data
            return rows[0] if rows else None
        with self._connect() as conn:
            row = conn.execute("select id,email,name,role,password_hash,created_at,email_verified,verification_token_hash,verification_expires_at,consent_at,consent_version,is_active,session_version,is_owner from users where email=?", (email,)).fetchone()
        return dict(row) if row else None

    def get_user(self, user_id: str) -> dict[str, Any] | None:
        if self.mode == "supabase":
            rows = self.client.table("users").select("id,email,name,role,created_at,email_verified,consent_version,is_active,session_version,is_owner").eq("id", user_id).limit(1).execute().data
            return rows[0] if rows else None
        with self._connect() as conn:
            row = conn.execute("select id,email,name,role,created_at,email_verified,consent_version,is_active,session_version,is_owner from users where id=?", (user_id,)).fetchone()
        return dict(row) if row else None

    def create_user(self, email: str, name: str, role: str, password_hash: str, token_hash: str, expires_at: str, consent_version: str) -> dict[str, Any]:
        user = {"id": _new_id("user"), "email": email.strip().lower(), "name": name.strip(), "role": role, "password_hash": password_hash, "created_at": now_iso(), "email_verified": False, "verification_token_hash": token_hash, "verification_expires_at": expires_at, "consent_at": now_iso(), "consent_version": consent_version, "is_active": True, "session_version": 0, "is_owner": False}
        if self.mode == "supabase":
            self.client.table("users").insert(user).execute()
        else:
            with self._connect() as conn:
                conn.execute("insert into users(id,email,name,role,password_hash,created_at,email_verified,verification_token_hash,verification_expires_at,consent_at,consent_version) values(?,?,?,?,?,?,0,?,?,?,?)", (user["id"], user["email"], user["name"], user["role"], user["password_hash"], user["created_at"], token_hash, expires_at, user["consent_at"], consent_version))
        return self._public_user(user)

    def verify_email(self, token_hash: str) -> bool:
        now = now_iso()
        if self.mode == "supabase":
            rows = self.client.table("users").select("id,verification_expires_at").eq("verification_token_hash", token_hash).eq("email_verified", False).limit(1).execute().data
            if not rows or not rows[0].get("verification_expires_at") or rows[0]["verification_expires_at"] <= now:
                return False
            self.client.table("users").update({"email_verified": True, "verification_token_hash": None, "verification_expires_at": None}).eq("id", rows[0]["id"]).execute()
            return True
        with self._connect() as conn:
            row = conn.execute("select id,verification_expires_at from users where verification_token_hash=? and email_verified=0", (token_hash,)).fetchone()
            if not row or not row["verification_expires_at"] or row["verification_expires_at"] <= now:
                return False
            conn.execute("update users set email_verified=1,verification_token_hash=null,verification_expires_at=null where id=?", (row["id"],))
            return True

    def set_verification(self, user_id: str, token_hash: str, expires_at: str, consent_version: str | None = None) -> None:
        values = {"verification_token_hash": token_hash, "verification_expires_at": expires_at}
        if consent_version:
            values.update({"consent_at": now_iso(), "consent_version": consent_version})
        if self.mode == "supabase":
            self.client.table("users").update(values).eq("id", user_id).execute()
            return
        with self._connect() as conn:
            if consent_version:
                conn.execute("update users set verification_token_hash=?,verification_expires_at=?,consent_at=?,consent_version=? where id=?", (token_hash, expires_at, now_iso(), consent_version, user_id))
            else:
                conn.execute("update users set verification_token_hash=?,verification_expires_at=? where id=?", (token_hash, expires_at, user_id))

    def user_stats(self) -> dict[str, int]:
        if self.mode == "supabase":
            rows = self.client.table("users").select("role").eq("email_verified", True).eq("is_active", True).execute().data
            return {"members": len(rows), "students": sum(row["role"] == "student" for row in rows), "business": sum(row["role"] == "business" for row in rows)}
        with self._connect() as conn:
            rows = conn.execute("select role, count(*) as total from users where email_verified=1 and is_active=1 group by role").fetchall()
        counts = {row["role"]: row["total"] for row in rows}
        return {"members": sum(counts.values()), "students": counts.get("student", 0), "business": counts.get("business", 0)}

    def list_admin_users(self) -> list[dict[str, Any]]:
        fields = "id,email,name,role,created_at,email_verified,consent_version,is_active"
        if self.mode == "supabase":
            rows = self.client.table("users").select(fields).order("created_at", desc=True).limit(500).execute().data
            return [self._public_user(row) for row in rows]
        with self._connect() as conn:
            rows = conn.execute(f"select {fields} from users order by created_at desc limit 500").fetchall()
        return [self._public_user(dict(row)) for row in rows]

    def set_user_active(self, user_id: str, is_active: bool) -> dict[str, Any] | None:
        if self.mode == "supabase":
            rows = self.client.table("users").update({"is_active": is_active}).eq("id", user_id).execute().data
            return self._public_user(rows[0]) if rows else None
        with self._connect() as conn:
            conn.execute("update users set is_active=? where id=?", (int(is_active), user_id))
            row = conn.execute("select id,email,name,role,created_at,email_verified,consent_version,is_active from users where id=?", (user_id,)).fetchone()
        return self._public_user(dict(row)) if row else None

    def update_user_identity(self, user_id: str, name: str, email: str) -> dict[str, Any] | None:
        profile = self.get_user(user_id)
        if not profile:
            return None
        email = email.strip().lower()
        changed_email = profile["email"].strip().lower() != email
        values = {"name": name.strip(), "email": email}
        if changed_email:
            values.update({"email_verified": False, "verification_token_hash": None, "verification_expires_at": None})
        if self.mode == "supabase":
            self.client.table("users").update(values).eq("id", user_id).execute()
            return self.get_user(user_id)
        with self._connect() as conn:
            if changed_email:
                conn.execute("update users set name=?, email=?, email_verified=0, verification_token_hash=null, verification_expires_at=null where id=?", (name.strip(), email, user_id))
            else:
                conn.execute("update users set name=?, email=? where id=?", (name.strip(), email, user_id))
        return self.get_user(user_id)

    def update_password_hash(self, user_id: str, password_hash: str) -> dict[str, Any] | None:
        if self.mode == "supabase":
            profile = self.get_user(user_id)
            if not profile:
                return None
            self.client.table("users").update({"password_hash": password_hash, "session_version": int(profile.get("session_version", 0)) + 1}).eq("id", user_id).execute()
            return self.get_user(user_id)
        with self._connect() as conn:
            conn.execute("update users set password_hash=?, session_version=session_version+1 where id=?", (password_hash, user_id))
        return self.get_user(user_id)

    def set_user_owner(self, user_id: str, is_owner: bool = True) -> None:
        if self.mode == "supabase":
            self.client.table("users").update({"is_owner": is_owner}).eq("id", user_id).execute()
            return
        with self._connect() as conn:
            conn.execute("update users set is_owner=? where id=?", (int(is_owner), user_id))

    def get_owner(self) -> dict[str, Any] | None:
        if self.mode == "supabase":
            rows = self.client.table("users").select("id,email,name,role,created_at,email_verified,consent_version,is_active,session_version,is_owner").eq("is_owner", True).limit(1).execute().data
            return self._public_user(rows[0]) if rows else None
        with self._connect() as conn:
            row = conn.execute("select id,email,name,role,created_at,email_verified,consent_version,is_active,session_version,is_owner from users where is_owner=1 limit 1").fetchone()
        return self._public_user(dict(row)) if row else None

    def record_page_view(self, viewer_key: str, page_key: str) -> None:
        viewed_at = datetime.now(timezone.utc)
        day = viewed_at.date().isoformat()
        event_id = hashlib.sha256(f"{viewer_key}:{page_key}:{day}".encode()).hexdigest()
        row = {"id": event_id, "viewer_key": viewer_key, "page_key": page_key, "view_date": day, "viewed_at": viewed_at.isoformat()}
        if self.mode == "supabase":
            self.client.table("page_views").upsert(row, on_conflict="id").execute()
            return
        with self._connect() as conn:
            conn.execute("insert or ignore into page_views(id,viewer_key,page_key,view_date,viewed_at) values(?,?,?,?,?)", (event_id, viewer_key, page_key, day, row["viewed_at"]))

    def list_page_views(self) -> list[dict[str, Any]]:
        if self.mode == "supabase":
            return self.client.table("page_views").select("viewer_key,page_key,view_date,viewed_at").limit(10000).execute().data
        with self._connect() as conn:
            rows = conn.execute("select viewer_key,page_key,view_date,viewed_at from page_views").fetchall()
        return [dict(row) for row in rows]

    def list_tasks(self) -> list[dict[str, Any]]:
        if self.mode == "supabase":
            rows = self.client.table("tasks").select("id,data,created_at").order("created_at", desc=True).execute().data
            return [self._merge(row) for row in rows]
        with self._connect() as conn:
            rows = conn.execute("select id, data, created_at from tasks order by created_at desc").fetchall()
        return [self._merge({"id": row["id"], "data": json.loads(row["data"]), "created_at": row["created_at"]}) for row in rows]

    def get_task(self, task_id: str) -> dict[str, Any] | None:
        if self.mode == "supabase":
            rows = self.client.table("tasks").select("id,data,created_at").eq("id", task_id).limit(1).execute().data
            return self._merge(rows[0]) if rows else None
        with self._connect() as conn:
            row = conn.execute("select id, data, created_at from tasks where id = ?", (task_id,)).fetchone()
        return self._merge({"id": row["id"], "data": json.loads(row["data"]), "created_at": row["created_at"]}) if row else None

    @staticmethod
    def _merge(row: dict[str, Any]) -> dict[str, Any]:
        data = dict(row.get("data") or {})
        data["id"] = row["id"]
        data.setdefault("created_at", row.get("created_at"))
        return data

    def create_task(self, data: dict[str, Any], owner: dict[str, Any] | None = None) -> dict[str, Any]:
        task_id = _new_id("task")
        record = {**data, "id": task_id, "owner_id": owner["id"] if owner else None, "owner_name": owner["name"] if owner else None, "owner_email_verified": bool(owner), "status": "published", "created_at": now_iso()}
        if self.mode == "supabase":
            self.client.table("tasks").insert({"id": task_id, "data": record, "created_at": record["created_at"]}).execute()
        else:
            with self._connect() as conn:
                conn.execute("insert into tasks(id, data, created_at) values (?, ?, ?)", (task_id, json.dumps(record, ensure_ascii=False), record["created_at"]))
        return record

    def list_responses(self, task_id: str | None = None) -> list[dict[str, Any]]:
        if self.mode == "supabase":
            query = self.client.table("responses").select("id,task_id,data,created_at").order("created_at", desc=True)
            if task_id:
                query = query.eq("task_id", task_id)
            rows = query.execute().data
            return [{**row["data"], "id": row["id"], "task_id": row["task_id"], "created_at": row["created_at"]} for row in rows]
        with self._connect() as conn:
            if task_id:
                rows = conn.execute("select id, task_id, data, created_at from responses where task_id = ? order by created_at desc", (task_id,)).fetchall()
            else:
                rows = conn.execute("select id, task_id, data, created_at from responses order by created_at desc").fetchall()
        return [{**json.loads(row["data"]), "id": row["id"], "task_id": row["task_id"], "created_at": row["created_at"]} for row in rows]

    def add_response(self, task_id: str, data: dict[str, Any], author: dict[str, Any] | None = None) -> dict[str, Any]:
        response_id = _new_id("response")
        created = now_iso()
        record = {**data, "id": response_id, "task_id": task_id, "author_id": author["id"] if author else None, "author_name": author["name"] if author else None, "author_email_verified": bool(author), "status": "pending", "created_at": created}
        if self.mode == "supabase":
            self.client.table("responses").insert({"id": response_id, "task_id": task_id, "data": record, "created_at": created}).execute()
        else:
            with self._connect() as conn:
                conn.execute("insert into responses(id, task_id, data, created_at) values (?, ?, ?, ?)", (response_id, task_id, json.dumps(record, ensure_ascii=False), created))
        return record

    def decide_response(self, response_id: str, status: str) -> dict[str, Any] | None:
        if self.mode == "supabase":
            rows = self.client.table("responses").select("id,task_id,data,created_at").eq("id", response_id).limit(1).execute().data
            if not rows:
                return None
            row = rows[0]
            record = {**row["data"], "id": row["id"], "task_id": row["task_id"], "status": status, "created_at": row["created_at"]}
            self.client.table("responses").update({"data": record}).eq("id", response_id).execute()
            return record
        with self._connect() as conn:
            row = conn.execute("select id, task_id, data, created_at from responses where id = ?", (response_id,)).fetchone()
            if not row:
                return None
            record = {**json.loads(row["data"]), "status": status}
            conn.execute("update responses set data = ? where id = ?", (json.dumps(record, ensure_ascii=False), response_id))
        return {**record, "id": row["id"], "task_id": row["task_id"], "created_at": row["created_at"]}

    def add_notification(self, audience: str, data: dict[str, Any]) -> dict[str, Any]:
        notification_id = _new_id("notice")
        created = now_iso()
        record = {**data, "id": notification_id, "audience": audience, "is_read": False, "created_at": created}
        if self.mode == "supabase":
            self.client.table("notifications").insert({"id": notification_id, "audience": audience, "data": record, "is_read": False, "created_at": created}).execute()
        else:
            with self._connect() as conn:
                conn.execute("insert into notifications(id, audience, data, is_read, created_at) values (?, ?, ?, 0, ?)", (notification_id, audience, json.dumps(record, ensure_ascii=False), created))
        return record

    def list_notifications(self, audience: str) -> list[dict[str, Any]]:
        if self.mode == "supabase":
            rows = self.client.table("notifications").select("id,audience,data,is_read,created_at").eq("audience", audience).order("created_at", desc=True).limit(50).execute().data
            return [{**row["data"], "id": row["id"], "audience": row["audience"], "is_read": row["is_read"], "created_at": row["created_at"]} for row in rows]
        with self._connect() as conn:
            rows = conn.execute("select id, audience, data, is_read, created_at from notifications where audience = ? order by created_at desc limit 50", (audience,)).fetchall()
        return [{**json.loads(row["data"]), "id": row["id"], "audience": row["audience"], "is_read": bool(row["is_read"]), "created_at": row["created_at"]} for row in rows]


store = Store()
