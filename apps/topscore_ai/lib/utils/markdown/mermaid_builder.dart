import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../widgets/interactive_mermaid_viewer.dart';

class MermaidElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    if (text.isEmpty) return null;

    final encoded = base64Encode(utf8.encode(text));
    final imageUrl = 'https://mermaid.ink/img/$encoded?bgColor=white';

    return InteractiveMermaidViewer(
      imageUrl: imageUrl,
      diagramSource: text,
    );
  }
}

class MermaidBlockSyntax extends md.BlockSyntax {
  @override
  md.Node parse(md.BlockParser parser) {
    // Determine the content logic
    // content should be everything between the fences
    // parser.details.lines includes the fences in some versions, but standard BlockSyntax might require handling.
    // However, for FencedCodeBlock, it's usually handled by the parser.
    // We want to capture the content.
    // Let's rely on standard current line consumption.

    // Actually, simpler implementation for a known block structure:
    var linesToConsume = <String>[];
    // consumed first line by pattern match
    parser.advance();

    while (!parser.isDone) {
      if (parser.current.content.startsWith('```')) {
        parser.advance();
        break;
      }
      linesToConsume.add(parser.current.content);
      parser.advance();
    }

    final content = linesToConsume.join('\n');
    return md.Element('mermaid', [md.Text(content)]);
  }

  @override
  RegExp get pattern => RegExp(r'^`{3,}\s?mermaid\s*$', multiLine: true);
}
