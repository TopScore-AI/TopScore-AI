import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'offline_service.dart';

/// XP values awarded per activity type.
/// All Firestore writes use transactions to prevent race conditions.
class XpService {
  static final XpService _instance = XpService._internal();
  factory XpService() => _instance;
  XpService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── XP table ────────────────────────────────────────────────────────────────
  static const Map<ActivityType, int> xpTable = {
    ActivityType.appVisit: 5,
    ActivityType.aiTutorMessage: 10,
    ActivityType.fileInteraction: 8,
    ActivityType.quizGenerated: 15,
    ActivityType.quizCompleted: 20,
    ActivityType.flashcardsGenerated: 15,
    ActivityType.flashcardsStudied: 12,
  };

  // ── Level thresholds (cumulative XP needed) ─────────────────────────────────
  static const List<int> levelThresholds = [
    0, // Level 1
    100, // Level 2
    250, // Level 3
    500, // Level 4
    900, // Level 5
    1400, // Level 6
    2000, // Level 7
    2800, // Level 8
    3800, // Level 9
    5000, // Level 10
  ];

  // Prestige levels beyond 10 — each prestige adds 2000 XP to the threshold.
  static const int _prestigeXpStep = 2000;

  static int levelForXp(int xp) {
    for (int i = levelThresholds.length - 1; i >= 0; i--) {
      if (xp >= levelThresholds[i]) {
        final baseLevel = i + 1;
        if (baseLevel < levelThresholds.length) return baseLevel;
        // At max base level — calculate prestige levels
        final xpBeyondMax = xp - levelThresholds.last;
        final prestigeLevels = xpBeyondMax ~/ _prestigeXpStep;
        return levelThresholds.length + prestigeLevels;
      }
    }
    return 1;
  }

  static int xpToNextLevel(int xp) {
    final level = levelForXp(xp);
    if (level < levelThresholds.length) {
      return levelThresholds[level] - xp;
    }
    // Prestige: next threshold is next multiple of _prestigeXpStep beyond max
    final xpBeyondMax = xp - levelThresholds.last;
    final nextPrestigeXp =
        ((xpBeyondMax ~/ _prestigeXpStep) + 1) * _prestigeXpStep;
    return (levelThresholds.last + nextPrestigeXp) - xp;
  }

  /// Returns true if [type] should be recorded now, false if it was already
  /// recorded within the debounce window (only applies to [ActivityType.appVisit]).
  static bool shouldRecordActivity(ActivityType type) {
    if (type != ActivityType.appVisit) return true;
    final lastMs = OfflineService().getLastAppVisitMs();
    if (lastMs == null) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
    // Debounce: only award appVisit XP once per 30 minutes
    return elapsed > const Duration(minutes: 30).inMilliseconds;
  }

  /// Mark the current time as the last app-visit XP award.
  static void markAppVisitRecorded() {
    OfflineService().setLastAppVisitMs(DateTime.now().millisecondsSinceEpoch);
  }

  /// Deep-level logic for awarding XP within an existing transaction.
  /// This is the primary way to avoid 'FAILED_PRECONDITION' errors by grouping
  /// multiple logical updates (XP + Streaks) into one Firestore commit.
  static Future<XpResult> performXpUpdateTransaction({
    required Transaction tx,
    required DocumentReference userRef,
    required int xpGain,
  }) async {
    final snap = await tx.get(userRef);
    final currentXp =
        (snap.data() as Map<String, dynamic>?)?['xp'] as int? ?? 0;

    final newXp = currentXp + xpGain;
    final oldLevel = levelForXp(currentXp);
    final newLevel = levelForXp(newXp);

    tx.set(
      userRef,
      {
        'xp': newXp,
        'level': newLevel,
        'lastActivityAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return XpResult(
      xpGained: xpGain,
      totalXp: newXp,
      newLevel: newLevel,
      leveledUp: newLevel > oldLevel,
    );
  }

  /// Awards XP for an activity.
  /// NOTE: Prefer calling StreakService.recordActivity which uses a combined transaction.
  Future<XpResult> awardXp(String uid, ActivityType type) async {
    final xpGain = xpTable[type] ?? 0;
    if (xpGain == 0) return XpResult(xpGained: 0, totalXp: 0, newLevel: 1);

    final userRef = _db.collection('users').doc(uid);

    try {
      return await _db.runTransaction<XpResult>((tx) async {
        return await performXpUpdateTransaction(
          tx: tx,
          userRef: userRef,
          xpGain: xpGain,
        );
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'XpService.awardXp transaction failed, falling back to atomic increment: $e');
      }

      // FALLBACK: If transaction fails (e.g. high contention), use atomic increment
      // to ensure XP is at least recorded, even if level calculation lags.
      try {
        await userRef.update({
          'xp': FieldValue.increment(xpGain),
          'lastActivityAt': FieldValue.serverTimestamp(),
        });
      } catch (e2) {
        if (kDebugMode) debugPrint('XpService fallback also failed: $e2');
      }

      return XpResult(xpGained: xpGain, totalXp: 0, newLevel: 0);
    }
  }
}

enum ActivityType {
  appVisit,
  aiTutorMessage,
  fileInteraction,
  quizGenerated,
  quizCompleted,
  flashcardsGenerated,
  flashcardsStudied,
}

class XpResult {
  final int xpGained;
  final int totalXp;
  final int newLevel;
  final bool leveledUp;

  const XpResult({
    required this.xpGained,
    required this.totalXp,
    required this.newLevel,
    this.leveledUp = false,
  });
}
