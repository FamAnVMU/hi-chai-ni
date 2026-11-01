/// Model representing a single sense or definition of a vocabulary entry.
class DictionarySense {
  final String id;
  final String partOfSpeech;
  final String meaningVi;
  final String? exampleCn;
  final String? examplePinyin;
  final String? exampleVi;

  const DictionarySense({
    required this.id,
    required this.partOfSpeech,
    required this.meaningVi,
    this.exampleCn,
    this.examplePinyin,
    this.exampleVi,
  });

  factory DictionarySense.fromMap(Map<String, dynamic> map) {
    return DictionarySense(
      id: map['id'] as String? ?? '',
      partOfSpeech: map['part_of_speech'] as String? ?? 'Từ',
      meaningVi: map['meaning_vi'] as String? ?? '',
      exampleCn: map['example_cn'] as String?,
      examplePinyin: map['example_pinyin'] as String?,
      exampleVi: map['example_vi'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'part_of_speech': partOfSpeech,
        'meaning_vi': meaningVi,
        if (exampleCn != null) 'example_cn': exampleCn,
        if (examplePinyin != null) 'example_pinyin': examplePinyin,
        if (exampleVi != null) 'example_vi': exampleVi,
      };
}

/// Model representing a full dictionary entry with all senses and user annotations.
class DictionaryEntry {
  final String id;
  final String simplified;
  final String? traditional;
  final String pinyin;
  final int hskLevel;
  final int? strokeCount;
  final String? radicals;
  final int? frequencyRank;
  final String? audioUri;
  final List<DictionarySense> senses;
  final bool isSaved;
  final String? customNote;

  const DictionaryEntry({
    required this.id,
    required this.simplified,
    this.traditional,
    required this.pinyin,
    required this.hskLevel,
    this.strokeCount,
    this.radicals,
    this.frequencyRank,
    this.audioUri,
    this.senses = const [],
    this.isSaved = false,
    this.customNote,
  });

  factory DictionaryEntry.fromMap(
    Map<String, dynamic> map, {
    List<DictionarySense>? senses,
    bool isSaved = false,
    String? customNote,
  }) {
    return DictionaryEntry(
      id: map['id'] as String,
      simplified: map['simplified'] as String,
      traditional: map['traditional'] as String?,
      pinyin: map['pinyin'] as String,
      hskLevel: map['hsk_level'] as int? ?? 1,
      strokeCount: map['stroke_count'] as int?,
      radicals: map['radicals'] as String?,
      frequencyRank: map['frequency_rank'] as int?,
      audioUri: map['audio_uri'] as String?,
      senses: senses ?? [],
      isSaved: isSaved,
      customNote: customNote,
    );
  }

  DictionaryEntry copyWith({
    String? id,
    String? simplified,
    String? traditional,
    String? pinyin,
    int? hskLevel,
    int? strokeCount,
    String? radicals,
    int? frequencyRank,
    String? audioUri,
    List<DictionarySense>? senses,
    bool? isSaved,
    String? customNote,
  }) {
    return DictionaryEntry(
      id: id ?? this.id,
      simplified: simplified ?? this.simplified,
      traditional: traditional ?? this.traditional,
      pinyin: pinyin ?? this.pinyin,
      hskLevel: hskLevel ?? this.hskLevel,
      strokeCount: strokeCount ?? this.strokeCount,
      radicals: radicals ?? this.radicals,
      frequencyRank: frequencyRank ?? this.frequencyRank,
      audioUri: audioUri ?? this.audioUri,
      senses: senses ?? this.senses,
      isSaved: isSaved ?? this.isSaved,
      customNote: customNote ?? this.customNote,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'simplified': simplified,
        if (traditional != null) 'traditional': traditional,
        'pinyin': pinyin,
        'hsk_level': hskLevel,
        if (strokeCount != null) 'stroke_count': strokeCount,
        if (radicals != null) 'radicals': radicals,
        if (frequencyRank != null) 'frequency_rank': frequencyRank,
        if (audioUri != null) 'audio_uri': audioUri,
        'senses': senses.map((s) => s.toMap()).toList(),
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
