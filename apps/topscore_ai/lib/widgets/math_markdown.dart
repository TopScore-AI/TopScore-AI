import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

/// 1. Custom Syntax Parser for LaTeX (supports $ and \(...\) / \[...\] delimiters)
class LatexSyntax extends md.InlineSyntax {
  // Updated Regex to support both $ and \( \) / \[ \] delimiters
  // Matches: $$...$$ (block), $...$ (inline), \[...\] (block), \(...\) (inline)
  LatexSyntax()
      : super(
            r'(\$\$[\s\S]*?\$\$)|(\\\[[\s\S]*?\\\])|(\$[^$\n]+\$)|(\\\([\s\S]*?\\\))');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final matchText = match[0]!;

    // Determine if block or inline based on delimiters
    bool isBlock;
    String content;

    if (matchText.startsWith(r'$$') && matchText.endsWith(r'$$')) {
      // Block: $$...$$
      isBlock = true;
      content = matchText.substring(2, matchText.length - 2);
    } else if (matchText.startsWith(r'\[') && matchText.endsWith(r'\]')) {
      // Block: \[...\]
      isBlock = true;
      content = matchText.substring(2, matchText.length - 2);
    } else if (matchText.startsWith(r'\(') && matchText.endsWith(r'\)')) {
      // Inline: \(...\)
      isBlock = false;
      content = matchText.substring(2, matchText.length - 2);
    } else {
      // Inline: $...$
      isBlock = false;
      content = matchText.substring(1, matchText.length - 1);
    }

    // Clean up content
    final cleanContent = content.trim();

    md.Element el = md.Element.text('latex', cleanContent);
    el.attributes['type'] = isBlock ? 'block' : 'inline';
    parser.addNode(el);
    return true;
  }
}

/// 2. Builder to render the LaTeX using flutter_math_fork
class LatexElementBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final content = element.textContent;
    final isBlock = element.attributes['type'] == 'block';

    try {
      if (isBlock) {
        return Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              content,
              textStyle: preferredStyle?.copyWith(
                fontSize: (preferredStyle.fontSize ?? 14) + 2,
              ),
              mathStyle: MathStyle.display,
            ),
          ),
        );
      } else {
        return Math.tex(
          content,
          textStyle: preferredStyle,
          mathStyle: MathStyle.text,
        );
      }
    } catch (e) {
      return Text(content, style: preferredStyle); // Fallback if TeX error
    }
  }
}

/// 3. Pre-processor to handle HTML tags like <u>
/// Flutter Markdown strips HTML by default. We map <u> to simple Bold or Italic.
String cleanContent(String input) {
  // 1. Remove technical placeholders
  String cleaned = input
      .replaceAll('[GRAPH_GENERATED]', '')
      .replaceAll('[IMAGE_FOUND]', '')
      .replaceAll('<u>', '')
      .replaceAll('</u>', '')
      .replaceAll(r'\n', '\n');

  // 2. Strip "Attached Document: <URL>" lines (file uploads shown via attachment card)
  cleaned = cleaned.replaceAll(
    RegExp(r'\n\nAttached Document: https?://\S+'),
    '',
  );

  // 3. Fix common AI markdown issues

  // 3a. "***Text:**" at line start → "* **Text:**" (list item + bold, not bold-italic)
  // Modified to be safer and not leave trailing stars for bold-italic scenarios
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'^(\s*)\*\*\*([^*:\n]+:)\*\*', multiLine: true),
    (m) => '${m.group(1)}* **${m.group(2)}**',
  );

  // 3b. Ensure blank line before headings (e.g. "some text### Heading" → "some text\n\n### Heading")
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'([^\n])(#{1,6}\s)'),
    (m) => '${m.group(1)}\n\n${m.group(2)}',
  );

  // 3c. Ensure blank line after heading line (e.g. "### Heading\nText" → "### Heading\n\nText")
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'^(#{1,6}\s+.+)\n(?!\n|#|\s*$)', multiLine: true),
    (m) => '${m.group(1)}\n\n',
  );

  // 3d. Ensure blank line BEFORE tables, lists, and horizontal rules
  // Many LLMs forget to add a blank line, causing flutter_markdown to fail block rendering.
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'([^\n])\n(\s*(?:\||[\-\*]\s|\d+\.\s|---))', multiLine: true),
    (m) => '${m.group(1)}\n\n${m.group(2)}',
  );

  // 4. Convert raw image/graph links to markdown images if missing '!'
  //    Pattern matches [description](url) where url ends with common image extensions or contains 'plot.png'
  //    Updated to be non-greedy and handle query tokens better.
  final imageLinkRegex = RegExp(
    r'(?<!\!)\[([^\]]*)\]\((https?://[^)]+?\.(?:png|jpg|jpeg|gif|webp|svg)(?:\?[^)]*)?|https?://[^)]+plot\.png[^)]*)\)',
    caseSensitive: false,
  );

  cleaned = cleaned.replaceAllMapped(imageLinkRegex, (match) {
    final description = match.group(1) ?? 'Image';
    final url = match.group(2)!;
    return '![$description]($url)';
  });

  return cleaned.trim();
}

/// Extract the URL from an "Attached Document: ..." suffix in message text.
/// Returns null if the pattern is not found.
String? extractAttachedDocumentUrl(String text) {
  final match = RegExp(r'Attached Document: (https?://\S+)').firstMatch(text);
  return match?.group(1);
}
