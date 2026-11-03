class DatabaseConstants {
  DatabaseConstants._();

  static const String databaseName = 'hi_chinese.db';
  static const int currentDatabaseVersion = 16;

  // Table names
  static const String tableVocabularies = 'vocabularies';
  static const String tableVocabularySenses = 'vocabulary_senses';
  static const String tableVocabularyExamples = 'vocabulary_examples';
  static const String tableDictionaryEntries = 'dictionary_entries';
  static const String tableGrammarItems = 'grammar_items';
  static const String tableGrammarProgress = 'grammar_progress';
  static const String tableGrammarExamples = 'grammar_examples';
  static const String tableGrammarTopics = 'grammar_topics';
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
  static const String tableUserProfiles = 'user_profiles';
  static const String tableGoalHistory = 'goal_history';
  static const String tableAppSettings = 'app_settings';

  // Schema v9 Curriculum & Content Catalog Tables
  static const String tableContentPacks = 'content_packs';
  static const String tableCurriculums = 'curriculums';
  static const String tableCurriculumUnits = 'curriculum_units';
  static const String tableCurriculumLessons = 'curriculum_lessons';
  static const String tableLessonSegments = 'lesson_segments';
  static const String tableContentItems = 'content_items';
  static const String tableCurriculumMastery = 'curriculum_mastery';
  static const String tableLevelExitExams = 'level_exit_exams';

  // Schema v10 Knowledge Normalization & Content Packs
  static const String tableKnowledgeRegistry = 'knowledge_registry';
  static const String tableLessonKnowledgeItems = 'lesson_knowledge_items';
  static const String tableContentIdMappings = 'content_id_mappings';

  // Schema v11 Offline Audio Asset Management & Pinyin Foundation
  static const String tableAudioAssets = 'audio_assets';
  static const String tablePinyinProgress = 'pinyin_progress';

  // Schema v14 Offline Hanzi Stroke Order & Handwriting Engine
  static const String tableHanziCharacters = 'hanzi_characters';
  static const String tableHanziWritingProgress = 'hanzi_writing_progress';

  // Schema v15 Sentence Library, Offline Audio Packs & Shadowing Engine
  static const String tableSentences = 'sentences';
  static const String tableSentenceAudio = 'sentence_audio';
  static const String tableSentencePracticeProgress = 'sentence_practice_progress';
}
