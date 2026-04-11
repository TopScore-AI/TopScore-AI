import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

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
  String? get dataUri => bytes != null ? 'data:$mimeType;base64,${base64Encode(bytes!)}' : null;
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
        return results;
      } else {
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: source,
          preferredCameraDevice: CameraDevice.rear,
          imageQuality: 85,
        );

        if (pickedFile != null) {
          final res = await _processXFile(pickedFile);
          return res != null ? [res] : [];
        }
      }
    } catch (e) {
      developer.log('Error picking image: $e', name: 'MediaPickerService', level: 900);
    }
    return [];
  }

  Future<List<MediaPickResult>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = false, // Allow forcing data load on mobile (e.g. for AI tools)
  }) async {
    _clearMemory();
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        withData: kIsWeb || withData, 
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
        return results;
      }
    } catch (e) {
      developer.log('Error picking file: $e', name: 'MediaPickerService', level: 900);
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
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt': return 'text/plain';
      case 'csv': return 'text/csv';
      case 'md': return 'text/markdown';
      case 'png': return 'image/png';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      default: return 'application/octet-stream';
    }
  }
}
