import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:home_widget/home_widget.dart';
import 'package:go_router/go_router.dart';

class LauncherService {
  static final LauncherService instance = LauncherService._internal();
  LauncherService._internal();

  final QuickActions _quickActions = const QuickActions();
  bool _initialized = false;

  /// Initialize Home Screen Quick Actions (Long-press shortcuts)
  void init(BuildContext context) {
    if (_initialized) return;
    _initialized = true;

    _quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'action_tutor',
        localizedTitle: 'AI Tutor',
        icon: 'ic_launcher',
      ),
      const ShortcutItem(
        type: 'action_library',
        localizedTitle: 'My Library',
        icon: 'ic_launcher',
      ),
      const ShortcutItem(
        type: 'action_flashcards',
        localizedTitle: 'Flashcards',
        icon: 'ic_launcher',
      ),
      const ShortcutItem(
        type: 'action_quiz',
        localizedTitle: 'Quiz Generator',
        icon: 'ic_launcher',
      ),
    ]);

    _quickActions.initialize((String type) {
      _handleShortcut(context, type);
    });
  }

  void _handleShortcut(BuildContext context, String type) {
    switch (type) {
      case 'action_tutor':
        GoRouter.of(context).go('/ai-tutor');
        break;
      case 'action_library':
        GoRouter.of(context).go('/library');
        break;
      case 'action_flashcards':
        GoRouter.of(context).go('/tools/flashcards');
        break;
      case 'action_quiz':
        GoRouter.of(context).go('/tools/quiz');
        break;
    }
  }

  /// Update the Home Screen Widget data
  /// [goalProgress] is a double between 0.0 and 1.0
  Future<void> updateStudyWidget({
    required String subject,
    required double progress,
    required String statusText,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('study_subject', subject);
      await HomeWidget.saveWidgetData<double>('study_progress', progress);
      await HomeWidget.saveWidgetData<String>('study_status', statusText);
      await HomeWidget.updateWidget(
        name: 'StudyWidgetProvider',
        androidName: 'StudyWidgetProvider',
      );
    } catch (e) {
      // Fail silently for widgets as they are optional
    }
  }
}
