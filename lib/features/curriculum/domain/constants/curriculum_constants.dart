class CurriculumConstants {
  CurriculumConstants._();

  // Curriculum IDs
  static const String currHsk1 = 'curr_hsk1';
  static const String currHsk2 = 'curr_hsk2';
  static const String currHsk3 = 'curr_hsk3';
  static const String currHsk4 = 'curr_hsk4';
  static const String currHsk5 = 'curr_hsk5';
  static const String currHsk6 = 'curr_hsk6';

  // Pack IDs
  static const String packHsk1 = 'hsk1_pack_v1';
  static const String packHsk2 = 'hsk2_pack_v1';

  // Official Standard Codes
  static const String codeHsk1 = 'HSK_2012_L1';
  static const String codeHsk2 = 'HSK_2012_L2';

  /// Returns canonical curriculum ID for a given HSK level (1..6)
  static String curriculumIdForLevel(int level) {
    if (level < 1 || level > 6) {
      throw ArgumentError.value(level, 'level', 'HSK level must be between 1 and 6');
    }
    return 'curr_hsk$level';
  }

  /// Extracts HSK level integer from a curriculum ID (e.g. 'curr_hsk1' -> 1)
  static int? levelFromCurriculumId(String curriculumId) {
    final match = RegExp(r'^curr_hsk([1-6])$').firstMatch(curriculumId);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }
}
