class CurriculumData {
  static const String cbc = 'CBC';
  static const String kcse844 = '844';
  static const String cambridgeIGCSE = 'Cambridge IGCSE';

  static List<String> getCurriculums() {
    return [cbc, kcse844, cambridgeIGCSE];
  }

  static List<String> getGradesForCurriculum(String curriculum) {
    switch (curriculum) {
      case cbc:
        return [
          'Grade 1', 'Grade 2', 'Grade 3',
          'Grade 4', 'Grade 5', 'Grade 6',
          'Grade 7', 'Grade 8', 'Grade 9',
          'Grade 10', 'Grade 11', 'Grade 12'
        ];
      case kcse844:
        return ['Form 1', 'Form 2', 'Form 3', 'Form 4'];
      case cambridgeIGCSE:
        return [
          'Year 7', 'Year 8', 'Year 9',
          'Year 10', 'Year 11', 'Year 12', 'Year 13',
          'AS Level', 'A Level'
        ];
      default:
        return ['Grade 7'];
    }
  }

  /// Helper to convert numeric or label-based grades to the standardized labels above
  static String? normalizeGrade(dynamic grade, String? curriculum) {
    if (grade == null) return null;
    
    final String gradeStr = grade.toString();
    
    if (curriculum == cambridgeIGCSE) {
      if (gradeStr.contains('Year') || gradeStr.contains('Level')) return gradeStr;
      return 'Year $gradeStr';
    }
    
    if (curriculum == kcse844) {
      if (gradeStr.contains('Form')) return gradeStr;
      return 'Form $gradeStr';
    }
    
    if (gradeStr.contains('Grade')) return gradeStr;
    return 'Grade $gradeStr';
  }
}
