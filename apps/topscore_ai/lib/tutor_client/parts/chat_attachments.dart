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
      await RecoveryService.saveNavigationState('/ai-tutor', threadId: _wsService.threadId);
      
      final results = await MediaPickerService.instance.pickFiles(
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'csv', 'md'],
        allowMultiple: true,
      );

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
            attachment.url = url;
            attachment.isUploaded = true;
            _checkUploadsFinished();
            notify();
          });
        }
      }
    } catch (e) {
      developer.log('File picker error: $e');
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
      await RecoveryService.saveNavigationState('/ai-tutor', threadId: _wsService.threadId);

      final results = await MediaPickerService.instance.pickImages(
        source: source,
        allowMultiple: false,
      );

      if (results.isNotEmpty) {
        await _processAndUploadMedia(results.first);
      }
    } catch (e) {
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
        final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
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
      
      attachment.url = url;
      attachment.isUploaded = true;
      _checkUploadsFinished();
      notify();
    } catch (e) {
      developer.log('Media processing/upload error: $e');
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

    // Use Custom In-App Camera to prevent Background Kill
    final XFile? result = await Navigator.push<XFile?>(
      context,
      MaterialPageRoute(
        builder: (context) => const DocumentScannerView(),
        fullscreenDialog: true,
      ),
    );

    if (result != null) {
      await _processAndUploadMedia(MediaPickResult(
        bytes: await result.readAsBytes(),
        name: result.name,
        extension: result.path.split('.').last.toLowerCase(),
        filePath: result.path,
        mimeType: 'image/jpeg',
      ));
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      
      if (result.type == ClipboardContentType.image && result.imageBytes != null) {
        // Handle as image paste
        await handlePaste(CustomPasteEvent(bytes: result.imageBytes));
        return;
      }

      if (result.hasText) {
        // Handle as smart text paste (insert at cursor)
        ClipboardService.instance.pasteIntoController(_textController, result.text!);
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
      final ref = FirebaseStorage.instance.ref().child('uploads/$userId/chat_uploads/$safeFileName');
      
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
        if (filePath != null) {
          uploadTask = ref.putFile(File(filePath), metadata);
        } else if (bytes != null) {
          uploadTask = ref.putData(bytes, metadata);
        } else {
          throw Exception("Either filePath or bytes must be provided");
        }
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      developer.log('Firebase Upload Error: $e');
      return null;
    }
  }

  void showAttachmentMenu(BuildContext context, ThemeData theme, bool isDark) {
    // Determine position of the button
    final RenderBox? box = _attachButtonKey.currentContext?.findRenderObject() as RenderBox?;
    Offset targetOffset = const Offset(20, 90); // Fallback
    double menuWidth = 220;
    
    if (box != null) {
      final position = box.localToGlobal(Offset.zero);
      // We want to be center-aligned or left-aligned with the button.
      // The button is near the bottom-left of the input pill.
      targetOffset = Offset(position.dx, position.dy);
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.1), // Dim background less
      builder: (context) => Stack(
        children: [
          Positioned(
            left: targetOffset.dx - 10, // Slight nudge left for better visual balance
            bottom: MediaQuery.of(context).size.height - targetOffset.dy + 8, // Positioned immediately ON TOP (8px gap)
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: menuWidth,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
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
                      // Camera and OCR are not supported on web
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
        ],
      ),
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

        final String? extractedText = await OCRService.extractTextFromPath(image.path);
        
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
