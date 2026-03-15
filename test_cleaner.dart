
import 'dart:core';

class MarkdownStripper {
  static String strip(String text) {
    return text.trim();
  }

  static String cleanTitle(String? title) {
    if (title == null || title.isEmpty) return 'New Chat';
    
    // Strip markdown first (simulated)
    final stripped = strip(title);
    
    // Clean up invisible characters and normalize
    final normalized = stripped.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '').trim();
    
    // Improved: Remove all non-alphanumeric for a final sanity check
    final alphanumericOnly = normalized.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    
    if (normalized.isEmpty ||
        normalized.toLowerCase() == 'none' ||
        RegExp(r'^\d+$').hasMatch(alphanumericOnly) ||
        normalized.length < 2) {
      return 'New Chat';
    }
    
    return normalized;
  }
}

void main() {
  print('Result for "2": ${MarkdownStripper.cleanTitle("2")}');
  print('Result for "2.": ${MarkdownStripper.cleanTitle("2.")}');
  print('Result for "Title: 2": ${MarkdownStripper.cleanTitle("Title: 2")}');
  print('Result for "None": ${MarkdownStripper.cleanTitle("None")}');
  print('Result for "": ${MarkdownStripper.cleanTitle("")}');
  print('Result for "Valid Title": ${MarkdownStripper.cleanTitle("Valid Title")}');
  print('Result for "2nd Chat": ${MarkdownStripper.cleanTitle("2nd Chat")}'); // Should be valid
}
