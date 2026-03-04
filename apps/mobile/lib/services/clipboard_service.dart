import 'dart:developer' as developer;
import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Detected content type from clipboard or text analysis.
enum ClipboardContentType {
  plainText,
  code,
  markdown,
  url,
  image,
  empty,
}

/// Result of reading from the clipboard.
class ClipboardReadResult {
  final ClipboardContentType type;
  final String? text;
  final Uint8List? imageBytes;

  const ClipboardReadResult({
    required this.type,
    this.text,
    this.imageBytes,
  });

  bool get hasContent => type != ClipboardContentType.empty;
  bool get hasImage => imageBytes != null && imageBytes!.isNotEmpty;
  bool get hasText => text != null && text!.isNotEmpty;
}

/// Cross-platform clipboard service with smart content detection.
///
/// Handles text, images, code, URLs, and markdown across
/// Web, iOS, Android, Windows, macOS, and Linux.
class ClipboardService {
  ClipboardService._();
  static final ClipboardService instance = ClipboardService._();

  // ---------------------------------------------------------------------------
  // COPY — write to clipboard
  // ---------------------------------------------------------------------------

  /// Copy plain text to the system clipboard.
  Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Copy text and show a themed snackbar with content-aware feedback.
  void copyWithFeedback(BuildContext context, String text) {
    final type = detectContentType(text);
    copyText(text);
    HapticFeedback.lightImpact();

    final (icon, label) = switch (type) {
      ClipboardContentType.code => (Icons.code_rounded, 'Code copied'),
      ClipboardContentType.url => (Icons.link_rounded, 'Link copied'),
      ClipboardContentType.markdown => (Icons.content_copy_rounded, 'Copied to clipboard'),
      _ => (Icons.check_rounded, 'Copied to clipboard'),
    };

    _showFeedbackSnackbar(context, icon, label);
  }

  /// Copy an image to the system clipboard (mobile/desktop only).
  Future<bool> copyImage(Uint8List imageBytes) async {
    if (kIsWeb) return false;
    try {
      await Pasteboard.writeImage(imageBytes);
      return true;
    } catch (e) {
      developer.log('ClipboardService.copyImage error: $e', name: 'Clipboard');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // PASTE — read from clipboard
  // ---------------------------------------------------------------------------

  /// Read the clipboard and auto-detect what's in it.
  ///
  /// Checks for images first (mobile/desktop), then falls back to text.
  /// Returns a [ClipboardReadResult] with the detected type and content.
  Future<ClipboardReadResult> readClipboard() async {
    try {
      // 1. Try image first (mobile/desktop only)
      if (!kIsWeb) {
        final imageBytes = await _tryReadImage();
        if (imageBytes != null) {
          return ClipboardReadResult(
            type: ClipboardContentType.image,
            imageBytes: imageBytes,
          );
        }
      }

      // 2. Try text
      final cbd = await Clipboard.getData(Clipboard.kTextPlain);
      if (cbd != null && cbd.text != null && cbd.text!.isNotEmpty) {
        final text = cbd.text!;
        final type = detectContentType(text);
        return ClipboardReadResult(type: type, text: text);
      }

      return const ClipboardReadResult(type: ClipboardContentType.empty);
    } catch (e) {
      developer.log('ClipboardService.readClipboard error: $e',
          name: 'Clipboard');
      return const ClipboardReadResult(type: ClipboardContentType.empty);
    }
  }

  /// Try to read an image from the clipboard. Returns null if no image found
  /// or if the data looks like HTML rather than a real image.
  Future<Uint8List?> _tryReadImage() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes == null || imageBytes.isEmpty) return null;

      // Guard: reject HTML content masquerading as image (starts with '<')
      if (imageBytes.length > 4 && imageBytes[0] == 0x3c) return null;

      return imageBytes;
    } catch (e) {
      developer.log('ClipboardService._tryReadImage error: $e',
          name: 'Clipboard');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PASTE INTO TEXT FIELD — insert at cursor position
  // ---------------------------------------------------------------------------

  /// Paste text into a [TextEditingController] at the current cursor position,
  /// replacing any selected text.
  void pasteIntoController(TextEditingController controller, String text) {
    final selection = controller.selection;
    final start = selection.start < 0 ? controller.text.length : selection.start;
    final end = selection.end < 0 ? start : selection.end;

    final newText = controller.text.replaceRange(start, end, text);
    final newOffset = start + text.length;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  // ---------------------------------------------------------------------------
  // SHARE — cross-platform sharing
  // ---------------------------------------------------------------------------

  /// Share text using the platform share sheet.
  void shareText(String text) {
    SharePlus.instance.share(ShareParams(text: text));
  }

  /// Share a message with a subject line.
  void shareTextWithSubject(String text, String subject) {
    SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  /// Download an image from [url] and share it via the platform share sheet.
  /// On web, opens the URL in a new tab instead.
  Future<void> shareImage(
    BuildContext context,
    String url, {
    String caption = 'Image from TopScore AI',
  }) async {
    try {
      if (kIsWeb) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        return;
      }

      _showFeedbackSnackbar(
        context,
        Icons.download_rounded,
        'Downloading image...',
        duration: const Duration(seconds: 1),
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Download failed');

      final tempDir = await getTemporaryDirectory();
      final fileName = 'topscore_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: caption),
      );
    } catch (e) {
      developer.log('ClipboardService.shareImage error: $e',
          name: 'Clipboard');
      if (context.mounted) {
        _showFeedbackSnackbar(
          context,
          Icons.error_outline_rounded,
          'Failed to download image',
          isError: true,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // CONTENT DETECTION
  // ---------------------------------------------------------------------------

  /// Analyze text to determine its content type.
  static ClipboardContentType detectContentType(String text) {
    if (text.isEmpty) return ClipboardContentType.empty;

    final trimmed = text.trim();

    // URL detection
    if (_isUrl(trimmed)) return ClipboardContentType.url;

    // Code detection — look for common code patterns
    if (_isCode(trimmed)) return ClipboardContentType.code;

    // Markdown detection — headings, bold, lists, links
    if (_isMarkdown(trimmed)) return ClipboardContentType.markdown;

    return ClipboardContentType.plainText;
  }

  static bool _isUrl(String text) {
    // Single-line URLs
    if (text.contains('\n')) return false;
    final urlPattern = RegExp(
      r'^https?://[^\s]+$',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(text);
  }

  static bool _isCode(String text) {
    // Fenced code blocks
    if (text.contains('```')) return true;

    final lines = text.split('\n');
    if (lines.length < 2) return false;

    // Common code indicators
    final codePatterns = [
      RegExp(r'^\s*(import |from |require\(|#include|using )'),
      RegExp(r'^\s*(def |fn |func |function |class |interface |struct )'),
      RegExp(r'^\s*(const |let |var |final |static )'),
      RegExp(r'[{};]\s*$'),
      RegExp(r'=>\s*[{(]'),
      RegExp(r'^\s*(if|for|while|switch)\s*\('),
    ];

    int codeLineCount = 0;
    for (final line in lines) {
      for (final pattern in codePatterns) {
        if (pattern.hasMatch(line)) {
          codeLineCount++;
          break;
        }
      }
    }

    // If >30% of lines look like code, call it code
    return codeLineCount > lines.length * 0.3;
  }

  static bool _isMarkdown(String text) {
    final mdPatterns = [
      RegExp(r'^#{1,6}\s+', multiLine: true),       // headings
      RegExp(r'\*\*[^*]+\*\*'),                       // bold
      RegExp(r'\[[^\]]+\]\([^)]+\)'),                 // links
      RegExp(r'^[-*+]\s+', multiLine: true),          // unordered lists
      RegExp(r'^\d+\.\s+', multiLine: true),          // ordered lists
      RegExp(r'^>\s+', multiLine: true),              // blockquotes
    ];

    int matches = 0;
    for (final pattern in mdPatterns) {
      if (pattern.hasMatch(text)) matches++;
    }
    return matches >= 2;
  }

  // ---------------------------------------------------------------------------
  // KEYBOARD SHORTCUT HELPERS
  // ---------------------------------------------------------------------------

  /// Whether the current platform uses Cmd (macOS) or Ctrl for shortcuts.
  static bool get usesMetaKey {
    if (kIsWeb) return false; // Web handles its own shortcuts
    try {
      return Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  /// Get the platform-appropriate copy shortcut label (e.g., "Cmd+C" or "Ctrl+C").
  static String get copyShortcutLabel => usesMetaKey ? '⌘C' : 'Ctrl+C';

  /// Get the platform-appropriate paste shortcut label.
  static String get pasteShortcutLabel => usesMetaKey ? '⌘V' : 'Ctrl+V';

  // ---------------------------------------------------------------------------
  // UI FEEDBACK
  // ---------------------------------------------------------------------------

  void _showFeedbackSnackbar(
    BuildContext context,
    IconData icon,
    String label, {
    Duration duration = const Duration(seconds: 2),
    bool isError = false,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: duration,
        backgroundColor: isError ? const Color(0xFFEF4444) : null,
      ),
    );
  }
}
