/// Strips common markdown formatting from a string, returning plain text.
/// Used for displaying AI-generated titles and chat content in plain UI contexts.
String stripMarkdown(String text) {
  if (text.isEmpty) return text;
  
  // First, remove technical metadata tags completely
  String cleaned = _removeTechnicalMetadata(text);
  
  return cleaned
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
  formatted = _removeTechnicalMetadata(formatted);

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

String _removeTechnicalMetadata(String text) {
  const tags = [
    'QUIZ_DATA',
    'FLASHCARDS_DATA',
    'MNEMONIC_DATA',
    'INTERACTIVE_GRAPH_CONFIG',
    'GRAPH_DATA',
    'PLOT_DATA',
    'TABLE_DATA',
    'SEARCH_QUERY',
    'PUNNETT_SQUARE',
    'GRAPH_GENERATED',
  ];

  String result = text;
  for (final tag in tags) {
    // 1. Robustly strip the balanced parenthesized payload
    result = stripBalancedTag(result, tag);
    // 2. Strip bare occurrences of [TAG] if left
    result = result.replaceAll('[$tag]', '');
  }

  // Image tools (wikimedia_tool, image_search_tool, serpapi_image_search_tool)
  // return confirmation strings like `[IMAGE_FOUND] ![alt](url)\n[Source: s](url)`
  // (legacy) or `[IMAGE_DELIVERED] Found image: '...'. The image has been sent...`
  // (current). If the agent echoes these into its prose, gpt_markdown can
  // mis-parse the blob as an image URL and issue a doomed request against
  // backendBaseUrl. Drop the whole line, not just the tag.
  result = result.replaceAll(
    RegExp(r'\[IMAGE_DELIVERED\][^\n]*', multiLine: true),
    '',
  );
  result = result.replaceAll(
    RegExp(r'\[IMAGE_FOUND\][^\n]*', multiLine: true),
    '',
  );

  return result;
}

/// Helper function to strip parenthesized metadata payloads by correctly 
/// tracking and matching balanced open and close parentheses. This prevents
/// leakage when parenthesized mathematical equations or text exist inside JSON strings.
String stripBalancedTag(String text, String tag) {
  String result = text;
  while (true) {
    final startTag = '[$tag](';
    final startIndex = result.indexOf(startTag);
    if (startIndex == -1) break;

    // Find the matching closing parenthesis
    final openParenIndex = startIndex + startTag.length - 1; // index of the '('
    int parenCount = 1;
    int endIndex = -1;

    for (int i = openParenIndex + 1; i < result.length; i++) {
      if (result[i] == '(') {
        parenCount++;
      } else if (result[i] == ')') {
        parenCount--;
        if (parenCount == 0) {
          endIndex = i;
          break;
        }
      }
    }

    if (endIndex != -1) {
      result = result.replaceRange(startIndex, endIndex + 1, '');
    } else {
      // Incomplete block (still streaming): strip from startTag to the end of string
      result = result.substring(0, startIndex);
      break;
    }
  }
  return result;
}

/// Extracts the contents inside the parentheses of a technical tag (e.g., [QUIZ_DATA](...))
/// by tracking and matching balanced open and close parentheses.
String? extractBalancedTagContent(String text, String tag) {
  final startTag = '[$tag](';
  final startIndex = text.indexOf(startTag);
  if (startIndex == -1) return null;

  final openParenIndex = startIndex + startTag.length - 1; // index of the '('
  int parenCount = 1;
  int endIndex = -1;

  for (int i = openParenIndex + 1; i < text.length; i++) {
    if (text[i] == '(') {
      parenCount++;
    } else if (text[i] == ')') {
      parenCount--;
      if (parenCount == 0) {
        endIndex = i;
        break;
      }
    }
  }

  if (endIndex != -1) {
    return text.substring(openParenIndex + 1, endIndex);
  } else {
    // Incomplete block (still streaming): return whatever we have inside so far
    return text.substring(openParenIndex + 1);
  }
}
