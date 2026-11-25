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

  static const List<String> officialTopics = [
    'Đời sống & Gia đình',
    'Ẩm thực Trung Hoa',
    'Du lịch & Khám phá',
    'Truyện ngụ ngôn & Thành ngữ',
    'Văn hóa & Lễ hội',
    'Khoa học & Tự nhiên',
  ];

  const ReadingPassage({
    required this.id,
    required this.hskLevel,
    required this.titleCn,
    required this.contentCn,
    required this.pinyin,
    required this.translationVi,
    this.audioUri,
    this.topic = 'Đời sống & Gia đình',
    this.estimatedMinutes = 3,
    this.questions = const [],
  });

  int get wordCount => contentCn.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '').length;

  static String resolveOfficialTopic({
    required String id,
    required int hskLevel,
    String? explicitTopic,
  }) {
    if (explicitTopic != null && officialTopics.contains(explicitTopic)) {
      return explicitTopic;
    }
    final lowerId = id.toLowerCase();
    if (lowerId.contains('friend') || lowerId.contains('family') || lowerId.contains('daily')) {
      return 'Đời sống & Gia đình';
    }
    if (lowerId.contains('restaurant') || lowerId.contains('breakfast') || lowerId.contains('food') || lowerId.contains('tea')) {
      return 'Ẩm thực Trung Hoa';
    }
    if (lowerId.contains('travel') || lowerId.contains('train') || lowerId.contains('beijing') || lowerId.contains('trip')) {
      return 'Du lịch & Khám phá';
    }
    if (lowerId.contains('idiom') || lowerId.contains('fable') || lowerId.contains('frog') || lowerId.contains('rabbit')) {
      return 'Truyện ngụ ngôn & Thành ngữ';
    }
    if (lowerId.contains('festival') || lowerId.contains('autumn') || lowerId.contains('spring') || lowerId.contains('culture')) {
      return 'Văn hóa & Lễ hội';
    }
    if (lowerId.contains('nature') || lowerId.contains('seasons') || lowerId.contains('panda') || lowerId.contains('science')) {
      return 'Khoa học & Tự nhiên';
    }
    if (hskLevel == 2) return 'Ẩm thực Trung Hoa';
    if (hskLevel == 3) return 'Du lịch & Khám phá';
    if (hskLevel == 4) return 'Văn hóa & Lễ hội';
    if (hskLevel >= 5) return 'Truyện ngụ ngôn & Thành ngữ';
    return 'Đời sống & Gia đình';
  }

  factory ReadingPassage.fromMap(Map<String, dynamic> map) {
    List<ReadingQuestion> parsedQuestions = [];
    final rawQuestions = map['questions_json'] ?? map['questions'];
    if (rawQuestions is String && rawQuestions.isNotEmpty) {
      try {
        final decoded = json.decode(rawQuestions) as List<dynamic>;
        parsedQuestions = decoded
            .map((q) => ReadingQuestion.fromJson(q as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    } else if (rawQuestions is List) {
      parsedQuestions = rawQuestions
          .whereType<Map<String, dynamic>>()
          .map(ReadingQuestion.fromJson)
          .toList();
    }

    final id = map['id'] as String? ?? '';
    final hsk = (map['hsk_level'] as int?) ?? (map['hskLevel'] as int?) ?? 1;
    final content = map['content_cn'] as String? ??
        map['contentCn'] as String? ??
        map['contentZh'] as String? ??
        '';
    final topicName = resolveOfficialTopic(
      id: id,
      hskLevel: hsk,
      explicitTopic: map['topic'] as String?,
    );
    final explicitEst = (map['estimatedMinutes'] as int?) ??
        (map['estimated_minutes'] as int?);
    final estMinutes = explicitEst ?? ((content.length ~/ 40) + 1).clamp(2, 10);

    return ReadingPassage(
      id: id,
      hskLevel: hsk,
      titleCn: map['title_cn'] as String? ??
          map['titleCn'] as String? ??
          map['title'] as String? ??
          '',
      contentCn: content,
      pinyin: map['pinyin'] as String? ?? '',
      translationVi: map['translation_vi'] as String? ??
          map['translationVi'] as String? ??
          '',
      audioUri: map['audio_uri'] as String? ?? map['audioUri'] as String?,
      topic: topicName,
      estimatedMinutes: estMinutes,
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
    final syllables = splitPinyinSyllables(pinyin);

    int sylIdx = 0;
    for (int i = 0; i < characters.length; i++) {
      final ch = characters[i];
      final isHanzi = RegExp(r'[\u4e00-\u9fa5]').hasMatch(ch);

      if (isHanzi) {
        final syl = sylIdx < syllables.length ? syllables[sylIdx] : '';
        segments.add(RubySegment.word(
          hanzi: ch,
          pinyin: syl,
          wordId: 'seg_$i',
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

const Set<String> _validMandarinSyllables = {
  'a', 'ai', 'an', 'ang', 'ao',
  'ba', 'bai', 'ban', 'bang', 'bao', 'bei', 'ben', 'beng', 'bi', 'bian', 'biao', 'bie', 'bin', 'bing', 'bo', 'bu',
  'ca', 'cai', 'can', 'cang', 'cao', 'ce', 'cen', 'ceng', 'cha', 'chai', 'chan', 'chang', 'chao', 'che', 'chen', 'cheng', 'chi', 'chong', 'chou', 'chu', 'chua', 'chuai', 'chuan', 'chuang', 'chui', 'chun', 'chuo', 'ci', 'cong', 'cou', 'cu', 'cuan', 'cui', 'cun', 'cuo',
  'da', 'dai', 'dan', 'dang', 'dao', 'de', 'dei', 'den', 'deng', 'di', 'dia', 'dian', 'diao', 'die', 'ding', 'diu', 'dong', 'dou', 'du', 'duan', 'dui', 'dun', 'duo',
  'e', 'ei', 'en', 'eng', 'er',
  'fa', 'fan', 'fang', 'fei', 'fen', 'feng', 'fo', 'fou', 'fu',
  'ga', 'gai', 'gan', 'gang', 'gao', 'ge', 'gei', 'gen', 'geng', 'gong', 'gou', 'gu', 'gua', 'guai', 'guan', 'guang', 'gui', 'gun', 'guo',
  'ha', 'hai', 'han', 'hang', 'hao', 'he', 'hei', 'hen', 'heng', 'hm', 'hng', 'hong', 'hou', 'hu', 'hua', 'huai', 'huan', 'huang', 'hui', 'hun', 'huo',
  'ji', 'jia', 'jian', 'jiang', 'jiao', 'jie', 'jin', 'jing', 'jiong', 'jiu', 'ju', 'juan', 'jue', 'jun',
  'ka', 'kai', 'kan', 'kang', 'kao', 'ke', 'kei', 'ken', 'keng', 'kong', 'kou', 'ku', 'kua', 'kuai', 'kuan', 'kuang', 'kui', 'kun', 'kuo',
  'la', 'lai', 'lan', 'lang', 'lao', 'le', 'lei', 'leng', 'li', 'lia', 'lian', 'liang', 'liao', 'lie', 'lin', 'ling', 'liu', 'lo', 'long', 'lou', 'lu', 'luan', 'lve', 'lun', 'luo', 'lv',
  'ma', 'mai', 'man', 'mang', 'mao', 'me', 'mei', 'men', 'meng', 'mi', 'mian', 'miao', 'mie', 'min', 'ming', 'miu', 'mo', 'mou', 'mu', 'm',
  'na', 'nai', 'nan', 'nang', 'nao', 'ne', 'nei', 'nen', 'neng', 'ng', 'ni', 'nian', 'niang', 'niao', 'nie', 'nin', 'ning', 'niu', 'nong', 'nou', 'nu', 'nuan', 'nve', 'nuo', 'nv', 'n',
  'o', 'ou',
  'pa', 'pai', 'pan', 'pang', 'pao', 'pei', 'pen', 'peng', 'pi', 'pian', 'piao', 'pie', 'pin', 'ping', 'po', 'pou', 'pu',
  'qi', 'qia', 'qian', 'qiang', 'qiao', 'qie', 'qin', 'qing', 'qiong', 'qiu', 'qu', 'quan', 'que', 'qun',
  'ran', 'rang', 'rao', 're', 'ren', 'reng', 'ri', 'rong', 'rou', 'ru', 'rua', 'ruan', 'rui', 'run', 'ruo', 'r',
  'sa', 'sai', 'san', 'sang', 'sao', 'se', 'sen', 'seng', 'sha', 'shai', 'shan', 'shang', 'shao', 'she', 'shei', 'shen', 'sheng', 'shi', 'shou', 'shu', 'shua', 'shuai', 'shuan', 'shuang', 'shui', 'shun', 'shuo', 'si', 'song', 'sou', 'su', 'suan', 'sui', 'sun', 'suo',
  'ta', 'tai', 'tan', 'tang', 'tao', 'te', 'tei', 'teng', 'ti', 'tian', 'tiao', 'tie', 'ting', 'tong', 'tou', 'tu', 'tuan', 'tui', 'tun', 'tuo',
  'wa', 'wai', 'wan', 'wang', 'wei', 'wen', 'weng', 'wo', 'wu',
  'xi', 'xia', 'xian', 'xiang', 'xiao', 'xie', 'xin', 'xing', 'xiong', 'xiu', 'xu', 'xuan', 'xue', 'xun',
  'ya', 'yan', 'yang', 'yao', 'ye', 'yi', 'yin', 'ying', 'yo', 'yong', 'you', 'yu', 'yuan', 'yue', 'yun',
  'za', 'zai', 'zan', 'zang', 'zao', 'ze', 'zei', 'zen', 'zeng', 'zha', 'zhai', 'zhan', 'zhang', 'zhao', 'zhe', 'zhei', 'zhen', 'zheng', 'zhi', 'zhong', 'zhou', 'zhu', 'zhua', 'zhuai', 'zhuan', 'zhuang', 'zhui', 'zhun', 'zhuo', 'zi', 'zong', 'zou', 'zu', 'zuan', 'zui', 'zun', 'zuo',
};

const Map<String, String> _pinyinPlainMap = {
  'ā': 'a', 'á': 'a', 'ǎ': 'a', 'à': 'a',
  'ē': 'e', 'é': 'e', 'ě': 'e', 'è': 'e',
  'ī': 'i', 'í': 'i', 'ǐ': 'i', 'ì': 'i',
  'ō': 'o', 'ó': 'o', 'ǒ': 'o', 'ò': 'o',
  'ū': 'u', 'ú': 'u', 'ǔ': 'u', 'ù': 'u',
  'ǖ': 'v', 'ǘ': 'v', 'ǚ': 'v', 'ǜ': 'v', 'ü': 'v',
  'ń': 'n', 'ň': 'n', 'ǹ': 'n', 'ḿ': 'm', 'ê': 'e',
};

const Set<String> _tonedPinyinChars = {
  'ā', 'á', 'ǎ', 'à', 'Ā', 'Á', 'Ǎ', 'À',
  'ē', 'é', 'ě', 'è', 'Ē', 'É', 'Ě', 'È',
  'ī', 'í', 'ǐ', 'ì', 'Ī', 'Í', 'Ǐ', 'Ì',
  'ō', 'ó', 'ǒ', 'ò', 'Ō', 'Ó', 'Ǒ', 'Ò',
  'ū', 'ú', 'ǔ', 'ù', 'Ū', 'Ú', 'Ǔ', 'Ù',
  'ǖ', 'ǘ', 'ǚ', 'ǜ', 'Ǖ', 'Ǘ', 'Ǚ', 'Ǜ',
  'ń', 'ň', 'ǹ', 'Ń', 'Ň', 'Ǹ', 'ḿ', 'Ḿ',
};

final RegExp _pinyinTokenRegex = RegExp(
  r'[a-zA-ZāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜüĀÁǍÀĒÉĚÈĪÍǏÌŌÓǑÒŪÚǓÙǕǗǙǛÜńňǹḿŃŇǸḾ]+',
);

/// Splits raw HSK Pinyin (space-separated, concatenated compounds, apostrophes, hyphens, erhua)
/// into individual syllable strings aligned 1-to-1 with Chinese characters.
List<String> splitPinyinSyllables(String rawPinyin) {
  if (rawPinyin.trim().isEmpty) return const [];
  final syllables = <String>[];
  for (final match in _pinyinTokenRegex.allMatches(rawPinyin)) {
    final token = match.group(0)!;
    syllables.addAll(_splitPinyinToken(token));
  }
  return syllables;
}

List<String> _splitPinyinToken(String word) {
  final plainBuf = StringBuffer();
  for (int i = 0; i < word.length; i++) {
    final lower = word[i].toLowerCase();
    plainBuf.write(_pinyinPlainMap[lower] ?? lower);
  }
  final plain = plainBuf.toString();
  if (plain.isEmpty) return const [];

  // Skip uppercase non-pinyin acronyms such as "IDC" embedded inside C3 pinyin strings.
  final isAllUpper = word == word.toUpperCase() && word != word.toLowerCase();
  if (isAllUpper && word.length > 1 && !_validMandarinSyllables.contains(plain)) {
    return const [];
  }

  final n = plain.length;
  final dp = List<List<String>?>.filled(n + 1, null);
  dp[n] = const [];

  for (int i = n - 1; i >= 0; i--) {
    List<String>? best;
    final maxLen = (n - i) < 6 ? (n - i) : 6;
    for (int len = maxLen; len >= 1; len--) {
      final subPlain = plain.substring(i, i + len);
      // Erhua 'r' only attaches as a trailing suffix to a preceding syllable.
      if (subPlain == 'r' && (i == 0 || i + len != n)) continue;
      if ((subPlain == 'n' || subPlain == 'm' || subPlain == 'ng') &&
          n > 1 &&
          i + len < n) {
        continue;
      }
      final tail = dp[i + len];
      if (tail == null || !_validMandarinSyllables.contains(subPlain)) continue;

      final subOrig = word.substring(i, i + len);
      int toneCount = 0;
      for (int k = 0; k < subOrig.length; k++) {
        if (_tonedPinyinChars.contains(subOrig[k])) toneCount++;
      }
      if (toneCount > 1) continue;

      final cand = [subOrig, ...tail];
      if (best == null || cand.length < best.length) {
        best = cand;
      }
    }
    dp[i] = best;
  }

  if (dp[0] != null) return dp[0]!;
  if (!isAllUpper && _validMandarinSyllables.contains(plain)) return [word];
  return const [];
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
