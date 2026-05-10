import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_spinner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:provider/provider.dart';

import '../../shared/services/media_picker_service.dart';
import '../../widgets/app_error_widget.dart';
import '../../services/feature_gate_service.dart';
import '../../widgets/premium_feature_dialog.dart';
import '../../providers/auth_provider.dart';

class SmartScannerScreen extends StatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  State<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends State<SmartScannerScreen> {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Check premium access first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      if (!FeatureGateService.canUseDocumentScanner(user)) {
        PremiumFeatureDialog.show(
          context,
          featureName: 'Document Scanner',
          icon: Icons.document_scanner,
        ).then((_) {
          if (mounted) Navigator.of(context).pop();
        });
        return;
      }

      // Automatically launch scanner on mobile if permission is granted
      if (!kIsWeb) {
        _launchScanner();
      }
    });
  }

  Future<void> _launchScanner() async {
    if (kIsWeb) {
      _pickImage(ImageSource.gallery);
      return;
    }

    // 1. Permission Check
    final status = await Permission.camera.request();
    if (status.isPermanentlyDenied) {
      _showPermissionDialog(openSettings: true);
      return;
    }
    if (!status.isGranted) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 2. Start ML Kit Doc Scanner
      final documentScanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormat: DocumentFormat.jpeg,
          mode: ScannerMode.full,
          isGalleryImport: true,
          pageLimit: 1,
        ),
      );

      final result = await documentScanner.scanDocument();

      if (result.images.isEmpty) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final imagePath = result.images.first;
      if (!mounted) return;

      // 3. Navigate to AI Tutor
      _navigateToTutor(XFile(imagePath));
    } catch (e) {
      if (kDebugMode) debugPrint("Scanner Error: $e");
      if (mounted) {
        setState(() => _isProcessing = false);
        // Fallback to simple image picker if ML Kit fails
        _pickImage(ImageSource.camera);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isProcessing = true);

    try {
      final results = await MediaPickerService.instance.pickImages(
        source: source,
        allowMultiple: false,
      );

      if (results.isEmpty) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final picked = results.first;
      if (!mounted) return;

      final xfile = (picked.bytes != null && kIsWeb)
          ? XFile.fromData(picked.bytes!,
              name: picked.name, mimeType: picked.mimeType)
          : XFile(picked.filePath ?? '');

      _navigateToTutor(xfile);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppErrorWidget.show(
          context,
          title: "Scanner Error",
          message: "We encountered an issue while processing your document.",
          details: e.toString(),
        );
      }
    }
  }

  void _navigateToTutor(XFile image) {
    context.go('/ai-tutor', extra: {
      'initial_image': image,
      'initial_input_text':
          "Analyze this image and solve the problem step-by-step.",
    });
  }

  void _showPermissionDialog({bool openSettings = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Camera Permission Required"),
        content: Text(
          openSettings
              ? "Camera access was permanently denied. Please enable it in your device Settings to use the scanner."
              : "Please allow camera access to scan problems.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (openSettings) {
                openAppSettings();
              } else {
                _launchScanner();
              }
            },
            child: Text(openSettings ? "Open Settings" : "Try Again"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Document Scanner",
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing) ...[
              AppSpinner(),
              const SizedBox(height: 24),
              Text(
                "Processing...",
                style: GoogleFonts.poppins(color: theme.colorScheme.onSurface),
              ),
            ] else ...[
              Icon(Icons.document_scanner_rounded,
                  size: 100, color: theme.primaryColor.withValues(alpha: 0.5)),
              const SizedBox(height: 40),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  "Scan your homework or diagrams for instant help.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _launchScanner,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text("Start Scanner"),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text("Upload from Gallery"),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
