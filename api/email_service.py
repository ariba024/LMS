"""
api/email_service.py — Transactional email via SMTP.

Configure in .env (all optional — leave smtp_host blank to disable):

    SMTP_HOST=smtp.gmail.com
    SMTP_PORT=587
    SMTP_USER=you@gmail.com
    SMTP_PASSWORD=app-password
    SMTP_FROM=noreply@arresto.in
    SMTP_TLS=true           # STARTTLS on port 587; set false for SSL on port 465
    APP_BASE_URL=https://your-lms.com

When smtp_host is blank every send_* call is a no-op and logs at DEBUG level,
so the app works fully without email configured.
"""

from __future__ import annotations

import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from api.config import settings

logger = logging.getLogger("arresto.email")


def is_configured() -> bool:
    """True when all required SMTP settings are present."""
    return bool(settings.smtp_host and settings.smtp_user and settings.smtp_password)


def send_email(to: str, subject: str, html_body: str, text_body: str | None = None) -> None:
    """
    Send one email. Logs a warning on failure; never raises — email errors
    must never crash the caller (registration, certificate download, etc.).
    """
    if not is_configured():
        logger.debug("Email not configured — skipping send to %s: %s", to, subject)
        return

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"]    = settings.smtp_from
    msg["To"]      = to

    if text_body:
        msg.attach(MIMEText(text_body, "plain"))
    msg.attach(MIMEText(html_body, "html"))

    try:
        if settings.smtp_tls:
            with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
                smtp.ehlo()
                smtp.starttls()
                smtp.login(settings.smtp_user, settings.smtp_password)
                smtp.sendmail(settings.smtp_from, to, msg.as_string())
        else:
            with smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=10) as smtp:
                smtp.login(settings.smtp_user, settings.smtp_password)
                smtp.sendmail(settings.smtp_from, to, msg.as_string())
        logger.info("Email sent → %s: %s", to, subject)
    except Exception as exc:
        logger.warning("Email to %s failed: %s", to, exc)


def send_welcome_email(to: str, display_name: str) -> None:
    name = display_name or to.split("@")[0].title()
    html = f"""<html><body style="font-family:sans-serif;color:#1b1b1d">
<div style="max-width:560px;margin:0 auto;padding:32px 24px">
  <h2 style="color:#f59e0b">Welcome to Arresto LMS</h2>
  <p>Hi {name},</p>
  <p>Your account is ready. Log in to start your first course.</p>
  <a href="{settings.app_base_url}"
     style="display:inline-block;background:#f59e0b;color:#1b1b1d;padding:12px 24px;
            border-radius:8px;text-decoration:none;font-weight:700;margin-top:8px">
    Open Arresto LMS</a>
  <p style="margin-top:24px;color:#71717a;font-size:12px">
    Arresto Safety &amp; Compliance Learning Platform</p>
</div></body></html>"""
    send_email(to, "Welcome to Arresto LMS",
               html, f"Hi {name}, your account is ready. Visit {settings.app_base_url}")


def send_password_reset_email(to: str, reset_link: str) -> None:
    html = f"""<html><body style="font-family:sans-serif;color:#1b1b1d">
<div style="max-width:560px;margin:0 auto;padding:32px 24px">
  <h2 style="color:#f59e0b">Reset your password</h2>
  <p>We received a request to reset your Arresto LMS password.</p>
  <a href="{reset_link}"
     style="display:inline-block;background:#f59e0b;color:#1b1b1d;padding:12px 24px;
            border-radius:8px;text-decoration:none;font-weight:700;margin-top:8px">
    Reset Password</a>
  <p style="margin-top:16px;color:#71717a;font-size:12px">
    This link expires in 15 minutes.<br>
    If you did not request a reset, ignore this email — your password will not change.</p>
</div></body></html>"""
    send_email(to, "Reset your Arresto LMS password",
               html, f"Reset your password: {reset_link}\nExpires in 15 minutes.")


def send_certificate_email(
    to: str, learner_name: str, course_title: str, cert_download_link: str,
) -> None:
    html = f"""<html><body style="font-family:sans-serif;color:#1b1b1d">
<div style="max-width:560px;margin:0 auto;padding:32px 24px">
  <h2 style="color:#f59e0b">Congratulations, {learner_name}!</h2>
  <p>You have successfully completed <strong>{course_title}</strong>.</p>
  <p>Download your certificate below:</p>
  <a href="{cert_download_link}"
     style="display:inline-block;background:#f59e0b;color:#1b1b1d;padding:12px 24px;
            border-radius:8px;text-decoration:none;font-weight:700;margin-top:8px">
    Download Certificate</a>
  <p style="margin-top:24px;color:#71717a;font-size:12px">
    Arresto Safety &amp; Compliance Learning Platform</p>
</div></body></html>"""
    send_email(to, f"Your certificate: {course_title}",
               html,
               f"Congratulations {learner_name}! Download your certificate: {cert_download_link}")
