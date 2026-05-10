import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import '../../shared/services/media_picker_service.dart';
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../../widgets/gpt_markdown_wrapper.dart';
import '../../providers/auth_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../../services/analytics_service.dart';
import '../../services/recovery_service.dart';
import '../../widgets/app_spinner.dart';
import '../../services/feature_gate_service.dart';
import '../../widgets/premium_feature_dialog.dart';
import '../../constants/colors.dart';

class PdfSummarizerScreen extends StatefulWidget {
  const PdfSummarizerScreen({super.key});

  @override
  State<PdfSummarizerScreen> createState() => _PdfSummarizerScreenState();
}

class _PdfSummarizerScreenState extends State<PdfSummarizerScreen> {
  String? _summaryMarkdown;
  bool _isUploading = false;
  String _statusText = "Upload a PDF to generate notes.";

  String _summaryType = 'detailed_bullet_points';

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logToolStarted('pdf_summarizer');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().userModel;

      if (!FeatureGateService.canUsePdfSummarizer(user)) {
        PremiumFeatureDialog.show(
          context,
          featureName: 'Document Summarizer',
          icon: Icons.summarize,
        ).then((_) {
          if (mounted) Navigator.of(context).pop();
        });
        return;
      }
    });
  }

  final List<String> _formats = [
    'detailed_bullet_points',
    'study_notes',
    'flashcard_format',
    'executive_summary'
  ];

  Future<void> _pickAndUploadPdf() async {
    try {
      await RecoveryService.saveNavigationState('/summarizer');

      final results = await MediaPickerService.instance.pickFiles(
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      await RecoveryService.clearRecoveryState();

      if (results.isEmpty) return;
      final picked = results.first;

      setState(() {
        _isUploading = true;
        _statusText = "Analyzing ${picked.name}...";
        _summaryMarkdown = null;
      });

      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userModel?.uid;
      if (userId == null) throw Exception("User not authenticated");

      Uint8List? fileBytes = picked.bytes;
      if (fileBytes == null && picked.filePath != null) {
        fileBytes = await File(picked.filePath!).readAsBytes();
      }

      if (fileBytes == null) throw Exception("Could not read file data");

      final aiService = AIService();
      final summary = await aiService.summarizePdfVision(
        pdfBytes: fileBytes,
        filename: picked.name,
        readingLevel: 'general',
        summaryType: _summaryType,
      );

      final rawJsonString = jsonEncode({'summary': summary});

      await studyDb.saveMaterial(
        type: 'summary',
        topic: picked.name.replaceAll('.pdf', ''),
        curriculum: 'General',
        grade: 'General',
        jsonData: rawJsonString,
      );

      setState(() {
        _summaryMarkdown = summary;
        _isUploading = false;
        _statusText = "Summary Ready!";
      });

      AnalyticsService.instance.logMaterialGenerated(
        type: 'pdf_summary',
        topic: picked.name.replaceAll('.pdf', ''),
        curriculum: 'General',
        grade: 'General',
      );
    } catch (e) {
      await RecoveryService.clearRecoveryState();
      if (mounted) {
        setState(() {
          _statusText = "Upload failed. Please try again.";
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Document Summarizer",
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.primary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  _buildGlassConfig(isDark),
                  const SizedBox(height: 20),
                  Expanded(child: _buildResultsArea(isDark)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassConfig(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : AppColors.primary)
                .withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (isDark ? Colors.white : AppColors.primary)
                  .withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFieldLabel("SUMMARY FORMAT", isDark),
              const SizedBox(height: 8),
              _buildGlassDropdown(
                _summaryType,
                _formats,
                isDark,
                (v) => setState(() => _summaryType = v!),
                isFormat: true,
              ),
              const SizedBox(height: 24),
              _buildActionButton(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.6),
      ),
    );
  }

  Widget _buildGlassDropdown(
      String value, List<String> items, bool isDark, Function(String?) onChanged,
      {bool isFormat = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : AppColors.primary).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : AppColors.primary)
              .withValues(alpha: 0.1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: isDark ? Colors.white60 : AppColors.primary),
          dropdownColor: isDark ? AppColors.surfaceElevatedDark : Colors.white,
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(
                      isFormat ? i.replaceAll('_', ' ').toUpperCase() : i,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ))
              .toList(),
          onChanged: _isUploading ? null : onChanged,
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isDark) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isUploading ? null : _pickAndUploadPdf,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isUploading)
              const AppSpinner(color: Colors.white, size: 20)
            else
              const Icon(Icons.cloud_upload_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              _isUploading ? "PROCESSOR ACTIVE..." : "SELECT PDF DOCUMENT",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsArea(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : AppColors.primary)
                .withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: (isDark ? Colors.white : AppColors.primary)
                  .withValues(alpha: 0.1),
            ),
          ),
          child: _summaryMarkdown != null
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: SelectionArea(
                    child: StyledGptMarkdown(
                      _summaryMarkdown!,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        height: 1.6,
                        color: isDark ? Colors.white : AppColors.text,
                      ),
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 64,
                      color: (isDark ? Colors.white : AppColors.primary)
                          .withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _statusText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: (isDark ? Colors.white : AppColors.primary)
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// Made with Bob
