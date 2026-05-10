import 'package:flutter/material.dart';
import '../utils/cors_proxy_helper.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:io';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/image_cache_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _preferredNameCtrl;
  late TextEditingController _schoolCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _gradeCtrl;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().userModel;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _preferredNameCtrl = TextEditingController(text: user?.preferredName ?? '');
    _schoolCtrl = TextEditingController(text: user?.schoolName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phoneNumber ?? '');
    _gradeCtrl = TextEditingController(text: user?.grade?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _preferredNameCtrl.dispose();
    _schoolCtrl.dispose();
    _phoneCtrl.dispose();
    _gradeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final auth = context.read<AuthProvider>(); // capture before any async gap
    final uid = auth.userModel?.uid;
    if (uid == null) return;

    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      String downloadUrl;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final ref = FirebaseStorage.instance.ref('profile_photos/$uid.jpg');
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        downloadUrl = await ref.getDownloadURL();
      } else {
        final ref = FirebaseStorage.instance.ref('profile_photos/$uid.jpg');
        await ref.putFile(File(picked.path));
        downloadUrl = await ref.getDownloadURL();
      }

      await auth.updatePhotoURL(downloadUrl);

      // Pre-warm the profile image cache so the new photo is instantly
      // available everywhere without a re-download.
      if (!kIsWeb) {
        await ProfileImageCacheManager().prewarmFromFile(
          downloadUrl,
          File(picked.path),
        );
      } else {
        // On web, just prime the cache manager with the URL so it fetches once
        unawaited(ProfileImageCacheManager().downloadFile(downloadUrl));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final auth = context.read<AuthProvider>();
      await auth.updateUserRole(
        role: auth.userModel?.role ?? 'student',
        grade: _gradeCtrl.text.trim(),
        schoolName: _schoolCtrl.text.trim(),
        displayName: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        preferredName: _preferredNameCtrl.text.trim().isNotEmpty
            ? _preferredNameCtrl.text.trim()
            : null,
        dateOfBirth: auth.userModel?.dateOfBirth,
        parentalConsentGiven: auth.userModel?.parentalConsentGiven,
      );
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Profile updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancelEdit() {
    final user = context.read<AuthProvider>().userModel;
    _nameCtrl.text = user?.displayName ?? '';
    _preferredNameCtrl.text = user?.preferredName ?? '';
    _schoolCtrl.text = user?.schoolName ?? '';
    _phoneCtrl.text = user?.phoneNumber ?? '';
    _gradeCtrl.text = user?.grade?.toString() ?? '';
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text('Profile',
            style:
                GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          if (user != null && !_isEditing)
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: Text('Edit',
                  style: GoogleFonts.inter(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600)),
            ),
          if (_isEditing) ...[
            TextButton(
                onPressed: _cancelEdit,
                child: Text('Cancel',
                    style: GoogleFonts.inter(color: Colors.grey))),
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Save',
                      style: GoogleFonts.inter(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            _buildAvatar(user, theme, isDark),
            const SizedBox(height: 20),
            if (user != null) ...[
              _buildXpCard(user, theme, isDark),
              const SizedBox(height: 20),
            ],
            if (_isEditing)
              _buildEditForm(theme, isDark)
            else
              _buildInfoCard(user, theme, isDark),
            const SizedBox(height: 20),
            if (user != null) _buildQuotaCard(user, theme, isDark),
            const SizedBox(height: 20),
            _buildSubscriptionCard(user, theme, isDark),
            const SizedBox(height: 20),
            _buildPreferencesSection(theme, isDark),
            const SizedBox(height: 20),
            _buildAboutSection(theme),
            const SizedBox(height: 32),
            _buildActionsSection(user, authProvider, theme),
            const SizedBox(height: 32),
            Text('\u00a9 TopScore AI 2026',
                style: GoogleFonts.nunito(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    fontSize: 11)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Avatar
  // ---------------------------------------------------------------------------
  Widget _buildAvatar(dynamic user, ThemeData theme, bool isDark) {
    final hasPhoto =
        user?.photoURL != null && (user!.photoURL as String).isNotEmpty;
    final initials = (user?.displayName as String?)?.isNotEmpty == true
        ? (user!.displayName as String).substring(0, 1).toUpperCase()
        : '?';

    return Center(
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.cardColor,
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ],
            ),
            child: ClipOval(
              child: _isUploadingPhoto
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : hasPhoto
                      ? CachedNetworkImage(
                          imageUrl: CorsProxyHelper.getCorsProxyUrl(
                              user!.photoURL as String),
                          cacheManager: ProfileImageCacheManager(),
                          httpHeaders: CorsProxyHelper.standardHeaders,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (_, __, ___) => Center(
                              child: Text(initials,
                                  style: GoogleFonts.nunito(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentTeal))),
                        )
                      : Center(
                          child: Text(initials,
                              style: GoogleFonts.nunito(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.accentTeal))),
            ),
          ),
          if (user != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickAndUploadPhoto,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.scaffoldBackgroundColor, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Colors.white, size: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildXpCard(dynamic user, ThemeData theme, bool isDark) {
    if (user == null) return const SizedBox.shrink();

    final xp = user.xp as int? ?? 0;
    final level = user.level as int? ?? 1;

    // Level progress: xp % 1000
    final xpInCurrentLevel = xp % 1000;
    final progress = xpInCurrentLevel / 1000.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.surfaceElevatedDark, AppColors.backgroundDark]
              : [Colors.white, AppColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level $level',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: theme.primaryColor,
                    ),
                  ),
                  Text(
                    'TopScore Scholar',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.amber, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$xpInCurrentLevel / 1000 XP',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: theme.primaryColor.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Earn more XP by completing AI and Multiplayer Quizzes!',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Info card (view mode)
  // ---------------------------------------------------------------------------
  Widget _buildInfoCard(dynamic user, ThemeData theme, bool isDark) {
    if (user == null) return const SizedBox.shrink();
    final items = <(IconData, String, String)>[
      (Icons.person_rounded, 'Name', user.displayName ?? '—'),
      (Icons.email_rounded, 'Email', user.email ?? '—'),
      if ((user.phoneNumber as String?)?.isNotEmpty == true)
        (Icons.phone_rounded, 'Phone', user.phoneNumber as String),
      (
        Icons.school_rounded,
        'School',
        (user.schoolName as String?)?.isNotEmpty == true
            ? user.schoolName as String
            : '—'
      ),
      (Icons.grade_rounded, 'Grade', user.gradeLabel ?? '—'),
      if ((user.role as String?)?.isNotEmpty == true)
        (Icons.badge_rounded, 'Role', _capitalize(user.role as String)),
      if ((user.curriculum as String?)?.isNotEmpty == true)
        (Icons.menu_book_rounded, 'Curriculum', user.curriculum as String),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final (icon, label, value) = entry.value;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 16, color: theme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(label,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                        Text(value,
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ])),
                ]),
              ),
              if (i < items.length - 1)
                Divider(
                    height: 1,
                    indent: 56,
                    color: theme.dividerColor.withValues(alpha: 0.4)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Edit form
  // ---------------------------------------------------------------------------
  Widget _buildEditForm(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(children: [
        _editField('Display Name', _nameCtrl, Icons.person_rounded),
        const SizedBox(height: 12),
        _editField('AI Tutor calls me...', _preferredNameCtrl,
            Icons.record_voice_over_rounded),
        const SizedBox(height: 12),
        _editField('School', _schoolCtrl, Icons.school_rounded),
        const SizedBox(height: 12),
        _editField('Phone Number', _phoneCtrl, Icons.phone_rounded,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        _editField('Grade / Form', _gradeCtrl, Icons.grade_rounded,
            keyboardType: TextInputType.number),
      ]),
    );
  }

  Widget _editField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? keyboardType}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, size: 18, color: theme.primaryColor),
        filled: true,
        fillColor:
            isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quota card
  // ---------------------------------------------------------------------------
  Widget _buildQuotaCard(dynamic user, ThemeData theme, bool isDark) {
    final isSubscribed = user?.isSubscribed as bool? ?? false;
    if (isSubscribed) return const SizedBox.shrink();

    final count = user?.freeMessageCount as int? ?? 0;
    final lastDate = user?.freeMessagesLastAt as DateTime?;
    final limit = 6; // Free tier limit is 6 messages

    // Calculate reset time (12-hour window)
    String resetLabel = 'Resets in 12 hours';
    if (lastDate != null) {
      final resetAt = lastDate.add(const Duration(hours: 12));
      final now = DateTime.now();
      if (resetAt.isAfter(now)) {
        final diff = resetAt.difference(now);
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        resetLabel = h > 0 ? 'Resets in ${h}h ${m}m' : 'Resets in ${m}m';
      } else {
        resetLabel = 'Quota refreshed';
      }
    }

    final used = count.clamp(0, limit);
    final progress = used / limit;
    final progressColor = progress >= 1.0
        ? Colors.red
        : progress >= 0.6
            ? Colors.orange
            : AppColors.accentTeal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Free Quota',
              style:
                  GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
          Text('$used / $limit messages',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.timer_outlined,
              size: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 4),
          Text(resetLabel,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
        ]),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // Subscription card
  // ---------------------------------------------------------------------------
  Widget _buildSubscriptionCard(dynamic user, ThemeData theme, bool isDark) {
    final isSubscribed = user?.isSubscribed as bool? ?? false;
    final expiry = user?.subscriptionExpiry as DateTime?;

    return GestureDetector(
      onTap: () => context.push('/subscription'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSubscribed
              ? const LinearGradient(
                  colors: [AppColors.aiAccent, Color(0xFF9C8FFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : LinearGradient(colors: [
                  isDark ? AppColors.surfaceElevatedDark : Colors.white,
                  isDark ? AppColors.surfaceElevatedDark : Colors.white
                ]),
          borderRadius: BorderRadius.circular(20),
          border: isSubscribed
              ? null
              : Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
                color: isSubscribed
                    ? AppColors.aiAccent.withValues(alpha: 0.25)
                    : theme.shadowColor.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSubscribed
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(FontAwesomeIcons.crown,
                size: 18, color: isSubscribed ? Colors.white : Colors.amber),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  isSubscribed ? 'Pro Plan' : 'Free Plan',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSubscribed
                          ? Colors.white
                          : theme.colorScheme.onSurface),
                ),
                Text(
                  isSubscribed
                      ? (expiry != null
                          ? 'Expires ${_formatDate(expiry)}'
                          : 'Active')
                      : 'Upgrade for unlimited access',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isSubscribed
                          ? Colors.white70
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ])),
          Icon(
            isSubscribed
                ? Icons.check_circle_rounded
                : Icons.arrow_forward_ios_rounded,
            color: isSubscribed
                ? Colors.white
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            size: isSubscribed ? 22 : 16,
          ),
        ]),
      ),
    );
  }

  Widget _buildPreferencesSection(ThemeData theme, bool isDark) {
    final settings = Provider.of<SettingsProvider>(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Preferences'),
      _tile(
        icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        iconColor: Colors.amber,
        title: 'Dark Mode',
        trailing: Switch(
          value: isDark,
          onChanged: (v) {
            settings.setThemeMode(v ? ThemeMode.dark : ThemeMode.light);
          },
          activeThumbColor: theme.colorScheme.primary,
        ),
        onTap: () {},
        theme: theme,
        isDark: isDark,
      ),
      const SizedBox(height: 10),
      _tile(
        icon: Icons.bolt_rounded,
        iconColor: Colors.orange,
        title: 'Lite Mode (Saves Data)',
        subtitle: 'Always enabled to save your internet',
        trailing: Switch(
          value: true,
          onChanged: null, // Disabled
          activeThumbColor: theme.colorScheme.primary,
        ),
        onTap: () {},
        theme: theme,
        isDark: isDark,
      ),
      const SizedBox(height: 10),
      _tile(
        icon: Icons.notifications_rounded,
        iconColor: AppColors.primary,
        title: 'Notifications & Reminders',
        subtitle: 'Study reminders, quiet hours',
        onTap: () => context.push('/notification-preferences'),
        theme: theme,
        isDark: isDark,
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // About
  // ---------------------------------------------------------------------------
  Widget _buildAboutSection(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('About'),
      _tile(
          icon: FontAwesomeIcons.shieldHalved,
          iconColor: Colors.teal,
          title: 'Privacy Policy',
          onTap: () => context.push('/privacy-policy'),
          theme: theme,
          isDark: isDark),
      const SizedBox(height: 10),
      _tile(
          icon: FontAwesomeIcons.fileContract,
          iconColor: Colors.teal,
          title: 'Terms of Use',
          onTap: () => context.push('/terms-of-use'),
          theme: theme,
          isDark: isDark),
      const SizedBox(height: 10),
      _tile(
          icon: FontAwesomeIcons.headset,
          iconColor: AppColors.aiAccent,
          title: 'Contact Support',
          subtitle: 'Get help or report an issue',
          onTap: () => context.push('/support'),
          theme: theme,
          isDark: isDark),
      if (!kIsWeb) ...[],
    ]);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Widget _buildActionsSection(
      dynamic user, AuthProvider authProvider, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    if (user == null) {
      return _tile(
        icon: FontAwesomeIcons.rightToBracket,
        iconColor: AppColors.primary,
        title: 'Sign In / Register',
        textColor: AppColors.primary,
        onTap: () => context.push('/login'),
        theme: theme,
        isDark: isDark,
        hasShadow: false,
      );
    }
    return Column(children: [
      _tile(
        icon: FontAwesomeIcons.rightFromBracket,
        iconColor: theme.colorScheme.error,
        title: 'Log Out',
        textColor: theme.colorScheme.error,
        backgroundColor: theme.colorScheme.error.withValues(alpha: 0.05),
        hasShadow: false,
        onTap: () async {
          try {
            await authProvider.signOut();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Logout failed: $e')));
            }
          }
        },
        theme: theme,
        isDark: isDark,
      ),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => context.push('/delete-account'),
        child: Text('Delete Account',
            style: GoogleFonts.nunito(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                fontSize: 13,
                decoration: TextDecoration.underline)),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Shared tile widget
  // ---------------------------------------------------------------------------
  Widget _tile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
    Color? textColor,
    Widget? trailing,
    bool hasShadow = true,
    Color? backgroundColor,
  }) {
    final bg = backgroundColor ??
        (isDark ? AppColors.surfaceElevatedDark : Colors.white);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ]
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: FaIcon(icon, size: 16, color: iconColor),
        ),
        title: Text(title,
            style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor ?? theme.colorScheme.onSurface)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5)))
            : null,
        trailing: trailing ??
            Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                size: 20),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(title.toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45))),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}
