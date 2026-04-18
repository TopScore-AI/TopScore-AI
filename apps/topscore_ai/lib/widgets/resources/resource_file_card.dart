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
        ? '${(file.size! / (1024 * 1024)).toStringAsFixed(2)} MB'
        : 'Unknown size';

    return Consumer<DownloadProvider>(
      builder: (context, downloadProvider, child) {
        final isDownloaded = downloadProvider.isDownloaded(file.path);
        final isDownloading = downloadProvider.isDownloading(file.path);
        final progress = downloadProvider.getProgress(file.path);

        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildIcon(isDark),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.displayName,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${file.subject ?? 'General'} • ${file.gradeLabel}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: theme.hintColor,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                sizeStr,
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // --- DOWNLOAD / SAVED ICON ---
                    if (isDownloading)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: progress > 0 ? progress : null,
                          strokeWidth: 2.5,
                          color: theme.primaryColor,
                        ),
                      )
                    else if (isDownloaded)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          Icons.file_download_outlined,
                          color: theme.hintColor.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (file.downloadUrl != null) {
                            downloadProvider.downloadGenericFile(
                              id: file.path,
                              title: file.displayName,
                              downloadUrl: file.downloadUrl!,
                            );
                          }
                        },
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.hintColor.withValues(alpha: 0.3),
                      size: 20,
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

  Widget _buildIcon(bool isDark) {
    if (file.thumbnailUrl != null) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: NetworkImage(file.thumbnailUrl!),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );
    }

    IconData iconData = Icons.insert_drive_file_rounded;
    Color iconColor = AppColors.primaryPurple;

    if (file.type == 'pdf') {
      iconData = Icons.picture_as_pdf_rounded;
      iconColor = const Color(0xFFEF4444); // Red-500
    } else if (file.type == 'jpg' || file.type == 'png' || file.type == 'jpeg') {
      iconData = Icons.image_rounded;
      iconColor = const Color(0xFFF59E0B); // Amber-500
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(iconData, color: iconColor, size: 24),
      ),
    );
  }
}
