/// Pre-processor to clean and normalize markdown content before rendering.
String cleanContent(String input) {
  String cleaned = input;

  // 0. Normalize CRLF/CR to LF so line-anchored regexes work consistently.
  // Windows-origin content and some streaming sources mix endings.
  cleaned = cleaned.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // 1. Remove technical placeholders
  cleaned = cleaned
      .replaceAll('[GRAPH_GENERATED]', '')
      .replaceAll('[IMAGE_FOUND]', '');

  // Strip fallback parser data blocks (Quiz, Flashcards, Mnemonic, Punnett Square)
  cleaned = cleaned
      .replaceAll(RegExp(r'\[QUIZ_DATA\]\([\s\S]*?(\)|$)'), '')
      .replaceAll(RegExp(r'\[FLASHCARDS_DATA\]\([\s\S]*?(\)|$)'), '')
      .replaceAll(RegExp(r'\[MNEMONIC_DATA\]\([\s\S]*?(\)|$)'), '')
      .replaceAll(RegExp(r'\[PUNNETT_SQUARE\]\([\s\S]*?(\)|$)'), '');

  // Strip HTML underline tags (not supported by gpt_markdown)
  cleaned = cleaned.replaceAll('<u>', '').replaceAll('</u>', '');

  // Replace literal "\n" escape sequences with real newlines — but only when
  // they appear as standalone escape sequences, NOT inside LaTeX commands
  // (e.g. \nabla, \nu, \neg must not be touched).
  // Strategy: only replace \n when preceded by a non-backslash non-letter char
  // or at the start of the string.
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'(?<![a-zA-Z])\\n'),
    (_) => '\n',
  );

  // 2. Strip "Attached Document: <URL>" lines
  cleaned = cleaned.replaceAll(
    RegExp(r'\n\nAttached Document: https?://\S+'),
    '',
  );

  // 3a. Fix "***Text:**" at line start only (bold-italic list item confusion).
  // Only fires when the pattern is at the very start of a line followed by
  // a colon — avoids touching mid-sentence bold-italic like ***word***.
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'^(\s*)\*\*\*([^*\n]+:)\*\*\s*$', multiLine: true),
    (m) => '${m.group(1)}* **${m.group(2)}**',
  );

  // 3b. Ensure ATX headings are surrounded by blank lines — gpt_markdown (and
  // CommonMark) require a blank line before a heading, otherwise it renders
  // as a literal "# Heading". The backend occasionally emits headings right
  // after a prose line or a stripped widget block, so we reflow them here.
  //
  // A heading line = start-of-line, 1-6 # chars, a space, then content.
  // We match each heading with optional leading/trailing single newline and
  // re-emit it with blank lines on both sides. The lookbehind/ahead for
  // `\n\n` prevents re-inserting blank lines that are already present.
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'(?<!\n)\n(#{1,6} [^\n]+)', multiLine: true),
    (m) => '\n\n${m.group(1)}',
  );
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'^(#{1,6} [^\n]+)\n(?!\n)', multiLine: true),
    (m) => '${m.group(1)}\n\n',
  );

  // 3d. Ensure blank line before Markdown tables (pipe at line start).
  // Deliberately NOT adding blank lines before list items here — that was
  // too aggressive and broke inline dashes like "e.g. - something".
  cleaned = cleaned.replaceAllMapped(
    RegExp(r'([^\n])\n(\|)', multiLine: true),
    (m) => '${m.group(1)}\n\n${m.group(2)}',
  );

  // 4. Convert raw image/graph links to markdown images if missing '!'
  cleaned = cleaned.replaceAllMapped(
    RegExp(
      r'(?<!\!)\[([^\]]*)\]\((https?://[^)]+?\.(?:png|jpg|jpeg|gif|webp|svg)(?:\?[^)]*)?|https?://[^)]+plot\.png[^)]*)\)',
      caseSensitive: false,
    ),
    (match) => '![${match.group(1) ?? 'Image'}](${match.group(2)!})',
  );

  return cleaned.trim();
}

/// Extract the URL from an "Attached Document: ..." suffix in message text.
String? extractAttachedDocumentUrl(String text) {
  final match = RegExp(r'Attached Document: (https?://\S+)').firstMatch(text);
  return match?.group(1);
}
