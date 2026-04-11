import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class ExportService {
  /// Exports a list of flashcards or quiz data to a CSV file and shares it.
  static Future<void> exportToCsv({
    required String fileName,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) async {
    try {
      final String csvContent = _generateCsv(headers, rows);
      
      final XFile xFile;
      if (kIsWeb) {
        // On web, we share the CSV content as a file download
        xFile = XFile.fromData(
          Uint8List.fromList(utf8.encode(csvContent)),
          name: '$fileName.csv',
          mimeType: 'text/csv',
        );
      } else {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$fileName.csv');
        await file.writeAsString(csvContent);
        xFile = XFile(file.path, name: '$fileName.csv', mimeType: 'text/csv');
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          subject: 'Exported Study Material: $fileName',
          text: 'Here is your exported study material from TopScore AI.',
        ),
      );

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Export Error: $e');
      }
    }
  }

  static String _generateCsv(List<String> headers, List<List<dynamic>> rows) {
    final StringBuffer sb = StringBuffer();
    
    // Add headers
    sb.writeln(headers.map((h) => '"${h.replaceAll('"', '""')}"').join(','));
    
    // Add rows
    for (final row in rows) {
      sb.writeln(row.map((field) {
        final String val = field?.toString() ?? '';
        return '"${val.replaceAll('"', '""')}"';
      }).join(','));
    }
    
    return sb.toString();
  }
}
