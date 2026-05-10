import 'package:universal_io/io.dart';
// Note: Document Scanner requires Google Play Services on Android.
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thrown when the doc scanner can't run. Callers should show this message.
class ScannerUnavailableException implements Exception {
  final String message;
  ScannerUnavailableException(this.message);
  @override
  String toString() => message;
}

class ScannerService {
  /// Opens the Google ML Kit Document Scanner UI on Android.
  ///
  /// Returns the list of image paths on success, or `null` if the user
  /// cancelled. Throws [ScannerUnavailableException] when the scanner
  /// can't run (e.g. missing Play Services, web platform) so the caller
  /// can show a message instead of silently doing nothing.
  Future<List<String>?> scanDocument() async {
    if (kIsWeb) {
      throw ScannerUnavailableException(
        'Document scanner is not available on web.',
      );
    }

    final scannerOptions = DocumentScannerOptions(
      documentFormat: DocumentFormat.jpeg,
      mode: ScannerMode.full,
      isGalleryImport: true,
      pageLimit: 20,
    );

    final documentScanner = DocumentScanner(options: scannerOptions);

    try {
      final result = await documentScanner.scanDocument();
      return result.images;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('Scanner PlatformException: ${e.code} ${e.message}');
      // ML Kit's document scanner module is downloaded on demand via Play
      // Services. If it's missing/outdated the plugin throws here.
      throw ScannerUnavailableException(
        'Document scanner unavailable. Please update Google Play Services and try again.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Scanner Error: $e');
      rethrow;
    } finally {
      documentScanner.close();
    }
  }

  /// Converts the scanned images into a single PDF file
  Future<File> generatePdf(List<String> imagePaths) async {
    final pdf = pw.Document();

    for (var path in imagePaths) {
      final image = pw.MemoryImage(File(path).readAsBytesSync());

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(image));
          },
        ),
      );
    }

    final output = await getTemporaryDirectory();
    final file = File(
      "${output.path}/scanned_doc_${DateTime.now().millisecondsSinceEpoch}.pdf",
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
