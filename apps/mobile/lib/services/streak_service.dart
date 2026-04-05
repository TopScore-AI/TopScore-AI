import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'xp_service.dart';

/// Manages daily learning streaks and awards XP for every tracked activity.
///
/// Firestore layout:
///   user_streaks/{uid}
///     currentStreak     int
///     longestStreak     int
///     lastActiveDate    String  (ISO date, e.g. "2026-03-31")
///     weeklyActiveDays  `List<String>`  (ISO dates of active days this week)
///     totalActiveDays   int
///     updatedAt         Timestamp
class StreakService {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final XpService _xp = XpService();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Call this on every meaningful user action.
  /// Updates streak, awards XP, and returns the current [StreakResult].
  /// USES A SINGLE TRANSACTION for atomicity and to prevent 'FAILED_PRECONDITION' errors.
  Future<StreakResult> recordActivity(String uid, ActivityType type) async {
    final streakRef = _db.collection('user_streaks').doc(uid);
    final userRef = _db.collection('users').doc(uid);
    final now = DateTime.now();
    final todayStr = _dateStr(now);
    final xpGain = XpService.xpTable[type] ?? 0;

    try {
      return await _db.runTransaction<StreakResult>((tx) async {
        // 1. AWARD XP (Inside the transaction)
        final xpResult = await XpService.performXpUpdateTransaction(
          tx: tx,
          userRef: userRef,
          xpGain: xpGain,
        );

        // 2. UPDATE STREAK (Inside the same transaction)
        final snap = await tx.get(streakRef);
        StreakResult result;

        if (!snap.exists) {
          result = StreakResult(
            currentStreak: 1,
            longestStreak: 1,
            weeklyActiveDays: [todayStr],
            totalActiveDays: 1,
            isNewDay: true,
          );
          tx.set(streakRef, _toFirestore(result, todayStr));
        } else {
          final data = snap.data()!;
          final lastActiveStr = data['lastActiveDate'] as String?;
          final currentStreak = (data['currentStreak'] as int?) ?? 0;
          final longestStreak = (data['longestStreak'] as int?) ?? 0;
          final totalActiveDays = (data['totalActiveDays'] as int?) ?? 0;
          final rawWeekly = data['weeklyActiveDays'];
          final weeklyActiveDays =
              rawWeekly is List ? List<String>.from(rawWeekly) : <String>[];

          if (lastActiveStr == todayStr) {
            result = StreakResult(
              currentStreak: currentStreak,
              longestStreak: longestStreak,
              weeklyActiveDays: _pruneWeekly(weeklyActiveDays, now),
              totalActiveDays: totalActiveDays,
              isNewDay: false,
            );
          } else {
            int newStreak;
            if (lastActiveStr != null) {
              final lastDate = DateTime.parse(lastActiveStr);
              final diff = _daysBetween(lastDate, now);
              newStreak = diff == 1 ? currentStreak + 1 : 1;
            } else {
              newStreak = 1;
            }

            final newLongest =
                newStreak > longestStreak ? newStreak : longestStreak;
            final newWeekly =
                _pruneWeekly([...weeklyActiveDays, todayStr], now);
            final newTotal = totalActiveDays + 1;

            result = StreakResult(
              currentStreak: newStreak,
              longestStreak: newLongest,
              weeklyActiveDays: newWeekly,
              totalActiveDays: newTotal,
              isNewDay: true,
            );
          }
          tx.update(streakRef, _toFirestore(result, todayStr));
        }

        // Return combined result
        return result.copyWith(
          xpGained: xpResult.xpGained,
          totalXp: xpResult.totalXp,
          leveledUp: xpResult.leveledUp,
          newLevel: xpResult.newLevel,
        );
      });
    } catch (e) {
      if (kDebugMode) debugPrint('StreakService.recordActivity error: $e');

      // Fallback: Try at least awarding XP if the mega-transaction fails
      if (xpGain > 0) {
        await _xp.awardXp(uid, type);
      }

      return StreakResult.empty();
    }
  }

  /// Read-only snapshot of the current streak data.
  Future<StreakResult> getStreakData(String uid) async {
    try {
      final doc = await _db.collection('user_streaks').doc(uid).get();
      if (!doc.exists) return StreakResult.empty();
      return StreakResult.fromFirestore(doc.data()!);
    } catch (e) {
      return StreakResult.empty();
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  String _dateStr(DateTime dt) => _dateFmt.format(dt);

  int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  /// Keep only dates within the current calendar week (Mon–Sun).
  List<String> _pruneWeekly(List<String> days, DateTime now) {
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    return days
        .where((d) {
          final dt = DateTime.tryParse(d);
          return dt != null && !dt.isBefore(weekStart);
        })
        .toSet()
        .toList();
  }

  Map<String, dynamic> _toFirestore(StreakResult r, String todayStr) => {
        'currentStreak': r.currentStreak,
        'longestStreak': r.longestStreak,
        'lastActiveDate': todayStr,
        'weeklyActiveDays': r.weeklyActiveDays,
        'totalActiveDays': r.totalActiveDays,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

// ── Data class ───────────────────────────────────────────────────────────────

class StreakResult {
  final int currentStreak;
  final int longestStreak;
  final List<String> weeklyActiveDays;
  final int totalActiveDays;
  final bool isNewDay;
  final int xpGained;
  final int totalXp;
  final bool leveledUp;
  final int newLevel;

  const StreakResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.weeklyActiveDays,
    required this.totalActiveDays,
    this.isNewDay = false,
    this.xpGained = 0,
    this.totalXp = 0,
    this.leveledUp = false,
    this.newLevel = 1,
  });

  factory StreakResult.empty() => const StreakResult(
        currentStreak: 0,
        longestStreak: 0,
        weeklyActiveDays: [],
        totalActiveDays: 0,
      );

  factory StreakResult.fromFirestore(Map<String, dynamic> data) {
    final rawWeekly = data['weeklyActiveDays'];
    return StreakResult(
      currentStreak: (data['currentStreak'] as int?) ?? 0,
      longestStreak: (data['longestStreak'] as int?) ?? 0,
      weeklyActiveDays: rawWeekly is List ? List<String>.from(rawWeekly) : [],
      totalActiveDays: (data['totalActiveDays'] as int?) ?? 0,
    );
  }

  StreakResult copyWith({
    int? currentStreak,
    int? longestStreak,
    List<String>? weeklyActiveDays,
    int? totalActiveDays,
    bool? isNewDay,
    int? xpGained,
    int? totalXp,
    bool? leveledUp,
    int? newLevel,
  }) =>
      StreakResult(
        currentStreak: currentStreak ?? this.currentStreak,
        longestStreak: longestStreak ?? this.longestStreak,
        weeklyActiveDays: weeklyActiveDays ?? this.weeklyActiveDays,
        totalActiveDays: totalActiveDays ?? this.totalActiveDays,
        isNewDay: isNewDay ?? this.isNewDay,
        xpGained: xpGained ?? this.xpGained,
        totalXp: totalXp ?? this.totalXp,
        leveledUp: leveledUp ?? this.leveledUp,
        newLevel: newLevel ?? this.newLevel,
      );

  /// Number of active days in the current week (Mon–Sun).
  int get weeklyProgress => weeklyActiveDays.length;
}
