import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// A custom builder for Markdown tables that adds horizontal scrolling support
/// to prevent UI overflow on mobile devices.
class MarkdownTableBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final MarkdownStyleSheet styleSheet;

  MarkdownTableBuilder(this.context, this.styleSheet);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // 1. Collect all rows (tr) recursively to be robust against missing thead/tbody
    final List<md.Element> rowElements = [];
    _collectRows(element, rowElements);

    if (rowElements.isEmpty) return null;

    final List<TableRow> rows = [];
    for (var i = 0; i < rowElements.length; i++) {
      // First row is usually the header in GFM or if it's the only row
      final isHeader = i == 0 && rowElements[i].children?.every((c) => c is md.Element && c.tag == 'th') == true;
      rows.add(_buildTableRow(rowElements[i], isHeader));
    }

    if (rows.isEmpty) return null;

    // 2. Wrap the Table in a horizontal scroll view
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(1), // prevent bleed
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  width: 1,
                ),
                verticalInside: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              children: rows,
            ),
          ),
        ),
      ),
    );
  }

  void _collectRows(md.Node node, List<md.Element> rows) {
    if (node is md.Element) {
      if (node.tag == 'tr') {
        rows.add(node);
      } else {
        for (var child in node.children ?? []) {
          _collectRows(child, rows);
        }
      }
    }
  }

  TableRow _buildTableRow(md.Element rowElement, bool isHeader) {
    final List<Widget> cells = [];
    
    for (var cell in rowElement.children ?? []) {
      if (cell is md.Element && (cell.tag == 'th' || cell.tag == 'td')) {
        cells.add(
          Padding(
            padding: styleSheet.tableCellsPadding ?? const EdgeInsets.all(12),
            child: _buildCellContent(cell, isHeader || cell.tag == 'th'),
          ),
        );
      }
    }
    
    return TableRow(
      decoration: isHeader 
        ? BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.08)) 
        : null,
      children: cells,
    );
  }

  Widget _buildCellContent(md.Element cellElement, bool isHeader) {
    // Recursively build a TextSpan for rich text support (bold, italics, etc.)
    final List<InlineSpan> spans = [];
    _buildSpan(cellElement, spans, isHeader);

    return RichText(
      textAlign: isHeader ? (styleSheet.tableHeadAlign ?? TextAlign.center) : TextAlign.left,
      text: TextSpan(
        children: spans,
        style: isHeader ? styleSheet.tableHead : styleSheet.tableBody,
      ),
    );
  }

  void _buildSpan(md.Node node, List<InlineSpan> spans, bool isHeader) {
    if (node is md.Text) {
      spans.add(TextSpan(text: node.text));
    } else if (node is md.Element) {
      final parentStyle = isHeader ? styleSheet.tableHead : styleSheet.tableBody;
      TextStyle? style;
      
      switch (node.tag) {
        case 'strong':
          style = parentStyle?.copyWith(fontWeight: FontWeight.bold);
          break;
        case 'em':
          style = parentStyle?.copyWith(fontStyle: FontStyle.italic);
          break;
        case 'code':
          style = styleSheet.code?.copyWith(fontSize: 12);
          break;
        default:
          style = parentStyle;
      }

      final List<InlineSpan> children = [];
      for (var child in node.children ?? []) {
        _buildSpan(child, children, isHeader);
      }

      if (children.isNotEmpty) {
        spans.add(TextSpan(
          children: children,
          style: style,
        ));
      } else if (node.textContent.isNotEmpty) {
        spans.add(TextSpan(
          text: node.textContent,
          style: style,
        ));
      }
    }
  }
}
