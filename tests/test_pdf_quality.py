import importlib.util
from pathlib import Path
import tempfile
import unittest

from reportlab.pdfgen import canvas
from pypdf import PdfReader, PdfWriter
from pypdf.annotations import FreeText

MODULE = Path(__file__).resolve().parents[1] / 'tools' / 'qa' / 'compare_pdf.py'
spec = importlib.util.spec_from_file_location('compare_pdf', MODULE)
qa = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qa)


class QualityRegressionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        base = Path(self.temp.name)
        self.before = base / 'before.pdf'
        self.after = base / 'after.pdf'
        c = canvas.Canvas(str(self.before))
        c.drawString(60, 720, 'DO NOT REMOVE ORIGINAL SEARCHABLE CONTENT')
        c.showPage()
        c.save()

    def tearDown(self):
        self.temp.cleanup()

    def test_identical_original_passes(self):
        self.after.write_bytes(self.before.read_bytes())
        self.assertTrue(qa.compare(self.before, self.after, require_incremental=True)['passed'])


    def test_incremental_text_annotation_preserves_original_stream(self):
        # Independent Python-generated FreeText revision; validates the QA gate,
        # NOT the Flutter editor implementation or Arabic font shaping.
        self.after.write_bytes(self.before.read_bytes())
        writer = PdfWriter(str(self.after), incremental=True)
        writer.add_annotation(
            page_number=0,
            annotation=FreeText(
                text='SAMPLE ADDED NOTE', rect=(60, 600, 300, 655), font_size='15pt'
            ),
        )
        with self.after.open('wb') as dest:
            writer.write(dest)
        result = qa.compare(self.before, self.after, require_incremental=True)
        self.assertTrue(result['passed'], result['failures'])
        self.assertEqual(result['page_checks'][0]['before_annotations'], 0)
        self.assertEqual(result['page_checks'][0]['after_annotations'], 1)
        self.assertTrue(result['original_bytes_prefix_preserved'])

    def test_detects_dropped_original_contents(self):
        writer = PdfWriter()
        writer.add_blank_page(width=612, height=792)
        with self.after.open('wb') as f:
            writer.write(f)
        result = qa.compare(self.before, self.after)
        self.assertFalse(result['passed'])
        self.assertTrue(any('original page content' in msg for msg in result['failures']))

    def test_detects_page_count_change(self):
        writer = PdfWriter()
        writer.append(PdfReader(str(self.before)))
        writer.add_blank_page(width=612, height=792)
        with self.after.open('wb') as f:
            writer.write(f)
        self.assertFalse(qa.compare(self.before, self.after)['passed'])

    def test_detects_nonincremental_rewrite(self):
        writer = PdfWriter()
        writer.append(PdfReader(str(self.before)))
        with self.after.open('wb') as f:
            writer.write(f)
        self.assertFalse(qa.compare(self.before, self.after, require_incremental=True)['passed'])


if __name__ == '__main__':
    unittest.main()
