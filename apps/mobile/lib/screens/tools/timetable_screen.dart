import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// Import services
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/glass_card.dart';

// ───────────────────────── Constants ─────────────────────────
const Color _kAccent = Color(0xFF6C63FF);

/// Entry types so the UI can distinguish classes from custom events.
enum _EntryType {
  classEntry('Class', FontAwesomeIcons.bookOpen, _kAccent),
  exam('Exam', FontAwesomeIcons.filePen, Color(0xFFFF6B6B)),
  studySession('Study', FontAwesomeIcons.lightbulb, Color(0xFFFFA726)),
  event('Event', FontAwesomeIcons.calendarCheck, Color(0xFF26A69A));

  final String label;
  final IconData icon;
  final Color color;
  const _EntryType(this.label, this.icon, this.color);
}

// ───────────────────────── Screen ─────────────────────────
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _notificationService.initialize();

    // Default to today's tab
    final todayIndex = DateTime.now().weekday - 1; // 0-indexed Mon
    if (todayIndex < _days.length) {
      _tabController.index = todayIndex;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─────────── Time picker helper ───────────
  Future<TimeOfDay?> _pickTime(BuildContext context, TimeOfDay initial) async {
    return showTimePicker(context: context, initialTime: initial);
  }

  String _formatTime(TimeOfDay t) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat.jm().format(dt); // e.g. "8:00 AM"
  }

  // ─────────── Add / Edit dialog ───────────
  void _showAddEditDialog(BuildContext context, String userId,
      {Map<String, dynamic>? existing, String? existingDay}) {
    final isEditing = existing != null;

    String subject = existing?['subject'] ?? '';
    String selectedDay = existingDay ?? _days[_tabController.index];
    _EntryType type = _EntryType.values.firstWhere(
      (e) => e.name == (existing?['type'] ?? 'classEntry'),
      orElse: () => _EntryType.classEntry,
    );

    TimeOfDay startTime = _parseTimeOfDay(existing?['startTime']) ??
        const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = _parseTimeOfDay(existing?['endTime']) ??
        const TimeOfDay(hour: 9, minute: 0);

    bool notifyEnabled = existing?['notifyEnabled'] ?? true;
    ReminderOffset reminderOffset = ReminderOffset.values.firstWhere(
      (e) => e.name == (existing?['reminderOffset'] ?? 'tenMin'),
      orElse: () => ReminderOffset.tenMin,
    );
    String notes = existing?['notes'] ?? '';

    final subjectCtrl = TextEditingController(text: subject);
    final notesCtrl = TextEditingController(text: notes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final theme = Theme.of(ctx);
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 24,
                right: 24,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEditing ? 'Edit Entry' : 'New Entry',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Type selector chips ──
                    Text('Type',
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _EntryType.values.map((t) {
                        final selected = t == type;
                        return ChoiceChip(
                          label: Text(t.label),
                          avatar: FaIcon(t.icon,
                              size: 14,
                              color: selected ? Colors.white : t.color),
                          selected: selected,
                          selectedColor: t.color,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : t.color,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => setSheetState(() => type = t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // ── Subject / Title ──
                    TextField(
                      controller: subjectCtrl,
                      decoration: InputDecoration(
                        labelText:
                            type == _EntryType.classEntry ? 'Subject' : 'Title',
                        prefixIcon: Icon(Icons.book_rounded, color: type.color),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => subject = v,
                    ),
                    const SizedBox(height: 16),

                    // ── Day ──
                    DropdownButtonFormField<String>(
                      initialValue: selectedDay,
                      items: _days
                          .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setSheetState(() => selectedDay = v!),
                      decoration: InputDecoration(
                        labelText: 'Day',
                        prefixIcon:
                            const Icon(Icons.calendar_today_rounded),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Start / End time ──
                    Row(
                      children: [
                        Expanded(
                          child: _TimeTile(
                            label: 'Starts',
                            value: _formatTime(startTime),
                            onTap: () async {
                              final picked =
                                  await _pickTime(ctx, startTime);
                              if (picked != null) {
                                setSheetState(() => startTime = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeTile(
                            label: 'Ends',
                            value: _formatTime(endTime),
                            onTap: () async {
                              final picked = await _pickTime(ctx, endTime);
                              if (picked != null) {
                                setSheetState(() => endTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Notes (optional) ──
                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: const Icon(Icons.notes_rounded),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (v) => notes = v,
                    ),
                    const SizedBox(height: 20),

                    // ── Notification section ──
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.notifications_active_rounded,
                                  color: notifyEnabled
                                      ? _kAccent
                                      : theme.disabledColor,
                                  size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Reminder Notification',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: notifyEnabled,
                                activeTrackColor: _kAccent,
                                onChanged: (v) =>
                                    setSheetState(() => notifyEnabled = v),
                              ),
                            ],
                          ),
                          if (notifyEnabled) ...[
                            const SizedBox(height: 12),
                            DropdownButtonFormField<ReminderOffset>(
                              initialValue: reminderOffset,
                              items: ReminderOffset.values
                                  .map((r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r.label),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setSheetState(() => reminderOffset = v!),
                              decoration: InputDecoration(
                                labelText: 'Remind me',
                                prefixIcon:
                                    const Icon(Icons.timer_outlined),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Save button ──
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        icon: Icon(isEditing ? Icons.save : Icons.add_rounded),
                        label: Text(isEditing ? 'Save Changes' : 'Add Entry'),
                        style: FilledButton.styleFrom(
                          backgroundColor: type.color,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final subjectText = subjectCtrl.text.trim();
                          if (subjectText.isEmpty) return;

                          _saveEntry(
                            userId: userId,
                            day: selectedDay,
                            subject: subjectText,
                            type: type,
                            startTime: startTime,
                            endTime: endTime,
                            notifyEnabled: notifyEnabled,
                            reminderOffset: reminderOffset,
                            notes: notesCtrl.text.trim(),
                            existingId: existing?['id'],
                            existingNotifIds: existing?['notificationIds'] !=
                                    null
                                ? List<int>.from(existing!['notificationIds'])
                                : (existing?['notificationId'] != null
                                    ? [existing!['notificationId'] as int]
                                    : null),
                            existingDay: existingDay,
                          );
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────── Save entry ───────────
  void _saveEntry({
    required String userId,
    required String day,
    required String subject,
    required _EntryType type,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required bool notifyEnabled,
    required ReminderOffset reminderOffset,
    required String notes,
    String? existingId,
    List<int>? existingNotifIds,
    String? existingDay,
  }) {
    // Cancel old notifications if editing
    if (existingNotifIds != null) {
      _notificationService.cancelNotifications(existingNotifIds);
    }

    // If day changed while editing, remove the old entry
    if (existingId != null && existingDay != null && existingDay != day) {
      FirebaseDatabase.instance
          .ref('users/$userId/timetable/$existingDay/$existingId')
          .remove();
    }

    final ref = existingId != null && (existingDay == null || existingDay == day)
        ? FirebaseDatabase.instance
            .ref('users/$userId/timetable/$day/$existingId')
        : FirebaseDatabase.instance
            .ref('users/$userId/timetable/$day')
            .push();

    final entryKey = existingId ?? ref.key;
    final startStr = _formatTime(startTime);
    final endStr = _formatTime(endTime);

    // Schedule notification(s) if enabled
    List<int> notificationIds = [];
    if (notifyEnabled) {
      final notifId = Random().nextInt(100000);
      notificationIds.add(notifId);

      final label = type == _EntryType.classEntry ? 'class' : type.label.toLowerCase();
      _notificationService.scheduleClassReminder(
        id: notifId,
        title: 'Upcoming: $subject',
        body: 'Your $subject $label starts at $startStr. Get ready!',
        dayName: day,
        timeString: startStr,
        reminderBefore: reminderOffset.duration,
      );
    }

    ref.set({
      'id': entryKey,
      'subject': subject,
      'type': type.name,
      'startTime': startStr,
      'endTime': endStr,
      'notifyEnabled': notifyEnabled,
      'reminderOffset': reminderOffset.name,
      'notificationIds': notificationIds,
      'notes': notes,
      // Keep legacy field for backwards compat
      'notificationId': notificationIds.isNotEmpty ? notificationIds.first : null,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notifyEnabled
                ? '${existingId != null ? "Updated" : "Added"} & reminder set! ⏰'
                : '${existingId != null ? "Updated" : "Added"} (no reminder)',
          ),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // ─────────── Parse "8:00 AM" → TimeOfDay ───────────
  TimeOfDay? _parseTimeOfDay(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(' ');
      final hm = parts[0].split(':');
      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      if (parts.length > 1) {
        if (parts[1].toUpperCase() == 'PM' && hour != 12) hour += 12;
        if (parts[1].toUpperCase() == 'AM' && hour == 12) hour = 0;
      }
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  // ─────────── Build ───────────
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Smart Timetable',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _kAccent,
          unselectedLabelColor: theme.disabledColor,
          isScrollable: true,
          indicatorColor: _kAccent,
          tabs: _days.map((d) {
            final isToday = DateTime.now().weekday ==
                (_days.indexOf(d) + 1);
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.substring(0, 3)),
                  if (isToday) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: _kAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days
            .map((day) => _DayView(
                  userId: user.uid,
                  day: day,
                  onEdit: (entry) =>
                      _showAddEditDialog(context, user.uid,
                          existing: entry, existingDay: day),
                ))
            .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context, user.uid),
        backgroundColor: _kAccent,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ───────────────────────── Time tile widget ─────────────────────────
class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.nunito(
                    fontSize: 12, color: theme.hintColor)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 18),
                const SizedBox(width: 6),
                Text(value,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Day view ─────────────────────────
class _DayView extends StatelessWidget {
  final String userId;
  final String day;
  final void Function(Map<String, dynamic> entry) onEdit;

  const _DayView({
    required this.userId,
    required this.day,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('users/$userId/timetable/$day')
          .onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(
                  'Nothing scheduled. Tap + to add!',
                  style: GoogleFonts.nunito(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final List<Map<String, dynamic>> entries = [];
        for (final child in snapshot.data!.snapshot.children) {
          if (child.value != null && child.value is Map) {
            entries.add(Map<String, dynamic>.from(child.value as Map));
          }
        }

        entries.sort(
          (a, b) =>
              (a['startTime'] as String).compareTo(b['startTime'] as String),
        );

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _EntryCard(
              entry: entry,
              day: day,
              userId: userId,
              onEdit: () => onEdit(entry),
              onToggleNotification: (enabled) =>
                  _toggleNotification(context, entry, day, userId, enabled),
            );
          },
        );
      },
    );
  }

  void _toggleNotification(BuildContext context, Map<String, dynamic> entry,
      String day, String userId, bool enabled) {
    final notificationService = NotificationService();
    final entryId = entry['id'];
    if (entryId == null) return;

    final ref = FirebaseDatabase.instance
        .ref('users/$userId/timetable/$day/$entryId');

    if (!enabled) {
      // Cancel existing notifications
      final notifIds = entry['notificationIds'];
      if (notifIds != null) {
        notificationService
            .cancelNotifications(List<int>.from(notifIds));
      } else if (entry['notificationId'] != null) {
        notificationService.cancelNotification(entry['notificationId']);
      }
      ref.update({'notifyEnabled': false, 'notificationIds': []});
    } else {
      // Re-schedule
      final notifId = Random().nextInt(100000);
      final reminderOffset = ReminderOffset.values.firstWhere(
        (e) => e.name == (entry['reminderOffset'] ?? 'tenMin'),
        orElse: () => ReminderOffset.tenMin,
      );

      final type = _EntryType.values.firstWhere(
        (e) => e.name == (entry['type'] ?? 'classEntry'),
        orElse: () => _EntryType.classEntry,
      );
      final label = type == _EntryType.classEntry
          ? 'class'
          : type.label.toLowerCase();

      notificationService.scheduleClassReminder(
        id: notifId,
        title: 'Upcoming: ${entry['subject']}',
        body:
            'Your ${entry['subject']} $label starts at ${entry['startTime']}. Get ready!',
        dayName: day,
        timeString: entry['startTime'],
        reminderBefore: reminderOffset.duration,
      );

      ref.update({
        'notifyEnabled': true,
        'notificationIds': [notifId],
        'notificationId': notifId,
      });
    }
  }
}

// ───────────────────────── Entry card ─────────────────────────
class _EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String day;
  final String userId;
  final VoidCallback onEdit;
  final void Function(bool enabled) onToggleNotification;

  const _EntryCard({
    required this.entry,
    required this.day,
    required this.userId,
    required this.onEdit,
    required this.onToggleNotification,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = _EntryType.values.firstWhere(
      (e) => e.name == (entry['type'] ?? 'classEntry'),
      orElse: () => _EntryType.classEntry,
    );
    final notifyEnabled = entry['notifyEnabled'] ?? true;
    final reminderOffset = ReminderOffset.values.firstWhere(
      (e) => e.name == (entry['reminderOffset'] ?? 'tenMin'),
      orElse: () => ReminderOffset.tenMin,
    );
    final notes = entry['notes'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: type.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: FaIcon(type.icon, color: type.color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    // Title + time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry['subject'] ?? 'Unknown',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${entry['startTime']} – ${entry['endTime']}',
                            style: GoogleFonts.nunito(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: type.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type.label,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: type.color,
                        ),
                      ),
                    ),
                  ],
                ),

                // Notes
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    notes,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 10),
                // Bottom row: notification info + actions
                Row(
                  children: [
                    // Notification indicator
                    InkWell(
                      onTap: () => onToggleNotification(!notifyEnabled),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: notifyEnabled
                              ? _kAccent.withValues(alpha: 0.08)
                              : theme.disabledColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              notifyEnabled
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_off_outlined,
                              size: 14,
                              color: notifyEnabled
                                  ? _kAccent
                                  : theme.disabledColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              notifyEnabled
                                  ? reminderOffset.label
                                  : 'No reminder',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: notifyEnabled
                                    ? _kAccent
                                    : theme.disabledColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Delete button
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 20),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Entry',
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: Text(
            'Remove "${entry['subject'] ?? 'this entry'}" from your timetable?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Cancel notifications
              final notifIds = entry['notificationIds'];
              if (notifIds != null) {
                NotificationService()
                    .cancelNotifications(List<int>.from(notifIds));
              } else if (entry['notificationId'] != null) {
                NotificationService()
                    .cancelNotification(entry['notificationId']);
              }
              // Delete from DB
              if (entry['id'] != null) {
                FirebaseDatabase.instance
                    .ref('users/$userId/timetable/$day/${entry['id']}')
                    .remove();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
