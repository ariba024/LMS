"""
PDF extractor using PyMuPDF (fitz).

Responsibilities:
- Open the PDF via fitz.open() and iterate over pages
- For each page:
    * Try page.get_text() first (fast path -- works for digital PDFs)
    * If the result is empty/near-empty AND the page has embedded images,
      the page is a scanned image -- render it to PNG and run OCR (slow path)
- Extract embedded images; insert [Image N] placeholders into the text
- Optionally render each page to a PNG thumbnail
- Pull document-level metadata from doc.metadata

OCR is opt-in (enable_ocr=False by default) to keep fast ingestion for
the common case of digital PDFs.
"""

import logging

import fitz  # PyMuPDF

logger = logging.getLogger("arresto.extractors.pdf")
from modules.content_ingestion.extractors.base import BaseExtractor
from modules.content_ingestion.models import (
    Asset, AssetType, ExtractedContent, ExtractedImage, ExtractedPage,
)
from modules.content_ingestion.ocr import OCREngine, needs_ocr, OCR_DPI

MIN_IMAGE_DIM = 50  # pixels; images smaller than this are decorative noise


def _is_toc_page(text: str, page_number: int) -> bool:
    """
    Return True if this page looks like a Table of Contents (1D).
    TOC pages add noise to retrieval — they duplicate section titles without
    substantive content. Detection is limited to the first 12 pages so content
    pages that happen to list items are never skipped.
    """
    if page_number > 12:
        return False
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    if not lines:
        return False
    # Explicit heading on first line
    first = lines[0].lower()
    if any(first == kw or first.startswith(kw + " ") for kw in
           ("table of contents", "contents", "index", "table des matières")):
        return True
    # Heuristic: most lines end with a digit (page number) or "..." leader
    if len(lines) < 4:
        return False
    ending_in_ref = sum(
        1 for l in lines
        if l[-1].isdigit() or l.endswith(("...", "…", "- ", "—"))
    )
    return ending_in_ref / len(lines) >= 0.55


def _extract_page_text(page_obj: "fitz.Page") -> str:
    """
    Extract text from one PDF page with:
      1A — two-column layout detection: reads left column then right column
           instead of mixing them in content-stream order
      1B — structured table extraction: formats detected tables as
           pipe-delimited markdown so the chunker keeps them atomic

    Falls back to page.get_text() on any error (e.g. old PyMuPDF without
    find_tables support).
    """
    table_bboxes: list[tuple] = []           # (x0,y0,x1,y1) of each detected table
    table_parts:  list[tuple] = []           # (y0, markdown_str)

    # ── 1B: structured table extraction ────────────────────────────────────────
    try:
        for tbl in page_obj.find_tables().tables:
            rows = tbl.extract()
            if not rows or len(rows) < 2:
                continue
            lines: list[str] = []
            for ridx, row in enumerate(rows):
                cells = [str(c or "").replace("\n", " ").strip() for c in row]
                lines.append("| " + " | ".join(cells) + " |")
                if ridx == 0:
                    lines.append("| " + " | ".join("---" for _ in cells) + " |")
            table_bboxes.append(tuple(tbl.bbox))
            table_parts.append((tbl.bbox[1], "\n".join(lines)))
    except Exception:
        pass  # find_tables unavailable in this PyMuPDF version

    # ── 1A: block-level text with two-column detection ──────────────────────────
    try:
        raw_blocks = page_obj.get_text("blocks")
    except Exception:
        return page_obj.get_text()

    def _in_table(bx0: float, by0: float, bx1: float, by1: float) -> bool:
        for tx0, ty0, tx1, ty1 in table_bboxes:
            if bx0 < tx1 and bx1 > tx0 and by0 < ty1 and by1 > ty0:
                return True
        return False

    # Text blocks only — skip image blocks and any block inside a table bbox
    blocks = [
        (float(b[0]), float(b[1]), float(b[2]), float(b[3]), b[4].strip())
        for b in raw_blocks
        if b[6] == 0 and b[4].strip()
        and not _in_table(b[0], b[1], b[2], b[3])
    ]

    if not blocks and not table_parts:
        return page_obj.get_text()

    # Two-column detection: at least 25 % of blocks on each side of the midpoint
    prose = ""
    two_col = False
    if blocks:
        pw = page_obj.rect.width
        if pw > 0:
            mid = pw * 0.48
            lefts  = [b for b in blocks if (b[0] + b[2]) / 2 <  mid]
            rights = [b for b in blocks if (b[0] + b[2]) / 2 >= mid]
            n = len(blocks)
            two_col = len(lefts) >= max(2, n * 0.25) and len(rights) >= max(2, n * 0.25)

        if two_col:
            left_text  = "\n".join(b[4] for b in sorted(lefts,  key=lambda b: b[1]))
            right_text = "\n".join(b[4] for b in sorted(rights, key=lambda b: b[1]))
            prose = "\n\n".join(t for t in [left_text, right_text] if t)
        else:
            prose = "\n".join(b[4] for b in sorted(blocks, key=lambda b: (b[1], b[0])))

    if not table_parts:
        return prose or page_obj.get_text()

    if two_col or not blocks:
        # For two-column layouts, tables are appended after prose (columns share y-space)
        table_text = "\n\n".join(md for _, md in sorted(table_parts, key=lambda x: x[0]))
        return "\n\n".join(t for t in [prose, table_text] if t)

    # Single-column: interleave text blocks and tables by y-position
    all_parts: list[tuple] = list(table_parts)
    for b in blocks:
        all_parts.append((b[1], b[4]))
    all_parts.sort(key=lambda p: p[0])
    return "\n".join(p[1] for p in all_parts if p[1])


class PdfExtractor(BaseExtractor):
    """Extracts text, embedded images, and optional OCR from PDF files."""

    def __init__(
        self,
        render_images: bool = False,
        image_dpi:     int  = 150,
        enable_ocr:    bool = False,
        ocr_lang:      str  = "eng",
    ) -> None:
        self.render_images = render_images
        self.image_dpi     = image_dpi
        self._ocr          = OCREngine(ocr_lang) if enable_ocr else None

    def can_handle(self, asset: Asset) -> bool:
        return asset.asset_type == AssetType.PDF

    def extract(self, asset: Asset) -> ExtractedContent:
        """
        Extract text (and optionally OCR scanned pages) from a PDF.

        For each page:
          1. page.get_text()  -- instant, works for digital PDFs
          2. If text < 50 chars AND page has images --> OCR path:
               a. Render page to PNG at 300 DPI via PyMuPDF
               b. Pass PNG to OCREngine (Tesseract or EasyOCR)
               c. Use OCR result as the page text
        """
        self._validate_file(asset)
        result = ExtractedContent(asset=asset)

        try:
            doc = fitz.open(asset.file_path)
        except Exception as exc:
            result.extraction_errors.append(f"fitz.open failed: {exc}")
            return result

        meta = doc.metadata or {}
        result.title  = meta.get("title", "")
        result.author = meta.get("author", "")
        result.doc_metadata = {k: v for k, v in meta.items() if v}

        ocr_pages = []   # collect page numbers where OCR was used
        pages = []

        for page_obj in doc:
            text      = _extract_page_text(page_obj)
            rect      = page_obj.rect
            page_num  = page_obj.number + 1

            # 1D: skip Table of Contents pages — they duplicate titles without substance
            if _is_toc_page(text, page_num):
                logger.debug("Page %d identified as TOC — skipping.", page_num)
                continue
            raw_images = page_obj.get_images(full=True)

            # -- OCR path: page is a scanned image ----------------------------
            page_is_ocr = False
            if self._ocr and needs_ocr(text, bool(raw_images)):
                # Render at OCR_DPI for best recognition quality
                mat = fitz.Matrix(OCR_DPI / 72, OCR_DPI / 72)
                pix = page_obj.get_pixmap(matrix=mat)
                png = pix.tobytes("png")
                try:
                    ocr_text = self._ocr.extract_text(png)
                    if ocr_text:
                        text = ocr_text      # plain OCR text, no [OCR page N] tag
                        page_is_ocr = True
                        ocr_pages.append(page_obj.number + 1)
                        logger.info("Page %d: OCR extracted %d chars",
                                    page_obj.number + 1, len(ocr_text))
                except RuntimeError as ocr_err:
                    # OCR engine not installed — keep whatever text the page
                    # already had (may be empty for a fully scanned page).
                    # Record once per document so operators know OCR is missing.
                    msg = f"OCR unavailable (page {page_obj.number + 1}): {ocr_err}"
                    if msg not in result.extraction_errors:
                        result.extraction_errors.append(msg)
                    logger.warning(msg)

            # -- Embedded image extraction ------------------------------------
            page_images: list[ExtractedImage] = []
            seen_xrefs: set[int] = set()
            img_index = 0

            for img_info in raw_images:
                xref = img_info[0]
                if xref in seen_xrefs:
                    continue
                seen_xrefs.add(xref)
                try:
                    base = doc.extract_image(xref)
                    w, h = base["width"], base["height"]
                    if w < MIN_IMAGE_DIM or h < MIN_IMAGE_DIM:
                        continue
                    page_images.append(ExtractedImage(
                        index=img_index,
                        image_bytes=base["image"],
                        width=w, height=h,
                        mime_type=f"image/{base['ext']}",
                    ))
                    img_index += 1
                except Exception:
                    continue

            if page_images:
                placeholders = "  ".join(
                    f"[Image {img.index}]" for img in page_images
                )
                text = text.rstrip() + f"\n{placeholders}"

            # -- Optional whole-page thumbnail --------------------------------
            thumbnail: bytes | None = None
            if self.render_images:
                mat = fitz.Matrix(self.image_dpi / 72, self.image_dpi / 72)
                pix = page_obj.get_pixmap(matrix=mat)
                thumbnail = pix.tobytes("png")

            pages.append(ExtractedPage(
                page_number=page_obj.number + 1,
                raw_text=text,
                width=rect.width,
                height=rect.height,
                image_bytes=thumbnail,
                images=page_images,
                is_ocr=page_is_ocr,
            ))

        doc.close()
        result.pages     = pages
        result.full_text = "\n".join(p.raw_text for p in pages)
        if ocr_pages:
            result.doc_metadata["ocr_pages"] = ocr_pages
        return result
