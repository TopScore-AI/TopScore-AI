import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math';

import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

// ---------------------------------------------------------------------------
// Subject color palette — cycles through these for visual variety
// ---------------------------------------------------------------------------
const _subjectColors = [
  Color(0xFF6C63FF), Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFFFFD93D),
  Color(0xFF43A047), Color(0xFFE91E63), Color(0xFF00BCD4), Color(0xFFFF7043),
  Color(0xFF8E24AA), Color(0xFF00897B),
];

Color _colorForSubject(String subject) {
  final hash = subject.codeUnits.fold(0, (a, b) => a + b);
  return _subjectColors[hash % _subjectColors.length];
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService = NotificationService();

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _notificationService.initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addClass(BuildContext context, String userId) async {
    String subject = '';
    String selectedDay = _days[_tabController.index];
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 9, minute: 0);

    await showDialog(
      context: context,
      builder: (ctx) => _AddClassDialog(
        days: _days,
        initialDay: selectedDay,
        onSave: (s, day, start, end) {
          subject = s;
          selectedDay = day;
          startTime = start;
          endTime = end;
        },
      ),
    );

    if (subject.isEmpty) return;

    // Format times before any async gap
    final startStr = startTime.format(context); // ignore: use_build_context_synchronously
    final endStr = endTime.format(context); // ignore: use_build_context_synchronously
    final notificationId = Random().nextInt(100000);
    final newKey = FirebaseDatabase.instance.ref('users/$userId/timetable/$selectedDay').push().key;

    if (newKey != null) {
      await FirebaseDatabase.instance.ref('users/$userId/timetable/$selectedDay/$newKey').set({
        'id': newKey,
        'notificationId': notificationId,
        'subject': subject,
        'startTime': startStr,
        'endTime': endStr,
      });
      _notificationService.scheduleClassReminder(
        id: notificationId,
        title: 'Upcoming: $subject',
        body: 'Your $subject class starts at $startStr. Get ready!',
        dayName: selectedDay,
        timeString: startStr,
      );
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class added & reminder set ⏰'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Timetable', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: theme.disabledColor,
          indicatorColor: const Color(0xFF6C63FF),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _days.map((d) => Tab(text: d.substring(0, 3))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days.map((day) => _DayTimeline(userId: user.uid, day: day)).toList(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addClass(context, user.uid),
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Class', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add class dialog with time pickers
// ---------------------------------------------------------------------------
class _AddClassDialog extends StatefulWidget {
  final List<String> days;
  final String initialDay;
  final void Function(String subject, String day, TimeOfDay start, TimeOfDay end) onSave;

  const _AddClassDialog({required this.days, required this.initialDay, required this.onSave});

  @override
  State<_AddClassDialog> createState() => _AddClassDialogState();
}

class _AddClassDialogState extends State<_AddClassDialog> {
  final _subjectCtrl = TextEditingController();
  late String _selectedDay;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay;
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) { _startTime = picked; }
        else { _endTime = picked; }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Add Class', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _subjectCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Subject',
              prefixIcon: const Icon(Icons.book_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedDay,
            decoration: InputDecoration(
              labelText: 'Day',
              prefixIcon: const Icon(Icons.calendar_today_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: widget.days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => _selectedDay = v!),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _timeTile('Start', _startTime, () => _pickTime(true), theme)),
            const SizedBox(width: 12),
            Expanded(child: _timeTile('End', _endTime, () => _pickTime(false), theme)),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_subjectCtrl.text.trim().isEmpty) return;
            widget.onSave(_subjectCtrl.text.trim(), _selectedDay, _startTime, _endTime);
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6C63FF)),
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _timeTile(String label, TimeOfDay time, VoidCallback onTap, ThemeData theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(time.format(context), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day timeline view
// ---------------------------------------------------------------------------
class _DayTimeline extends StatelessWidget {
  final String userId;
  final String day;

  const _DayTimeline({required this.userId, required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('users/$userId/timetable/$day').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.calendar_today_rounded, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('No classes on $day', style: GoogleFonts.nunito(color: Colors.grey[500], fontSize: 16)),
              const SizedBox(height: 4),
              Text('Tap + to add a class', style: GoogleFonts.nunito(color: Colors.grey[400], fontSize: 13)),
            ]),
          );
        }

        final List<Map<String, dynamic>> classes = [];
        for (final child in snapshot.data!.snapshot.children) {
          // ignore: deprecated_member_use
          if (child.value != null && child.value is Map) {
            // ignore: deprecated_member_use
            classes.add(Map<String, dynamic>.from(child.value as Map));
          }
        }
        classes.sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final cls = classes[index];
            final subject = cls['subject'] as String? ?? 'Unknown';
            final color = _colorForSubject(subject);
            final isFirst = index == 0;
            final isLast = index == classes.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Timeline column
                  SizedBox(
                    width: 48,
                    child: Column(children: [
                      // Top connector
                      if (!isFirst)
                        Expanded(child: Center(child: Container(width: 2, color: Colors.grey[300])))
                      else
                        const SizedBox(height: 8),
                      // Dot
                      Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6)]),
                      ),
                      // Bottom connector
                      if (!isLast)
                        Expanded(child: Center(child: Container(width: 2, color: Colors.grey[300])))
                      else
                        const SizedBox(height: 8),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  // Card
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border(left: BorderSide(color: color, width: 4)),
                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(subject, style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text('${cls['startTime']} – ${cls['endTime']}',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
                            ]),
                          ])),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                            onPressed: () {
                              if (cls['notificationId'] != null) {
                                NotificationService().cancelNotification(cls['notificationId']);
                              }
                              if (cls['id'] != null) {
                                FirebaseDatabase.instance
                                    .ref('users/$userId/timetable/$day/${cls['id']}')
                                    .remove();
                              }
                            },
                          ),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
