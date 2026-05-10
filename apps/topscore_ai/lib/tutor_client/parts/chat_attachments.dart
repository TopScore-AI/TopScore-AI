part of '../chat_controller.dart';

// ===========================================================================
// Attachments — picking, uploading, camera, paste handling
// ===========================================================================

extension ChatControllerAttachments on ChatController {
  Future<void> pickAndUploadFile() async {
    if (_pendingAttachments.length >= 3) {
      _showLimitReachedSnackBar();
      return;
    }

    try {
      await RecoveryService.saveNavigationState('/ai-tutor',
          threadId: _wsService?.threadId);

      final results = await MediaPickerService.instance.pickFiles(
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'csv', 'md'],
        allowMultiple: true,
      );

      // Back in the app — clear recovery regardless of result
      await RecoveryService.clearRecoveryState();

      if (results.isNotEmpty) {
        final remainingSlots = 3 - _pendingAttachments.length;
        final filesToProcess = results.take(remainingSlots).toList();

        for (final file in filesToProcess) {
          final id = generateRandomId();
          final attachment = PendingAttachment(
            id: id,
            name: file.name,
            type: getFileType(file.extension),
            bytes: file.bytes,
            isUploaded: false,
          );

          _pendingAttachments.add(attachment);
          _isUploading = true;
          notify();

          uploadToFirebase(
            bytes: file.bytes,
            filePath: file.filePath,
            fileName: file.name,
            mimeType: file.mimeType,
          ).then((url) {
            if (url == null) {
              _pendingAttachments.removeWhere((a) => a.id == id);
              _showUploadErrorSnackBar();
              _checkUploadsFinished();
              notify();
              return;
            }
            attachment.url = url;
            attachment.isUploaded = true;
            _checkUploadsFinished();
            notify();
          });
        }
      }
    } catch (e) {
      await RecoveryService.clearRecoveryState();
      developer.log('File picker error: $e');
      _showUploadErrorSnackBar();
      _checkUploadsFinished();
      notify();
    }
  }

  Future<void> pickAndUploadImage(ImageSource source) async {
    if (_pendingAttachments.length >= 3) {
      _showLimitReachedSnackBar();
      return;
    }

    try {
      await RecoveryService.saveNavigationState('/ai-tutor',
          threadId: _wsService?.threadId);

      final results = await MediaPickerService.instance.pickImages(
        source: source,
        allowMultiple: false,
      );

      // Back in the app — clear recovery regardless of result
      await RecoveryService.clearRecoveryState();

      if (results.isNotEmpty) {
        await _processAndUploadMedia(results.first);
      }
    } catch (e) {
      await RecoveryService.clearRecoveryState();
      developer.log('Image picker error: $e');
      _checkUploadsFinished();
      notify();
    }
  }

  /// Processes picked media: Compresses images if needed and then uploads.
  Future<void> _processAndUploadMedia(MediaPickResult pick) async {
    try {
      _isUploading = true;
      notify();

      Uint8List? uploadBytes = pick.bytes;
      String? uploadPath = pick.filePath;

      // Compression Path for Mobile Images
      if (!kIsWeb && pick.mimeType.startsWith('image/')) {
        final tempDir = await getTemporaryDirectory();
        final targetPath =
            '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          pick.filePath!,
          targetPath,
          quality: 70,
          format: CompressFormat.jpeg,
          minWidth: 1024,
          minHeight: 1024,
        );

        if (compressedFile != null) {
          uploadPath = compressedFile.path;
          uploadBytes = await compressedFile.readAsBytes();
        }
      }

      final id = generateRandomId();
      final attachment = PendingAttachment(
        id: id,
        name: pick.name,
        type: pick.mimeType,
        bytes: uploadBytes,
        previewData: pick.mimeType.startsWith('image/') && uploadBytes != null
            ? 'data:${pick.mimeType};base64,${base64Encode(uploadBytes)}'
            : null,
        isUploaded: false,
      );

      _pendingAttachments.add(attachment);
      notify();

      final url = await uploadToFirebase(
        bytes: uploadBytes,
        filePath: uploadPath,
        fileName: pick.name,
        mimeType: pick.mimeType,
      );

      if (url == null) {
        _pendingAttachments.removeWhere((a) => a.id == id);
        _showUploadErrorSnackBar();
        _checkUploadsFinished();
        notify();
        return;
      }

      attachment.url = url;
      attachment.isUploaded = true;
      _checkUploadsFinished();
      notify();
    } catch (e) {
      developer.log('Media processing/upload error: $e');
      _showUploadErrorSnackBar();
      _checkUploadsFinished();
      notify();
    }
  }

  Future<void> openCamera() async {
    if (kIsWeb) {
      await pickAndUploadImage(ImageSource.camera);
      return;
    }

    final context = scaffoldKey.currentContext;
    if (context == null) return;

    // Check premium access for document scanner
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (!FeatureGateService.canUseDocumentScanner(user)) {
      await PremiumFeatureDialog.show(
        context,
        featureName: 'Document Scanner',
        icon: Icons.document_scanner,
      );
      return;
    }

    // 1. Request Permissions
    final status = await Permission.camera.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Camera Permission"),
            content: const Text(
                "Please enable camera access in settings to scan your work."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    openAppSettings();
                  },
                  child: const Text("Settings")),
            ],
          ),
        );
      }
      return;
    }

    // 2. Launch Native Multi-Page Scanner
    List<String>? images;
    try {
      images = await ScannerService().scanDocument();
    } on ScannerUnavailableException catch (e) {
      final ctx = scaffoldKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    } catch (e) {
      if (kDebugMode) debugPrint('Scanner unexpected error: $e');
      final ctx = scaffoldKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content:
                const Text('Could not open the scanner. Please try again.'),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (images != null && images.isNotEmpty) {
      // 3. Process & Upload each page
      for (final path in images) {
        final file = File(path);
        final name = path.split('/').last;

        await _processAndUploadMedia(MediaPickResult(
          bytes: await file.readAsBytes(),
          name: name,
          extension: name.split('.').last.toLowerCase(),
          filePath: path,
          mimeType: 'image/jpeg',
        ));
      }

      // 4. Scanned images are now in _pendingAttachments, visible at the chat input
    }
  }

  void removeAttachment(String id) {
    _pendingAttachments.removeWhere((a) => a.id == id);
    _checkUploadsFinished();
    notify();
  }

  void clearPendingAttachment() {
    _pendingAttachments.clear();
    _isUploading = false;
    notify();
  }

  void _checkUploadsFinished() {
    _isUploading = _pendingAttachments.any((a) => !a.isUploaded);
  }

  void _showLimitReachedSnackBar() {
    // This assumes scaffoldKey is available from ChatController
    final context = scaffoldKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Maximum of 3 attachments reached. Please remove a file if you want to add a different one.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showUploadErrorSnackBar() {
    final context = scaffoldKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to upload file. Please try again.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> handlePaste(CustomPasteEvent event) async {
    if (_pendingAttachments.length >= 3) {
      _showLimitReachedSnackBar();
      return;
    }
    if (event.bytes != null) {
      final id = generateRandomId();
      final name = 'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png';

      final attachment = PendingAttachment(
        id: id,
        name: name,
        type: 'image/png',
        bytes: event.bytes,
        previewData: 'data:image/png;base64,${base64Encode(event.bytes!)}',
        isUploaded: false,
      );

      _pendingAttachments.add(attachment);
      _isUploading = true;
      notify();

      uploadToFirebase(
        bytes: event.bytes,
        fileName: name,
        mimeType: 'image/png',
      ).then((url) {
        if (url == null) {
          _pendingAttachments.removeWhere((a) => a.id == id);
          _showUploadErrorSnackBar();
          _checkUploadsFinished();
          notify();
          return;
        }
        attachment.url = url;
        attachment.isUploaded = true;
        _checkUploadsFinished();
        notify();
      });
    }
  }

  Future<void> handleGenericPaste() async {
    try {
      final result = await ClipboardService.instance.readClipboard();

      if (result.type == ClipboardContentType.image &&
          result.imageBytes != null) {
        // Handle as image paste
        await handlePaste(CustomPasteEvent(bytes: result.imageBytes));
        return;
      }

      if (result.hasText) {
        // Handle as smart text paste (insert at cursor)
        ClipboardService.instance
            .pasteIntoController(_textController, result.text!);
        notify();
      }
    } catch (e) {
      developer.log('ChatController.handleGenericPaste error: $e');
    }
  }

  Future<String?> uploadToFirebase({
    Uint8List? bytes,
    String? filePath,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'guest';

      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final ref = FirebaseStorage.instance
          .ref()
          .child('uploads/$userId/chat_uploads/$safeFileName');

      final metadata = SettableMetadata(
        contentType: mimeType,
        customMetadata: {
          'original_name': fileName,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
      );

      UploadTask uploadTask;
      if (kIsWeb) {
        if (bytes == null) throw Exception("Bytes required for Web upload");
        uploadTask = ref.putData(bytes, metadata);
      } else {
        File? resolvedFile;
        if (filePath != null) {
          final tempFile = File(filePath);
          if (tempFile.existsSync()) {
            resolvedFile = tempFile;
          }
        }

        // Prioritize writing from memory bytes on android/ios where path loss occurs randomly or if `File` is unreadable
        if (bytes != null) {
          uploadTask = ref.putData(bytes, metadata);
        } else if (resolvedFile != null) {
          uploadTask = ref.putFile(resolvedFile, metadata);
        } else {
          throw Exception("Either a valid filePath or bytes must be provided");
        }
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      developer.log('Firebase Upload Error: $e');
      return null;
    }
  }

  void showAttachmentMenu(BuildContext context, ThemeData theme, bool isDark,
      {LayerLink? link}) {
    // Determine position of the button
    final renderObject = _attachButtonKey.currentContext?.findRenderObject();
    final RenderBox? box = renderObject is RenderBox ? renderObject : null;

    // Default/Fallback position
    Offset targetOffset = Offset(20, MediaQuery.of(context).size.height - 100);
    double menuWidth = 220;

    if (box != null) {
      final position = box.localToGlobal(Offset.zero);
      targetOffset = Offset(position.dx, position.dy);
    }

    // Use showGeneralDialog to prevent the default centering behavior of showDialog
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close Attachment Menu',
      barrierColor: Colors.black.withValues(alpha: 0.1),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, anim1, anim2) {
        final menuContent = FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: menuWidth,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1C1C1E).withValues(alpha: 0.95)
                      : Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAttachmentOption(
                        context,
                        icon: CupertinoIcons.photo_on_rectangle,
                        label: 'Photo Library',
                        onTap: () => pickAndUploadImage(ImageSource.gallery),
                        theme: theme,
                      ),
                      if (!kIsWeb) ...[
                        _buildAttachmentOption(
                          context,
                          icon: CupertinoIcons.camera,
                          label: 'Take Photo',
                          onTap: () => openCamera(),
                          theme: theme,
                        ),
                        _buildAttachmentOption(
                          context,
                          icon: CupertinoIcons.viewfinder,
                          label: 'Scan Text (OCR)',
                          onTap: () => pickAndExtractText(),
                          theme: theme,
                        ),
                      ],
                      _buildAttachmentOption(
                        context,
                        icon: CupertinoIcons.doc_text,
                        label: 'Document',
                        onTap: () => pickAndUploadFile(),
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        return Stack(
          children: [
            if (link != null)
              CompositedTransformFollower(
                link: link,
                showWhenUnlinked: false,
                offset: const Offset(-10, -8),
                followerAnchor: Alignment.bottomLeft,
                targetAnchor: Alignment.topLeft,
                child: menuContent,
              )
            else
              Positioned(
                left: (targetOffset.dx - 10).clamp(
                    10.0, MediaQuery.of(context).size.width - menuWidth - 10.0),
                bottom:
                    (MediaQuery.of(context).size.height - targetOffset.dy + 8.0),
                child: menuContent,
              ),
          ],
        );
      },
    );
  }

  Future<void> pickAndExtractText() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100, // Better quality for OCR
      );

      if (image != null) {
        _isUploading = true;
        notify();

        final String? extractedText =
            await OCRService.extractTextFromPath(image.path);

        _isUploading = false;

        if (extractedText != null && extractedText.trim().isNotEmpty) {
          final currentText = _textController.text;
          final space = currentText.isEmpty ? '' : '\n\n';
          _textController.text = '$currentText$space$extractedText';
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        } else {
          developer.log('OCR: No text found');
        }
        notify();
      }
    } catch (e) {
      developer.log('OCR Error: $e');
      _isUploading = false;
      notify();
    }
  }

  Widget _buildAttachmentOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20, color: theme.primaryColor),
      title: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
    );
  }
}
