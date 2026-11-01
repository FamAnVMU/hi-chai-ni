import 'dart:convert';
import '../../../../core/theme/components/ruby_text/ruby_segment.dart';

/// Reading view modes for interactive reading exercise
enum ReadingDisplayMode {
  /// Hiển thị đầy đủ: Chữ Hán, Pinyin và Bản dịch tiếng Việt
  full,

  /// Hiển thị Chữ Hán và Pinyin (ẩn bản dịch để tự hiểu)
  hanziAndPinyin,

  /// Chỉ hiển thị Chữ Hán (thử thách đọc không cần Pinyin)
  hanziOnly,

  /// Hiển thị Chữ Hán và Bản dịch (ẩn Pinyin để luyện mặt chữ)
  hanziAndTranslation,
}

/// Comprehension question type
enum ReadingQuestionType {
  singleChoice,
  trueFalse,
  detailVerification,
}

/// A comprehension question testing understanding of passage meaning
class ReadingQuestion {
  final String id;
  final ReadingQuestionType type;
  final String question;
  final List<String> options;
  final int answerIndex;
  final String? answerText;
  final String explanationVi;
  final String? citationText;

  const ReadingQuestion({
    required this.id,
    required this.type,
    required this.question,
    this.options = const [],
    this.answerIndex = 0,
    this.answerText,
    required this.explanationVi,
    this.citationText,
  });

  factory ReadingQuestion.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String? ?? 'single_choice';
    final qType = rawType == 'true_false'
        ? ReadingQuestionType.trueFalse
        : (rawType == 'detail'
            ? ReadingQuestionType.detailVerification
            : ReadingQuestionType.singleChoice);

    final rawOptions = json['options'] as List<dynamic>? ?? [];
    final options = rawOptions.map((e) => e.toString()).toList();

    int ansIndex = 0;
    String? ansText;
    final rawAns = json['answer'];
    if (rawAns is int) {
      ansIndex = rawAns;
    } else if (rawAns is String) {
      ansText = rawAns;
      // Match option if exists
      final idx = options.indexOf(rawAns);
      if (idx >= 0) ansIndex = idx;
    }

    return ReadingQuestion(
      id: json['id'] as String? ?? '',
      type: qType,
      question: json['question'] as String? ?? '',
      options: options,
      answerIndex: ansIndex,
      answerText: ansText,
      explanationVi: json['explanationVi'] as String? ?? '',
      citationText: json['citationText'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'question': question,
        'options': options,
        'answer': answerIndex,
        'explanationVi': explanationVi,
        if (citationText != null) 'citationText': citationText,
      };
}

/// An interactive Chinese reading passage
class ReadingPassage {
  final String id;
  final int hskLevel;
  final String titleCn;
  final String contentCn;
  final String pinyin;
  final String translationVi;
  final String? audioUri;
  final String topic;
  final int estimatedMinutes;
  final List<ReadingQuestion> questions;

  const ReadingPassage({
    required this.id,
    required this.hskLevel,
    required this.titleCn,
    required this.contentCn,
    required this.pinyin,
    required this.translationVi,
    this.audioUri,
    this.topic = 'Đời sống',
    this.estimatedMinutes = 3,
    this.questions = const [],
  });

  int get wordCount => contentCn.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '').length;

  factory ReadingPassage.fromMap(Map<String, dynamic> map) {
    List<ReadingQuestion> parsedQuestions = [];
    final rawQuestions = map['questions_json'];
    if (rawQuestions is String && rawQuestions.isNotEmpty) {
      try {
        final decoded = json.decode(rawQuestions) as List<dynamic>;
        parsedQuestions = decoded
            .map((q) => ReadingQuestion.fromJson(q as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    int hsk = map['hsk_level'] as int? ?? 1;
    String topicName = 'Đời sống';
    if (hsk == 2) topicName = 'Ẩm thực';
    if (hsk == 3) topicName = 'Du lịch';
    if (hsk == 4) topicName = 'Văn hóa';
    if (hsk >= 5) topicName = 'Thành ngữ';

    return ReadingPassage(
      id: map['id'] as String,
      hskLevel: hsk,
      titleCn: map['title_cn'] as String? ?? map['title'] as String? ?? '',
      contentCn: map['content_cn'] as String? ?? map['contentZh'] as String? ?? '',
      pinyin: map['pinyin'] as String? ?? '',
      translationVi: map['translation_vi'] as String? ?? map['translationVi'] as String? ?? '',
      audioUri: map['audio_uri'] as String?,
      topic: topicName,
      estimatedMinutes: (map['content_cn']?.toString().length ?? 100) ~/ 40 + 1,
      questions: parsedQuestions,
    );
  }

  /// Converts the passage content and pinyin into a list of RubySegments for interactive reading.
  List<RubySegment> buildRubySegments() {
    // If text already has brackets like '李明[Lǐ Míng]', use parser
    if (contentCn.contains('[') && contentCn.contains(']')) {
      return RubySegment.fromAnnotatedString(contentCn);
    }

    // Otherwise segment by character/word with aligned syllables
    final List<RubySegment> segments = [];
    final characters = contentCn.split('');
    final syllables = pinyin.split(' ').where((s) => s.isNotEmpty).toList();

    int sylIdx = 0;
    for (int i = 0; i < characters.length; i++) {
      final ch = characters[i];
      final isHanzi = RegExp(r'[\u4e00-\u9fa5]').hasMatch(ch);

      if (isHanzi) {
        final syl = sylIdx < syllables.length ? syllables[sylIdx] : '';
        segments.add(RubySegment.word(
          hanzi: ch,
          pinyin: syl,
          wordId: 'word_$ch',
          offset: i,
        ));
        sylIdx++;
      } else if (RegExp(r'[，。！？；：“”‘’（）《》、\.,!\?;:\(\)]').hasMatch(ch)) {
        segments.add(RubySegment.punctuation(ch, offset: i));
      } else {
        segments.add(RubySegment.plainText(ch, offset: i));
      }
    }

    return segments;
  }
}

/// Saved user reading progress on a passage
class ReadingProgress {
  final String id;
  final String passageId;
  final double lastScrollOffset;
  final bool isCompleted;
  final int readingTimeSeconds;
  final Map<String, int> answers;
  final double? score;
  final DateTime? completedAt;
  final DateTime updatedAt;

  const ReadingProgress({
    required this.id,
    required this.passageId,
    this.lastScrollOffset = 0.0,
    this.isCompleted = false,
    this.readingTimeSeconds = 0,
    this.answers = const {},
    this.score,
    this.completedAt,
    required this.updatedAt,
  });

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    Map<String, int> parsedAnswers = {};
    final rawAns = map['answers_json'];
    if (rawAns is String && rawAns.isNotEmpty) {
      try {
        final decoded = json.decode(rawAns) as Map<String, dynamic>;
        parsedAnswers = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    return ReadingProgress(
      id: map['id'] as String,
      passageId: map['passage_id'] as String,
      lastScrollOffset: (map['last_scroll_offset'] as num?)?.toDouble() ?? 0.0,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      readingTimeSeconds: map['reading_time_seconds'] as int? ?? 0,
      answers: parsedAnswers,
      score: (map['score'] as num?)?.toDouble(),
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'] as String)
          : null,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'passage_id': passageId,
        'last_scroll_offset': lastScrollOffset,
        'is_completed': isCompleted ? 1 : 0,
        'reading_time_seconds': readingTimeSeconds,
        'answers_json': json.encode(answers),
        if (score != null) 'score': score,
        if (completedAt != null) 'completed_at': completedAt!.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}
