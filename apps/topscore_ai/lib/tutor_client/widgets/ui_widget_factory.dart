import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'interactive_table_widget.dart';
import 'ai_image_widget.dart';
import 'mnemonic_card.dart';
import 'punnett_square_widget.dart';

/// A factory that dispatches dynamic UI widgets based on the configuration sent by the server.
class UiWidgetFactory extends StatelessWidget {
  final String jsonConfig;

  const UiWidgetFactory({super.key, required this.jsonConfig});

  @override
  Widget build(BuildContext context) {
    try {
      final data = json.decode(jsonConfig);
      final String type = data['type'] ?? 'unknown';
      final String title = data['title'] ?? 'Interactive Component';
      final config = data['config'] ?? {};

      switch (type) {
        case 'interactive_table':
          // Defensive extraction
          final rawCols = config['columns'];
          final rawRows = config['rows'];

          final List<String> columns = [];
          if (rawCols is List) {
            for (var c in rawCols) {
              columns.add(c?.toString() ?? '');
            }
          }

          final List<List<dynamic>> rows = [];
          if (rawRows is List) {
            for (var r in rawRows) {
              if (r is List) {
                rows.add(r);
              } else {
                rows.add([r?.toString() ?? '']);
              }
            }
          }

          return InteractiveTableWidget(
            title: title,
            columns: columns,
            rows: rows,
          );

        case 'image_widget':
          final imageUrl = config['url'] ?? config['image_url'] ?? '';
          return AiImageWidget(
            title: title,
            url: imageUrl.toString(),
          );

        case 'mnemonic_card':
          return MnemonicCard(
            mnemonicDataJson: jsonEncode(config),
          );

        case 'punnett_square':
          return PunnettSquareWidget(
            dataJson: jsonEncode(config),
          );
        
        default:
          return const SizedBox.shrink();
      }
    } catch (e, stack) {
      developer.log('Error rendering component: $e',
          name: 'UiWidgetFactory', error: e, stackTrace: stack);
      developer.log('Component JSON: $jsonConfig', name: 'UiWidgetFactory');
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withAlpha(75)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Interactive Component Error',
              style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '$e',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ),
      );
    }
  }
}
