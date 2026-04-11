import 'dart:async';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  // Stub stream — never fires on native
  Stream<void> get onUpdateAvailable => const Stream.empty();

  bool get isUpdateAvailable => false;

  void startAutoCheck() {}
  void checkAndAutoApplyOnNavigation(String location) {}
  Future<void> checkForUpdate() async {}
  Future<void> applyUpdate() async {}
  void dispose() {}
}
