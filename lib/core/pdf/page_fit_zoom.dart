import 'dart:math' as math;

/// Fits one PDF page inside an editor that also contains a header, toolbars,
/// and possibly a thumbnail sidebar.
///
/// [hostWidth] and [hostHeight] are the outer editor area, not the viewer's
/// exact layout box. We deliberately use the full host width (the actual
/// viewer is never wider) and reserve vertical room for editor chrome, so the
/// resulting fit is conservative rather than clipping document contents.
///
/// The result uses [PdfViewport.zoom] units: 1 means *fit width*, not 100%
/// actual pixels-per-point. The editor accepts down to 0.25 fit-width.
double pdfEditorFitPageZoom({
  required double pageWidth,
  required double pageHeight,
  required double hostWidth,
  required double hostHeight,
  double chromeHeight = 100,
  double safeFraction = 0.94,
}) {
  for (final value in [
    pageWidth, pageHeight, hostWidth, hostHeight, chromeHeight, safeFraction,
  ]) {
    if (!value.isFinite) {
      throw const FormatException('Non-finite PDF page/viewer dimensions.');
    }
  }
  if (pageWidth <= 0 || pageHeight <= 0 ||
      hostWidth <= 0 || hostHeight <= 0 ||
      chromeHeight < 0 || safeFraction <= 0 || safeFraction > 1) {
    throw const FormatException('Invalid PDF page/viewer dimensions.');
  }
  final usableHeight = math.max(1, hostHeight - chromeHeight);
  final pageHeightAtFitWidth = hostWidth * pageHeight / pageWidth;
  return (usableHeight / pageHeightAtFitWidth * safeFraction)
      .clamp(0.25, 1.0)
      .toDouble();
}
