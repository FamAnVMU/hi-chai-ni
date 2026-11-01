import '../models/pronunciation_models.dart';

/// Curated bank of pronunciation targets covering Mandarin Chinese phonology.
class PronunciationItemBank {
  const PronunciationItemBank();

  static const List<PronunciationTarget> allTargets = [
    // 1. Tones (Thanh điệu)
    PronunciationTarget(
      id: 'TONE_01_MA1',
      text: '妈',
      pinyin: 'mā',
      meaningVi: 'Mẹ (Thanh 1: âm vực 55 cao bằng)',
      category: PronunciationCategory.tone,
      ipa: '/ma˥˥/',
      audioUri: 'assets/audio/pronunciation/ma1.mp3',
      hintVi: 'Giữ âm cao đều ở mức 5-5, không hạ giọng ở cuối.',
    ),
    PronunciationTarget(
      id: 'TONE_02_MA2',
      text: '麻',
      pinyin: 'má',
      meaningVi: 'Vừng/mè, tê rần (Thanh 2: âm vực 35 vút lên)',
      category: PronunciationCategory.tone,
      ipa: '/ma˧˥/',
      audioUri: 'assets/audio/pronunciation/ma2.mp3',
      hintVi: 'Bắt đầu ở mức trung bình và vút nhanh lên cao như dấu hỏi/sắc trong tiếng Việt.',
    ),
    PronunciationTarget(
      id: 'TONE_03_MA3',
      text: '马',
      pinyin: 'mǎ',
      meaningVi: 'Con ngựa (Thanh 3: âm vực 214 trầm sâu)',
      category: PronunciationCategory.tone,
      ipa: '/ma˨˩˦/',
      audioUri: 'assets/audio/pronunciation/ma3.mp3',
      hintVi: 'Hạ giọng thật sâu xuống đáy cổ họng rồi mới hơi lướt nhẹ lên.',
    ),
    PronunciationTarget(
      id: 'TONE_04_MA4',
      text: '骂',
      pinyin: 'mà',
      meaningVi: 'Mắng mỏ (Thanh 4: âm vực 51 rơi dứt khoát)',
      category: PronunciationCategory.tone,
      ipa: '/ma˥˩/',
      audioUri: 'assets/audio/pronunciation/ma4.mp3',
      hintVi: 'Rơi thật dứt khoát từ mức cao nhất xuống thấp nhất, phát âm dứt khoát.',
    ),

    // 2. Initials (Thanh mẫu âm uốn lưỡi vs đầu lưỡi)
    PronunciationTarget(
      id: 'INIT_01_ZH_CH',
      text: '吃饭',
      pinyin: 'chī fàn',
      meaningVi: 'Ăn cơm (Âm bật hơi uốn lưỡi ch)',
      category: PronunciationCategory.initial,
      ipa: '/ʈʂʰʐ̩˥ fan˥˩/',
      audioUri: 'assets/audio/pronunciation/chifan.mp3',
      hintVi: 'Uốn đầu lưỡi chạm vòm họng và bật luồng hơi mạnh ra ngoài khi phát âm "ch".',
    ),
    PronunciationTarget(
      id: 'INIT_02_Z_C',
      text: '知道',
      pinyin: 'zhī dào',
      meaningVi: 'Biết, thấu hiểu (Âm không bật hơi uốn lưỡi zh)',
      category: PronunciationCategory.initial,
      ipa: '/ʈʂʐ̩˥ taʊ̯˥˩/',
      audioUri: 'assets/audio/pronunciation/zhidao.mp3',
      hintVi: 'Uốn đầu lưỡi chạm ngạc cứng nhưng không bật hơi.',
    ),

    // 3. Finals (Vận mẫu mũi trước vs mũi sau)
    PronunciationTarget(
      id: 'FINAL_01_AN_ANG',
      text: '帮忙',
      pinyin: 'bāng máng',
      meaningVi: 'Giúp đỡ (Vận mẫu ang mở rộng)',
      category: PronunciationCategory.finalSound,
      ipa: '/paŋ˥ maŋ˧˥/',
      audioUri: 'assets/audio/pronunciation/bangmang.mp3',
      hintVi: 'Mở rộng khẩu hình vòm họng sau khi ngân âm vang "ang".',
    ),

    // 4. Common HSK Words
    PronunciationTarget(
      id: 'WORD_01_NIHAO',
      text: '你好',
      pinyin: 'nǐ hǎo',
      meaningVi: 'Xin chào (Biến điệu hai thanh 3: ní hǎo)',
      category: PronunciationCategory.hskWord,
      ipa: '/ni˧˥ xaʊ̯˨˩˦/',
      audioUri: 'assets/audio/pronunciation/nihao.mp3',
      hintVi: 'Quy tắc biến điệu: hai thanh 3 đi liền nhau thì thanh đầu đọc thành thanh 2 (ní hǎo).',
    ),
    PronunciationTarget(
      id: 'WORD_02_XIEXIE',
      text: '谢谢',
      pinyin: 'xiè xie',
      meaningVi: 'Cảm ơn (Thanh 4 kết hợp khinh thanh)',
      category: PronunciationCategory.hskWord,
      ipa: '/ɕjɛ˥˩ ɕjɛ/',
      audioUri: 'assets/audio/pronunciation/xiexie.mp3',
      hintVi: 'Từ thứ hai đọc nhẹ, ngắn, không nhấn trọng âm (khinh thanh).',
    ),
  ];

  List<PronunciationTarget> get targets => allTargets;

  List<PronunciationTarget> getTargetsByCategory(PronunciationCategory cat) {
    return allTargets.where((t) => t.category == cat).toList();
  }

  PronunciationTarget? getTargetById(String id) {
    try {
      return allTargets.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
