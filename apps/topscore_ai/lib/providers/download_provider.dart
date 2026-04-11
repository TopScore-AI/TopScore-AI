import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/download_service.dart';
import '../models/download_model.dart';
import '../models/resource_model.dart';
import '../main.dart'; // To access studyDb

class DownloadProvider with ChangeNotifier {
  final DownloadService _downloadService = DownloadService();

  List<DownloadTaskModel> _downloads = [];
  bool _isLoading = false;
  final Map<String, double> _downloadProgress = {};

  List<DownloadTaskModel> get downloads => _downloads;
  bool get isLoading => _isLoading;
  Map<String, double> get downloadProgress => _downloadProgress;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    _downloads = await _downloadService.listDownloads();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> downloadResource(ResourceModel resource) async {
    await downloadGenericFile(
      id: resource.id,
      title: resource.title,
      downloadUrl: resource.downloadUrl,
    );
  }

  Future<void> downloadGenericFile({
    required String id,
    required String title,
    required String downloadUrl,
  }) async {
    _downloadProgress[id] = 0.0;
    notifyListeners();

    try {
      final localPath = await _downloadService.downloadFile(
        id: id,
        title: title,
        downloadUrl: downloadUrl,
        onProgress: (progress) {
          _downloadProgress[id] = progress;
          notifyListeners();
        },
      );

      // Save to studyDb for the "Offline/Saved" section of MyStuffScreen
      if (localPath.isNotEmpty && localPath != 'web_download_triggered') {
        await studyDb.saveMaterial(
          type: 'pdf',
          topic: title,
          curriculum: 'Downloaded',
          grade: 'Offline',
          jsonData: jsonEncode({'localPath': localPath}),
        );
      }

      // Refresh list after download
      _downloads = await _downloadService.listDownloads();
      _downloadProgress.remove(id);
    } catch (e) {
      if (kDebugMode) debugPrint("Download error: $e");
      _downloadProgress.remove(id);
    } finally {
      notifyListeners();
    }
  }

  Future<void> deleteDownload(String id) async {
    await _downloadService.deleteDownload(id);
    _downloads = await _downloadService.listDownloads();
    notifyListeners();
  }

  bool isDownloaded(String resourceId) {
    return _downloads.any((task) => task.resourceId == resourceId);
  }

  bool isDownloading(String resourceId) {
    return _downloadProgress.containsKey(resourceId);
  }

  double getProgress(String resourceId) {
    return _downloadProgress[resourceId] ?? 0.0;
  }
}

