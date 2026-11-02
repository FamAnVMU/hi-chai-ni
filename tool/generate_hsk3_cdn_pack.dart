import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main() {
  print('[HSK 3 Generator] Generating online content pack for HSK 3...');

  // Sample 20 representative words for HSK 3 demonstration on GitHub CDN
  final hsk3Words = [
    {'s': '打算', 'p': 'dǎsuàn', 'm': 'dự định, tính toán', 'pos': 'động từ', 'sen': '你假期有什么打算？ (Kỳ nghỉ bạn có dự định gì?)'},
    {'s': '经常', 'p': 'jīngcháng', 'm': 'thường xuyên', 'pos': 'phó từ', 'sen': '我经常去图书馆。 (Tôi thường xuyên đi thư viện.)'},
    {'s': '其实', 'p': 'qíshí', 'm': 'thực ra, kỳ thực', 'pos': 'phó từ', 'sen': '其实并不难。 (Thực ra không khó lắm.)'},
    {'s': '了解', 'p': 'liǎojiě', 'm': 'hiểu rõ, tìm hiểu', 'pos': 'động từ', 'sen': '了解中国文化。 (Tìm hiểu văn hóa Trung Quốc.)'},
    {'s': '相信', 'p': 'xiāngxìn', 'm': 'tin tưởng', 'pos': 'động từ', 'sen': '我相信你一定行。 (Tôi tin bạn nhất định làm được.)'},
    {'s': '决定', 'p': 'juédìng', 'm': 'quyết định', 'pos': 'động từ', 'sen': '做出了重要的决定。 (Đã đưa ra quyết định quan trọng.)'},
    {'s': '水平', 'p': 'shuǐpíng', 'm': 'trình độ', 'pos': 'danh từ', 'sen': '提高汉语水平。 (Nâng cao trình độ tiếng Trung.)'},
    {'s': '提高', 'p': 'tígāo', 'm': 'nâng cao', 'pos': 'động từ', 'sen': '成绩提高了。 (Thành tích đã nâng cao.)'},
    {'s': '练习', 'p': 'liànxí', 'm': 'luyện tập', 'pos': 'động từ', 'sen': '每天练习口语。 (Mỗi ngày luyện khẩu ngữ.)'},
    {'s': '完成', 'p': 'wánchéng', 'm': 'hoàn thành', 'pos': 'động từ', 'sen': '顺利完成任务。 (Thuận lợi hoàn thành nhiệm vụ.)'},
  ];

  final units = [
    {
      'id': 'unit_3_1',
      'order_index': 1,
      'title_vi': 'Phần 1: Dự định & Kế hoạch trung cấp',
      'title_zh': '第一部分：中级计划与目标',
      'description_vi': 'Luyện tập ngữ pháp phức hợp, từ vựng trừu tượng và giao tiếp linh hoạt.',
      'is_locked': false,
      'lessons': [
        {
          'id': 'lesson_3_1',
          'order_index': 1,
          'title_vi': 'Kế hoạch cuối tuần của bạn',
          'title_zh': '周末的打算',
          'pinyin': 'Zhōumò de dǎsuàn',
          'estimated_minutes': 25,
          'is_locked': false,
          'unlock_score_threshold': 0.8,
          'prerequisites': <String>[],
          'segments': [
            {'id': 'seg_3_1_1', 'step_order': 1, 'segment_type': 'warmup', 'title': 'Khởi động', 'content_ref_id': 'WARMUP_L3_1'},
            {'id': 'seg_3_1_2', 'step_order': 2, 'segment_type': 'vocabulary', 'title': 'Từ vựng mới', 'content_ref_id': 'VOCAB_L3_1'},
            {'id': 'seg_3_1_3', 'step_order': 3, 'segment_type': 'grammar', 'title': 'Ngữ pháp', 'content_ref_id': 'GRAMMAR_L3_1'},
            {'id': 'seg_3_1_4', 'step_order': 4, 'segment_type': 'dialogue', 'title': 'Hội thoại bài đọc', 'content_ref_id': 'DIALOGUE_L3_1'},
            {'id': 'seg_3_1_5', 'step_order': 5, 'segment_type': 'practice', 'title': 'Luyện tập thích ứng', 'content_ref_id': 'PRACTICE_L3_1'},
            {'id': 'seg_3_1_6', 'step_order': 6, 'segment_type': 'mastery_check', 'title': 'Kiểm tra hoàn thành', 'content_ref_id': 'MASTERY_L3_1'},
          ]
        }
      ]
    }
  ];

  final contentItems = [
    {
      'content_id': 'WARMUP_L3_1',
      'curriculum_id': 'curr_hsk3',
      'hsk_level': 3,
      'knowledge_type': 'warmup',
      'title': 'Dẫn nhập Bài 1 HSK 3: Dự định cuối tuần',
      'content_json': json.encode({
        'objective': 'Làm quen với chủ đề lập kế hoạch và các liên từ biểu đạt ý định.',
        'starter_question': 'Bạn thường lên kế hoạch cho kỳ nghỉ hoặc cuối tuần như thế nào?',
        'key_preview': ['打算', '其实', '决定'],
      }),
      'objectives': ['Khởi động và kích hoạt kiến thức nền cho HSK 3'],
      'source_reference': 'HSK 3.0 Standard Course Lesson 1'
    },
    {
      'content_id': 'VOCAB_L3_1',
      'curriculum_id': 'curr_hsk3',
      'hsk_level': 3,
      'knowledge_type': 'vocabulary',
      'title': 'Từ vựng Bài 1 HSK 3: 周末的打算',
      'content_json': json.encode({
        'words': hsk3Words.map((w) => {
          'simplified': w['s'],
          'pinyin': w['p'],
          'meaning_vi': w['m'],
          'part_of_speech': w['pos'],
          'example_sentence': w['sen'],
          'audio_uri': 'assets/audio/hsk3/${w['s']}.mp3',
        }).toList(),
      }),
      'objectives': ['Làm chủ 10 từ vựng cốt lõi Bài 1 HSK 3'],
      'source_reference': 'HSK 3.0 Official Vocabulary List Level 3'
    },
    {
      'content_id': 'GRAMMAR_L3_1',
      'curriculum_id': 'curr_hsk3',
      'hsk_level': 3,
      'knowledge_type': 'grammar',
      'title': 'Ngữ pháp HSK 3: Cấu trúc biểu đạt kế hoạch',
      'content_json': json.encode({
        'points': [
          {
            'title': 'Điểm 1: Động từ "打算"',
            'structure': 'Chủ ngữ + 打算 + Động từ/Mệnh đề',
            'explanation': 'Biểu đạt dự định tương lai một cách lịch sự, trang trọng.',
            'positive_example': '我打算去北京旅游。',
            'contrastive_example': 'Không dùng sau phó từ phủ định sai vị trí.'
          }
        ]
      }),
      'objectives': ['Vận dụng chính xác cấu trúc打算'],
      'source_reference': 'HSK 3.0 Grammar Handbook Level 3'
    },
    {
      'content_id': 'DIALOGUE_L3_1',
      'curriculum_id': 'curr_hsk3',
      'hsk_level': 3,
      'knowledge_type': 'dialogue',
      'title': 'Hội thoại HSK 3 Bài 1',
      'content_json': json.encode({
        'context': 'Thảo luận về kế hoạch kỳ nghỉ',
        'lines': [
          {'speaker': 'A', 'text_zh': '周末你有什么打算？', 'pinyin': 'Zhōumò nǐ yǒu shénme dǎsuàn?', 'text_vi': 'Cuối tuần bạn có dự định gì?'},
          {'speaker': 'B', 'text_zh': '我打算去图书馆看书。', 'pinyin': 'Wǒ dǎsuàn qù túshūguǎn kànshū.', 'text_vi': 'Tôi dự định đến thư viện đọc sách.'}
        ]
      }),
      'objectives': ['Luyện đọc diễn cảm ngữ điệu hội thoại trung cấp'],
      'source_reference': 'HSK 3.0 Standard Course Dialogue 1'
    },
    {
      'content_id': 'PRACTICE_L3_1',
      'curriculum_id': 'curr_hsk3',
      'hsk_level': 3,
      'knowledge_type': 'exercise',
      'title': 'Bài tập củng cố HSK 3 Bài 1',
      'content_json': json.encode({
        'exercises': [
          {
            'id': 'ex_hsk3_1_1',
            'type': 'multiple_choice',
            'skill_type': 'reading',
            'prompt': 'Từ "打算" (dǎsuàn) có nghĩa là gì?',
            'options': ['dự định, tính toán', 'thường xuyên', 'tin tưởng'],
            'correct_answer': 'dự định, tính toán',
            'explanation': '"打算" có nghĩa là dự định, tính toán.'
          }
        ]
      }),
      'objectives': ['Đánh giá kiến thức bài học'],
      'source_reference': 'HSK 3.0 Practice Workbook Lesson 1'
    }
  ];

  final fullPack = {
    'manifest': {
      'pack_id': 'hsk3_pack_v1',
      'hsk_level': 3,
      'version': '1.0.0',
      'title': 'Giáo trình chuẩn HSK 3 (Trực tuyến)',
      'description': '300 từ vựng trung cấp, cấu trúc ngữ pháp phức hợp, hội thoại mở rộng và phản xạ thực tế.',
      'is_bundled': false,
      'size_bytes': 0,
      'sha256': ''
    },
    'curriculum': {
      'id': 'curr_hsk3',
      'code': 'HSK_2012_L3',
      'standard_name': 'HSK 2.0 Level 3 Official Curriculum',
      'hsk_level': 3,
      'units': units,
    },
    'content_items': contentItems,
  };

  final rawJson = json.encode(fullPack);
  final sha = sha256.convert(utf8.encode(rawJson)).toString();
  (fullPack['manifest'] as Map<String, dynamic>)['sha256'] = sha;
  (fullPack['manifest'] as Map<String, dynamic>)['size_bytes'] = utf8.encode(rawJson).length;

  final finalJson = json.encode(fullPack);
  final targetFile = File('content_packs_cdn/hsk3_pack_v1.json');
  targetFile.writeAsStringSync(finalJson);
  print('Successfully generated ${targetFile.path} (${finalJson.length} bytes, SHA: $sha).');
}
