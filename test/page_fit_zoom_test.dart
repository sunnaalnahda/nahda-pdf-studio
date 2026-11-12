import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/core/pdf/page_fit_zoom.dart';

void main() {
  test('portrait PDF shrinks below fit-width to show the entire page', () {
    final zoom = pdfEditorFitPageZoom(
      pageWidth: 595, pageHeight: 842,
      hostWidth: 1400, hostHeight: 620,
    );
    expect(zoom, lessThan(1));
    expect(zoom, greaterThanOrEqualTo(0.25));
    final actualHeight = 1400 * 842 / 595 * zoom;
    expect(actualHeight, lessThanOrEqualTo(620 - 100));
  });

  test('landscape document gets a larger fit factor than portrait', () {
    final portrait = pdfEditorFitPageZoom(
      pageWidth: 595, pageHeight: 842,
      hostWidth: 1200, hostHeight: 650,
    );
    final landscape = pdfEditorFitPageZoom(
      pageWidth: 842, pageHeight: 595,
      hostWidth: 1200, hostHeight: 650,
    );
    expect(landscape, greaterThan(portrait));
    expect(landscape, lessThanOrEqualTo(1));
  });

  test('spacious windows use fit-width rather than over-enlarge', () {
    final zoom = pdfEditorFitPageZoom(
      pageWidth: 1200, pageHeight: 350,
      hostWidth: 900, hostHeight: 1000,
    );
    expect(zoom, 1);
  });

  test('refuses nonfinite and negative page or canvas measurements', () {
    expect(() => pdfEditorFitPageZoom(
      pageWidth: 0, pageHeight: 100,
      hostWidth: 900, hostHeight: 500,
    ), throwsFormatException);
    expect(() => pdfEditorFitPageZoom(
      pageWidth: double.infinity, pageHeight: 100,
      hostWidth: 900, hostHeight: 500,
    ), throwsFormatException);
    expect(() => pdfEditorFitPageZoom(
      pageWidth: 500, pageHeight: 100,
      hostWidth: 900, hostHeight: 500,
      safeFraction: 2,
    ), throwsFormatException);
  });
}
