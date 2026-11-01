class DatabaseConstants {
  DatabaseConstants._();

  static const String databaseName = 'hi_chinese.db';
  static const int currentDatabaseVersion = 7;

  // Table names
  static const String tableVocabularies = 'vocabularies';
  static const String tableVocabularySenses = 'vocabulary_senses';
  static const String tableGrammarItems = 'grammar_items';
  static const String tableGrammarProgress = 'grammar_progress';
  static const String tableReadingPassages = 'reading_passages';
  static const String tableSrsItems = 'srs_items';
  static const String tableLearnerEvidence = 'learner_evidence';
  static const String tableMasterySnapshots = 'mastery_snapshots';
  static const String tableChatSessions = 'chat_sessions';
  static const String tableChatMessages = 'chat_messages';
  static const String tableLearningActivities = 'learning_activities';
  static const String tableSeedHistory = 'seed_history';
  static const String tablePlacementTestSessions = 'placement_test_sessions';
  static const String tablePlacementTestResponses = 'placement_test_responses';
  static const String tableDictionaryHistory = 'dictionary_history';
  static const String tableUserSavedWords = 'user_saved_words';
  static const String tableReadingProgress = 'reading_progress';
  static const String tableLearnerGoals = 'learner_goals';
  static const String tableLessonProgress = 'lesson_progress';
  static const String tableRoadmapSnapshots = 'roadmap_snapshots';
  static const String tablePracticeExercises = 'practice_exercises';
  static const String tablePracticeSessions = 'practice_sessions';
  static const String tablePracticeAttempts = 'practice_attempts';
}
