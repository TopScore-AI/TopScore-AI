import 'dart:convert';
import 'package:flutter/material.dart';

class PunnettSquareWidget extends StatelessWidget {
  final String dataJson;

  const PunnettSquareWidget({
    super.key,
    required this.dataJson,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final Map<String, dynamic> data = json.decode(dataJson);
      final List<dynamic> topAlleles = data['top_alleles'] ?? [];
      final List<dynamic> leftAlleles = data['left_alleles'] ?? [];
      final List<dynamic> grid = data['grid'] ?? [];
      final String? title = data['title'];
      final String? description = data['description'];
      final Map<String, dynamic>? legend = data['legend'];

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.02),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final double cellSize = (constraints.maxWidth - 40) / (topAlleles.length + 1);
                return Table(
                  defaultColumnWidth: FixedColumnWidth(cellSize),
                  border: TableBorder.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.5,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  children: [
                    // Header Row (Top Alleles)
                    TableRow(
                      children: [
                        const SizedBox.shrink(), // Empty top-left cell
                        ...topAlleles.map((allele) => _buildHeaderCell(allele.toString(), isVertical: false)),
                      ],
                    ),
                    // Grid Rows
                    for (int i = 0; i < leftAlleles.length; i++)
                      TableRow(
                        children: [
                          _buildHeaderCell(leftAlleles[i].toString(), isVertical: true),
                          ...List.generate(topAlleles.length, (j) {
                            final cellValue = (grid.length > i && (grid[i] as List).length > j)
                                ? grid[i][j].toString()
                                : '';
                            return _buildGridCell(cellValue);
                          }),
                        ],
                      ),
                  ],
                );
              },
            ),
            if (legend != null && legend.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'GENOTYPE KEY',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: legend.entries.map((e) => _buildLegendItem(e.key, e.value.toString())).toList(),
              ),
            ],
            if (description != null) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('Error rendering Punnett Square: $e', style: const TextStyle(color: Colors.redAccent)),
      );
    }
  }

  Widget _buildHeaderCell(String text, {required bool isVertical}) {
    return Container(
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildGridCell(String text) {
    return Container(
      height: 50,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildLegendItem(String key, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            key,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
