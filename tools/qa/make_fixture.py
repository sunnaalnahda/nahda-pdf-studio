"""Create a vector PDF fixture. No rasterized source pages."""
import sys
from pathlib import Path
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas


def make_fixture(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(path), pagesize=A4, pageCompression=1)
    w, h = A4
    c.setTitle('Nahda PDF vector QA original')
    c.setFont('Helvetica-Bold', 17)
    c.drawString(54, h - 70, 'NAHDA PDF STUDIO - ORIGINAL DOCUMENT')
    c.setLineWidth(1.5)
    c.line(54, h - 80, w - 54, h - 80)
    c.setFont('Helvetica', 12)
    c.drawString(54, h - 150, 'Preserve this searchable original text and vector line.')
    c.rect(55, 190, 470, 60, stroke=1, fill=0)
    c.drawString(66, 216, 'Original drawing: do not rasterize the page.')
    c.showPage()
    c.setFont('Helvetica', 12)
    c.drawString(55, h - 75, 'Page 2: original page count should stay unchanged.')
    c.showPage()
    c.save()


if __name__ == '__main__':
    make_fixture(Path(sys.argv[1] if len(sys.argv) > 1 else 'qa-results/original.pdf'))
