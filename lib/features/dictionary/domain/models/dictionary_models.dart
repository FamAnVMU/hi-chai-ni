/// Model representing a single sense or definition of a vocabulary entry.
class DictionarySense {
  final String id;
  final String partOfSpeech;
  final String meaningVi;
  final String? meaningEn;
  final String? exampleCn;
  final String? examplePinyin;
  final String? exampleVi;
  final String? exampleEn;
  final String? source;
  final int orderIndex;

  const DictionarySense({
    required this.id,
    required this.partOfSpeech,
    required this.meaningVi,
    this.meaningEn,
    this.exampleCn,
    this.examplePinyin,
    this.exampleVi,
    this.exampleEn,
    this.source,
    this.orderIndex = 1,
  });

  factory DictionarySense.fromMap(Map<String, dynamic> map) {
    return DictionarySense(
      id: map['id'] as String? ?? '',
      partOfSpeech: map['part_of_speech'] as String? ?? 'Từ',
      meaningVi: map['meaning_vi'] as String? ?? '',
      meaningEn: map['meaning_en'] as String?,
      exampleCn: map['example_cn'] as String?,
      examplePinyin: map['example_pinyin'] as String?,
      exampleVi: map['example_vi'] as String?,
      exampleEn: map['example_en'] as String?,
      source: map['source'] as String?,
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'part_of_speech': partOfSpeech,
        'meaning_vi': meaningVi,
        if (meaningEn != null) 'meaning_en': meaningEn,
        if (exampleCn != null) 'example_cn': exampleCn,
        if (examplePinyin != null) 'example_pinyin': examplePinyin,
        if (exampleVi != null) 'example_vi': exampleVi,
        if (exampleEn != null) 'example_en': exampleEn,
        if (source != null) 'source': source,
        'order_index': orderIndex,
      };
}

/// Model representing a verified example sentence.
class DictionaryExample {
  final String id;
  final String vocabularyId;
  final String? senseId;
  final int hskLevel;
  final String exampleCn;
  final String examplePinyin;
  final String? exampleVi;
  final String? exampleEn;
  final String? audioUri;
  final String? source;
  final int orderIndex;

  const DictionaryExample({
    required this.id,
    required this.vocabularyId,
    this.senseId,
    required this.hskLevel,
    required this.exampleCn,
    required this.examplePinyin,
    this.exampleVi,
    this.exampleEn,
    this.audioUri,
    this.source,
    this.orderIndex = 1,
  });

  factory DictionaryExample.fromMap(Map<String, dynamic> map) {
    return DictionaryExample(
      id: map['id'] as String? ?? '',
      vocabularyId: map['vocabulary_id'] as String? ?? '',
      senseId: map['sense_id'] as String?,
      hskLevel: (map['hsk_level'] as num?)?.toInt() ?? 1,
      exampleCn: map['example_cn'] as String? ?? '',
      examplePinyin: map['example_pinyin'] as String? ?? '',
      exampleVi: map['example_vi'] as String?,
      exampleEn: map['example_en'] as String?,
      audioUri: map['audio_uri'] as String?,
      source: map['source'] as String?,
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'vocabulary_id': vocabularyId,
        if (senseId != null) 'sense_id': senseId,
        'hsk_level': hskLevel,
        'example_cn': exampleCn,
        'example_pinyin': examplePinyin,
        if (exampleVi != null) 'example_vi': exampleVi,
        if (exampleEn != null) 'example_en': exampleEn,
        if (audioUri != null) 'audio_uri': audioUri,
        if (source != null) 'source': source,
        'order_index': orderIndex,
      };
}

/// Model representing a full dictionary entry with all senses and user annotations.
class DictionaryEntry {
  final String id;
  final String simplified;
  final String? traditional;
  final String pinyin;
  final String? pinyinClean;
  final String? hanviet;
  final int hskLevel;
  final int? strokeCount;
  final String? radicals;
  final int? frequencyRank;
  final String? audioUri;
  final String? source;
  final String? license;
  final bool isPolyphone;
  final List<DictionarySense> senses;
  final List<DictionaryExample> examples;
  final bool isSaved;
  final String? customNote;

  const DictionaryEntry({
    required this.id,
    required this.simplified,
    this.traditional,
    required this.pinyin,
    this.pinyinClean,
    this.hanviet,
    required this.hskLevel,
    this.strokeCount,
    this.radicals,
    this.frequencyRank,
    this.audioUri,
    this.source,
    this.license,
    this.isPolyphone = false,
    this.senses = const [],
    this.examples = const [],
    this.isSaved = false,
    this.customNote,
  });

  factory DictionaryEntry.fromMap(
    Map<String, dynamic> map, {
    List<DictionarySense>? senses,
    List<DictionaryExample>? examples,
    bool isSaved = false,
    String? customNote,
  }) {
    return DictionaryEntry(
      id: map['id'] as String,
      simplified: map['simplified'] as String,
      traditional: map['traditional'] as String?,
      pinyin: map['pinyin'] as String,
      pinyinClean: map['pinyin_clean'] as String?,
      hanviet: map['hanviet'] as String?,
      hskLevel: map['hsk_level'] as int? ?? 1,
      strokeCount: map['stroke_count'] as int?,
      radicals: map['radicals'] as String?,
      frequencyRank: map['frequency_rank'] as int?,
      audioUri: map['audio_uri'] as String?,
      source: map['source'] as String?,
      license: map['license'] as String?,
      isPolyphone: (map['is_polyphone'] as int? ?? 0) == 1,
      senses: senses ?? [],
      examples: examples ?? [],
      isSaved: isSaved,
      customNote: customNote,
    );
  }

  DictionaryEntry copyWith({
    String? id,
    String? simplified,
    String? traditional,
    String? pinyin,
    String? pinyinClean,
    String? hanviet,
    int? hskLevel,
    int? strokeCount,
    String? radicals,
    int? frequencyRank,
    String? audioUri,
    String? source,
    String? license,
    bool? isPolyphone,
    List<DictionarySense>? senses,
    List<DictionaryExample>? examples,
    bool? isSaved,
    String? customNote,
  }) {
    return DictionaryEntry(
      id: id ?? this.id,
      simplified: simplified ?? this.simplified,
      traditional: traditional ?? this.traditional,
      pinyin: pinyin ?? this.pinyin,
      pinyinClean: pinyinClean ?? this.pinyinClean,
      hanviet: hanviet ?? this.hanviet,
      hskLevel: hskLevel ?? this.hskLevel,
      strokeCount: strokeCount ?? this.strokeCount,
      radicals: radicals ?? this.radicals,
      frequencyRank: frequencyRank ?? this.frequencyRank,
      audioUri: audioUri ?? this.audioUri,
      source: source ?? this.source,
      license: license ?? this.license,
      isPolyphone: isPolyphone ?? this.isPolyphone,
      senses: senses ?? this.senses,
      examples: examples ?? this.examples,
      isSaved: isSaved ?? this.isSaved,
      customNote: customNote ?? this.customNote,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'simplified': simplified,
        if (traditional != null) 'traditional': traditional,
        'pinyin': pinyin,
        if (pinyinClean != null) 'pinyin_clean': pinyinClean,
        if (hanviet != null) 'hanviet': hanviet,
        'hsk_level': hskLevel,
        if (strokeCount != null) 'stroke_count': strokeCount,
        if (radicals != null) 'radicals': radicals,
        if (frequencyRank != null) 'frequency_rank': frequencyRank,
        if (audioUri != null) 'audio_uri': audioUri,
        if (source != null) 'source': source,
        if (license != null) 'license': license,
        'is_polyphone': isPolyphone ? 1 : 0,
        'senses': senses.map((s) => s.toMap()).toList(),
        'examples': examples.map((e) => e.toMap()).toList(),
        'is_saved': isSaved,
        if (customNote != null) 'custom_note': customNote,
      };
}

/// User saved favorite word model.
class UserSavedWord {
  final String id;
  final String vocabularyId;
  final String simplified;
  final String pinyin;
  final String? customNote;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSavedWord({
    required this.id,
    required this.vocabularyId,
    required this.simplified,
    required this.pinyin,
    this.customNote,
    this.isFavorite = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSavedWord.fromMap(Map<String, dynamic> map) {
    return UserSavedWord(
      id: map['id'] as String,
      vocabularyId: map['vocabulary_id'] as String,
      simplified: map['simplified'] as String,
      pinyin: map['pinyin'] as String,
      customNote: map['custom_note'] as String?,
      isFavorite: (map['is_favorite'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'vocabulary_id': vocabularyId,
        'simplified': simplified,
        'pinyin': pinyin,
        if (customNote != null) 'custom_note': customNote,
        'is_favorite': isFavorite ? 1 : 0,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

/// Dictionary search query history item.
class DictionaryHistoryItem {
  final String id;
  final String query;
  final String searchType;
  final DateTime createdAt;

  const DictionaryHistoryItem({
    required this.id,
    required this.query,
    this.searchType = 'text',
    required this.createdAt,
  });

  factory DictionaryHistoryItem.fromMap(Map<String, dynamic> map) {
    return DictionaryHistoryItem(
      id: map['id'] as String,
      query: map['query'] as String,
      searchType: map['search_type'] as String? ?? 'text',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'query': query,
        'search_type': searchType,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}

class VocabularyMinimal {
  final String id;
  final String hanzi;
  final String pinyin;
  final String? pinyinClean;
  final String? meaningVi;
  final int hskLevel;
  final String? source;

  const VocabularyMinimal({
    required this.id,
    required this.hanzi,
    required this.pinyin,
    this.pinyinClean,
    this.meaningVi,
    this.hskLevel = 0,
    this.source = 'CVDICT',
  });

  factory VocabularyMinimal.fromDictionaryEntry(DictionaryEntry entry) {
    return VocabularyMinimal(
      id: entry.id,
      hanzi: entry.simplified,
      pinyin: entry.pinyin,
      pinyinClean: entry.pinyinClean,
      meaningVi: entry.senses.isNotEmpty ? entry.senses.first.meaningVi : null,
      hskLevel: entry.hskLevel,
      source: entry.source ?? 'CVDICT',
    );
  }
}
