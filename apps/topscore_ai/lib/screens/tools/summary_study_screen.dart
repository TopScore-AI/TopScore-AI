import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/math_markdown.dart';
import '../../utils/markdown/mermaid_builder.dart';

class SummaryStudyScreen extends StatelessWidget {
  final String topic;
  final String markdownContent;

  const SummaryStudyScreen({
    super.key,
    required this.topic,
    required this.markdownContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Executive Summary",
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              topic,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 24),
            MarkdownBody(
              data: markdownContent,
              selectable: true,
              builders: {
                'latex': LatexElementBuilder(),
                'mermaid': MermaidElementBuilder(),
              },
              extensionSet: markdown.ExtensionSet(
                [
                  ...markdown.ExtensionSet.gitHubFlavored.blockSyntaxes,
                  MermaidBlockSyntax()
                ],
                [
                  markdown.EmojiSyntax(),
                  LatexSyntax(),
                  ...markdown.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                ],
              ),
              styleSheet: MarkdownStyleSheet(
                p: GoogleFonts.inter(fontSize: 16, height: 1.6, color: const Color(0xFF334155)),
                h1: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B), height: 2),
                h2: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF2563EB), height: 1.8),
                h3: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B), height: 1.6),
                listBullet: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF2563EB)),
                blockquote: GoogleFonts.inter(color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                blockquoteDecoration: BoxDecoration(
                  border: const Border(left: BorderSide(color: Color(0xFFCBD5E1), width: 4)),
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
