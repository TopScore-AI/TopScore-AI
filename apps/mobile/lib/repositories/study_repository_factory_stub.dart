import 'package:shared_preferences/shared_preferences.dart';
import 'study_repository.dart';
import 'web_study_repository.dart';

Future<StudyRepository> createStudyRepository() async {
  final prefs = await SharedPreferences.getInstance();
  return WebStudyRepository(prefs);
}
