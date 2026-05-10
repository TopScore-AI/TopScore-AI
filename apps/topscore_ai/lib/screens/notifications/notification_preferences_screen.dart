import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../widgets/app_spinner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_headers.dart';
import '../../services/notification_service.dart';

// SharedPreferences keys for local persistence
const _kStudyReminders = 'notif_study_reminders';
const _kMorningReminders = 'notif_morning_reminders';
const _kStreakReminders = 'notif_streak_reminders';
const _kSubscriptionAlerts = 'notif_subscription_alerts';
const _kQuietStart = 'notif_quiet_start';
const _kQuietEnd = 'notif_quiet_end';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  // Prefs
  bool _studyReminders = true;
  bool _morningReminders = true;
  bool _streakReminders = true;
  bool _subscriptionAlerts = true;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // ── Load: local cache first, then backend ──────────────────────────────────

  Future<void> _loadPreferences() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    // 1. Load from local cache immediately so the UI is never blank
    await _loadFromLocal();

    // 2. Try to sync from backend in the background
    try {
      final headers = await AuthHeaders.getHeaders();
      final resp = await http
          .get(
            Uri.parse('${AppConfig.backendBaseUrl}/notifications/preferences'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _studyReminders = data['study_reminders'] ?? _studyReminders;
            _morningReminders = data['morning_reminders'] ?? _morningReminders;
            _streakReminders = data['streak_reminders'] ?? _streakReminders;
            _subscriptionAlerts =
                data['subscription_alerts'] ?? _subscriptionAlerts;
            _quietStart =
                _parseTime(data['quiet_start'] ?? _formatTime(_quietStart));
            _quietEnd = _parseTime(data['quiet_end'] ?? _formatTime(_quietEnd));
          });
          // Keep local cache in sync with backend
          await _saveToLocal();
        }
      }
    } catch (e) {
      // Non-fatal — local cache is already loaded, just note the sync failed
      if (mounted) {
        setState(() => _loadError =
            'Could not sync with server. Showing saved preferences.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _studyReminders = prefs.getBool(_kStudyReminders) ?? true;
          _morningReminders = prefs.getBool(_kMorningReminders) ?? true;
          _streakReminders = prefs.getBool(_kStreakReminders) ?? true;
          _subscriptionAlerts = prefs.getBool(_kSubscriptionAlerts) ?? true;
          _quietStart = _parseTime(prefs.getString(_kQuietStart) ?? '22:00');
          _quietEnd = _parseTime(prefs.getString(_kQuietEnd) ?? '07:00');
        });
      }
    } catch (_) {}
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kStudyReminders, _studyReminders);
      await prefs.setBool(_kMorningReminders, _morningReminders);
      await prefs.setBool(_kStreakReminders, _streakReminders);
      await prefs.setBool(_kSubscriptionAlerts, _subscriptionAlerts);
      await prefs.setString(_kQuietStart, _formatTime(_quietStart));
      await prefs.setString(_kQuietEnd, _formatTime(_quietEnd));
    } catch (_) {}
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);

    // 1. Apply local scheduled notifications immediately — this always works
    try {
      await NotificationService().applyPreferences(
        morningReminders: _morningReminders,
        studyReminders: _studyReminders,
        streakReminders: _streakReminders,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update local notifications: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // 2. Persist locally so prefs survive app restarts without network
    await _saveToLocal();

    // 2b. Force a token re-sync to ensure the backend has the latest target
    // for these new preferences.
    if (mounted) {
      unawaited(Provider.of<AuthProvider>(context, listen: false).forceSyncFCMToken());
    }

    // 3. Sync to backend (best-effort)
    bool backendSaved = false;
    try {
      final headers = await AuthHeaders.getHeaders();
      final resp = await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/notifications/preferences'),
            headers: headers,
            body: jsonEncode({
              'study_reminders': _studyReminders,
              'morning_reminders': _morningReminders,
              'streak_reminders': _streakReminders,
              'subscription_alerts': _subscriptionAlerts,
              'quiet_start': _formatTime(_quietStart),
              'quiet_end': _formatTime(_quietEnd),
            }),
          )
          .timeout(const Duration(seconds: 8));
      backendSaved = resp.statusCode == 200;
    } catch (_) {}

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(backendSaved
              ? 'Notification preferences saved ✓'
              : 'Saved locally. Will sync when online.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ── Test notification ──────────────────────────────────────────────────────

  Future<void> _sendTest() async {
    try {
      final headers = await AuthHeaders.getHeaders();
      // Include the current FCM token so the backend can send even if the
      // profile token hasn't been registered yet.
      final fcmToken = await NotificationService().getToken();
      final resp = await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/notifications/test'),
            headers: headers,
            body: jsonEncode({
              if (fcmToken != null) 'fcm_token': fcmToken,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent! Check your device 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed (${resp.statusCode}). Make sure notifications are enabled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 22,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietStart : _quietEnd,
      helpText: isStart ? 'Quiet hours start' : 'Quiet hours end',
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _quietStart = picked;
        } else {
          _quietEnd = picked;
        }
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text('Notifications',
            style:
                GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          TextButton(
            onPressed: _saving || _loading ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16, height: 16, child: AppSpinner(strokeWidth: 2))
                : Text('Save',
                    style: GoogleFonts.inter(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _loading
          ? _buildShimmerLoading(context)
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // Sync error banner
                if (_loadError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_loadError!,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.orange.shade800)),
                      ),
                    ]),
                  ),

                _sectionLabel('Push Notifications', theme),
                _switchTile(
                  icon: Icons.wb_sunny_rounded,
                  iconColor: Colors.amber,
                  title: 'Morning Boost',
                  subtitle: 'Weekend motivation at 9:00 AM',
                  value: _morningReminders,
                  onChanged: (v) => setState(() => _morningReminders = v),
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _switchTile(
                  icon: Icons.school_rounded,
                  iconColor: AppColors.primary,
                  title: 'Study Reminders',
                  subtitle: 'Weekdays at 4:00 PM, 6:00 PM & Weekends at 1:00 PM, 6:00 PM',
                  value: _studyReminders,
                  onChanged: (v) => setState(() => _studyReminders = v),
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _switchTile(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.deepOrange,
                  title: 'Streak Reminders',
                  subtitle: 'Weekdays at 7:30 PM & Weekends at 8:00 PM',
                  value: _streakReminders,
                  onChanged: (v) => setState(() => _streakReminders = v),
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _switchTile(
                  icon: Icons.workspace_premium_rounded,
                  iconColor: Colors.amber.shade700,
                  title: 'Subscription Alerts',
                  subtitle: 'Renewal reminders and upgrade tips',
                  value: _subscriptionAlerts,
                  onChanged: (v) => setState(() => _subscriptionAlerts = v),
                  theme: theme,
                  isDark: isDark,
                ),
                const SizedBox(height: 24),
                _sectionLabel('Quiet Hours', theme),
                Text(
                  'No notifications will be sent during quiet hours.',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _timeTile(
                      label: 'Start',
                      time: _quietStart,
                      onTap: () => _pickTime(true),
                      theme: theme,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _timeTile(
                      label: 'End',
                      time: _quietEnd,
                      onTap: () => _pickTime(false),
                      theme: theme,
                      isDark: isDark,
                    ),
                  ),
                ]),
                const SizedBox(height: 32),
                if (auth.userModel != null)
                  OutlinedButton.icon(
                    onPressed: _sendTest,
                    icon: const Icon(Icons.notifications_active_rounded),
                    label: Text('Send Test Notification',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.4)),
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                letterSpacing: 0.8)),
      );

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: theme.colorScheme.primary,
        ),
      ]),
    );
  }

  Widget _timeTile({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceElevatedDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.access_time_rounded,
                size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(time.format(context),
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.white.withValues(alpha: 0.16) : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Section header shimmer
          Container(
            height: 12,
            width: 80,
            margin: const EdgeInsets.only(bottom: 12, top: 12, right: 250),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // 4 switch tiles shimmers
          for (int i = 0; i < 4; i++) ...[
            Container(
              height: 72,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
          const SizedBox(height: 14),
          // Quiet hours section header shimmer
          Container(
            height: 12,
            width: 100,
            margin: const EdgeInsets.only(bottom: 8, right: 230),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            height: 12,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16, right: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Two time tile shimmers
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
