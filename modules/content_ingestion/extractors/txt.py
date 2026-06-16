"""
Plain-text / CSV extractor.

Reads the file as UTF-8 text (with error replacement) and stores the
content in ExtractedContent.full_text.  The chunker's _chunk_docx fallback
handles the rest: paragraphs are split on blank lines into ≤400-word chunks.
"""

from pathlib import Path

from modules.content_ingestion.extractors.base import BaseExtractor
from modules.content_ingestion.models import Asset, AssetType, ExtractedContent


class TxtExtractor(BaseExtractor):
    """Extracts plain text from .txt and .csv files."""

    def can_handle(self, asset: Asset) -> bool:
        return asset.asset_type == AssetType.TXT

    def extract(self, asset: Asset) -> ExtractedContent:
        self._validate_file(asset)
        result = ExtractedContent(asset=asset)
        try:
            result.full_text = Path(asset.file_path).read_text(
                encoding="utf-8", errors="replace"
            )
            result.title = Path(asset.original_filename).stem
        except Exception as exc:
            result.extraction_errors.append(f"Read failed: {exc}")
        return result
