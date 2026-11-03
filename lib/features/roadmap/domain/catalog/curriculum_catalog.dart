import '../models/roadmap_models.dart';

/// Immutable Curriculum Catalog decoupling curriculum content from personal learner progress.
class CurriculumCatalog {
  CurriculumCatalog._();

  static const List<CurriculumLevel> levels = [
    // Pinyin Foundation (Level 0)
    CurriculumLevel(
      level: 0,
      title: 'Pinyin Foundation: Ngữ Âm Nền Tảng',
      description: 'Dành riêng cho người mới bắt đầu từ số 0. Làm chủ 21 thanh mẫu, 36 vận mẫu, 4 thanh điệu và các quy tắc biến điệu then chốt.',
      units: [
        CurriculumUnit(
          id: 'UNIT_PINYIN_01',
          level: 0,
          unitNumber: 1,
          title: 'Khởi động & Cấu tạo âm tiết',
          description: 'Bản chất Pinyin và phân biệt với chữ Quốc ngữ tiếng Việt.',
          lessons: [
            CurriculumLesson(
              id: 'LES_PINYIN_01_ANATOMY',
              unitId: 'UNIT_PINYIN_01',
              level: 0,
              title: 'Cấu tạo âm tiết: Thanh mẫu + Vận mẫu + Thanh điệu',
              description: 'Nhận diện các thành tố của âm tiết tiếng Trung.',
              primarySkill: SkillDimension.speaking,
              estimatedMinutes: 10,
              prerequisiteLessonIds: [],
              prerequisiteSkills: [],
            ),
          ],
        ),
        CurriculumUnit(
          id: 'UNIT_PINYIN_02',
          level: 0,
          unitNumber: 2,
          title: 'Thanh mẫu & Vận mẫu cốt lõi',
          description: 'Kỹ thuật đặt môi, lưỡi, bật hơi và ghép vần.',
          lessons: [
            CurriculumLesson(
              id: 'LES_PINYIN_02_INITIALS',
              unitId: 'UNIT_PINYIN_02',
              level: 0,
              title: 'Thanh mẫu: b, p, m, f, d, t, n, l, g, k, h',
              description: 'Làm chủ phụ âm đầu và kỹ thuật bật hơi p, t, k.',
              primarySkill: SkillDimension.speaking,
              estimatedMinutes: 15,
              prerequisiteLessonIds: ['LES_PINYIN_01_ANATOMY'],
              prerequisiteSkills: ['pinyin_anatomy'],
            ),
          ],
        ),
      ],
    ),
    // HSK 1 Level
    CurriculumLevel(
      level: 1,
      title: 'HSK 1: Nhập Môn & Khởi Đầu',
      description: 'Nắm vững ngữ âm Pinyin, 150 từ vựng cốt lõi và các mẫu câu cơ bản nhất.',
      units: [
        CurriculumUnit(
          id: 'UNIT_HSK1_01',
          level: 1,
          unitNumber: 1,
          title: 'Chương 1: Ngữ Âm & Chào Hỏi',
          description: 'Học 4 thanh điệu chuẩn, âm đầu, vận mẫu và cách chào hỏi tự nhiên.',
          lessons: [
            CurriculumLesson(
              id: 'LES_HSK1_01_TONES',
              unitId: 'UNIT_HSK1_01',
              level: 1,
              title: '4 Thanh điệu cơ bản (mā, má, mǎ, mà)',
              description: 'Luyện tai nghe và phát âm chính xác đường nét cao độ 4 thanh trong tiếng Hán.',
              primarySkill: SkillDimension.speaking,
              estimatedMinutes: 10,
              prerequisiteLessonIds: [],
              prerequisiteSkills: [],
              contentReferences: {'pronunciation_category': 'tone'},
            ),
            CurriculumLesson(
              id: 'LES_HSK1_02_WRITING_BASICS',
              unitId: 'UNIT_HSK1_01',
              level: 1,
              title: 'Các nét bút thuận cơ bản (一, 二, 三, 人)',
              description: 'Làm quen quy tắc bút thuận GB/T 13000 trên ô lưới 米字格.',
              primarySkill: SkillDimension.writing,
              estimatedMinutes: 15,
              prerequisiteLessonIds: ['LES_HSK1_01_TONES'],
              prerequisiteSkills: ['tones_basic'],
              contentReferences: {'hanzi_list': ['一', '二', '三', '人']},
            ),
            CurriculumLesson(
              id: 'LES_HSK1_03_GREETINGS',
              unitId: 'UNIT_HSK1_01',
              level: 1,
              title: 'Từ vựng chào hỏi: 你好, 谢谢, 再见',
              description: 'Nắm vững cách chào hỏi, cảm ơn và tạm biệt trong giao tiếp hàng ngày.',
              primarySkill: SkillDimension.vocabulary,
              estimatedMinutes: 15,
              prerequisiteLessonIds: ['LES_HSK1_01_TONES'],
              prerequisiteSkills: ['tones_basic'],
              contentReferences: {'vocab_ids': ['VOCAB_001_NIHAO']},
            ),
          ],
        ),
        CurriculumUnit(
          id: 'UNIT_HSK1_02',
          level: 1,
          unitNumber: 2,
          title: 'Chương 2: Bản Thân & Gia Đình',
          description: 'Giới thiệu tên tuổi, quốc tịch và các mối quan hệ thân thiết.',
          lessons: [
            CurriculumLesson(
              id: 'LES_HSK1_04_GRAMMAR_SHI',
              unitId: 'UNIT_HSK1_02',
              level: 1,
              title: 'Ngữ pháp: Câu phán đoán với 是 (shì)',
              description: 'Cấu trúc Chủ ngữ + 是 + Danh từ: khẳng định danh tính và nghề nghiệp.',
              primarySkill: SkillDimension.grammar,
              estimatedMinutes: 20,
              prerequisiteLessonIds: ['LES_HSK1_03_GREETINGS'],
              prerequisiteSkills: ['vocab_greetings'],
              contentReferences: {'grammar_code': 'HSK1_GR_01_SHI'},
            ),
            CurriculumLesson(
              id: 'LES_HSK1_05_READING_FRIEND',
              unitId: 'UNIT_HSK1_02',
              level: 1,
              title: 'Bài đọc hiểu: 我的中国朋友 (Bạn Trung Quốc của tôi)',
              description: 'Đọc tương tác văn bản ngắn về bạn bè, tuổi tác và thói quen sinh hoạt.',
              primarySkill: SkillDimension.reading,
              estimatedMinutes: 15,
              prerequisiteLessonIds: ['LES_HSK1_04_GRAMMAR_SHI'],
              prerequisiteSkills: ['grammar_shi'],
              contentReferences: {'passage_id': 'RDG_1_reading_hsk1_friend'},
            ),
            CurriculumLesson(
              id: 'LES_HSK1_06_SHADOWING_GREETING',
              unitId: 'UNIT_HSK1_02',
              level: 1,
              title: 'Shadowing: Hội thoại chào hỏi và giới thiệu',
              description: 'Luyện nói đuổi theo nhịp điệu bản xứ và kiểm soát thời lượng câu.',
              primarySkill: SkillDimension.listening,
              estimatedMinutes: 15,
              prerequisiteLessonIds: ['LES_HSK1_05_READING_FRIEND'],
              prerequisiteSkills: ['reading_basic'],
              contentReferences: {'shadowing_doc_id': 'SHADOW_DOC_01'},
            ),
          ],
        ),
      ],
    ),

    // HSK 2 Level
    CurriculumLevel(
      level: 2,
      title: 'HSK 2: Đời Sống & Sinh Hoạt',
      description: 'Mở rộng 300 từ vựng, giao tiếp tự tin khi đi ăn, mua sắm và hỏi đường.',
      units: [
        CurriculumUnit(
          id: 'UNIT_HSK2_01',
          level: 2,
          unitNumber: 1,
          title: 'Chương 1: Ẩm Thực & Mua Sắm',
          description: 'Gọi món tại nhà hàng và mặc cả giá cả.',
          lessons: [
            CurriculumLesson(
              id: 'LES_HSK2_01_RESTAURANT_VOCAB',
              unitId: 'UNIT_HSK2_01',
              level: 2,
              title: 'Từ vựng gọi món: 菜单, 饭馆, 服务员',
              description: 'Các từ vựng thiết yếu trong quán ăn Trung Quốc.',
              primarySkill: SkillDimension.vocabulary,
              estimatedMinutes: 20,
              prerequisiteLessonIds: ['LES_HSK1_06_SHADOWING_GREETING'],
              prerequisiteSkills: ['hsk1_mastery'],
              contentReferences: {'vocab_category': 'food'},
            ),
            CurriculumLesson(
              id: 'LES_HSK2_02_READING_ORDERING',
              unitId: 'UNIT_HSK2_01',
              level: 2,
              title: 'Đọc hiểu: 在饭馆点菜 (Gọi món tại quán ăn)',
              description: 'Đọc hiểu mẩu đối thoại gọi món và xử lý câu hỏi trắc nghiệm.',
              primarySkill: SkillDimension.reading,
              estimatedMinutes: 20,
              prerequisiteLessonIds: ['LES_HSK2_01_RESTAURANT_VOCAB'],
              prerequisiteSkills: ['vocab_food'],
              contentReferences: {'passage_id': 'RDG_2_reading_hsk2_restaurant'},
            ),
          ],
        ),
      ],
    ),
  ];

  static CurriculumLevel getLevel(int level) {
    return levels.firstWhere(
      (l) => l.level == level,
      orElse: () => levels.first,
    );
  }

  static const Map<String, String> _catalogAliases = {
    'lesson_1_1': 'LES_HSK1_01_TONES',
    'lesson_hsk1_u1_l1': 'LES_HSK1_01_TONES',
    'c_hsk1_l1': 'LES_HSK1_01_TONES',

    'lesson_1_2': 'LES_HSK1_02_WRITING_BASICS',
    'lesson_hsk1_u1_l2': 'LES_HSK1_02_WRITING_BASICS',
    'c_hsk1_l2': 'LES_HSK1_02_WRITING_BASICS',

    'lesson_1_3': 'LES_HSK1_03_GREETINGS',
    'lesson_hsk1_u1_l3': 'LES_HSK1_03_GREETINGS',
    'c_hsk1_l3': 'LES_HSK1_03_GREETINGS',

    'lesson_1_4': 'LES_HSK1_04_GRAMMAR_SHI',
    'lesson_hsk1_u2_l4': 'LES_HSK1_04_GRAMMAR_SHI',
    'c_hsk1_l4': 'LES_HSK1_04_GRAMMAR_SHI',

    'lesson_1_5': 'LES_HSK1_05_READING_FRIEND',
    'lesson_hsk1_u2_l5': 'LES_HSK1_05_READING_FRIEND',
    'c_hsk1_l5': 'LES_HSK1_05_READING_FRIEND',

    'lesson_1_6': 'LES_HSK1_06_SHADOWING_GREETING',
    'lesson_hsk1_u2_l6': 'LES_HSK1_06_SHADOWING_GREETING',
    'c_hsk1_l6': 'LES_HSK1_06_SHADOWING_GREETING',

    'lesson_2_1': 'LES_HSK2_01_RESTAURANT_VOCAB',
    'lesson_hsk2_u1_l1': 'LES_HSK2_01_RESTAURANT_VOCAB',
    'c_hsk2_l1': 'LES_HSK2_01_RESTAURANT_VOCAB',

    'lesson_2_2': 'LES_HSK2_02_GRAMMAR_LE',
    'lesson_hsk2_u1_l2': 'LES_HSK2_02_GRAMMAR_LE',
    'c_hsk2_l2': 'LES_HSK2_02_GRAMMAR_LE',

    'lesson_2_3': 'LES_HSK2_03_READING_RESTAURANT',
    'lesson_hsk2_u1_l3': 'LES_HSK2_03_READING_RESTAURANT',
    'c_hsk2_l3': 'LES_HSK2_03_READING_RESTAURANT',
  };

  static CurriculumLesson? findLessonById(String id) {
    final cleanId = id.trim();
    for (final lvl in levels) {
      for (final unit in lvl.units) {
        for (final les in unit.lessons) {
          if (les.id == cleanId) return les;
        }
      }
    }

    final mappedId = _catalogAliases[cleanId];
    if (mappedId != null) {
      for (final lvl in levels) {
        for (final unit in lvl.units) {
          for (final les in unit.lessons) {
            if (les.id == mappedId) return les;
          }
        }
      }
    }

    return null;
  }
}
