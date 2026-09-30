"""FastAPI backend for AI Sana Challenge Hub."""
from __future__ import annotations

import json
import hashlib
import os
import re
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Literal

from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, field_validator

from . import ai
from .auth import create_token, current_user, hash_password, require_admin, require_role, verify_password
from .email_service import send_verification
from .storage import ROOT, store

app = FastAPI(
    title="AI Sana Challenge Hub",
    description="API for task clarification, readiness scoring, team proposals and in-app notifications.",
    version="1.0.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "PATCH", "OPTIONS"],
    allow_headers=["*"],
)
app.mount("/assets", StaticFiles(directory=ROOT / "assets"), name="assets")


@app.get("/", include_in_schema=False)
def browser_app() -> FileResponse:
    """Serve the responsive browser client; Flutter clients use the same /api routes."""
    return FileResponse(ROOT / "index.html")


@app.get("/login", include_in_schema=False)
def login_page() -> FileResponse:
    return FileResponse(ROOT / "auth.html")


@app.get("/privacy", include_in_schema=False)
def privacy_page() -> FileResponse:
    return FileResponse(ROOT / "privacy.html")


@app.get("/verify-email", include_in_schema=False)
def verify_page() -> FileResponse:
    return FileResponse(ROOT / "verify.html")

WEIGHTS = {
    "context": 10,
    "need": 10,
    "data": 20,
    "result": 15,
    "success": 15,
    "constraints": 10,
    "users": 10,
    "contact": 10,
}
FIELD_NAMES = {
    "context": "Контекст проблемы",
    "need": "Потребность бизнеса",
    "data": "Данные и материалы",
    "result": "Ожидаемый результат",
    "success": "Критерии успеха",
    "constraints": "Ограничения",
    "users": "Пользователи",
    "contact": "Связь с бизнесом",
}


def readiness(data: dict[str, Any]) -> dict[str, Any]:
    fields = []
    score = 0
    missing = []
    for key, weight in WEIGHTS.items():
        filled = len(str(data.get(key, "")).strip()) > 7
        earned = weight if filled else 0
        score += earned
        fields.append({"key": key, "label": FIELD_NAMES[key], "earned": earned, "weight": weight, "filled": filled})
        if not filled:
            missing.append(FIELD_NAMES[key])
    level = "Черновик" if score < 40 else "Рабочая" if score < 70 else "Готовая" if score < 90 else "Приоритетная"
    return {"score": score, "level": level, "fields": fields, "missing": missing}


class DraftRequest(BaseModel):
    draft: str = Field(min_length=12, max_length=5000)


class OrganizeRequest(DraftRequest):
    answers: dict[str, str] = Field(default_factory=dict)


class TaskRequest(BaseModel):
    title: str = Field(min_length=4, max_length=180)
    company: str = Field(default="Бизнес-партнёр", max_length=140)
    topic: str = Field(default="Образование", max_length=80)
    context: str = Field(min_length=8, max_length=2500)
    need: str = Field(default="", max_length=1500)
    users: str = Field(default="", max_length=1000)
    data: str = Field(default="", max_length=1500)
    result: str = Field(default="", max_length=1500)
    success: str = Field(default="", max_length=1500)
    constraints: str = Field(default="", max_length=1500)
    contact: str = Field(default="", max_length=500)

    @field_validator("title", "context")
    @classmethod
    def strip_required_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Поле не может быть пустым")
        return value


class ResponseRequest(BaseModel):
    team: str = Field(min_length=2, max_length=100)
    idea: str = Field(min_length=10, max_length=2000)
    plan: str = Field(default="", max_length=2000)
    timeline: str = Field(default="", max_length=100)
    link: str = Field(default="", max_length=500)


class DecisionRequest(BaseModel):
    status: Literal["accepted", "rejected"]


class RegisterRequest(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    email: str = Field(min_length=5, max_length=254)
    password: str = Field(min_length=8, max_length=128)
    role: Literal["business", "student"]
    privacy_consent: bool


class LoginRequest(BaseModel):
    email: str = Field(min_length=5, max_length=254)
    password: str = Field(min_length=8, max_length=128)


class ProfileUpdateRequest(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    email: str = Field(min_length=5, max_length=254)
    current_password: str = Field(min_length=8, max_length=128)

    @field_validator("name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Имя не может быть пустым")
        return value

    @field_validator("email")
    @classmethod
    def clean_email(cls, value: str) -> str:
        value = value.strip().lower()
        if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", value):
            raise ValueError("Укажите корректный адрес почты")
        return value


class PasswordUpdateRequest(BaseModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class VerifyEmailRequest(BaseModel):
    token: str = Field(min_length=20, max_length=200)


class ViewEventRequest(BaseModel):
    viewer_key: str = Field(min_length=16, max_length=100)
    page: str = Field(pattern=r"^(login|catalog|task:[A-Za-z0-9_-]{1,100})$")


class UserStatusRequest(BaseModel):
    is_active: bool


def auth_result(user: dict[str, Any]) -> dict[str, Any]:
    user = dict(user)
    admin_email = os.getenv("ADMIN_EMAIL", "").strip().lower()
    if admin_email and user.get("email", "").strip().lower() == admin_email:
        store.set_user_owner(user["id"])
        user = store.get_user(user["id"]) or user
    if user.get("is_owner"):
        user["role"] = "admin"
    return {"access_token": create_token(user), "token_type": "bearer", "user": user}


CONSENT_VERSION = "v1-2026-09-23"


def issue_verification(user_id: str, email: str, name: str, consent_version: str | None = None) -> bool:
    token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    expires_at = (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat()
    store.set_verification(user_id, token_hash, expires_at, consent_version)
    return send_verification(email, name, token)


@app.post("/api/auth/register", status_code=201)
def register(request: RegisterRequest) -> dict[str, Any]:
    if not request.privacy_consent:
        raise HTTPException(422, "Чтобы создать аккаунт, нужно согласиться с обработкой данных")
    email = request.email.strip().lower()
    if "@" not in email or email.startswith("@") or email.endswith("@"):
        raise HTTPException(422, "Укажите корректную почту")
    existing = store.get_user_by_email(email)
    if existing:
        raise HTTPException(409, "Аккаунт с такой почтой уже существует. Войдите с этой почтой и паролем.")
    admin_email = os.getenv("ADMIN_EMAIL", "").strip().lower()
    owner = store.get_owner()
    if admin_email and email == admin_email and owner:
        raise HTTPException(409, "Почта владельца зарезервирована")
    token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    expires_at = (datetime.now(timezone.utc) + timedelta(hours=24)).isoformat()
    user = store.create_user(email, request.name, request.role, hash_password(request.password), token_hash, expires_at, CONSENT_VERSION)
    # Email confirmation is temporarily disabled for the hackathon MVP.
    store.verify_email(token_hash)
    return auth_result(store.get_user(user["id"]) or {**user, "email_verified": True})


@app.post("/api/auth/login")
def login(request: LoginRequest) -> dict[str, Any]:
    user_record = store.get_user_by_email(request.email)
    if not user_record or not verify_password(request.password, user_record["password_hash"]):
        raise HTTPException(401, "Неверная почта или пароль")
    if not user_record.get("is_active", True):
        raise HTTPException(403, "Доступ к аккаунту отключён администратором")
    user = store._public_user(user_record)
    return auth_result(user)


@app.post("/api/auth/verify-email")
def verify_email(request: VerifyEmailRequest) -> dict[str, str]:
    token_hash = hashlib.sha256(request.token.encode()).hexdigest()
    if store.verify_email(token_hash):
        return {"message": "Почта подтверждена. Теперь можно войти."}
    raise HTTPException(400, "Ссылка недействительна или срок её действия истёк")


@app.get("/api/auth/me")
def me(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return {"user": user}


@app.patch("/api/auth/profile")
def update_profile(request: ProfileUpdateRequest, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    record = store.get_user_by_email(user["email"])
    if not record or not verify_password(request.current_password, record["password_hash"]):
        raise HTTPException(400, "Текущий пароль указан неверно")
    admin_email = os.getenv("ADMIN_EMAIL", "").strip().lower()
    if user["role"] != "admin" and admin_email and request.email == admin_email:
        raise HTTPException(409, "Этот адрес закреплён за владельцем сайта")
    existing = store.get_user_by_email(request.email)
    if existing and existing["id"] != user["id"]:
        raise HTTPException(409, "Аккаунт с такой почтой уже существует")
    updated = store.update_user_identity(user["id"], request.name, request.email)
    if not updated:
        raise HTTPException(404, "Аккаунт не найден")
    updated["role"] = user["role"]
    return {"user": updated}


@app.patch("/api/auth/password")
def update_password(request: PasswordUpdateRequest, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    record = store.get_user_by_email(user["email"])
    if not record or not verify_password(request.current_password, record["password_hash"]):
        raise HTTPException(400, "Текущий пароль указан неверно")
    if request.current_password == request.new_password:
        raise HTTPException(422, "Новый пароль должен отличаться от текущего")
    updated = store.update_password_hash(user["id"], hash_password(request.new_password))
    if not updated:
        raise HTTPException(404, "Аккаунт не найден")
    updated["role"] = user["role"]
    return auth_result(updated)


@app.get("/api/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "service": "AI Sana Challenge Hub API",
        "storage": store.mode,
        "ai_enabled": ai.AI_ENABLED,
        "ai_provider": ai.PROVIDER if ai.AI_ENABLED else "demo",
        "ai_model": ai.MODEL if ai.AI_ENABLED else None,
    }


@app.get("/api/tasks")
def tasks(user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    output = []
    for task in store.list_tasks():
        task["readiness"] = readiness(task)
        task["response_count"] = len(store.list_responses(task["id"]))
        output.append(task)
    return output


@app.get("/api/tasks/{task_id}")
def task(task_id: str, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    result = store.get_task(task_id)
    if not result:
        raise HTTPException(404, "Задача не найдена")
    result["readiness"] = readiness(result)
    responses = store.list_responses(task_id)
    if user["role"] == "student":
        responses = [r for r in responses if r.get("author_id") == user["id"]]
    elif result.get("owner_id") != user["id"]:
        responses = []
    result["responses"] = responses
    return result


@app.post("/api/ai/refine")
async def refine_task(request: DraftRequest, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    try:
        questions, mode = await ai.refine(request.draft.strip())
        return {"questions": questions, "mode": mode, "count": len(questions)}
    except Exception as exc:
        questions = ai.demo_questions(request.draft.strip())
        return {"questions": questions, "mode": "demo_fallback", "count": len(questions), "warning": f"AI временно недоступен; использованы локальные вопросы: {exc}"}


@app.post("/api/ai/organize")
async def organize_task(request: OrganizeRequest, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    try:
        fields, mode = await ai.organize(request.draft.strip(), request.answers)
        return {"card": fields, "mode": mode, "note": "Проверьте и подтвердите каждое поле перед публикацией."}
    except Exception as exc:
        fields = ai.demo_organize(request.draft.strip(), request.answers)
        return {"card": fields, "mode": "demo_fallback", "warning": f"AI временно недоступен; собран локальный черновик: {exc}", "note": "Проверьте и подтвердите каждое поле перед публикацией."}


@app.post("/api/tasks", status_code=201)
def create_task(request: TaskRequest, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "business")
    created = store.create_task(request.model_dump(), user)
    created["readiness"] = readiness(created)
    created["response_count"] = 0
    return created


@app.get("/api/tasks/{task_id}/responses")
def task_responses(task_id: str, user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    target = store.get_task(task_id)
    if not target:
        raise HTTPException(404, "Задача не найдена")
    if user["id"] != target.get("owner_id") and user["role"] == "student":
        return [r for r in store.list_responses(task_id) if r.get("author_id") == user["id"]]
    if user["id"] == target.get("owner_id"):
        return store.list_responses(task_id)
    return []


@app.post("/api/tasks/{task_id}/responses", status_code=201)
def create_response(task_id: str, request: ResponseRequest, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "student")
    target = store.get_task(task_id)
    if not target:
        raise HTTPException(404, "Задача не найдена")
    response_data = request.model_dump()
    response_data["team"] = user["name"]
    response = store.add_response(task_id, response_data, user)
    notice = store.add_notification(
        target.get("owner_id") or "business",
        {
            "kind": "new_response",
            "title": "Новый отклик на вашу задачу",
            "message": f"Команда «{user['name']}» предложила решение для задачи «{target['title']}».",
            "task_id": task_id,
            "response_id": response["id"],
            "team": user["name"],
        },
    )
    store.add_notification(
        user["id"],
        {
            "kind": "response_sent",
            "title": "Отклик отправлен",
            "message": f"Ваше предложение отправлено заказчику «{target.get('company', 'Бизнес-партнёр')}». Вы получите уведомление, когда он примет решение.",
            "task_id": task_id,
            "response_id": response["id"],
        },
    )
    return {**response, "acknowledgement": "Отклик сохранён. Заказчик получил уведомление в приложении.", "notification_id": notice["id"]}


@app.get("/api/responses")
def responses(user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    result = []
    tasks_by_id = {item["id"]: item for item in store.list_tasks()}
    for response in store.list_responses():
        target = tasks_by_id.get(response["task_id"], {})
        if user["role"] == "business" and target.get("owner_id") != user["id"]:
            continue
        if user["role"] == "student" and response.get("author_id") != user["id"]:
            continue
        result.append({**response, "task_title": target.get("title", "Задача"), "company": target.get("company", "Бизнес-партнёр")})
    return result


@app.patch("/api/responses/{response_id}/decision")
def decide(response_id: str, request: DecisionRequest, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "business")
    found = next((r for r in store.list_responses() if r["id"] == response_id), None)
    task_owner = store.get_task(found["task_id"]) if found else None
    if not found or not task_owner or task_owner.get("owner_id") != user["id"]:
        raise HTTPException(404, "Отклик не найден")
    response = store.decide_response(response_id, request.status)
    if not response:
        raise HTTPException(404, "Отклик не найден")
    task = store.get_task(response["task_id"]) or {}
    chosen = request.status == "accepted"
    store.add_notification(
        response.get("author_id") or "team",
        {
            "kind": "response_decision",
            "title": "Заказчик выбрал ваше предложение" if chosen else "Заказчик обновил статус отклика",
            "message": f"Решение по задаче «{task.get('title', 'Образовательная задача')}»: {'ваша команда выбрана для дальнейшей работы' if chosen else 'заказчик решил продолжить с другой командой'}.",
            "task_id": response["task_id"],
            "response_id": response["id"],
        },
    )
    return response


@app.get("/api/notifications")
def notifications(user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    return store.list_notifications(user["id"])


@app.get("/api/config")
def config() -> dict[str, Any]:
    """Safe frontend config: never return API keys or Supabase credentials."""
    return {"ai_enabled": ai.AI_ENABLED, "ai_provider": ai.PROVIDER if ai.AI_ENABLED else "demo", "storage": store.mode}


@app.get("/api/stats")
def stats() -> dict[str, int]:
    """Public aggregate only; never returns member names, emails, or profiles."""
    return store.user_stats()


@app.post("/api/metrics/view", status_code=202)
def record_view(request: ViewEventRequest) -> dict[str, bool]:
    """Record one anonymous page visit per browser session, page and day."""
    store.record_page_view(request.viewer_key, request.page)
    return {"ok": True}


@app.get("/api/admin/overview")
def admin_overview(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_admin(user)
    users = store.list_admin_users()
    views = store.list_page_views()
    tasks = store.list_tasks()
    task_by_id = {task["id"]: task for task in tasks}
    today = datetime.now(timezone.utc).date().isoformat()
    dates = [(datetime.now(timezone.utc).date() - timedelta(days=offset)).isoformat() for offset in range(6, -1, -1)]
    daily_views = [{"date": day, "views": sum(row["view_date"] == day for row in views)} for day in dates]
    page_counts: dict[str, int] = {}
    for view in views:
        page_counts[view["page_key"]] = page_counts.get(view["page_key"], 0) + 1
    task_views = [
        {"id": task_id, "title": task_by_id.get(task_id, {}).get("title", "Задача"), "views": count}
        for page_key, count in page_counts.items()
        if page_key.startswith("task:")
        for task_id in [page_key.partition(":")[2]]
    ]
    task_views.sort(key=lambda row: row["views"], reverse=True)
    return {
        "stats": {
            "visitors": len({row["viewer_key"] for row in views}),
            "today_visitors": len({row["viewer_key"] for row in views if row["view_date"] == today}),
            "views": len(views),
            "today_views": sum(row["view_date"] == today for row in views),
            "members": len(users),
            "active_members": sum(user["is_active"] for user in users),
            "suspended_members": sum(not user["is_active"] for user in users),
            "tasks": len(tasks),
            "responses": len(store.list_responses()),
        },
        "daily_views": daily_views,
        "task_views": task_views[:10],
        "users": users,
    }


@app.patch("/api/admin/users/{user_id}/status")
def set_user_status(user_id: str, request: UserStatusRequest, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_admin(user)
    if user_id == user["id"] and not request.is_active:
        raise HTTPException(422, "Нельзя отключить собственный аккаунт администратора")
    updated = store.set_user_active(user_id, request.is_active)
    if not updated:
        raise HTTPException(404, "Участник не найден")
    return updated
