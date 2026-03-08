import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Service to handle synchronization of app data with native home screen widgets.
class WidgetDataService {
  // App Group for iOS (must match Xcode capability)
  static const String _appGroup = 'group.ai.topscore.widgets';
  static const String _androidWidgetName = 'TopScoreStreakWidget';
  static const String _iosWidgetName = 'TopScoreStreakWidget';

  /// Updates the streak data displayed on the home screen widget.
  static Future<void> updateStreakWidget({
    required int streakCount,
    required double dayProgress,
  }) async {
    try {
      // 1. Save data to shared storage accessible by the widget
      await HomeWidget.saveWidgetData<int>('streak_count', streakCount);
      await HomeWidget.saveWidgetData<double>('day_progress', dayProgress);

      // 2. Notify the platform to update the widget UI
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );

      debugPrint(
          "✅ Widget data updated: Streak $streakCount, Progress $dayProgress");
    } catch (e) {
      debugPrint("❌ Error updating widget data: $e");
    }
  }

  /// Optional: Set the app group for iOS if needed
  static Future<void> setup() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await HomeWidget.setAppGroupId(_appGroup);
    }
  }
}
