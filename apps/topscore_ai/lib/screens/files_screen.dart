import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:go_router/go_router.dart';
import '../models/firebase_file.dart';
import '../services/storage_service.dart';
import '../shared/services/media_picker_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_spinner.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  late Future<List<FirebaseFile>> _filesFuture;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _filesFuture = _fetchAndFilterFiles();
  }

  Future<void> _refreshFiles() async {
    setState(() {
      _filesFuture = _fetchAndFilterFiles();
    });
  }

  Future<List<FirebaseFile>> _fetchAndFilterFiles() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // 1. Fetch public files
      final publicFiles = await StorageService.getAllFilesFromFirestore();

      // 2. Fetch user files if logged in
      List<FirebaseFile> userFiles = [];
      if (user != null) {
        userFiles = await StorageService.getUserFiles(user.uid);
      }

      final allFiles = [...userFiles, ...publicFiles];

      return allFiles.where((file) {
        final name = file.name.toLowerCase();
        return name.endsWith('.pdf') ||
            name.endsWith('.doc') ||
            name.endsWith('.docx');
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint("Error fetching files: $e");
      return [];
    }
  }

  Future<void> _uploadFile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showAuthDialog();
      return;
    }

    try {
      final results = await MediaPickerService.instance.pickFiles(
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (results.isEmpty) return;
      final file = results.first;

      setState(() => _isUploading = true);

      final url = await StorageService.uploadUserFile(
        userId: user.uid,
        fileName: file.name,
        mimeType: file.mimeType,
        bytes: file.bytes,
        filePath: file.filePath,
      );

      if (url != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("File uploaded successfully!")),
          );
        }
        _refreshFiles();
      } else {
        throw Exception("Upload failed");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Upload failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Authentication Required",
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: const Text(
            "Please sign in or create an account to upload and manage your own study resources."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigation to sign-in would go here
            },
            child: const Text("SIGN IN"),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(FirebaseFile file) async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      _showAuthDialog();
      return;
    }

    context.push('/pdf-viewer', extra: {
      'storagePath': file.path,
      'title': file.name,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Library Resources",
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final files = await _filesFuture;
              if (!context.mounted) return;
              showSearch(
                context: context,
                delegate: FileSearchDelegate(files, _openFile),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<List<FirebaseFile>>(
            future: _filesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return AppSpinner.center();
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        "Error loading resources",
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                    ],
                  ),
                );
              }

              final files = snapshot.data ?? [];
              if (files.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open,
                          size: 60, color: theme.disabledColor),
                      const SizedBox(height: 16),
                      Text(
                        "No documents found",
                        style: TextStyle(color: theme.hintColor),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _refreshFiles,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: files.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final isUserFile = file.path.contains('uploads/');

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: theme.cardColor,
                      child: ListTile(
                        leading: _getFileIcon(file.name),
                        title: Text(
                          file.name,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: isUserFile
                            ? Text("Personal",
                                style: TextStyle(
                                    color: theme.primaryColor, fontSize: 12))
                            : null,
                        trailing:
                            const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () => _openFile(file),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          if (_isUploading)
            Container(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.15),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppSpinner(),
                        SizedBox(height: 16),
                        Text("Uploading document..."),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _uploadFile,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text("Upload"),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    late Color color;
    late IconData icon;

    switch (ext) {
      case 'pdf':
        color = const Color(0xFFFF6B6B);
        icon = Icons.picture_as_pdf;
        break;
      case 'doc':
      case 'docx':
        color = const Color(0xFF4A90E2);
        icon = Icons.description;
        break;
      default:
        color = Colors.grey;
        icon = Icons.insert_drive_file;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class FileSearchDelegate extends SearchDelegate {
  final List<FirebaseFile> allFiles;
  final Function(FirebaseFile) onFileTap;

  FileSearchDelegate(this.allFiles, this.onFileTap);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = allFiles.where((file) {
      final q = query.toLowerCase();
      return file.name.toLowerCase().contains(q) ||
          (file.path.toLowerCase().contains(q));
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final file = results[index];
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.grey),
          title: Text(file.name),
          onTap: () => onFileTap(file),
        );
      },
    );
  }
}
