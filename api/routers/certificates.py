"""
api/routers/certificates.py

GET /api/v1/certificates/{attempt_id}   Generate and stream a PDF certificate
"""

from __future__ import annotations

import io
import time

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse

from api.config import settings
from api.db import SessionLocal
from api.dependencies import get_current_user
from api.models.progress import AssessmentAttemptRow
from api.models.courses import CourseScriptRow
from api.models.users import UserRow

router = APIRouter(prefix="/api/v1/certificates", tags=["Certificates"])


def _generate_pdf(
    learner_name: str,
    course_title: str,
    score: int,
    cert_id: str,
    issue_date: str,
) -> bytes:
    """Generate a certificate PDF and return raw bytes."""
    from fpdf import FPDF

    pdf = FPDF(orientation="L", unit="mm", format="A4")
    pdf.add_page()
    pdf.set_auto_page_break(False)

    W, H = 297, 210

    # Background
    pdf.set_fill_color(247, 245, 242)
    pdf.rect(0, 0, W, H, "F")

    # Amber accent bar (top)
    pdf.set_fill_color(245, 190, 63)
    pdf.rect(0, 0, W, 8, "F")

    # Amber accent bar (bottom)
    pdf.rect(0, H - 8, W, 8, "F")

    # Left accent column
    pdf.set_fill_color(27, 27, 29)
    pdf.rect(0, 0, 18, H, "F")

    # Logo text in left column (rotated)
    pdf.set_font("Helvetica", "B", 9)
    pdf.set_text_color(245, 190, 63)
    pdf.set_xy(2, H // 2 - 20)
    pdf.rotate(90)
    pdf.cell(40, 6, "ARRESTO LMS", align="C")
    pdf.rotate(0)

    # Certificate content area
    X = 28

    # Eyebrow
    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(194, 65, 12)
    pdf.set_xy(X, 20)
    pdf.cell(0, 6, "CERTIFICATE OF COMPLETION", ln=True)

    # Title divider
    pdf.set_draw_color(232, 228, 222)
    pdf.set_line_width(0.3)
    pdf.line(X, 28, W - 12, 28)

    # "This is to certify that"
    pdf.set_font("Helvetica", "I", 11)
    pdf.set_text_color(113, 113, 122)
    pdf.set_xy(X, 35)
    pdf.cell(0, 7, "This is to certify that", ln=True)

    # Learner name
    pdf.set_font("Helvetica", "B", 26)
    pdf.set_text_color(27, 27, 29)
    pdf.set_xy(X, 44)
    pdf.cell(0, 12, learner_name, ln=True)

    # "has successfully completed"
    pdf.set_font("Helvetica", "I", 11)
    pdf.set_text_color(113, 113, 122)
    pdf.set_xy(X, 58)
    pdf.cell(0, 7, "has successfully completed", ln=True)

    # Course title
    pdf.set_font("Helvetica", "B", 18)
    pdf.set_text_color(27, 27, 29)
    pdf.set_xy(X, 67)
    pdf.multi_cell(W - X - 14, 9, course_title)

    # Score badge
    pdf.set_fill_color(220, 252, 231)
    pdf.set_text_color(31, 138, 91)
    pdf.set_font("Helvetica", "B", 11)
    pdf.set_xy(X, 100)
    pdf.cell(36, 8, f"  Score: {score}%  ", border=0, fill=True, align="C")

    # Metadata row
    meta_y = 122
    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(113, 113, 122)

    pdf.set_xy(X, meta_y)
    pdf.cell(0, 5, "Issue Date", ln=True)
    pdf.set_font("Helvetica", "B", 10)
    pdf.set_text_color(27, 27, 29)
    pdf.set_xy(X, meta_y + 5)
    pdf.cell(0, 5, issue_date, ln=True)

    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(113, 113, 122)
    pdf.set_xy(X + 60, meta_y)
    pdf.cell(0, 5, "Certificate ID", ln=True)
    pdf.set_font("Helvetica", "B", 10)
    pdf.set_text_color(27, 27, 29)
    pdf.set_xy(X + 60, meta_y + 5)
    pdf.cell(0, 5, cert_id, ln=True)

    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(113, 113, 122)
    pdf.set_xy(X + 130, meta_y)
    pdf.cell(0, 5, "Issued by", ln=True)
    pdf.set_font("Helvetica", "B", 10)
    pdf.set_text_color(27, 27, 29)
    pdf.set_xy(X + 130, meta_y + 5)
    pdf.cell(0, 5, "Arresto LMS", ln=True)

    # Bottom divider
    pdf.set_draw_color(232, 228, 222)
    pdf.line(X, 142, W - 12, 142)

    # Footer note
    pdf.set_font("Helvetica", "I", 8)
    pdf.set_text_color(161, 161, 170)
    pdf.set_xy(X, 145)
    pdf.cell(
        0, 5,
        "This certificate confirms successful completion of the above course on the Arresto LMS platform.",
        ln=True,
    )

    return pdf.output()


@router.get("/{attempt_id}")
def download_certificate(
    attempt_id: str,
    current_user: UserRow = Depends(get_current_user),
):
    """Generate and return a PDF certificate for a passed assessment attempt."""
    with SessionLocal() as db:
        attempt = db.get(AssessmentAttemptRow, attempt_id)
        if attempt is None:
            raise HTTPException(status_code=404, detail="Attempt not found.")
        if not attempt.passed:
            raise HTTPException(status_code=400, detail="This attempt did not pass.")
        if current_user.role != "admin" and attempt.learner_id != current_user.email:
            raise HTTPException(status_code=403, detail="Access denied.")

        course = db.get(CourseScriptRow, attempt.script_id)
        course_title = course.course_title if course else attempt.script_id

    cert_id = f"CERT-{attempt_id[:8].upper()}"
    issue_date = time.strftime("%d %b %Y", time.localtime(attempt.taken_at))
    learner_name = (
        current_user.display_name
        or current_user.email.split("@")[0].replace(".", " ").replace("_", " ").title()
    )

    pdf_bytes = _generate_pdf(
        learner_name=learner_name,
        course_title=course_title,
        score=attempt.score,
        cert_id=cert_id,
        issue_date=issue_date,
    )

    filename = f"certificate_{cert_id}.pdf"
    return StreamingResponse(
        io.BytesIO(pdf_bytes),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("/{attempt_id}/email", status_code=204)
def email_certificate(
    attempt_id: str,
    current_user: UserRow = Depends(get_current_user),
):
    """Send the certificate download link to the learner's registered email."""
    from api.email_service import send_certificate_email, is_configured

    if not is_configured():
        raise HTTPException(
            status_code=503,
            detail="Email is not configured on this server. Download the certificate manually.",
        )

    with SessionLocal() as db:
        attempt = db.get(AssessmentAttemptRow, attempt_id)
        if attempt is None:
            raise HTTPException(status_code=404, detail="Attempt not found.")
        if not attempt.passed:
            raise HTTPException(status_code=400, detail="This attempt did not pass.")
        if current_user.role != "admin" and attempt.learner_id != current_user.email:
            raise HTTPException(status_code=403, detail="Access denied.")
        course = db.get(CourseScriptRow, attempt.script_id)
        course_title = course.course_title if course else attempt.script_id

    learner_name = (
        current_user.display_name
        or current_user.email.split("@")[0].replace(".", " ").replace("_", " ").title()
    )
    download_link = f"{settings.app_base_url}/api/v1/certificates/{attempt_id}"
    send_certificate_email(
        to=current_user.email,
        learner_name=learner_name,
        course_title=course_title,
        cert_download_link=download_link,
    )
