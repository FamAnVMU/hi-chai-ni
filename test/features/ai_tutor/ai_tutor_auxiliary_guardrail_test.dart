import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hi_chinese/features/ai_tutor/domain/prompts/tutor_system_prompt_builder.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/ai_tutor_helper_sheet.dart';

void main() {
  group('AI Tutor Auxiliary Guardrails & Helper Sheet Tests', () {
    test('1. System Prompt contains strict auxiliary tutor guardrails and anti-overwriting rules', () {
      final prompt = TutorSystemPromptBuilder.build(const TutorPromptOptions());

      // 1. Auxiliary tutor identity
      expect(prompt.contains('trợ giảng bổ trợ'), isTrue);

      // 2. Cannot alter official curriculum
      expect(prompt.contains('KHÔNG được tự ý thay đổi nội dung giáo trình'), isTrue);

      // 3. Cannot overwrite official exercise answer keys
      expect(prompt.contains('KHÔNG tự tạo đáp án chuẩn rồi ghi đè đáp án'), isTrue);

      // 4. Cannot falsely mark mastery
      expect(prompt.contains('KHÔNG tự đánh dấu kiến thức thành thạo'), isTrue);
    });

    testWidgets('2. AiTutorHelperSheet displays offline fallback when offline or no API key', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AiTutorHelperSheet(
                topicTitle: 'Cấu trúc câu chữ 是',
                topicContext: 'Đại từ + 是 + Danh từ',
                isOnline: false,
              ),
            ),
          ),
        ),
      );

      // Verify title & context
      expect(find.text('Trợ Giảng AI Bổ Trợ'), findsOneWidget);
      expect(find.textContaining('Cấu trúc câu chữ 是'), findsOneWidget);

      // Verify offline fallback banner
      expect(
        find.textContaining('AI chỉ là trợ giảng bổ trợ khi có mạng'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Bạn vẫn có thể tiếp tục tự học giáo trình ngoại tuyến 100%'),
        findsOneWidget,
      );
    });

    testWidgets('3. AiTutorHelperSheet displays query chips when online', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AiTutorHelperSheet(
                topicTitle: 'Ngữ pháp 你好',
                topicContext: 'Lời chào thông dụng trong tiếng Trung',
                isOnline: true,
              ),
            ),
          ),
        ),
      );

      // Verify online state chips
      expect(find.text('Giải thích dễ hiểu hơn'), findsOneWidget);
      expect(find.text('Cho thêm 2 ví dụ'), findsOneWidget);
      expect(find.text('Hỏi AI trợ giảng'), findsOneWidget);
    });
  });
}
