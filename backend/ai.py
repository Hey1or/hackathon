"""AI provider adapter. API keys are read server-side and never returned to clients."""
from __future__ import annotations

import json
import os
import re
from typing import Any

from dotenv import load_dotenv

from .storage import ROOT

load_dotenv(ROOT / ".env")

PROVIDER = os.getenv("AI_PROVIDER", "openai").strip().lower()
API_KEY = os.getenv("AI_API_KEY", "").strip()
MODEL = os.getenv("AI_MODEL", "gpt-6-astra").strip()
NVIDIA_BASE_URL = os.getenv("NVIDIA_BASE_URL", "https://integrate.api.nvidia.com/v1").strip()
AI_ENABLED = bool(API_KEY)

QUESTIONS = [
    ("users", r"студент|школьник|учител|преподав|родител|куратор|пользоват|абитуриент|слушател", "Кто именно сталкивается с проблемой? Опишите основную группу пользователей."),
    ("need", r"нужно|надо|необходим|хотим|хотел|цель|потребност|важно|задач", "Что именно вы хотите изменить или упростить благодаря решению команды?"),
    ("data", r"данн|таблиц|выгруз|статистик|источник|материал|пример|опрос|аналитик", "Какие данные, материалы или примеры вы сможете предоставить команде?"),
    ("result", r"результ|прототип|дашборд|сервис|систем|прилож|создат|разработ|внедрит|улучш", "Какой конкретный результат вы ожидаете от команды к концу проекта?"),
    ("success", r"критери|метрик|успех|измер|показател|процент|количеств", "По каким признакам вы поймёте, что решение полезно? Есть ли целевой показатель?"),
    ("constraints", r"срок|огранич|бюджет|доступ|запрет|соглас|недел|месяц|апи|безопасност", "Какие ограничения важны: сроки, доступ к данным, технологии или правила безопасности?"),
    ("context", r"проблем|происход|сейчас|ситуац|трудн|сложн|не могут|не понима", "Можете привести конкретный пример этой проблемы и объяснить, как её решают сейчас?"),
]
FALLBACKS = [
    ("contact", "Кто со стороны бизнеса будет отвечать на вопросы и давать команде обратную связь?"),
    ("pilot", "Какой самый небольшой пилот поможет проверить идею?"),
    ("previous", "Какие решения уже пробовали и что в них не сработало?"),
]


def demo_questions(draft: str) -> list[dict[str, str]]:
    text = draft.lower()
    output = [
        {"field": field, "question": question}
        for field, pattern, question in QUESTIONS
        if not re.search(pattern, text, re.IGNORECASE)
    ][:5]
    for field, question in FALLBACKS:
        if len(output) >= 3:
            break
        output.append({"field": field, "question": question})
    return output[:5]


def demo_organize(draft: str, answers: dict[str, str]) -> dict[str, str]:
    title = re.split(r"[.!?\n]", draft.strip(), maxsplit=1)[0][:90].strip()
    return {
        "title": title or "Новая образовательная задача",
        "company": "Бизнес-партнёр",
        "topic": "Образование",
        "context": draft.strip(),
        "need": answers.get("need", ""),
        "users": answers.get("users", ""),
        "data": answers.get("data", ""),
        "result": answers.get("result", ""),
        "success": answers.get("success", ""),
        "constraints": answers.get("constraints", ""),
        "contact": answers.get("contact", ""),
    }


async def _ask_json(instructions: str, payload: dict[str, Any]) -> dict[str, Any]:
    from openai import AsyncOpenAI

    base_url = NVIDIA_BASE_URL if PROVIDER == "nvidia" else None
    client = AsyncOpenAI(api_key=API_KEY, base_url=base_url)
    response = await client.responses.create(
        model=MODEL,
        instructions=instructions,
        input=json.dumps(payload, ensure_ascii=False),
        text={"format": {"type": "json_object"}},
        store=False,
    )
    parsed = json.loads(response.output_text)
    if not isinstance(parsed, dict):
        raise ValueError("Ожидался JSON-объект от модели")
    return parsed


async def refine(draft: str) -> tuple[list[dict[str, str]], str]:
    if not AI_ENABLED:
        return demo_questions(draft), "demo"
    result = await _ask_json(
        "Ты — редактор бизнес-задач для студенческих команд. Верни JSON вида {\"questions\":[{\"field\":\"context|need|users|data|result|success|constraints|contact\",\"question\":\"короткий вопрос на русском\"}]}. Сначала определи, что уже явно сказано. Спроси о недостающем, не повторяй известное. Задай от 3 до 5 вопросов. Не добавляй никаких фактов, решений или оценок от себя. Если черновик общий, уточни конкретный пример проблемы, пользователей, доступные данные, ожидаемый результат и ограничения.",
        {"draft": draft},
    )
    cleaned: list[dict[str, str]] = []
    valid_fields = {"context", "need", "users", "data", "result", "success", "constraints", "contact"}
    for item in result.get("questions", []):
        if not isinstance(item, dict):
            continue
        field = str(item.get("field", "context"))
        question = str(item.get("question", "")).strip()
        if field in valid_fields and 8 <= len(question) <= 240:
            cleaned.append({"field": field, "question": question})
    if len(cleaned) < 3:
        raise ValueError("AI вернул меньше трёх корректных вопросов; попросите повторить генерацию")
    return cleaned[:5], "ai"


async def organize(draft: str, answers: dict[str, str]) -> tuple[dict[str, str], str]:
    if not AI_ENABLED:
        return demo_organize(draft, answers), "demo"
    result = await _ask_json(
        "Ты структурируешь карточку образовательной бизнес-задачи для студенческой команды. Верни только JSON-объект с ключами title, company, topic, context, need, users, data, result, success, constraints, contact (все значения — строки). Используй только факты из входного черновика и ответов. Не выдумывай значения. Если данных нет, оставь пустую строку. Не давай оценок и не подменяй ожидания заказчика.",
        {"draft": draft, "answers": answers},
    )
    keys = ("title", "company", "topic", "context", "need", "users", "data", "result", "success", "constraints", "contact")
    card = {key: str(result.get(key, "")).strip()[:2000] for key in keys}
    card["context"] = card["context"] or draft.strip()
    return card, "ai"
