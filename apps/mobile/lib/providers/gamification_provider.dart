import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/streak_service.dart';
import '../services/xp_service.dart';

/// Reactive provider for streak + XP state.
/// Attach to the widget tree once (in main.dart) and read anywhere.
class GamificationProvider with ChangeNotifier {
  static final GamificationProvider instance = GamificationProvider._();
  GamificationProvider._();

  final StreakService _streakService = StreakService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── State ────────────────────────────────────────────────────────────────────
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _weeklyProgress = 0;
  int _totalActiveDays = 0;
  int _totalXp = 0;
  int _level = 1;
  bool _isLoading = false;
  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<DocumentSnapshot>? _streakSub;

  // Level-up event stream — UI layers listen to this to show the overlay.
  final StreamController<int> _levelUpController =
      StreamController<int>.broadcast();

  // ── Getters ──────────────────────────────────────────────────────────────────
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get weeklyProgress => _weeklyProgress;
  int get totalActiveDays => _totalActiveDays;
  int get totalXp => _totalXp;
  int get level => _level;
  bool get isLoading => _isLoading;
  int get xpToNextLevel => XpService.xpToNextLevel(_totalXp);

  /// Emits the new level number whenever the user levels up.
  Stream<int> get onLevelUp => _levelUpController.stream;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Call once after the user signs in.
  /// Safe to call multiple times — re-subscribes only if the UID changes.
  void startListening(String uid) {
    // Already listening for this user — don't create duplicate subscriptions.
    if (_userSub != null) return;

    _isLoading = true;
    notifyListeners();

    // Real-time listener on user doc for XP/level
    _userSub = _db.collection('users').doc(uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      _totalXp = (data['xp'] as int?) ?? 0;
      _level = (data['level'] as int?) ?? XpService.levelForXp(_totalXp);
      _isLoading = false;
      notifyListeners();
    });

    // Real-time listener on streak doc
    _streakSub =
        _db.collection('user_streaks').doc(uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final result = StreakResult.fromFirestore(snap.data()!);
      _currentStreak = result.currentStreak;
      _longestStreak = result.longestStreak;
      _weeklyProgress = result.weeklyProgress;
      _totalActiveDays = result.totalActiveDays;
      notifyListeners();
    });
  }

  void stopListening() {
    _userSub?.cancel();
    _streakSub?.cancel();
    _userSub = null;
    _streakSub = null;
    _reset();
  }

  // ── Activity recording ───────────────────────────────────────────────────────

  /// Records an activity, updates Firestore, and returns the result.
  /// The real-time listeners will automatically update the UI.
  /// [ActivityType.appVisit] is debounced to once per 30 minutes.
  /// Emits on [onLevelUp] if the user leveled up.
  Future<StreakResult> record(String uid, ActivityType type) async {
    if (!XpService.shouldRecordActivity(type)) {
      return StreakResult.empty();
    }
    if (type == ActivityType.appVisit) XpService.markAppVisitRecorded();

    final result = await _streakService.recordActivity(uid, type);
    if (result.leveledUp && !_levelUpController.isClosed) {
      _levelUpController.add(result.newLevel);
    }
    return result;
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _streakSub?.cancel();
    _levelUpController.close();
    super.dispose();
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  void _reset() {
    _currentStreak = 0;
    _longestStreak = 0;
    _weeklyProgress = 0;
    _totalActiveDays = 0;
    _totalXp = 0;
    _level = 1;
    _isLoading = false;
    notifyListeners();
  }
}
