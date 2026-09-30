"""SMTP mail delivery; console link fallback is for local development only."""
from __future__ import annotations

import html
import os
import smtplib
import ssl
from email.message import EmailMessage
from urllib.parse import quote


def send_verification(email: str, name: str, token: str) -> bool:
    base_url = os.getenv("APP_PUBLIC_URL", "http://127.0.0.1:8000").rstrip("/")
    link = f"{base_url}/verify-email?token={quote(token)}"
    host = os.getenv("SMTP_HOST", "").strip()
    if not host:
        print(f"[email-verification: local development only] To: {email} | Link: {link}")
        return False

    port = int(os.getenv("SMTP_PORT", "587"))
    username = os.getenv("SMTP_USER", "").strip()
    password = os.getenv("SMTP_PASSWORD", "")
    sender = os.getenv("SMTP_FROM", username).strip()
    if not sender:
        raise RuntimeError("SMTP_FROM или SMTP_USER должен содержать адрес отправителя")
    message = EmailMessage()
    message["Subject"] = "Подтвердите почту — AI Sana Challenge Hub"
    message["From"] = sender
    message["To"] = email
    message.set_content(f"Здравствуйте, {name}!\n\nПодтвердите адрес электронной почты по ссылке (она действует 24 часа):\n{link}\n\nЕсли вы не создавали аккаунт, просто проигнорируйте письмо.")
    message.add_alternative(
        f"<p>Здравствуйте, {html.escape(name)}!</p><p>Подтвердите адрес электронной почты. Ссылка действует 24 часа.</p><p><a href=\"{html.escape(link, quote=True)}\">Подтвердить почту</a></p><p>Если вы не создавали аккаунт, проигнорируйте письмо.</p>",
        subtype="html",
    )
    if port == 465:
        with smtplib.SMTP_SSL(host, port, context=ssl.create_default_context(), timeout=15) as server:
            if username:
                server.login(username, password)
            server.send_message(message)
    else:
        with smtplib.SMTP(host, port, timeout=15) as server:
            server.ehlo()
            server.starttls(context=ssl.create_default_context())
            server.ehlo()
            if username:
                server.login(username, password)
            server.send_message(message)
    return True
