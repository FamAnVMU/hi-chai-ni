import '../models/shadowing_models.dart';

/// Curated library of structured conversational passages for Shadowing practice.
class ShadowingDocumentBank {
  const ShadowingDocumentBank();

  static const List<ShadowingDocument> allDocuments = [
    // Document 1: Gặp gỡ và làm quen (HSK 1)
    ShadowingDocument(
      id: 'DOC_01_GREETINGS',
      title: 'Chào hỏi và làm quen tại sân bay',
      description: 'Hội thoại giao tiếp cơ bản khi lần đầu gặp đối tác hoặc bạn bè.',
      hskLevel: 1,
      segments: [
        ShadowingSegment(
          id: 'DOC01_SEG01',
          order: 1,
          hanzi: '你好，请问你是王老师吗？',
          pinyin: 'Nǐ hǎo, qǐngwèn nǐ shì Wáng lǎoshī ma?',
          meaningVi: 'Xin chào, xin hỏi bạn có phải là thầy Vương không?',
          audioUri: 'assets/audio/shadowing/doc01_01.mp3',
          durationMs: 2800,
        ),
        ShadowingSegment(
          id: 'DOC01_SEG02',
          order: 2,
          hanzi: '我是，请问你是李明吗？',
          pinyin: 'Wǒ shì, qǐngwèn nǐ shì Lǐ Míng ma?',
          meaningVi: 'Tôi đây, xin hỏi bạn có phải là Lý Minh không?',
          audioUri: 'assets/audio/shadowing/doc01_02.mp3',
          durationMs: 2500,
        ),
        ShadowingSegment(
          id: 'DOC01_SEG03',
          order: 3,
          hanzi: '很高兴认识你！一路辛苦了。',
          pinyin: 'Hěn gāoxìng rènshí nǐ! Yílù xīnkǔ le.',
          meaningVi: 'Rất vui được gặp bạn! Đi đường vất vả rồi.',
          audioUri: 'assets/audio/shadowing/doc01_03.mp3',
          durationMs: 3100,
        ),
      ],
    ),

    // Document 2: Gọi món ăn tại nhà hàng (HSK 2)
    ShadowingDocument(
      id: 'DOC_02_RESTAURANT',
      title: 'Gọi món tại nhà hàng Trung Hoa',
      description: 'Giao tiếp gọi món, hỏi hương vị và yêu cầu đồ uống.',
      hskLevel: 2,
      segments: [
        ShadowingSegment(
          id: 'DOC02_SEG01',
          order: 1,
          hanzi: '服务员，我们要两碗牛肉面。',
          pinyin: 'Fúwùyuán, wǒmen yào liǎng wǎn niúròumiàn.',
          meaningVi: 'Phục vụ ơi, chúng tôi gọi hai bát mì bò.',
          audioUri: 'assets/audio/shadowing/doc02_01.mp3',
          durationMs: 2900,
        ),
        ShadowingSegment(
          id: 'DOC02_SEG02',
          order: 2,
          hanzi: '好的，请问面里要放辣椒吗？',
          pinyin: 'Hǎode, qǐngwèn miàn lǐ yào fàng làjiāo ma?',
          meaningVi: 'Vâng ạ, xin hỏi trong mì có cần cho ớt không?',
          audioUri: 'assets/audio/shadowing/doc02_02.mp3',
          durationMs: 2700,
        ),
        ShadowingSegment(
          id: 'DOC02_SEG03',
          order: 3,
          hanzi: '少放一点，再来一杯冰水，谢谢！',
          pinyin: 'Shǎo fàng yìdiǎn, zài lái yì bēi bīngshuǐ, xièxie!',
          meaningVi: 'Cho ít thôi nhé, thêm một cốc nước đá nữa, cảm ơn!',
          audioUri: 'assets/audio/shadowing/doc02_03.mp3',
          durationMs: 3400,
        ),
      ],
    ),

    // Document 3: Hỏi đường và phương tiện (HSK 3)
    ShadowingDocument(
      id: 'DOC_03_DIRECTIONS',
      title: 'Hỏi đường đến ga tàu điện ngầm',
      description: 'Hỏi hướng đi, khoảng cách và thời gian di chuyển.',
      hskLevel: 3,
      segments: [
        ShadowingSegment(
          id: 'DOC03_SEG01',
          order: 1,
          hanzi: '请问去最近的地铁站怎么走？',
          pinyin: 'Qǐngwèn qù zuìjìn de dìtiězhàn zěnme zǒu?',
          meaningVi: 'Xin hỏi đến ga tàu điện ngầm gần nhất đi như thế nào?',
          audioUri: 'assets/audio/shadowing/doc03_01.mp3',
          durationMs: 3000,
        ),
        ShadowingSegment(
          id: 'DOC03_SEG02',
          order: 2,
          hanzi: '一直往前走，在第二个路口向右拐。',
          pinyin: 'Yìzhí wǎng qián zǒu, zài dì èr gè lùkǒu xiàng yòu guǎi.',
          meaningVi: 'Đi thẳng về phía trước, ở ngã tư thứ hai thì rẽ phải.',
          audioUri: 'assets/audio/shadowing/doc03_02.mp3',
          durationMs: 3500,
        ),
        ShadowingSegment(
          id: 'DOC03_SEG03',
          order: 3,
          hanzi: '太感谢你了，祝你今天过得愉快！',
          pinyin: 'Tài gǎnxiè nǐ le, zhù nǐ jīntiān guò de yúkuài!',
          meaningVi: 'Cảm ơn bạn rất nhiều, chúc bạn một ngày vui vẻ!',
          audioUri: 'assets/audio/shadowing/doc03_03.mp3',
          durationMs: 3100,
        ),
      ],
    ),
  ];

  ShadowingDocument? getDocumentById(String id) {
    try {
      return allDocuments.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}
