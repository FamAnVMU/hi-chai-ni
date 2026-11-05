enum SeedStage {
  idle,
  validating,
  seedingVocabularies,
  seedingGrammar,
  seedingReading,
  completed,
  failed,
}

class SeedProgress {
  final SeedStage stage;
  final int processedItems;
  final int totalItems;
  final String message;

  const SeedProgress({
    required this.stage,
    required this.processedItems,
    required this.totalItems,
    required this.message,
  });

  double get percent => totalItems > 0 ? (processedItems / totalItems).clamp(0.0, 1.0) : 0.0;

  @override
  String toString() => 'SeedProgress($stage, $processedItems/$totalItems [${(percent * 100).toStringAsFixed(1)}%]: $message)';
}

class SeedResult {
  final bool success;
  final bool skipped;
  final int totalItems;
  final Duration duration;
  final String? message;
  final String? errorMessage;

  const SeedResult({
    required this.success,
    this.skipped = false,
    this.totalItems = 0,
    this.duration = Duration.zero,
    this.message,
    this.errorMessage,
  });

  factory SeedResult.completed({required int totalItems, required Duration duration, String? message}) {
    return SeedResult(
      success: true,
      skipped: false,
      totalItems: totalItems,
      duration: duration,
      message: message ?? 'Seed completed successfully.',
    );
  }

  factory SeedResult.skipped({String? reason, Duration? duration}) {
    return SeedResult(
      success: true,
      skipped: true,
      duration: duration ?? Duration.zero,
      message: reason ?? 'Dataset is already up to date; seed skipped.',
    );
  }

  factory SeedResult.failed({required String error, Duration? duration, int processedItems = 0}) {
    return SeedResult(
      success: false,
      skipped: false,
      totalItems: processedItems,
      duration: duration ?? Duration.zero,
      errorMessage: error,
    );
  }
}

class SeedExampleItem {
  final String zh;
  final String pinyin;
  final String vi;

  const SeedExampleItem({
    required this.zh,
    required this.pinyin,
    required this.vi,
  });

  factory SeedExampleItem.fromJson(Map<String, dynamic> json) {
    return SeedExampleItem(
      zh: json['zh'] as String? ?? '',
      pinyin: json['pinyin'] as String? ?? '',
      vi: json['vi'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'zh': zh,
        'pinyin': pinyin,
        'vi': vi,
      };
}

class SeedSenseItem {
  final String id;
  final String partOfSpeech;
  final String meaningVi;
  final String? meaningEn;
  final List<SeedExampleItem> examples;

  const SeedSenseItem({
    required this.id,
    required this.partOfSpeech,
    required this.meaningVi,
    this.meaningEn,
    this.examples = const [],
  });

  factory SeedSenseItem.fromJson(Map<String, dynamic> json) {
    final rawExamples = json['examples'] as List<dynamic>? ?? [];
    return SeedSenseItem(
      id: json['id'] as String? ?? '',
      partOfSpeech: json['partOfSpeech'] as String? ?? json['part_of_speech'] as String? ?? 'Từ',
      meaningVi: json['meaningVi'] as String? ?? json['meaning_vi'] as String? ?? '',
      meaningEn: json['meaningEn'] as String? ?? json['meaning_en'] as String?,
      examples: rawExamples
          .map((e) => SeedExampleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'partOfSpeech': partOfSpeech,
        'meaningVi': meaningVi,
        if (meaningEn != null) 'meaningEn': meaningEn,
        'examples': examples.map((e) => e.toJson()).toList(),
      };
}

class SeedVocabularyItem {
  final String id;
  final String simplified;
  final String? traditional;
  final String pinyin;
  final String? pinyinClean;
  final String? hanviet;
  final int hskLevel;
  final String hskVersion;
  final int? frequency;
  final List<SeedSenseItem> senses;
  final String? source;
  final String? license;
  final String? syllabusVersion;

  const SeedVocabularyItem({
    required this.id,
    required this.simplified,
    this.traditional,
    required this.pinyin,
    this.pinyinClean,
    this.hanviet,
    required this.hskLevel,
    this.hskVersion = 'HSK2.0',
    this.frequency,
    this.senses = const [],
    this.source,
    this.license,
    this.syllabusVersion,
  });

  factory SeedVocabularyItem.fromJson(Map<String, dynamic> json) {
    final rawSenses = json['senses'] as List<dynamic>? ?? [];
    return SeedVocabularyItem(
      id: json['id'] as String? ?? '',
      simplified: json['simplified'] as String? ?? '',
      traditional: json['traditional'] as String?,
      pinyin: json['pinyin'] as String? ?? '',
      pinyinClean: json['pinyinClean'] as String? ?? json['pinyin_clean'] as String?,
      hanviet: json['hanviet'] as String?,
      hskLevel: json['hskLevel'] as int? ?? json['hsk_level'] as int? ?? 1,
      hskVersion: json['hskVersion'] as String? ?? json['hsk_version'] as String? ?? 'HSK2.0',
      frequency: json['frequency'] as int? ?? json['frequency_rank'] as int?,
      senses: rawSenses
          .map((s) => SeedSenseItem.fromJson(s as Map<String, dynamic>))
          .toList(),
      source: json['source'] as String?,
      license: json['license'] as String?,
      syllabusVersion: json['syllabusVersion'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'simplified': simplified,
        'traditional': traditional,
        'pinyin': pinyin,
        'pinyinClean': pinyinClean,
        'hskLevel': hskLevel,
        'hskVersion': hskVersion,
        'frequency': frequency,
        'senses': senses.map((s) => s.toJson()).toList(),
        'source': source,
        'syllabusVersion': syllabusVersion,
      };
}

class SeedGrammarItem {
  final String id;
  final String code;
  final int hskLevel;
  final String title;
  final String pattern;
  final String explanationVi;
  final List<SeedExampleItem> examples;

  const SeedGrammarItem({
    required this.id,
    required this.code,
    required this.hskLevel,
    required this.title,
    required this.pattern,
    required this.explanationVi,
    this.examples = const [],
  });

  factory SeedGrammarItem.fromJson(Map<String, dynamic> json) {
    final rawExamples = json['examples'] as List<dynamic>? ?? [];
    return SeedGrammarItem(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      hskLevel: json['hskLevel'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      pattern: json['pattern'] as String? ?? '',
      explanationVi: json['explanationVi'] as String? ?? '',
      examples: rawExamples
          .map((e) => SeedExampleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'hskLevel': hskLevel,
        'title': title,
        'pattern': pattern,
        'explanationVi': explanationVi,
        'examples': examples.map((e) => e.toJson()).toList(),
      };
}

class SeedReadingPassageItem {
  final String id;
  final int hskLevel;
  final String title;
  final String contentZh;
  final String pinyin;
  final String translationVi;
  final String? audioUri;
  final List<Map<String, dynamic>> questions;

  const SeedReadingPassageItem({
    required this.id,
    required this.hskLevel,
    required this.title,
    required this.contentZh,
    required this.pinyin,
    required this.translationVi,
    this.audioUri,
    this.questions = const [],
  });

  factory SeedReadingPassageItem.fromJson(Map<String, dynamic> json) {
    final rawQuestions = json['questions'] as List<dynamic>? ?? [];
    return SeedReadingPassageItem(
      id: json['id'] as String? ?? '',
      hskLevel: json['hskLevel'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      contentZh: json['contentZh'] as String? ?? '',
      pinyin: json['pinyin'] as String? ?? '',
      translationVi: json['translationVi'] as String? ?? '',
      audioUri: json['audioUri'] as String? ?? json['audio_uri'] as String?,
      questions: rawQuestions.map((q) => q as Map<String, dynamic>).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'hskLevel': hskLevel,
        'title': title,
        'contentZh': contentZh,
        'pinyin': pinyin,
        'translationVi': translationVi,
        if (audioUri != null) 'audioUri': audioUri,
        'questions': questions,
      };
}

class SeedBundle {
  final String bundleName;
  final int version;
  final String syllabusVersion;
  final String source;
  final List<SeedVocabularyItem> vocabularies;
  final List<SeedGrammarItem> grammarItems;
  final List<SeedReadingPassageItem> readingPassages;
  final Map<String, dynamic> metadata;

  const SeedBundle({
    required this.bundleName,
    required this.version,
    required this.syllabusVersion,
    required this.source,
    this.vocabularies = const [],
    this.grammarItems = const [],
    this.readingPassages = const [],
    this.metadata = const {},
  });

  int get totalItemCount =>
      vocabularies.length + grammarItems.length + readingPassages.length;

  factory SeedBundle.fromJson(Map<String, dynamic> json) {
    final rawVocabs = json['vocabularies'] as List<dynamic>? ?? [];
    final rawGrammar = json['grammarItems'] as List<dynamic>? ?? [];
    final rawReading = json['readingPassages'] as List<dynamic>? ?? [];

    return SeedBundle(
      bundleName: json['bundleName'] as String? ?? 'default_seed_bundle',
      version: json['version'] as int? ?? 1,
      syllabusVersion: json['syllabusVersion'] as String? ?? 'HSK2.0',
      source: json['source'] as String? ?? 'hi_chinese_verified',
      vocabularies: rawVocabs
          .map((v) => SeedVocabularyItem.fromJson(v as Map<String, dynamic>))
          .toList(),
      grammarItems: rawGrammar
          .map((g) => SeedGrammarItem.fromJson(g as Map<String, dynamic>))
          .toList(),
      readingPassages: rawReading
          .map((r) => SeedReadingPassageItem.fromJson(r as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'bundleName': bundleName,
        'version': version,
        'syllabusVersion': syllabusVersion,
        'source': source,
        'vocabularies': vocabularies.map((v) => v.toJson()).toList(),
        'grammarItems': grammarItems.map((g) => g.toJson()).toList(),
        'readingPassages': readingPassages.map((r) => r.toJson()).toList(),
        'metadata': metadata,
      };
}

class SeedHistoryEntry {
  final String bundleName;
  final int version;
  final String checksum;
  final String status;
  final int totalItems;
  final int appliedItems;
  final String appliedAt;
  final String? errorMessage;

  const SeedHistoryEntry({
    required this.bundleName,
    required this.version,
    required this.checksum,
    required this.status,
    required this.totalItems,
    required this.appliedItems,
    required this.appliedAt,
    this.errorMessage,
  });

  factory SeedHistoryEntry.fromMap(Map<String, dynamic> map) {
    return SeedHistoryEntry(
      bundleName: map['bundle_name'] as String,
      version: map['version'] as int,
      checksum: map['checksum'] as String,
      status: map['status'] as String,
      totalItems: map['total_items'] as int? ?? 0,
      appliedItems: map['applied_items'] as int? ?? 0,
      appliedAt: map['applied_at'] as String,
      errorMessage: map['error_message'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'bundle_name': bundleName,
        'version': version,
        'checksum': checksum,
        'status': status,
        'total_items': totalItems,
        'applied_items': appliedItems,
        'applied_at': appliedAt,
        'error_message': errorMessage,
      };
}
