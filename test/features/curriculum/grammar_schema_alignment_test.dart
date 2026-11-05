import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/dictionary/domain/models/dictionary_models.dart';

void main() {
  group('GrammarPoint Model & Alignment Tests', () {
    test('1. Parses GrammarPoint from positive_example and contrastive_example schema', () {
      final map = {
        'title': 'Điểm 1: Cấu trúc sử dụng với "你"',
        'structure': 'Chủ ngữ + 你 + Tân ngữ/Vị ngữ',
        'explanation': 'Cách dùng cơ bản trong câu khẳng định và phủ định.',
        'positive_example': '你好！ (Chào bạn!)',
        'contrastive_example': 'Không dùng đứng độc lập thiếu đại từ bổ ngữ.',
      };

      final point = GrammarPoint.fromMap(map);

      expect(point.title, equals('Điểm 1: Cấu trúc sử dụng với "你"'));
      expect(point.structure, equals('Chủ ngữ + 你 + Tân ngữ/Vị ngữ'));
      expect(point.explanation, equals('Cách dùng cơ bản trong câu khẳng định và phủ định.'));
      expect(point.positiveExample, equals('你好！ (Chào bạn!)'));
      expect(point.contrastiveExample, equals('Không dùng đứng độc lập thiếu đại từ bổ ngữ.'));
      expect(point.examples, isEmpty);

      final serialized = point.toMap();
      expect(serialized['title'], equals('Điểm 1: Cấu trúc sử dụng với "你"'));
      expect(serialized['positive_example'], equals('你好！ (Chào bạn!)'));
      expect(serialized['contrastive_example'], equals('Không dùng đứng độc lập thiếu đại từ bổ ngữ.'));
    });

    test('2. Parses GrammarPoint with traditional examples list', () {
      final map = {
        'title': 'Câu chữ 是',
        'structure': 'A + 是 + B',
        'explanation': 'A là B.',
        'examples': [
          {
            'chinese': '我是学生。',
            'pinyin': 'Wǒ shì xuésheng.',
            'vietnamese': 'Tôi là học sinh.',
          },
          {
            'chinese': '他是老师。',
            'pinyin': 'Tā shì lǎoshī.',
            'vietnamese': 'Anh ấy là giáo viên.',
          }
        ]
      };

      final point = GrammarPoint.fromMap(map);

      expect(point.title, equals('Câu chữ 是'));
      expect(point.examples.length, equals(2));
      expect(point.examples.first['chinese'], equals('我是学生。'));
      expect(point.examples.last['vietnamese'], equals('Anh ấy là giáo viên.'));
      expect(point.positiveExample, isNull);
      expect(point.contrastiveExample, isNull);
    });

    test('3. Parses GrammarPoint supporting both schemas concurrently', () {
      final map = {
        'title': 'Trợ từ nghi vấn 吗',
        'structure': 'Câu trần thuật + 吗？',
        'explanation': 'Dùng để biến câu khẳng định thành câu hỏi Yes/No.',
        'positive_example': '你好吗？ (Bạn khỏe không?)',
        'contrastive_example': 'Không dùng cùng từ để hỏi 什么, 谁.',
        'examples': [
          {
            'chinese': '他是中国人吗？',
            'pinyin': 'Tā shì Zhōngguórén ma?',
            'vietnamese': 'Anh ấy là người Trung Quốc phải không?',
          }
        ]
      };

      final point = GrammarPoint.fromMap(map);

      expect(point.title, equals('Trợ từ nghi vấn 吗'));
      expect(point.positiveExample, equals('你好吗？ (Bạn khỏe không?)'));
      expect(point.contrastiveExample, equals('Không dùng cùng từ để hỏi 什么, 谁.'));
      expect(point.examples.length, equals(1));
      expect(point.examples.first['chinese'], equals('他是中国人吗？'));
    });

    test('4. LessonSegment.grammarPoints resolves points array from contentPayload', () {
      final segment = LessonSegment.fromMap({
        'id': 'seg_1_3',
        'lesson_id': 'lesson_1_1',
        'step_order': 3,
        'segment_type': 'grammar',
        'title': 'Ngữ pháp',
        'content_payload': {
          'points': [
            {
              'title': 'Điểm 1',
              'structure': 'A + B',
              'explanation': 'Giải thích 1',
              'positive_example': 'Ví dụ 1',
              'contrastive_example': 'Lưu ý 1',
            },
            {
              'title': 'Điểm 2',
              'structure': 'C + D',
              'explanation': 'Giải thích 2',
              'positive_example': 'Ví dụ 2',
            }
          ]
        }
      });

      final points = segment.grammarPoints;
      expect(points.length, equals(2));
      expect(points[0].title, equals('Điểm 1'));
      expect(points[0].contrastiveExample, equals('Lưu ý 1'));
      expect(points[1].title, equals('Điểm 2'));
      expect(points[1].positiveExample, equals('Ví dụ 2'));
      expect(points[1].contrastiveExample, isNull);
    });

    test('5. LessonSegment.fromMap decodes JSON string content_json seamlessly', () {
      const jsonContent = '{"points":[{"title":"P1","structure":"S1","explanation":"E1","positive_example":"Ex1"}]}';
      final segment = LessonSegment.fromMap({
        'id': 'seg_2_3',
        'lesson_id': 'lesson_1_2',
        'step_order': 3,
        'segment_type': 'grammar',
        'title': 'Ngữ pháp',
        'content_json': jsonContent,
      });

      final points = segment.grammarPoints;
      expect(points.length, equals(1));
      expect(points.first.title, equals('P1'));
      expect(points.first.positiveExample, equals('Ex1'));
    });
  });

  group('VocabularyMinimal Model Tests', () {
    test('Constructs VocabularyMinimal and converts from DictionaryEntry', () {
      const entry = DictionaryEntry(
        id: 'dict_custom_1',
        simplified: '外卖',
        traditional: '外賣',
        pinyin: 'wai4 mai4',
        pinyinClean: 'waimai',
        hskLevel: 0,
        senses: [
          DictionarySense(
            id: 'sns_1',
            partOfSpeech: 'danh từ',
            meaningVi: 'đồ ăn mang về; giao hàng tận nơi',
          ),
        ],
      );

      final minimal = VocabularyMinimal.fromDictionaryEntry(entry);
      expect(minimal.id, equals('dict_custom_1'));
      expect(minimal.hanzi, equals('外卖'));
      expect(minimal.pinyin, equals('wai4 mai4'));
      expect(minimal.pinyinClean, equals('waimai'));
      expect(minimal.meaningVi, equals('đồ ăn mang về; giao hàng tận nơi'));
      expect(minimal.hskLevel, equals(0));
      expect(minimal.source, equals('CVDICT'));
    });
  });
}
