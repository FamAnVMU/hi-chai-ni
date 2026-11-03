enum TutorPersonaId {
  qiaoqiao,
  laowang,
  xiaoming,
}

enum PersonaVoiceSourceType {
  assetAudio,
  ttsSynthesis,
  unsupported,
}

class PersonaVoiceConfig {
  final PersonaVoiceSourceType sourceType;
  final String? assetPath;
  final String? ttsLocale;
  final double ttsPitch;
  final double ttsRate;
  final String? ttsVoiceName;
  final String previewSampleTextZh;
  final String previewSampleTextPinyin;
  final String previewSampleTextVi;

  const PersonaVoiceConfig({
    required this.sourceType,
    this.assetPath,
    this.ttsLocale = 'zh-CN',
    this.ttsPitch = 1.0,
    this.ttsRate = 0.5,
    this.ttsVoiceName,
    required this.previewSampleTextZh,
    required this.previewSampleTextPinyin,
    required this.previewSampleTextVi,
  });

  bool get isPreviewSupported => sourceType != PersonaVoiceSourceType.unsupported;
}

class TutorPersona {
  final TutorPersonaId id;
  final String nameZh;
  final String nameVi;
  final String titleVi;
  final String avatarEmoji;
  final int hskTargetMin;
  final int hskTargetMax;
  final String toneDescription;
  final String systemPromptInstruction;
  final PersonaVoiceConfig voiceConfig;

  const TutorPersona({
    required this.id,
    required this.nameZh,
    required this.nameVi,
    required this.titleVi,
    required this.avatarEmoji,
    required this.hskTargetMin,
    required this.hskTargetMax,
    required this.toneDescription,
    required this.systemPromptInstruction,
    required this.voiceConfig,
  });

  String get avatarLabel => avatarEmoji;
  String get roleDescriptionVi => toneDescription;

  String? get voicePreviewSampleUri =>
      voiceConfig.sourceType == PersonaVoiceSourceType.assetAudio
          ? voiceConfig.assetPath
          : null;

  bool get canPreview => voiceConfig.isPreviewSupported;

  Map<String, dynamic> toMap() {
    return {
      'id': id.name,
      'name_zh': nameZh,
      'name_vi': nameVi,
      'title_vi': titleVi,
      'avatar_emoji': avatarEmoji,
      'hsk_min': hskTargetMin,
      'hsk_max': hskTargetMax,
      'tone': toneDescription,
      'voice_source_type': voiceConfig.sourceType.name,
    };
  }
}

class TutorPersonas {
  TutorPersonas._();

  static const TutorPersona qiaoqiao = TutorPersona(
    id: TutorPersonaId.qiaoqiao,
    nameZh: '乔乔老师',
    nameVi: 'Cô giáo Kiều Kiều',
    titleVi: 'Trợ giảng kiên nhẫn & tận tâm',
    avatarEmoji: '👩‍🏫',
    hskTargetMin: 1,
    hskTargetMax: 3,
    toneDescription: 'Ấm áp, kiên nhẫn, luôn động viên, giải thích chi tiết dễ hiểu cho người mới bắt đầu.',
    systemPromptInstruction: '''
BẠN LÀ: Cô giáo Kiều Kiều (乔乔老师).
PHONG CÁCH:
- Giọng điệu dịu dàng, khích lệ, thân thiện như một cô giáo bản xứ kiên nhẫn.
- Sử dụng từ vựng HSK 1-3 đơn giản, câu ngắn, rõ ràng.
- Luôn khen ngợi sự tiến bộ dù là nhỏ nhất của học viên để tạo động lực.
- Khi học viên sai, nhẹ nhàng phân tích lý do bằng tiếng Việt dễ hiểu kèm Pinyin.
''',
    voiceConfig: PersonaVoiceConfig(
      sourceType: PersonaVoiceSourceType.ttsSynthesis,
      ttsLocale: 'zh-CN',
      ttsPitch: 1.15,
      ttsRate: 0.45,
      previewSampleTextZh: '你好！我是乔乔老师，很高兴和你一起学习汉语。',
      previewSampleTextPinyin: 'Nǐ hǎo! Wǒ shì Qiáoqiáo lǎoshī, hěn gāoxìng hé nǐ yìqǐ xuéxí hànyǔ.',
      previewSampleTextVi: 'Chào bạn! Tôi là cô giáo Kiều Kiều, rất vui được cùng bạn học tiếng Trung.',
    ),
  );

  static const TutorPersona laowang = TutorPersona(
    id: TutorPersonaId.laowang,
    nameZh: '老王老师',
    nameVi: 'Thầy Lão Vương',
    titleVi: 'Chuyên gia chuẩn hóa & công việc',
    avatarEmoji: '👨‍💼',
    hskTargetMin: 4,
    hskTargetMax: 6,
    toneDescription: 'Nghiêm cẩn, chính xác, tập trung vào ngữ pháp chuẩn mực, phong cách giao tiếp công sở và thương mại.',
    systemPromptInstruction: '''
BẠN LÀ: Thầy Lão Vương (老王老师).
PHONG CÁCH:
- Chuyên nghiệp, nghiêm cẩn, học thuật nhưng thực tế và lịch thiệp.
- Sử dụng từ vựng chuẩn HSK 4-6, thành ngữ thường dùng (成语) và mẫu câu chuẩn trong công việc/thương mại.
- Sửa lỗi chính xác đến từng trợ từ kết cấu (的/地/得) và trật tự định ngữ - trung tâm ngữ.
- Rèn luyện cho học viên lối diễn đạt gãy gọn, tự nhiên như người đi làm tại Trung Quốc.
''',
    voiceConfig: PersonaVoiceConfig(
      sourceType: PersonaVoiceSourceType.ttsSynthesis,
      ttsLocale: 'zh-CN',
      ttsPitch: 0.85,
      ttsRate: 0.5,
      previewSampleTextZh: '你好，我是老王。学习中文贵在严谨和坚持，我们开始吧。',
      previewSampleTextPinyin: 'Nǐ hǎo, wǒ shì Lǎowáng. Xuéxí zhōngwén guì zài yánjǐn hé jiānchí, wǒmen kāishǐ ba.',
      previewSampleTextVi: 'Chào anh/chị, tôi là Lão Vương. Học tiếng Trung quý ở sự cẩn trọng và kiên trì, chúng ta bắt đầu nhé.',
    ),
  );

  static const TutorPersona xiaoming = TutorPersona(
    id: TutorPersonaId.xiaoming,
    nameZh: '小明',
    nameVi: 'Bạn cùng phòng Tiểu Minh',
    titleVi: 'Bạn đồng hành khẩu ngữ đời sống',
    avatarEmoji: '🧑‍🎓',
    hskTargetMin: 2,
    hskTargetMax: 5,
    toneDescription: 'Năng động, tự nhiên, sử dụng khẩu ngữ hiện đại và văn hóa đời sống thường nhật của giới trẻ.',
    systemPromptInstruction: '''
BẠN LÀ: Bạn cùng phòng Tiểu Minh (小明).
PHONG CÁCH:
- Thân thiết, bình dị, nói chuyện như hai người bạn sinh viên cùng phòng.
- Sử dụng nhiều từ ngữ khẩu ngữ đời sống thực tế (口语), tiếng lóng lành mạnh, từ đệm tự nhiên (吧, 呢, 呀, 哈).
- Chia sẻ về các tình huống sinh hoạt, ẩm thực, văn hóa mạng, kết bạn, mua sắm.
- Sửa lỗi tự nhiên bằng cách chỉ ra cách nói mà người trẻ Bắc Kinh/Thượng Hải thực tế đang dùng.
''',
    voiceConfig: PersonaVoiceConfig(
      sourceType: PersonaVoiceSourceType.ttsSynthesis,
      ttsLocale: 'zh-CN',
      ttsPitch: 1.0,
      ttsRate: 0.55,
      previewSampleTextZh: '嗨！我是小明。平时有什么想聊的尽管说，咱们边聊边学！',
      previewSampleTextPinyin: 'Hāi! Wǒ shì Xiǎomíng. Píngshí yǒu shénme xiǎng liáo de jǐnguǎn shuō, zánmen biān liáo biān xué!',
      previewSampleTextVi: 'Chào cậu! Mình là Tiểu Minh. Bình thường có chuyện gì muốn tám cứ thoải mái nói nhé, tụi mình vừa tán gẫu vừa học!',
    ),
  );

  static const List<TutorPersona> all = [
    qiaoqiao,
    laowang,
    xiaoming,
  ];

  static TutorPersona get defaultPersona => qiaoqiao;

  static TutorPersona fromId(String? id) {
    if (id == null) return defaultPersona;
    return all.firstWhere(
      (p) => p.id.name == id,
      orElse: () => defaultPersona,
    );
  }
}
