part of '../chat_controller.dart';

// ===========================================================================
// Attachments — picking, uploading, camera, paste handling
// ===========================================================================

extension ChatControllerAttachments on ChatController {
  Future<void> pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        _pendingFileBytes = result.files.single.bytes;
        _pendingFileName = result.files.single.name;
        _pendingFileType = result.files.single.extension == 'pdf' ? 'pdf' : 'doc';
        _isUploading = true;
        notify();

        final url = await uploadToFirebase(
          _pendingFileBytes!,
          _pendingFileName!,
          _pendingFileType == 'pdf' ? 'application/pdf' : 'application/octet-stream',
        );

        _pendingFileUrl = url;
        _isUploading = false;
        notify();
      }
    } catch (e) {
      developer.log('File picker error: $e');
      _isUploading = false;
      notify();
    }
  }

  Future<void> pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        _pendingFileBytes = bytes;
        _pendingPreviewData = 'data:image/png;base64,$base64Image';
        _pendingFileName = image.name;
        _pendingFileType = 'image';
        _isUploading = true;
        notify();

        final url = await uploadToFirebase(bytes, image.name, 'image/png');
        _pendingFileUrl = url;
        _isUploading = false;
        notify();
      }
    } catch (e) {
      developer.log('Image picker error: $e');
      _isUploading = false;
      notify();
    }
  }

  Future<void> openCamera() async {
    await pickAndUploadImage(ImageSource.camera);
  }

  void clearPendingAttachment() {
    _pendingFileBytes = null;
    _pendingFileUrl = null;
    _pendingPreviewData = null;
    _pendingFileName = null;
    _pendingFileType = null;
    _isUploading = false;
    notify();
  }

  Future<void> handlePaste(CustomPasteEvent event) async {
    if (event.bytes != null) {
      final base64Image = base64Encode(event.bytes!);
      _pendingFileBytes = event.bytes;
      _pendingPreviewData = 'data:image/png;base64,$base64Image';
      _pendingFileName = 'pasted_image_${DateTime.now().millisecondsSinceEpoch}.png';
      _pendingFileType = 'image';
      _isUploading = true;
      notify();

      final url = await uploadToFirebase(event.bytes!, _pendingFileName!, 'image/png');
      _pendingFileUrl = url;
      _isUploading = false;
      notify();
    }
  }

  Future<void> handleGenericPaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _textController.text = _textController.text + data!.text!;
      notify();
    }
  }

  Future<String?> uploadToFirebase(Uint8List bytes, String fileName, String mimeType) async {
    try {
      final ref = FirebaseStorage.instance.ref().child('chat_uploads/$fileName');
      final metadata = SettableMetadata(contentType: mimeType);
      final uploadTask = ref.putData(bytes, metadata);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      developer.log('Firebase Upload Error: $e');
      return null;
    }
  }

  void showAttachmentMenu(BuildContext context, ThemeData theme, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.1), // Dim background less
      builder: (context) => Stack(
        children: [
          Positioned(
            left: 20,
            bottom: 90, // Positioned near the attachment icon in ChatInputArea
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 220,
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
        _pendingFileName = 'Scanning...';
        notify();

        final String? extractedText = await OCRService.extractTextFromPath(image.path);
        
        _isUploading = false;
        _pendingFileName = null;
        
        if (extractedText != null && extractedText.trim().isNotEmpty) {
          final currentText = _textController.text;
          final space = currentText.isEmpty ? '' : '\n\n';
          _textController.text = '$currentText$space$extractedText';
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: _textController.text.length),
          );
        } else {
          developer.log('OCR: No text found');
          // Optional: show a snackbar or toast
        }
        notify();
      }
    } catch (e) {
      developer.log('OCR Error: $e');
      _isUploading = false;
      _pendingFileName = null;
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
