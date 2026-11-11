"""Offline structural and optional visual PDF regression checker (BSD/Apache deps).

Usage:
    python tools/qa/compare_pdf.py --before original.pdf --after edited.pdf \
        --require-incremental --render --report qa-results/report.json

This is a detection tool: a pass is not a PDF/A/PDF/UA certification, and
unchanged appearance does not prove correct Arabic shaping/selection order.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from pypdf import PdfReader


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def content_hashes(page: Any) -> list[str]:
    contents = page.get_contents()
    if contents is None:
        return []
    if isinstance(contents, list):
        return [sha256(obj.get_object().get_data()) for obj in contents]
    return [sha256(contents.get_object().get_data())]


def page_geometry(page: Any) -> tuple[float, float, float, float, int]:
    media = page.mediabox
    crop = page.cropbox
    return (
        round(float(media.width), 3), round(float(media.height), 3),
        round(float(crop.width), 3), round(float(crop.height), 3),
        int(page.get('/Rotate', 0)),
    )


def font_resources(page: Any) -> list[str]:
    resources = page.get('/Resources')
    if resources is None:
        return []
    resources = resources.get_object()
    fonts = resources.get('/Font')
    if fonts is None:
        return []
    fonts = fonts.get_object()
    return sorted(str(font.get_object().get('/BaseFont', key))
                  for key, font in fonts.items())


def compare(before: Path, after: Path, *, require_incremental: bool = False) -> dict[str, Any]:
    src = before.read_bytes()
    dst = after.read_bytes()
    old = PdfReader(str(before), strict=False)
    new = PdfReader(str(after), strict=False)
    failures: list[str] = []
    warnings: list[str] = []
    pages = []
    if len(old.pages) != len(new.pages):
        failures.append(f'Page count changed: {len(old.pages)} -> {len(new.pages)}')
    incremental = dst.startswith(src)
    if require_incremental and not incremental:
        failures.append('Edited bytes do not retain the original as an exact prefix')
    for i in range(min(len(old.pages), len(new.pages))):
        a, b = old.pages[i], new.pages[i]
        same_geometry = page_geometry(a) == page_geometry(b)
        same_base_streams = content_hashes(a) == content_hashes(b)
        old_text, new_text = (a.extract_text() or ''), (b.extract_text() or '')
        original_text_preserved = not old_text.strip() or old_text.strip() in new_text
        fonts_before, fonts_after = set(font_resources(a)), set(font_resources(b))
        old_annots, new_annots = len(a.get('/Annots', [])), len(b.get('/Annots', []))
        # Annotation addition must not modify the existing page /Contents.
        pages.append({
            'page': i + 1,
            'same_media_crop_box_and_rotation': same_geometry,
            'same_original_contents': same_base_streams,
            'original_extracted_text_preserved': original_text_preserved,
            'original_font_resources_preserved': fonts_before.issubset(fonts_after),
            'page_font_resources_before': sorted(fonts_before),
            'page_font_resources_after': sorted(fonts_after),
            'before_annotations': old_annots,
            'after_annotations': new_annots,
        })
        if not same_geometry:
            failures.append(f'Page {i+1}: MediaBox/CropBox/rotation changed')
        if not same_base_streams:
            failures.append(f'Page {i+1}: original page content streams changed')
        if not fonts_before.issubset(fonts_after):
            failures.append(f'Page {i+1}: original page font resources missing')
        if new_annots < old_annots:
            failures.append(f'Page {i+1}: original annotations removed')
        if not original_text_preserved:
            warnings.append(f'Page {i+1}: original text extraction changed; inspect manually')
    return {
        'passed': not failures,
        'input': str(before),
        'output': str(after),
        'input_sha256': sha256(src),
        'output_sha256': sha256(dst),
        'original_bytes_prefix_preserved': incremental,
        'pages_before': len(old.pages),
        'pages_after': len(new.pages),
        'page_checks': pages,
        'failures': failures,
        'warnings': warnings,
    }


def add_visual_diff(result: dict[str, Any], before: Path, after: Path, dpi: int) -> None:
    """Optional visual differences (pixel bounding boxes), not a text QA substitute."""
    import pypdfium2 as pdfium
    from PIL import ImageChops

    a_doc = pdfium.PdfDocument(str(before))
    b_doc = pdfium.PdfDocument(str(after))
    changed = []
    try:
        for i in range(min(len(a_doc), len(b_doc))):
            a_page, b_page = a_doc[i], b_doc[i]
            a_bitmap = a_page.render(scale=dpi / 72).to_pil().convert('RGB')
            b_bitmap = b_page.render(scale=dpi / 72).to_pil().convert('RGB')
            if a_bitmap.size != b_bitmap.size:
                result['failures'].append(f'Page {i+1}: render dimensions changed')
                continue
            bounds = ImageChops.difference(a_bitmap, b_bitmap).getbbox()
            changed.append({'page': i+1, 'changed_bbox_pixels': bounds})
    finally:
        a_doc.close()
        b_doc.close()
    result['visual_diff_dpi'] = dpi
    result['visual_diff'] = changed
    result['passed'] = not result['failures']


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--before', type=Path, required=True)
    ap.add_argument('--after', type=Path, required=True)
    ap.add_argument('--require-incremental', action='store_true')
    ap.add_argument('--render', action='store_true')
    ap.add_argument('--dpi', type=int, default=144)
    ap.add_argument('--report', type=Path)
    args = ap.parse_args()
    result = compare(args.before, args.after, require_incremental=args.require_incremental)
    if args.render:
        add_visual_diff(result, args.before, args.after, dpi=args.dpi)
    text = json.dumps(result, ensure_ascii=False, indent=2)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(text, encoding='utf-8')
    print(text)
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
