import 'dart:convert';
import 'package:flutter/material.dart';

/// Type of audio voice source
enum AudioType {
  /// Real human recording contributed by native speakers (e.g. Tatoeba / Shtooka)
  humanRecording,
  /// Synthesized offline/online Text-to-Speech from the device OS (Android/iOS)
  nativeOsTts,
  /// High-fidelity neural studio simulation (e.g. CosyVoice2 / zh-female-studio)
  studioSimulation,
  /// Unverified or unknown audio source
  unknown;

  static AudioType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'human_recording':
      case 'human':
        return AudioType.humanRecording;
      case 'native_os_tts':
      case 'tts':
        return AudioType.nativeOsTts;
      case 'studio_simulation':
      case 'studio':
        return AudioType.studioSimulation;
      default:
        return AudioType.unknown;
    }
  }

  String toDbString() {
    switch (this) {
      case AudioType.humanRecording:
        return 'human_recording';
      case AudioType.nativeOsTts:
        return 'native_os_tts';
      case AudioType.studioSimulation:
        return 'studio_simulation';
      case AudioType.unknown:
        return 'unknown';
    }
  }

  String get displayLabel {
    switch (this) {
      case AudioType.humanRecording:
        return 'Giọng người thật (Tatoeba)';
      case AudioType.nativeOsTts:
        return 'Giọng tổng hợp OS TTS';
      case AudioType.studioSimulation:
        return 'Giọng đọc Studio';
      case AudioType.unknown:
        return 'Âm thanh';
    }
  }

  Color get badgeColor {
    switch (this) {
      case AudioType.humanRecording:
        return const Color(0xFF10B981); // Emerald Green
      case AudioType.nativeOsTts:
        return const Color(0xFF64748B); // Slate Grey
      case AudioType.studioSimulation:
        return const Color(0xFF2563EB); // Royal Blue
      case AudioType.unknown:
        return const Color(0xFF94A3B8);
    }
  }

  bool get isHumanVoice => this == AudioType.humanRecording;
}

/// Tokenized word component in a sentence with meaning and HSK level
class SentenceToken {
  final String word;
  final String pinyin;
  final String meaningVi;
  final int hskLevel;

  const SentenceToken({
    required this.word,
    this.pinyin = '',
    this.meaningVi = '',
    this.hskLevel = 1,
  });

  factory SentenceToken.fromJson(Map<String, dynamic> json) {
    return SentenceToken(
      word: json['word'] as String? ?? '',
      pinyin: json['pinyin'] as String? ?? '',
      meaningVi: json['meaning_vi'] as String? ?? json['gloss_en'] as String? ?? '',
      hskLevel: (json['hsk_level'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'pinyin': pinyin,
    'meaning_vi': meaningVi,
    'hsk_level': hskLevel,
  };
}

/// Metadata and storage link for a sentence audio recording
class SentenceAudio {
  final String id;
  final String sentenceId;
  final AudioType audioType;
  final String speakerName;
  final String gender;
  final String accent;
  final String speedType; // 'normal', 'slow', 'fast'
  final String urlRemote;
  final String? localPath;
  final String status; // 'remote', 'bundled', 'downloaded'
  final String fileFormat; // 'mp3', 'opus', 'aac'
  final int fileSizeBytes;
  final int durationMs;
  final String? checksumSha256;
  final String license;
  final String attribution;

  const SentenceAudio({
    required this.id,
    required this.sentenceId,
    required this.audioType,
    this.speakerName = '',
    this.gender = 'female',
    this.accent = 'zh-CN-Beijing',
    this.speedType = 'normal',
    this.urlRemote = '',
    this.localPath,
    this.status = 'remote',
    this.fileFormat = 'mp3',
    this.fileSizeBytes = 0,
    this.durationMs = 0,
    this.checksumSha256,
    this.license = 'CC BY-NC 4.0',
    this.attribution = '',
  });

  factory SentenceAudio.fromMap(Map<String, dynamic> map) {
    return SentenceAudio(
      id: map['id'] as String? ?? '',
      sentenceId: map['sentence_id'] as String? ?? '',
      audioType: AudioType.fromString(map['audio_type'] as String?),
      speakerName: map['speaker_name'] as String? ?? map['speaker'] as String? ?? '',
      gender: map['gender'] as String? ?? 'female',
      accent: map['accent'] as String? ?? 'zh-CN-Beijing',
      speedType: map['speed_type'] as String? ?? 'normal',
      urlRemote: map['url_remote'] as String? ?? map['audio_url'] as String? ?? '',
      localPath: map['local_path'] as String?,
      status: map['status'] as String? ?? 'remote',
      fileFormat: map['file_format'] as String? ?? 'mp3',
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      durationMs: (map['duration_ms'] as num?)?.toInt() ?? 0,
      checksumSha256: map['checksum_sha256'] as String?,
      license: map['license'] as String? ?? 'CC BY-NC 4.0',
      attribution: map['attribution'] as String? ?? map['attribution_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'sentence_id': sentenceId,
    'audio_type': audioType.toDbString(),
    'speaker_name': speakerName,
    'gender': gender,
    'accent': accent,
    'speed_type': speedType,
    'url_remote': urlRemote,
    'local_path': localPath,
    'status': status,
    'file_format': fileFormat,
    'file_size_bytes': fileSizeBytes,
    'duration_ms': durationMs,
    'checksum_sha256': checksumSha256,
    'license': license,
    'attribution': attribution,
    'updated_at': DateTime.now().toIso8601String(),
  };

  SentenceAudio copyWith({
    String? localPath,
    String? status,
  }) {
    return SentenceAudio(
      id: id,
      sentenceId: sentenceId,
      audioType: audioType,
      speakerName: speakerName,
      gender: gender,
      accent: accent,
      speedType: speedType,
      urlRemote: urlRemote,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      fileFormat: fileFormat,
      fileSizeBytes: fileSizeBytes,
      durationMs: durationMs,
      checksumSha256: checksumSha256,
      license: license,
      attribution: attribution,
    );
  }
}

/// Comprehension check question for validating sentence understanding.
class SentenceComprehensionCheck {
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;

  const SentenceComprehensionCheck({
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    this.explanation = '',
  });

  factory SentenceComprehensionCheck.fromJson(Map<String, dynamic> json) {
    return SentenceComprehensionCheck(
      question: json['question'] as String? ?? '',
      options: (json['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      correctOptionIndex: (json['correct_option_index'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'question': question,
    'options': options,
    'correct_option_index': correctOptionIndex,
    'explanation': explanation,
  };
}

/// Core domain entity for an example sentence in HI Chinese
class SentenceItem {
  final String id;
  final String chinese;
  final String traditional;
  final String pinyin;
  final String pinyinNumbered;
  final String translationVi;
  final String translationEn;
  final String translationViSource; // 'tatoeba_original', 'verified', 'needs_verification', 'lexicon_draft'
  final int hskLevel;
  final String hskLevelBasis; // 'exact_match', 'direct_corpus', 'estimated_vocab_grammar', 'unassigned'
  final List<SentenceToken> tokens;
  final List<String> matchedVocabIds;
  final List<String> grammarTags;
  final String topic;
  final String contributor;
  final String source;
  final String license;
  final bool hasHumanAudio;
  final bool hasTtsFallback;
  final List<SentenceAudio> audios;
  final SentenceComprehensionCheck? comprehensionCheck;

  const SentenceItem({
    required this.id,
    required this.chinese,
    this.traditional = '',
    this.pinyin = '',
    this.pinyinNumbered = '',
    this.translationVi = '',
    this.translationEn = '',
    this.translationViSource = 'verified',
    this.hskLevel = 1,
    this.hskLevelBasis = 'exact_match',
    this.tokens = const [],
    this.matchedVocabIds = const [],
    this.grammarTags = const [],
    this.topic = 'general',
    this.contributor = '',
    this.source = 'Tatoeba Project',
    this.license = 'CC BY 2.0 FR',
    this.hasHumanAudio = false,
    this.hasTtsFallback = true,
    this.audios = const [],
    this.comprehensionCheck,
  });

  factory SentenceItem.fromJson(Map<String, dynamic> json) {
    // Parse tokens
    List<SentenceToken> parsedTokens = [];
    final rawTokens = json['tokens'] ?? json['tokens_json'];
    if (rawTokens is List) {
      parsedTokens = rawTokens
          .map((t) => SentenceToken.fromJson(t as Map<String, dynamic>))
          .toList();
    } else if (rawTokens is String) {
      try {
        final decoded = jsonDecode(rawTokens) as List;
        parsedTokens = decoded
            .map((t) => SentenceToken.fromJson(t as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    // Parse matched vocab ids
    List<String> parsedVocabs = [];
    final rawVocabs = json['matched_vocab_ids'] ?? json['matched_vocab_ids_json'];
    if (rawVocabs is List) {
      parsedVocabs = rawVocabs.map((v) => v.toString()).toList();
    } else if (rawVocabs is String) {
      try {
        final decoded = jsonDecode(rawVocabs) as List;
        parsedVocabs = decoded.map((v) => v.toString()).toList();
      } catch (_) {}
    }

    // Parse grammar tags
    List<String> parsedGrammar = [];
    final rawGrammar = json['grammar_tags'] ?? json['grammar_tags_json'];
    if (rawGrammar is List) {
      parsedGrammar = rawGrammar.map((g) => g.toString()).toList();
    } else if (rawGrammar is String) {
      try {
        final decoded = jsonDecode(rawGrammar) as List;
        parsedGrammar = decoded.map((g) => g.toString()).toList();
      } catch (_) {}
    }

    // Parse audios
    List<SentenceAudio> parsedAudios = [];
    final rawAudios = json['audios'];
    if (rawAudios is List) {
      parsedAudios = rawAudios
          .map((a) => SentenceAudio.fromMap(a as Map<String, dynamic>))
          .toList();
    }

    final sentId = json['id'] as String? ?? json['sentence_id'] as String? ?? '';
    final hasHuman = json['has_human_audio'] == 1 ||
        json['has_human_audio'] == true ||
        parsedAudios.any((a) => a.audioType == AudioType.humanRecording);

    SentenceComprehensionCheck? check;
    if (json['comprehension_check'] is Map<String, dynamic>) {
      check = SentenceComprehensionCheck.fromJson(json['comprehension_check'] as Map<String, dynamic>);
    } else if (json['comprehension_check'] is String) {
      try {
        final decoded = jsonDecode(json['comprehension_check'] as String);
        if (decoded is Map<String, dynamic>) {
          check = SentenceComprehensionCheck.fromJson(decoded);
        }
      } catch (_) {}
    }

    return SentenceItem(
      id: sentId,
      chinese: json['chinese'] as String? ?? '',
      traditional: json['traditional'] as String? ?? '',
      pinyin: json['pinyin'] as String? ?? '',
      pinyinNumbered: json['pinyin_numbered'] as String? ?? '',
      translationVi: json['translation_vi'] as String? ?? '',
      translationEn: json['translation_en'] as String? ?? '',
      translationViSource: json['translation_vi_source'] as String? ?? 'verified',
      hskLevel: (json['hsk_level'] as num?)?.toInt() ?? 1,
      hskLevelBasis: json['hsk_level_basis'] as String? ?? 'exact_match',
      tokens: parsedTokens,
      matchedVocabIds: parsedVocabs,
      grammarTags: parsedGrammar,
      topic: json['topic'] as String? ?? 'general',
      contributor: json['contributor'] as String? ?? '',
      source: json['source'] as String? ?? 'Tatoeba Project',
      license: json['license'] as String? ?? 'CC BY 2.0 FR',
      hasHumanAudio: hasHuman,
      hasTtsFallback: json['has_tts_fallback'] != 0,
      audios: parsedAudios,
      comprehensionCheck: check,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'chinese': chinese,
    'traditional': traditional,
    'pinyin': pinyin,
    'pinyin_numbered': pinyinNumbered,
    'translation_vi': translationVi,
    'translation_en': translationEn,
    'translation_vi_source': translationViSource,
    'hsk_level': hskLevel,
    'hsk_level_basis': hskLevelBasis,
    'tokens_json': jsonEncode(tokens.map((t) => t.toJson()).toList()),
    'matched_vocab_ids_json': jsonEncode(matchedVocabIds),
    'grammar_tags_json': jsonEncode(grammarTags),
    'topic': topic,
    'contributor': contributor,
    'source': source,
    'license': license,
    'has_human_audio': hasHumanAudio ? 1 : 0,
    'has_tts_fallback': hasTtsFallback ? 1 : 0,
    if (comprehensionCheck != null)
      'comprehension_check': jsonEncode(comprehensionCheck!.toJson()),
  };
}

/// Progress entity tracking learner's practice, shadowing, and SRS schedules per sentence
class SentencePracticeProgress {
  final String id;
  final String sentenceId;
  final int hskLevel;
  final int listeningAttempts;
  final int shadowingAttempts;
  final int readingAttempts;
  final double lastScore;
  final double bestScore;
  final DateTime? lastPracticedAt;
  final String? lastShadowingAudioPath;
  final String masteryLevel; // 'new', 'learning', 'practiced', 'mastered'
  final DateTime? srsDueDate;

  const SentencePracticeProgress({
    required this.id,
    required this.sentenceId,
    this.hskLevel = 1,
    this.listeningAttempts = 0,
    this.shadowingAttempts = 0,
    this.readingAttempts = 0,
    this.lastScore = 0.0,
    this.bestScore = 0.0,
    this.lastPracticedAt,
    this.lastShadowingAudioPath,
    this.masteryLevel = 'new',
    this.srsDueDate,
  });

  factory SentencePracticeProgress.fromMap(Map<String, dynamic> map) {
    return SentencePracticeProgress(
      id: map['id'] as String? ?? 'prog_${map['sentence_id']}',
      sentenceId: map['sentence_id'] as String? ?? '',
      hskLevel: (map['hsk_level'] as num?)?.toInt() ?? 1,
      listeningAttempts: (map['listening_attempts'] as num?)?.toInt() ?? 0,
      shadowingAttempts: (map['shadowing_attempts'] as num?)?.toInt() ?? 0,
      readingAttempts: (map['reading_attempts'] as num?)?.toInt() ?? 0,
      lastScore: (map['last_score'] as num?)?.toDouble() ?? 0.0,
      bestScore: (map['best_score'] as num?)?.toDouble() ?? 0.0,
      lastPracticedAt: map['last_practiced_at'] != null
          ? DateTime.tryParse(map['last_practiced_at'].toString())
          : null,
      lastShadowingAudioPath: map['last_shadowing_audio_path'] as String?,
      masteryLevel: map['mastery_level'] as String? ?? 'new',
      srsDueDate: map['srs_due_date'] != null
          ? DateTime.tryParse(map['srs_due_date'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'sentence_id': sentenceId,
    'hsk_level': hskLevel,
    'listening_attempts': listeningAttempts,
    'shadowing_attempts': shadowingAttempts,
    'reading_attempts': readingAttempts,
    'last_score': lastScore,
    'best_score': bestScore,
    'last_practiced_at': lastPracticedAt?.toIso8601String(),
    'last_shadowing_audio_path': lastShadowingAudioPath,
    'mastery_level': masteryLevel,
    'srs_due_date': srsDueDate?.toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  };

  SentencePracticeProgress copyWith({
    int? listeningAttempts,
    int? shadowingAttempts,
    int? readingAttempts,
    double? lastScore,
    double? bestScore,
    DateTime? lastPracticedAt,
    String? lastShadowingAudioPath,
    String? masteryLevel,
    DateTime? srsDueDate,
  }) {
    return SentencePracticeProgress(
      id: id,
      sentenceId: sentenceId,
      hskLevel: hskLevel,
      listeningAttempts: listeningAttempts ?? this.listeningAttempts,
      shadowingAttempts: shadowingAttempts ?? this.shadowingAttempts,
      readingAttempts: readingAttempts ?? this.readingAttempts,
      lastScore: lastScore ?? this.lastScore,
      bestScore: bestScore ?? this.bestScore,
      lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
      lastShadowingAudioPath: lastShadowingAudioPath ?? this.lastShadowingAudioPath,
      masteryLevel: masteryLevel ?? this.masteryLevel,
      srsDueDate: srsDueDate ?? this.srsDueDate,
    );
  }
}

/// Audio download pack bundle descriptor
class AudioPack {
  final String id;
  final String title;
  final int hskLevel;
  final int sentenceCount;
  final int totalSizeBytes;
  final String downloadStatus; // 'not_downloaded', 'downloading', 'downloaded'
  final double progress; // 0.0 to 1.0

  const AudioPack({
    required this.id,
    required this.title,
    required this.hskLevel,
    required this.sentenceCount,
    required this.totalSizeBytes,
    this.downloadStatus = 'not_downloaded',
    this.progress = 0.0,
  });

  bool get isDownloaded => downloadStatus == 'downloaded' || downloadStatus == 'bundled';
  bool get isBundled => downloadStatus == 'bundled';
  bool get isDownloading => downloadStatus == 'downloading';
  String get sizeMb => (totalSizeBytes / (1024 * 1024)).toStringAsFixed(1);
}
