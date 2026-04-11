import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../widgets/interactive_desmos_graph.dart';

class InteractiveGraphElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    if (text.isEmpty) return null;

    try {
      final config = jsonDecode(text);
      return InteractiveDesmosGraph(config: config);
    } catch (e) {
      return const SizedBox.shrink();
    }
  }
}

class InteractiveGraphSyntax extends md.InlineSyntax {
  // Matches [INTERACTIVE_GRAPH_CONFIG]({"type": "desmos_config", ...})
  InteractiveGraphSyntax() : super(r'\[INTERACTIVE_GRAPH_CONFIG\]\((.*?)\)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final content = match.group(1);
    if (content == null) return false;

    final element = md.Element('interactive-graph', [md.Text(content)]);
    parser.addNode(element);
    return true;
  }
}
