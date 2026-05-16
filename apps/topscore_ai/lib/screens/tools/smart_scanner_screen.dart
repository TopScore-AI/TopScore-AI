import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
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
import '../../constants/colors.dart';
import '../../widgets/glass_card.dart';

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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Document Scanner",
          style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.primary),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [AppColors.backgroundDark, AppColors.surfaceElevatedDark]
                      : [const Color(0xFFF8FAFC), Colors.white],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessing) ...[
                      Lottie.asset('assets/lottie/loading.json', height: 120),
                      const SizedBox(height: 32),
                      Text(
                        "PREPARING LENS...",
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white70 : AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 2,
                        ),
                      ),
                    ] else ...[
                      GlassCard(
                        padding: const EdgeInsets.all(40),
                        borderRadius: 32,
                        opacity: isDark ? 0.05 : 0.03,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                CupertinoIcons.camera_viewfinder,
                                size: 64,
                                color: AppColors.primary,
                              ),
                            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                                begin: const Offset(1, 1),
                                end: const Offset(1.1, 1.1),
                                duration: 2000.ms,
                                curve: Curves.easeInOut),
                            const SizedBox(height: 32),
                            Text(
                              "Homework Solver",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Scan your homework or diagrams for instant step-by-step help from the AI Tutor.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn().slideY(begin: 0.1),
                      const SizedBox(height: 48),

                      SizedBox(
                        width: double.infinity,
                        height: 64,
                        child: ElevatedButton.icon(
                          onPressed: _launchScanner,
                          icon: const Icon(CupertinoIcons.camera_fill, size: 20),
                          label: Text(
                            "START SCANNER",
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            elevation: 8,
                            shadowColor: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                      const SizedBox(height: 16),

                      TextButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(CupertinoIcons.photo_on_rectangle),
                        label: Text(
                          "PICK FROM GALLERY",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ).animate().fadeIn(delay: 400.ms),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
