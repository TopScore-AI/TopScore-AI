/// Utility to strip markdown formatting from text for TTS (text-to-speech).
///
/// Converts markdown-formatted text into plain readable text so the TTS
/// engine speaks natural sentences instead of raw markdown syntax.
class MarkdownStripper {
  /// Strips all markdown formatting and returns plain text suitable for TTS.
  static String strip(String text) {
    var cleaned = text;

    // 1. Remove fenced code blocks (```lang\ncode```) entirely
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), '');

    // 2. Remove images: ![alt](url)
    cleaned = cleaned.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');

    // 3. Convert links [text](url) to just the text
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\[(.*?)\]\(.*?\)'),
      (m) => m[1] ?? '',
    );

    // 4. Remove horizontal rules (---, ***, ___)
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*([-*_])\s*(?:\1\s*){2,}$', multiLine: true),
      '',
    );

    // 5. Remove table markup
    // Strip separator lines like |---|---|
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*[:\-|\s]+$', multiLine: true),
      '',
    );
    // Strip pipe characters
    cleaned = cleaned.replaceAll('|', ' ');

    // 6. Remove header markers (#, ##, ###, etc.)
    cleaned = cleaned.replaceAll(RegExp(r'^#+\s*', multiLine: true), '');

    // 7. Remove blockquote markers (>)
    cleaned = cleaned.replaceAll(RegExp(r'^>\s*', multiLine: true), '');

    // 8. Remove task list checkboxes (- [ ], - [x])
    cleaned = cleaned.replaceAll(RegExp(r'\[[ xX]\]\s*'), '');

    // 9. Remove list bullets and numbers (-, *, +, 1.)
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*([-*+]|\d+\.)\s+', multiLine: true),
      ' ',
    );

    // 10. Remove strikethrough (~~text~~)
    cleaned = cleaned.replaceAll(RegExp(r'~~(.*?)~~'), r'$1');

    // 11. Remove bold/italic markers (**, __, *, _)
    // Bold first, then italic to avoid partial matches
    cleaned = cleaned.replaceAll(RegExp(r'(\*\*|__)(.*?)\1'), r'$2');
    cleaned = cleaned.replaceAll(RegExp(r'(\*|_)(.*?)\1'), r'$2');

    // 12. Remove inline code backticks
    cleaned = cleaned.replaceAll(RegExp(r'`([^`]*)`'), r'$1');
    cleaned = cleaned.replaceAll('`', '');

    // 13. Remove LaTeX/math delimiters ($$ and $)
    // Use regex to avoid issues with raw string escaping
    cleaned = cleaned.replaceAll(RegExp(r'\$\$'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\$'), '');

    // 14. Remove HTML tags
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]+>'), '');

    // 15. Remove footnote references ([^1])
    cleaned = cleaned.replaceAll(RegExp(r'\[\^\w+\]'), '');

    // 16. Cleanup extra whitespace and blank lines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');

    return cleaned.trim();
  }
}
