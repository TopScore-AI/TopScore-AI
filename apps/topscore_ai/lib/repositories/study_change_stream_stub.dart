import 'study_repository.dart';

/// Web fallback: no reactive Isar query available. Returns an empty stream;
/// the listener path in [SyncedStudyRepository] will still keep the
/// SharedPreferences mirror in sync, but UI must call refresh manually.
Stream<void> watchStudyChanges(StudyRepository repo) async* {
  // Intentionally empty.
}
