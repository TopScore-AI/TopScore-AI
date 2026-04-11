import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import '../../shared/services/media_picker_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as markdown;
import 'package:provider/provider.dart';
import '../../services/ai_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/math_markdown.dart';
import '../../utils/markdown/mermaid_builder.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart'; // To access studyDb
import '../../utils/curriculum_utils.dart';
import '../../services/analytics_service.dart';

class PdfSummarizerScreen extends StatefulWidget {
  const PdfSummarizerScreen({super.key});

  @override
  State<PdfSummarizerScreen> createState() => _PdfSummarizerScreenState();
}

class _PdfSummarizerScreenState extends State<PdfSummarizerScreen> {
  String? _summaryMarkdown;
  bool _isUploading = false;
  String _statusText = "Upload a PDF to generate notes.";

  // Controls for the prompt
  String _selectedCurriculum = 'CBC';
  String _selectedGrade = 'Grade 7';
  String _summaryType = 'detailed_bullet_points';

  final List<String> _curriculums = CurriculumData.getCurriculums();
  
  List<String> get _availableGrades => CurriculumData.getGradesForCurriculum(_selectedCurriculum);

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logToolStarted('pdf_summarizer');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().userModel;
      if (user != null && user.curriculum != null) {
        setState(() {
          final cur = user.curriculum == '8-4-4' ? '844' : user.curriculum!;
          if (_curriculums.contains(cur)) {
            _selectedCurriculum = cur;
            
            final userGradeLabel = user.gradeLabel.split(' ').last;
            final normalizedGrade = CurriculumData.normalizeGrade(userGradeLabel, _selectedCurriculum);
            
            if (normalizedGrade != null && _availableGrades.contains(normalizedGrade)) {
              _selectedGrade = normalizedGrade;
            } else {
              _selectedGrade = _availableGrades.first;
            }
          }
        });
      }
    });
  }

  final List<String> _formats = [
    'detailed_bullet_points', 'study_notes', 'flashcard_format', 'executive_summary'
  ];

  Future<void> _pickAndUploadPdf() async {
    try {
      final results = await MediaPickerService.instance.pickFiles(
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (results.isEmpty) return;
      final picked = results.first;

      setState(() {
        _isUploading = true;
        _statusText = "Analyzing ${picked.name}... this might take a minute depending on the PDF size.";
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
        readingLevel: '$_selectedCurriculum $_selectedGrade',
        summaryType: _summaryType,
      );

      final rawJsonString = jsonEncode({'summary': summary});

      await studyDb.saveMaterial(
        type: 'summary',
        topic: picked.name.replaceAll('.pdf', ''),
        curriculum: _selectedCurriculum,
        grade: _selectedGrade,
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
        curriculum: _selectedCurriculum,
        grade: _selectedGrade,
      );

      // Auto-save for offline access
      await studyDb.saveMaterial(
        type: 'pdf_summary',
        topic: picked.name.replaceAll('.pdf', ''),
        curriculum: _selectedCurriculum,
        grade: _selectedGrade,
        jsonData: jsonEncode({'summary': summary}),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusText = "Upload failed. Please ensure the backend is running.\n\nError: $e";
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildConfigSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Curriculum", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCurriculum,
                          isExpanded: true,
                          items: _curriculums.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: _isUploading ? null : (v) {
                            setState(() {
                              _selectedCurriculum = v!;
                              _selectedGrade = _availableGrades.first;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Grade/Level", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGrade,
                          isExpanded: true,
                          items: _availableGrades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: _isUploading ? null : (v) => setState(() => _selectedGrade = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text("Summary Format", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _summaryType,
                isExpanded: true,
                items: _formats.map((f) => DropdownMenuItem(value: f, child: Text(f.replaceAll('_', ' ')))).toList(),
                onChanged: _isUploading ? null : (v) => setState(() => _summaryType = v!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // The Upload Button
          ElevatedButton.icon(
            icon: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.upload_file),
            label: Text(_isUploading ? "Summarizing..." : "Select PDF Document"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: _isUploading ? null : _pickAndUploadPdf,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Document Summarizer", style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildConfigSection(),
            const SizedBox(height: 16),

            // The Results Area
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                ),
                child: _summaryMarkdown != null
                    ? SingleChildScrollView(
                        child: MarkdownBody(
                          data: _summaryMarkdown!,
                          selectable: true,
                          builders: {
                            'latex': LatexElementBuilder(),
                            'mermaid': MermaidElementBuilder(),
                          },
                          extensionSet: markdown.ExtensionSet(
                            [
                              ...markdown.ExtensionSet.gitHubFlavored.blockSyntaxes,
                              MermaidBlockSyntax()
                            ],
                            [
                              markdown.EmojiSyntax(),
                              LatexSyntax(),
                              ...markdown.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                            ],
                          ),
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(fontSize: 16, height: 1.5),
                            h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                          ),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _statusText,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Made with Bob
