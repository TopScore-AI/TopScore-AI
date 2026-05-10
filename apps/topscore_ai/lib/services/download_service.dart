import 'dart:async';
import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/web_download_helper.dart';
import '../models/resource_model.dart';
import '../models/download_model.dart';
import 'notification_service.dart';

class DownloadService {
  static const String _storageKey = 'elimu_downloads';

  Future<String> get _localPath async {
    if (kIsWeb) return '';

    // Use app-specific storage on every platform. On Android this is
    // /Android/data/<pkg>/files, which requires no permission on any API
    // level and survives app upgrades. Users access the files through the
    // in-app Downloads list.
    Directory? directory;
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }

    final elimuDir = Directory('${directory.path}/TopScoreAI');
    if (!await elimuDir.exists()) {
      await elimuDir.create(recursive: true);
    }
    return elimuDir.path;
  }

  Future<String> downloadResource(
    ResourceModel resource,
    Function(double) onProgress,
  ) async {
    return downloadFile(
      id: resource.id,
      title: resource.title,
      downloadUrl: resource.downloadUrl,
      onProgress: onProgress,
    );
  }

  Future<String> downloadFile({
    required String id,
    required String title,
    required String downloadUrl,
    required Function(double) onProgress,
  }) async {
    if (kIsWeb) {
      final processedUrl = _processUrl(downloadUrl);
      try {
        final response = await http.get(Uri.parse(processedUrl)).timeout(const Duration(seconds: 60));
        if (response.statusCode == 200) {
          final fileName = '${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
          WebDownloadHelper.downloadBytes(response.bodyBytes, fileName);
          return 'web_download_triggered';
        }
      } catch (e) {
        // Fallback to opening link if CORS or other issues occur
        await launchUrl(Uri.parse(processedUrl), mode: LaunchMode.externalApplication);
      }
      return 'web_download_triggered';
    }

    final path = await _localPath;
    final processedUrl = _processUrl(downloadUrl);

    String extension = 'pdf';
    final uri = Uri.parse(processedUrl);
    if (uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last;
      if (lastSegment.contains('.')) {
        extension = lastSegment.split('.').last;
      }
    }

    final filename = '${title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.$extension';
    final file = File('$path/$filename');

    // 1. Firebase Storage Optimization (Highly Robust)
    if (_isFirebaseStorageUrl(processedUrl)) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(processedUrl);
        final downloadTask = ref.writeToFile(file);

        final completer = Completer<String>();
        
        downloadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress);
          }
        }, onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        });

        await downloadTask;
        
        final task = DownloadTaskModel(
          id: id,
          resourceId: id,
          localPath: file.path,
          downloadedAt: DateTime.now().millisecondsSinceEpoch,
          filename: filename,
        );
        await _saveDownloadRecord(task);
        
        await NotificationService().showNotification(
          title: 'Download Complete',
          body: 'Finished downloading $title',
          payload: file.path,
        );

        return file.path;
      } catch (e) {
        if (kDebugMode) debugPrint("[TOPSCORE] Firebase SDK download failed, falling back to HTTP: $e");
        // Continue to HTTP fallback
      }
    }

    // 2. HTTP Streaming Fallback
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(processedUrl));
      final response = await client.send(request).timeout(const Duration(seconds: 120));
      final contentLength = response.contentLength ?? 0;

      if (response.statusCode != 200) {
        throw Exception('Server returned status code ${response.statusCode}');
      }

      final IOSink sink = file.openWrite();
      double received = 0;
      double lastReportedProgress = 0;

      try {
        await for (final List<int> chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          
          if (contentLength > 0) {
            final progress = received / contentLength;
            if (progress - lastReportedProgress > 0.01 || progress == 1.0) {
              onProgress(progress);
              lastReportedProgress = progress;
            }
          } else {
            // Indeterminate progress: report received MBs or fake progress
            // For now, just report 0.05 increments to show activity
            final fakeProgress = (received / (5 * 1024 * 1024)).clamp(0.0, 0.95);
            if (fakeProgress - lastReportedProgress > 0.05) {
              onProgress(fakeProgress);
              lastReportedProgress = fakeProgress;
            }
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      final task = DownloadTaskModel(
        id: id,
        resourceId: id,
        localPath: file.path,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
        filename: filename,
      );
      await _saveDownloadRecord(task);
      
      await NotificationService().showNotification(
        title: 'Download Complete',
        body: 'Finished downloading $title',
        payload: file.path,
      );

      return file.path;
    } finally {
      client.close();
    }
  }


  String _processUrl(String url) {
    // Convert Google Drive View URLs to Download URLs
    // Example: https://drive.google.com/file/d/1234567890abcdef/view?usp=sharing
    // Becomes: https://drive.google.com/uc?export=download&id=1234567890abcdef
    if (url.contains('drive.google.com') &&
        (url.contains('/view') || url.contains('/file/d/'))) {
      try {
        final id = url.split('/d/')[1].split('/')[0];
        return 'https://drive.google.com/uc?export=download&id=$id';
      } catch (e) {
        return url;
      }
    }
    return url;
  }

  bool _isFirebaseStorageUrl(String url) {
    if (url.contains('firebasestorage.googleapis.com')) return true;
    if (url.contains('storage.googleapis.com')) {
      if (url.contains('firebasestorage.app')) return true;
      if (url.contains('elimisha-90787')) return true;
    }
    if (url.startsWith('gs://')) return true;
    return false;
  }

  Future<void> _saveDownloadRecord(DownloadTaskModel task) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> downloads = prefs.getStringList(_storageKey) ?? [];

    // Remove existing if any
    downloads.removeWhere((item) {
      final t = DownloadTaskModel.fromJson(jsonDecode(item));
      return t.id == task.id;
    });

    downloads.add(jsonEncode(task.toJson()));
    await prefs.setStringList(_storageKey, downloads);
  }

  Future<List<DownloadTaskModel>> listDownloads() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> downloads = prefs.getStringList(_storageKey) ?? [];
    return downloads
        .map((item) => DownloadTaskModel.fromJson(jsonDecode(item)))
        .toList();
  }

  Future<void> deleteDownload(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> downloads = prefs.getStringList(_storageKey) ?? [];

    DownloadTaskModel? taskToDelete;
    downloads.removeWhere((item) {
      final t = DownloadTaskModel.fromJson(jsonDecode(item));
      if (t.id == id) {
        taskToDelete = t;
        return true;
      }
      return false;
    });

    if (taskToDelete != null) {
      final file = File(taskToDelete!.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await prefs.setStringList(_storageKey, downloads);
  }

  Future<bool> isDownloaded(String id) async {
    final downloads = await listDownloads();
    return downloads.any((d) => d.id == id);
  }
}
