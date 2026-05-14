import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent gamification state for Language Buddy:
/// - daily streak (advances when XP earned on a new local date)
/// - daily XP (resets at local-tz date rollover)
/// - hearts (max 5, slow refill 1 per hour)
/// - per-language lesson-tree node unlock state
class BuddyProgressService extends ChangeNotifier {
  BuddyProgressService._();
  static final BuddyProgressService instance = BuddyProgressService._();

  static const _kStreak = 'buddy_streak';
  static const _kLastActiveDate = 'buddy_last_date';
  static const _kDailyXp = 'buddy_daily_xp';
  static const _kHearts = 'buddy_hearts';
  static const _kHeartsTs = 'buddy_hearts_ts';
  static const int maxHearts = 5;
  static const int dailyGoal = 50;

  int _streak = 0;
  int _dailyXp = 0;
  int _hearts = maxHearts;
  String _lastDate = '';
  bool _loaded = false;

  int get streak => _streak;
  int get dailyXp => _dailyXp;
  int get hearts => _hearts;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final p = await SharedPreferences.getInstance();
    _streak = p.getInt(_kStreak) ?? 0;
    _dailyXp = p.getInt(_kDailyXp) ?? 0;
    _hearts = p.getInt(_kHearts) ?? maxHearts;
    _lastDate = p.getString(_kLastActiveDate) ?? '';
    _refillHearts(p);
    _rolloverIfNeeded(p);
    _loaded = true;
    notifyListeners();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void _rolloverIfNeeded(SharedPreferences p) {
    final today = _todayKey();
    if (_lastDate.isEmpty) {
      _lastDate = today;
      p.setString(_kLastActiveDate, today);
      return;
    }
    if (_lastDate != today) {
      // New local-tz date — reset daily XP. Streak only kept if yesterday was active.
      final yesterday = _yesterdayKey();
      if (_lastDate != yesterday) {
        _streak = 0;
      }
      _dailyXp = 0;
      _lastDate = today;
      p.setInt(_kDailyXp, 0);
      p.setInt(_kStreak, _streak);
      p.setString(_kLastActiveDate, today);
    }
  }

  String _yesterdayKey() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }

  Future<void> _refillHearts(SharedPreferences p) async {
    if (_hearts >= maxHearts) return;
    final lastTs = p.getInt(_kHeartsTs) ?? DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - lastTs;
    final hoursElapsed = elapsedMs ~/ (1000 * 60 * 60);
    if (hoursElapsed > 0) {
      _hearts = (_hearts + hoursElapsed).clamp(0, maxHearts);
      await p.setInt(_kHearts, _hearts);
      await p.setInt(_kHeartsTs, DateTime.now().millisecondsSinceEpoch);
    }
  }

  Future<void> addXp(int amount) async {
    final p = await SharedPreferences.getInstance();
    _rolloverIfNeeded(p);
    final hadXpToday = _dailyXp > 0;
    _dailyXp += amount;
    if (!hadXpToday) {
      // First XP of the day — bump streak
      _streak += 1;
      await p.setInt(_kStreak, _streak);
    }
    await p.setInt(_kDailyXp, _dailyXp);
    notifyListeners();
  }

  Future<void> loseHeart() async {
    final p = await SharedPreferences.getInstance();
    if (_hearts <= 0) return;
    _hearts -= 1;
    await p.setInt(_kHearts, _hearts);
    await p.setInt(_kHeartsTs, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> restoreHearts() async {
    final p = await SharedPreferences.getInstance();
    _hearts = maxHearts;
    await p.setInt(_kHearts, _hearts);
    notifyListeners();
  }

  // ── Lesson tree node unlocks ──────────────────────────────────────────────
  String _nodeKey(String language, int index) =>
      'buddy_node_${language.toLowerCase()}_$index';

  Future<bool> isNodeCompleted(String language, int index) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_nodeKey(language, index)) ?? false;
  }

  Future<void> markNodeCompleted(String language, int index) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_nodeKey(language, index), true);
    notifyListeners();
  }

  Future<int> currentNodeIndex(String language, int totalNodes) async {
    final p = await SharedPreferences.getInstance();
    for (var i = 0; i < totalNodes; i++) {
      if (!(p.getBool(_nodeKey(language, i)) ?? false)) return i;
    }
    return totalNodes;
  }
}
