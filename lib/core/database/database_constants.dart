class DatabaseConstants {
  DatabaseConstants._();

  static const String databaseName = 'hi_chinese.db';
  static const int currentDatabaseVersion = 2;

  // Table names
  static const String tableVocabularies = 'vocabularies';
  static const String tableVocabularySenses = 'vocabulary_senses';
  static const String tableGrammarItems = 'grammar_items';
  static const String tableReadingPassages = 'reading_passages';
  static const String tableSrsItems = 'srs_items';
  static const String tableLearnerEvidence = 'learner_evidence';
  static const String tableMasterySnapshots = 'mastery_snapshots';
  static const String tableChatSessions = 'chat_sessions';
  static const String tableChatMessages = 'chat_messages';
  static const String tableLearningActivities = 'learning_activities';
  static const String tableSeedHistory = 'seed_history';
}
