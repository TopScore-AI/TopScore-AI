import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tutor_client/widgets/interactive_table_widget.dart';

/// A wrapper around GptMarkdown that provides premium styling for tables
/// and consistent typography across the app.
class StyledGptMarkdown extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final bool shrinkWrap;
  final Widget Function(BuildContext, String)? imageBuilder;
  final Widget Function(BuildContext, InlineSpan, String, TextStyle)?
      linkBuilder;
  final Widget Function(BuildContext, String, String, bool)? codeBuilder;
  final Widget Function(BuildContext, String, TextStyle, bool)? latexBuilder;
  final Widget Function(BuildContext, String, TextStyle)? highlightBuilder;
  final void Function(String, String)? onLinkTap;
  final TextAlign? textAlign;
  final TextScaler? textScaler;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool followLinkColor;
  final bool useDollarSignsForLatex;

  const StyledGptMarkdown(
    this.data, {
    super.key,
    this.style,
    this.shrinkWrap = true,
    this.imageBuilder,
    this.linkBuilder,
    this.codeBuilder,
    this.latexBuilder,
    this.highlightBuilder,
    this.onLinkTap,
    this.textAlign,
    this.textScaler,
    this.maxLines,
    this.overflow,
    this.followLinkColor = false,
    this.useDollarSignsForLatex = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use default style if none provided
    final effectiveStyle = style ??
        GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        );

    // Pre-process markdown to fix common table formatting issues
    // that prevent GptMarkdown from recognizing them.
    String processedData = data;

    // 0. Split concatenated table rows.
    // Streaming often joins rows on one line: "...cell |  | **Col** | cell |"
    // The "| |" or "||" boundary marks where one row ended and the next began.
    // Split these back into separate lines BEFORE any other normalisation.
    processedData = processedData.replaceAllMapped(
      RegExp(r'\|\s*\|\s*(?=\*{0,2}[A-Za-z0-9])'),
      (m) => '|\n| ',
    );

    // 1. Ensure there's a double newline before and after a table if it follows/precedes text
    processedData = processedData.replaceAllMapped(
      RegExp(r'([^\n])\n\|'),
      (match) => '${match.group(1)}\n\n|',
    );
    processedData = processedData.replaceAllMapped(
      RegExp(r'\|\n([^\n|])'),
      (match) => '|\n\n${match.group(1)}',
    );

    // 2. Fix tables that lack leading/trailing pipes or have malformed separators
    final lines = processedData.split('\n');
    bool inTable = false;
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      
      if (line.contains('|')) {
        inTable = true;
        // Ensure leading and trailing pipes
        if (!line.startsWith('|')) line = '| $line';
        if (!line.endsWith('|')) line = '$line |';
        
        lines[i] = line;
      } else if (inTable) {
        inTable = false;
      }
    }
    processedData = lines.join('\n');

    return GptMarkdown(
      processedData,
      style: effectiveStyle,
      imageBuilder: imageBuilder,
      linkBuilder: linkBuilder,
      codeBuilder: (context, name, code, isInline) {
        if (codeBuilder != null) return codeBuilder!(context, name, code, isInline);
        
        if (isInline) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              code,
              style: GoogleFonts.firaCode(
                fontSize: 14,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        name.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Icon(Icons.copy_all_rounded, size: 14, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    code,
                    style: GoogleFonts.firaCode(
                      fontSize: 13,
                      height: 1.5,
                      color: theme.brightness == Brightness.dark ? Colors.indigo.shade100 : Colors.indigo.shade900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      latexBuilder: latexBuilder,
      highlightBuilder: highlightBuilder,
      onLinkTap: onLinkTap,
      textAlign: textAlign,
      textScaler: textScaler,
      maxLines: maxLines,
      overflow: overflow,
      followLinkColor: followLinkColor,
      useDollarSignsForLatex: useDollarSignsForLatex,
      tableBuilder: (context, tableRows, textStyle, config) {
        if (tableRows.isEmpty) return const SizedBox.shrink();

        // Extract columns from the first row
        final List<String> columns = tableRows.first.fields
            .map((f) => f.data.trim())
            .toList();

        // Extract data rows (all rows after the first one)
        final List<List<dynamic>> rows = [];
        if (tableRows.length > 1) {
          for (int i = 1; i < tableRows.length; i++) {
            rows.add(tableRows[i].fields.map((f) => f.data.trim()).toList());
          }
        }

        return InteractiveTableWidget(
          title: "", // Titles are usually provided as headings above the table in markdown
          columns: columns,
          rows: rows,
        );
      },
    );
  }
}
