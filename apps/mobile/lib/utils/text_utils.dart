/// Strips common markdown formatting from a string, returning plain text.
/// Used for displaying AI-generated titles and chat content in plain UI contexts.
String stripMarkdown(String text) {
  return text
      .replaceAll(RegExp(r'\*\*\*([^*]+)\*\*\*'), r'$1') // ***bold italic***
      .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')     // **bold**
      .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1')          // *italic*
      .replaceAll(RegExp(r'__([^_]+)__'), r'$1')           // __underline__
      .replaceAll(RegExp(r'_([^_]+)_'), r'$1')            // _italic_
      .replaceAll(RegExp(r'`([^`]+)`'), r'$1')            // `code`
      .replaceAll(RegExp(r'~~([^~]+)~~'), r'$1')          // ~~strikethrough~~
      .replaceAll(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), r'$1') // [text](url)
      .replaceAll(RegExp(r'\[([^\]]*)\]\[[^\]]*\]'), r'$1')  // [text][ref]
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '') // # headers
      .replaceAll(RegExp(r'^[-*]\s+', multiLine: true), '')   // - lists
      .replaceAll(RegExp(r'^\d+\.\s+', multiLine: true), '')  // 1. lists
      .replaceAll(RegExp(r'\n{2,}'), ' ')                     // collapse newlines
      .trim();
}

/// Formats the AI response by removing technical metadata tags, fixing common 
/// rendering issues, and cleaning up internal model thoughts/reasoning.
String postFormatAIResponse(String text) {
  if (text.isEmpty) return text;

  String formatted = text;

  // 1. Hide Technical Metadata Tags (Internal artifact triggers)
  final List<String> metadataPatterns = [
    r'\[INTERACTIVE_GRAPH_CONFIG\]\([^)]*\)',
    r'\[QUIZ_DATA\]\([^)]*\)',
    r'\[FLASHCARDS_DATA\]\([^)]*\)',
    r'\[MNEMONIC_DATA\]\([^)]*\)',
    r'\[GRAPH_DATA\]\([^)]*\)',
    r'\[PLOT_DATA\]\([^)]*\)',
    r'\[TABLE_DATA\]\([^)]*\)',
    r'\[SEARCH_QUERY\]\([^)]*\)',
  ];

  for (final pattern in metadataPatterns) {
    formatted = formatted.replaceAll(RegExp(pattern), '');
  }

  // 2. Hide Thinking/Reasoning tags (if they are in the main text stream)
  formatted = formatted.replaceAll(RegExp(r'<thought>[\s\S]*?<\/thought>'), '');
  formatted = formatted.replaceAll(RegExp(r'<reasoning>[\s\S]*?<\/reasoning>'), '');

  // 3. Fix Non-standard Image Markdown: ! `url` -> ![image](url)
  // This ensures the markdown renderer shows the image and hides the raw backticked text.
  formatted = formatted.replaceAllMapped(
    RegExp(r'!\s*`([^`]+)`'),
    (match) => '![image](${match.group(1)})',
  );

  // 4. Fix LaTeX/Math formatting inconsistencies
  // Ensure math blocks aren't accidentally split by extra newlines
  formatted = formatted.replaceAll(RegExp(r'\$\$\n+'), '\$\$\n');
  formatted = formatted.replaceAll(RegExp(r'\n+\$\$'), '\n\$\$');

  // 4. Ensure balanced code blocks (fixes trailing ``` if truncated)
  final codeBlockMatches = RegExp(r'```').allMatches(formatted);
  if (codeBlockMatches.length % 2 != 0) {
    formatted += '\n```';
  }

  // 5. Final cleanup: collapse excessive newlines and trim
  formatted = formatted.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  
  return formatted.trim();
}
