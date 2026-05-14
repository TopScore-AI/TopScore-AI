import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import '../../constants/colors.dart';

class InteractiveTableWidget extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<List<dynamic>> rows;

  const InteractiveTableWidget({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      final headingColor = AppColors.topscoreBlue;
      final borderColor = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.05);

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) _buildTitle(isDark, headingColor),
            LayoutBuilder(
              builder: (context, constraints) {
                // Determine if we should use horizontal or vertical layout
                // We use a threshold of 500px, or if number of columns is high (>3)
                final useVerticalLayout =
                    constraints.maxWidth < 500 || columns.length > 3;

                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: useVerticalLayout
                        ? _buildVerticalTable(isDark, headingColor, borderColor)
                        : _buildHorizontalTable(
                            isDark, headingColor, borderColor),
                  ),
                );
              },
            ),
          ],
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Table render error: $e',
            style: const TextStyle(color: Colors.orange)),
      );
    }
  }

  Widget _buildTitle(bool isDark, Color headingColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: headingColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.table_chart_rounded,
              size: 16,
              color: headingColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.text,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalTable(
      bool isDark, Color headingColor, Color borderColor) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          // Header Row
          TableRow(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.white.withValues(alpha: 0.02),
                      ]
                    : [
                        const Color(0xFFF9FAFB),
                        const Color(0xFFF3F4F6),
                      ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(
                bottom: BorderSide(color: borderColor, width: 1.5),
              ),
            ),
            children: columns.map((col) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                child: Text(
                  col.trim().toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: headingColor,
                    letterSpacing: 0.8,
                  ),
                ),
              );
            }).toList(),
          ),
          // Data Rows
          ...rows.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final row = entry.value;
            final isEven = rowIndex % 2 == 0;
            final isLast = rowIndex == rows.length - 1;

            return TableRow(
              decoration: BoxDecoration(
                color: !isEven
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : const Color(0xFFFBFBFE))
                    : null,
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(color: borderColor, width: 0.8),
                      ),
              ),
              children: row.map((cell) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: GptMarkdown(
                    cell.toString().trim(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: (isDark ? Colors.white : AppColors.text)
                          .withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVerticalTable(
      bool isDark, Color headingColor, Color borderColor) {
    return Column(
      children: rows.asMap().entries.map((entry) {
        final rowIndex = entry.key;
        final row = entry.value;
        final isLastRow = rowIndex == rows.length - 1;

        return Container(
          decoration: BoxDecoration(
            border: isLastRow
                ? null
                : Border(
                    bottom: BorderSide(color: borderColor, width: 1.5),
                  ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: row.asMap().entries.map((cellEntry) {
              final cellIndex = cellEntry.key;
              final cell = cellEntry.value;
              final columnName =
                  columns.length > cellIndex ? columns[cellIndex] : "";

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        columnName.trim().toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: headingColor.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: GptMarkdown(
                        cell.toString().trim(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: (isDark ? Colors.white : AppColors.text)
                              .withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
