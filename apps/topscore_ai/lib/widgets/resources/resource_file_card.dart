import 'package:flutter/material.dart';
import '../../models/firebase_file.dart';
import '../../constants/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/download_provider.dart';

class ResourceFileCard extends StatelessWidget {
  final FirebaseFile file;
  final VoidCallback onTap;

  const ResourceFileCard({
    super.key,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sizeStr = file.size != null
        ? '${(file.size! / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '';

    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, child) {
        final isDownloaded = downloadProvider.isDownloaded(file.path);
        final isDownloading = downloadProvider.isDownloading(file.path);
        final progress = downloadProvider.getProgress(file.path);

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    _buildIcon(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.displayName,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (file.subject != null) ...[
                                _Tag(
                                  label: file.subject!,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                              ],
                              _Tag(
                                label: file.gradeLabel,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                              const Spacer(),
                              if (sizeStr.isNotEmpty)
                                Text(
                                  sizeStr,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Download / saved indicator
                    if (isDownloading)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          value: progress > 0 ? progress : null,
                          strokeWidth: 2.5,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    else if (isDownloaded)
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: AppColors.success,
                          size: 14,
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          if (file.downloadUrl != null) {
                            downloadProvider.downloadGenericFile(
                              id: file.path,
                              title: file.displayName,
                              downloadUrl: file.downloadUrl!,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.download_rounded,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.7),
                            size: 16,
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    if (file.thumbnailUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          file.thumbnailUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fileTypeIcon(),
        ),
      );
    }
    return _fileTypeIcon();
  }

  Widget _fileTypeIcon() {
    IconData iconData;
    Color iconColor;

    switch (file.type.toLowerCase()) {
      case 'pdf':
        iconData = Icons.picture_as_pdf_rounded;
        iconColor = AppColors.error;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        iconData = Icons.image_rounded;
        iconColor = AppColors.warning;
        break;
      case 'doc':
      case 'docx':
        iconData = Icons.description_rounded;
        iconColor = AppColors.info;
        break;
      case 'mp4':
      case 'mov':
      case 'avi':
        iconData = Icons.play_circle_rounded;
        iconColor = AppColors.aiAccent;
        break;
      default:
        iconData = Icons.insert_drive_file_rounded;
        iconColor = AppColors.primary;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }
}

// ── Small tag chip ────────────────────────────────────────────────────────────

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
