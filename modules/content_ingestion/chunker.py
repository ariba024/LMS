"""
Text chunker -- splits ExtractedContent into Chunk objects for embedding.

Strategy per format
-------------------
DOCX  Heading-aware split.  The # / ## markers written by the DOCX extractor
      are the natural section boundaries.  H1 sections are primary chunks;
      sections that exceed max_tokens are split further on H2, then on
      individual paragraphs with a sliding overlap window.

PDF   Page-based.  Each page is one chunk.  Pages that exceed max_tokens are
      split on paragraph boundaries with overlap.

PPTX  Slide-based.  Each slide is one chunk (slides are rarely longer than
      max_tokens).  Speaker notes, when present, are appended to the slide
      chunk so the full slide context travels together.

Token counting
--------------
We use word count as a fast approximation (1 word ~= 1.3 BPE tokens).
max_tokens=400 words ~= 500-520 BPE tokens, well within the 512-token
context window of MiniLM and similar sentence-transformer models.
"""

import re
from dataclasses import dataclass

from modules.content_ingestion.models import Chunk, ExtractedContent

# ── Numbered-step / procedure detection ───────────────────────────────────────
# Matches "1." / "1)" / "Step 1:" at the start of a line (up to 3-digit step numbers).
_STEP_RE = re.compile(r'(?m)^\s*([1-9]\d{0,2})\s*[.):\-]\s+\S')


def _last_step_num(text: str) -> int | None:
    """Return the last numbered-step number found in `text`, or None."""
    nums = [int(m.group(1)) for m in _STEP_RE.finditer(text)]
    return nums[-1] if nums else None


def _first_step_num(text: str) -> int | None:
    """Return the first numbered-step number found in `text`, or None."""
    m = _STEP_RE.search(text)
    return int(m.group(1)) if m else None


# ── Table detection patterns ───────────────────────────────────────────────────

# Pipe-delimited: | col1 | col2 | — needs at least 2 pipes
_TABLE_PIPE_RE  = re.compile(r'\|.*\|')
# Separator row: ---+--- or ===+==
_TABLE_SEP_RE   = re.compile(r'^[-=+|: ]{5,}$')
# 3+ column alignment via 2+ consecutive spaces between tokens
_TABLE_ALIGN_RE = re.compile(r'\S+(?:[ \t]{2,}\S+){2,}')


def _is_table_line(line: str) -> bool:
    """Return True if this line looks like part of a table row or separator."""
    s = line.strip()
    if not s or len(s) < 4:
        return False
    if _TABLE_PIPE_RE.search(s):
        return True
    if _TABLE_SEP_RE.fullmatch(s):
        return True
    if s.count('\t') >= 2:
        return True
    if _TABLE_ALIGN_RE.search(s):
        return True
    return False


def _extract_table_blocks(
    lines: list[str],
) -> list[tuple[bool, list[str]]]:
    """
    Segment `lines` into alternating (is_table, lines) blocks.
    A run of >= 3 consecutive table-like lines is treated as one table block
    and will be kept atomic (never split across chunks).
    """
    MIN_TABLE_ROWS = 3
    result: list[tuple[bool, list[str]]] = []
    i = 0
    while i < len(lines):
        # Count how many consecutive table lines start here
        j = i
        while j < len(lines) and _is_table_line(lines[j]):
            j += 1
        if j - i >= MIN_TABLE_ROWS:
            result.append((True, lines[i:j]))
            i = j
        else:
            # Accumulate non-table lines until the next table run
            start = i
            i += 1
            while i < len(lines):
                k = i
                while k < len(lines) and _is_table_line(lines[k]):
                    k += 1
                if k - i >= MIN_TABLE_ROWS:
                    break
                i += 1
            result.append((False, lines[start:i]))
    return result


@dataclass
class ChunkingConfig:
    max_tokens: int     = 600   # max words per chunk (bge-m3 supports 8,192 tokens; 600 words ≈ 780 tokens, well within limit)
    overlap_tokens: int = 100   # overlap words carried into the next chunk (was 50 — ~2 sentences; 100 ≈ 4-5 sentences)
    min_tokens: int     = 20    # discard chunks shorter than this


# -- Helpers --------------------------------------------------------------------

def _wc(text: str) -> int:
    return len(text.split())


def _slug(filename: str) -> str:
    """Filesystem-safe prefix for chunk IDs derived from the filename."""
    return re.sub(r"[^a-z0-9]+", "_", filename.lower())[:40].strip("_")


_SENTENCE_END = re.compile(r'(?<=[.!?])\s+(?=[A-Z"\'(\[])')


def _split_at_sentences(text: str, max_tokens: int) -> list[str]:
    """
    3D — Split an oversized paragraph at sentence boundaries.
    Called when a single paragraph exceeds max_tokens words.
    Falls back to returning the whole text if no sentence boundaries are found.
    """
    sentences = _SENTENCE_END.split(text)
    if len(sentences) <= 1:
        return [text]
    chunks: list[str] = []
    window: list[str] = []
    window_wc = 0
    for sent in sentences:
        sent_wc = _wc(sent)
        if window_wc + sent_wc > max_tokens and window:
            chunks.append(" ".join(window))
            window = [sent]
            window_wc = sent_wc
        else:
            window.append(sent)
            window_wc += sent_wc
    if window:
        chunks.append(" ".join(window))
    return chunks or [text]


def _split_paragraphs_with_overlap(
    paragraphs: list[str],
    max_tokens: int,
    overlap_tokens: int,
    min_tokens: int,
) -> list[str]:
    """
    Greedily pack paragraphs into chunks up to max_tokens words.
    When a chunk is full, carry the last `overlap_tokens` words worth of
    paragraphs into the next chunk so context is not lost at boundaries.
    """
    # 3D: pre-split any paragraph that is itself over the limit at sentence boundaries
    expanded: list[str] = []
    for para in paragraphs:
        if _wc(para) > max_tokens:
            expanded.extend(_split_at_sentences(para, max_tokens))
        else:
            expanded.append(para)
    paragraphs = expanded

    chunks: list[str] = []
    window: list[str] = []
    window_wc = 0

    for para in paragraphs:
        para_wc = _wc(para)
        if window_wc + para_wc > max_tokens and window:
            text = "\n".join(window).strip()
            if _wc(text) >= min_tokens:
                chunks.append(text)
            # Build overlap tail
            overlap: list[str] = []
            overlap_wc = 0
            for p in reversed(window):
                w = _wc(p)
                if overlap_wc + w <= overlap_tokens:
                    overlap.insert(0, p)
                    overlap_wc += w
                else:
                    break
            window = overlap + [para]
            window_wc = overlap_wc + para_wc
        else:
            window.append(para)
            window_wc += para_wc

    if window:
        text = "\n".join(window).strip()
        if _wc(text) >= min_tokens:
            chunks.append(text)

    return chunks


# -- Main class -----------------------------------------------------------------

class Chunker:

    def __init__(self, config: ChunkingConfig | None = None) -> None:
        self.cfg = config or ChunkingConfig()

    def chunk(self, content: ExtractedContent) -> list[Chunk]:
        if content.pages:
            return self._chunk_pdf(content)
        if content.slides:
            return self._chunk_pptx(content)
        return self._chunk_docx(content)

    # -- Private builders -------------------------------------------------------

    def _make(
        self,
        text: str,
        content: ExtractedContent,
        idx: int,
        *,
        page: int | None = None,
        slide: int | None = None,
        heading: str | None = None,
        is_ocr: bool = False,
        is_table: bool = False,
    ) -> Chunk:
        prefix = _slug(content.asset.original_filename)
        # 3F: auto-detect numbered procedure lists in the chunk text
        is_procedure = is_table is False and bool(_STEP_RE.search(text))
        return Chunk(
            chunk_id=f"{prefix}_{idx:04d}",
            text=text,
            asset_id=content.asset.id,
            source_file=content.asset.original_filename,
            asset_type=content.asset.asset_type.value,
            chunk_index=idx,
            token_count=_wc(text),
            page_number=page,
            slide_number=slide,
            section_heading=heading,
            is_ocr=is_ocr,
            is_table=is_table,
            is_procedure=is_procedure,
            doc_title=content.title or "",
            doc_author=content.author or "",
        )

    def _chunk_pdf(self, content: ExtractedContent) -> list[Chunk]:
        chunks: list[Chunk] = []
        idx = 0

        # 3A — Cross-page procedure merge: if page N ends with step K and page N+1
        # starts with step K+1, merge them so the numbered sequence stays in one chunk.
        # Only non-OCR pages are merged (OCR text is too noisy for reliable step detection).
        page_data: list[tuple] = [
            (p.page_number, p.cleaned_text.strip(), p.is_ocr)
            for p in content.pages
        ]
        changed = True
        while changed:
            changed = False
            out: list[tuple] = []
            i = 0
            while i < len(page_data):
                if (
                    i + 1 < len(page_data)
                    and not page_data[i][2]        # neither page is OCR
                    and not page_data[i + 1][2]
                ):
                    last_n  = _last_step_num(page_data[i][1])
                    first_n = _first_step_num(page_data[i + 1][1])
                    if last_n is not None and first_n is not None and first_n == last_n + 1:
                        merged_text = page_data[i][1] + "\n" + page_data[i + 1][1]
                        out.append((page_data[i][0], merged_text, False))
                        i += 2
                        changed = True
                        continue
                out.append(page_data[i])
                i += 1
            page_data = out

        for page_number, text, is_ocr in page_data:
            if not text:
                continue

            # For OCR pages the "heading" is page N (the [OCR page N] tag is gone
            # so we synthesise a heading from the page number instead).
            # For digital pages the first non-empty line is a good heading.
            if is_ocr:
                heading = f"Page {page_number} (OCR)"
            else:
                heading = next((l.strip() for l in text.splitlines() if l.strip()), None)

            if _wc(text) <= self.cfg.max_tokens:
                chunks.append(self._make(text, content, idx,
                                         page=page_number,
                                         heading=heading,
                                         is_ocr=is_ocr))
                idx += 1
            else:
                lines = [p for p in text.splitlines() if p.strip()]
                for is_tbl, block in _extract_table_blocks(lines):
                    if is_tbl:
                        # Keep the entire table as one atomic chunk — never split.
                        table_text = "\n".join(block)
                        chunks.append(self._make(table_text, content, idx,
                                                 page=page_number,
                                                 heading=heading,
                                                 is_ocr=is_ocr,
                                                 is_table=True))
                        idx += 1
                    else:
                        for sub in _split_paragraphs_with_overlap(
                                block, self.cfg.max_tokens,
                                self.cfg.overlap_tokens, self.cfg.min_tokens):
                            chunks.append(self._make(sub, content, idx,
                                                     page=page_number,
                                                     heading=heading,
                                                     is_ocr=is_ocr))
                            idx += 1
        return chunks

    def _chunk_pptx(self, content: ExtractedContent) -> list[Chunk]:
        chunks: list[Chunk] = []
        idx = 0
        for slide in content.slides:
            text = slide.cleaned_text.strip()
            if not text:
                continue
            if slide.speaker_notes:
                text = text + "\n[Notes] " + slide.speaker_notes.strip()
            heading = next((l.strip() for l in text.splitlines() if l.strip()), None)
            if _wc(text) <= self.cfg.max_tokens:
                chunks.append(self._make(text, content, idx,
                                         slide=slide.slide_number, heading=heading))
                idx += 1
            else:
                paras = [p for p in text.splitlines() if p.strip()]
                for sub in _split_paragraphs_with_overlap(
                        paras, self.cfg.max_tokens,
                        self.cfg.overlap_tokens, self.cfg.min_tokens):
                    chunks.append(self._make(sub, content, idx,
                                             slide=slide.slide_number, heading=heading))
                    idx += 1
        return chunks

    def _chunk_docx(self, content: ExtractedContent) -> list[Chunk]:
        """
        Split on # (H1) first -> each H1 section becomes one or more chunks.
        Sections longer than max_tokens are split further on ## (H2) sections,
        then on paragraph boundaries with overlap if still too long.
        """
        chunks: list[Chunk] = []
        idx = 0

        # Split text into H1 blocks (each starts with "# " or is pre-heading text)
        h1_blocks = re.split(r"(?m)^(?=# )", content.full_text)

        for block in h1_blocks:
            block = block.strip()
            if not block:
                continue

            first_line = block.splitlines()[0].strip()
            h1_heading = first_line.lstrip("#").strip() if first_line.startswith("#") else None

            if _wc(block) <= self.cfg.max_tokens:
                chunks.append(self._make(block, content, idx, heading=h1_heading))
                idx += 1
                continue

            # Block is too long -> split on ## (H2)
            h2_blocks = re.split(r"(?m)^(?=## )", block)
            for sub in h2_blocks:
                sub = sub.strip()
                if not sub:
                    continue
                sub_first = sub.splitlines()[0].strip()
                h2_heading = sub_first.lstrip("#").strip() if sub_first.startswith("#") else h1_heading

                if _wc(sub) <= self.cfg.max_tokens:
                    chunks.append(self._make(sub, content, idx, heading=h2_heading))
                    idx += 1
                    continue

                # Still too long -> table-aware split then paragraph overlap
                lines = [p for p in sub.splitlines() if p.strip()]
                for is_tbl, block in _extract_table_blocks(lines):
                    if is_tbl:
                        table_text = "\n".join(block)
                        chunks.append(self._make(table_text, content, idx,
                                                 heading=h2_heading, is_table=True))
                        idx += 1
                    else:
                        for piece in _split_paragraphs_with_overlap(
                                block, self.cfg.max_tokens,
                                self.cfg.overlap_tokens, self.cfg.min_tokens):
                            chunks.append(self._make(piece, content, idx, heading=h2_heading))
                            idx += 1

        return chunks
