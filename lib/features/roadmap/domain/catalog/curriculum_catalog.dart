import '../models/roadmap_models.dart';

/// Immutable Curriculum Catalog decoupling curriculum content from personal learner progress.
class CurriculumCatalog {
  CurriculumCatalog._();

  static const List<CurriculumLevel> levels = [
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

  static CurriculumLesson? findLessonById(String id) {
    for (final lvl in levels) {
      for (final unit in lvl.units) {
        for (final les in unit.lessons) {
          if (les.id == id) return les;
        }
      }
    }
    return null;
  }
}
