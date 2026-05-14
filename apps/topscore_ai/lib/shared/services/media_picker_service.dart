import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/painting.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// Maximum total file size allowed across all attachments (30 MB).
const int kMaxTotalUploadBytes = 30 * 1024 * 1024;

/// Thrown when the user's selected files exceed [kMaxTotalUploadBytes].
class FileSizeLimitException implements Exception {
  final int totalBytes;
  FileSizeLimitException(this.totalBytes);

  String get humanReadableLimit =>
      '${(kMaxTotalUploadBytes / (1024 * 1024)).round()} MB';
  String get humanReadableActual =>
      '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  String toString() =>
      'Selected files total $humanReadableActual, which exceeds the $humanReadableLimit limit.';
}

/// Result from media picking operations
class MediaPickResult {
  final Uint8List? bytes;
  final String name;
  final String extension;
  final String? filePath;
  final String mimeType;

  MediaPickResult({
    this.bytes,
    required this.name,
    required this.extension,
    this.filePath,
    required this.mimeType,
  });

  String? get base64Data => bytes != null ? base64Encode(bytes!) : null;
  String? get dataUri =>
      bytes != null ? 'data:$mimeType;base64,${base64Encode(bytes!)}' : null;
}

/// Shared media picker service for images and files
class MediaPickerService {
  static final MediaPickerService instance = MediaPickerService._();
  MediaPickerService._();

  final ImagePicker _imagePicker = ImagePicker();

  void _clearMemory() {
    if (!kIsWeb) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  }

  Future<List<MediaPickResult>> pickImages({
    ImageSource source = ImageSource.gallery,
    bool allowMultiple = false,
  }) async {
    _clearMemory();
    try {
      if (allowMultiple && source == ImageSource.gallery) {
        final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
          imageQuality: 85,
        );

        List<MediaPickResult> results = [];
        for (var file in pickedFiles) {
          final res = await _processXFile(file);
          if (res != null) results.add(res);
        }

        // Enforce 30 MB total size limit across all selected images
        final totalBytes = results.fold<int>(
            0, (sum, r) => sum + (r.bytes?.length ?? 0));
        if (totalBytes > kMaxTotalUploadBytes) {
          throw FileSizeLimitException(totalBytes);
        }

        return results;
      } else {
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: source,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          final res = await _processXFile(pickedFile);
          if (res != null) {
            final size = res.bytes?.length ?? 0;
            if (size > kMaxTotalUploadBytes) {
              throw FileSizeLimitException(size);
            }
            return [res];
          }
        }
      }
    } catch (e) {
      developer.log('Error picking image: $e',
          name: 'MediaPickerService', level: 900);
    }
    return [];
  }

  Future<List<MediaPickResult>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData =
        false, // Allow forcing data load on mobile (e.g. for AI tools)
  }) async {
    _clearMemory();
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        // Always load bytes on Android: the activity can be killed while the
        // system file picker is open, and the temp file path becomes invalid
        // after relaunch. Bytes survive in memory and are returned via
        // FilePicker's own lost-data mechanism.
        withData: kIsWeb ||
            withData ||
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android),
        allowMultiple: allowMultiple,
      );

      if (result != null) {
        List<MediaPickResult> results = [];
        for (var file in result.files) {
          final extension = file.extension?.toLowerCase() ?? '';
          final mimeType = _getMimeType(extension);

          results.add(MediaPickResult(
            bytes: file.bytes,
            name: file.name,
            extension: extension,
            filePath: file.path,
            mimeType: mimeType,
          ));
        }

        // Enforce 30 MB total size limit across all selected files
        final totalBytes = results.fold<int>(
            0, (sum, r) => sum + (r.bytes?.length ?? 0));
        if (totalBytes > kMaxTotalUploadBytes) {
          throw FileSizeLimitException(totalBytes);
        }

        return results;
      }
    } catch (e) {
      developer.log('Error picking file: $e',
          name: 'MediaPickerService', level: 900);
    }
    return [];
  }

  Future<MediaPickResult?> _processXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final extension = file.path.split('.').last.toLowerCase();
    final mimeType = 'image/${extension == 'jpg' ? 'jpeg' : extension}';

    return MediaPickResult(
      bytes: bytes,
      name: file.name,
      extension: extension,
      filePath: file.path,
      mimeType: mimeType,
    );
  }

  String _getMimeType(String extension) {
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'md':
        return 'text/markdown';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
