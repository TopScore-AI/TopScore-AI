import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class VideoPlayerScreen extends StatefulWidget {
  final String? videoUrl;
  final File? videoFile;
  final String title;

  const VideoPlayerScreen({
    super.key,
    this.videoUrl,
    this.videoFile,
    required this.title,
  }) : assert(videoUrl != null || videoFile != null, "Provide a URL or a File");

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }


  Future<void> _initializePlayer() async {
    final theme = Theme.of(context);
    try {
      if (widget.videoFile != null) {
        _videoController = VideoPlayerController.file(widget.videoFile!);
      } else {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl!),
        );
      }

      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoController.value.aspectRatio,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        showOptions: false,
        placeholder: Center(
          child: CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary)),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                    _initializePlayer();
                  },
                  child: const Text('Retry'),
                )
              ],
            ),
          );
        },
        materialProgressColors: ChewieProgressColors(
          playedColor: theme.colorScheme.primary,
          handleColor: theme.colorScheme.primary,
          backgroundColor: Colors.grey.withValues(alpha: 0.5),
          bufferedColor: Colors.white24,
        ),
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: theme.colorScheme.primary,
          handleColor: theme.colorScheme.primary,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white24,
        ),
      );

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Could not play video: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadAndShare() async {
    if (widget.videoFile != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(widget.videoFile!.path)],
          subject: 'Sharing ${widget.title}',
        ),
      );
      return;
    }

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Download not supported on Web yet")),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Downloading video...")),
      );

      final response = await http.get(Uri.parse(widget.videoUrl!));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final safeTitle = widget.title.replaceAll(RegExp(r'[^\w\s\.]'), '_');
        final fileName =
            safeTitle.endsWith('.mp4') ? safeTitle : '$safeTitle.mp4';
        final file = File('${tempDir.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path)],
              subject: 'Sharing ${widget.title}',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Download failed: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: "Share/Download",
            onPressed: _downloadAndShare,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: _isLoading
              ? CircularProgressIndicator.adaptive(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary))
              : _errorMessage != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _errorMessage = null;
                            });
                            _initializePlayer();
                          },
                          child: const Text("Retry"),
                        )
                      ],
                    )
                  : Chewie(controller: _chewieController!),
        ),
      ),
    );
  }
}
