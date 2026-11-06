import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/lesson_step_error_boundary.dart';

void main() {
  group('LessonStepErrorBoundary Tests', () {
    testWidgets('Test 1: When child builds normally, child content is rendered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: LessonStepErrorBoundary(
              stepName: 'Khởi động',
              child: Text('Nội dung bình thường'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nội dung bình thường'), findsOneWidget);
      expect(find.text('Bước này gặp gián đoạn dữ liệu học liệu'), findsNothing);
    });

    testWidgets(
      'Test 2: When builder throws an exception, LessonStepErrorBoundary displays fallback error UI with stepName and does not crash',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: LessonStepErrorBoundary(
                stepName: 'Từ vựng',
                builder: (context) {
                  throw Exception('Corrupt segment data payload');
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bước này gặp gián đoạn dữ liệu học liệu'), findsOneWidget);
        expect(
          find.text('Nội dung bước Từ vựng đang được đồng bộ hoặc gặp lỗi hiển thị.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.school_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'Test 3: Tapping "Bỏ qua bước này" or skip button triggers the onSkip callback',
      (tester) async {
        var skipCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: LessonStepErrorBoundary(
                stepName: 'Ngữ pháp',
                onSkip: () {
                  skipCalled = true;
                },
                builder: (context) {
                  throw Exception('Parsing error in grammar tables');
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bỏ qua bước này'), findsOneWidget);
        await tester.tap(find.text('Bỏ qua bước này'));
        await tester.pumpAndSettle();

        expect(skipCalled, isTrue);
      },
    );

    testWidgets('Test 4: Tapping "Thử lại" triggers onRetry', (tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: LessonStepErrorBoundary(
              stepName: 'Đối thoại',
              onRetry: () {
                retryCalled = true;
              },
              builder: (context) {
                throw Exception('Audio dialogue sync error');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thử lại'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
    });

    testWidgets('Test 5: Recovers content after tapping "Thử lại" when builder succeeds', (tester) async {
      var shouldFail = true;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: LessonStepErrorBoundary(
                  stepName: 'Luyện tập',
                  onRetry: () {
                    setState(() {
                      shouldFail = false;
                    });
                  },
                  builder: (context) {
                    if (shouldFail) {
                      throw Exception('Temporary exercise build failure');
                    }
                    return const Text('Nội dung bài tập đã phục hồi thành công');
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bước này gặp gián đoạn dữ liệu học liệu'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Nội dung bài tập đã phục hồi thành công'), findsOneWidget);
      expect(find.text('Bước này gặp gián đoạn dữ liệu học liệu'), findsNothing);
    });

    testWidgets('Test 6: buildErrorFallback & createErrorWidgetBuilder helper methods work properly', (tester) async {
      final fallback = LessonStepErrorBoundary.buildErrorFallback(
        stepName: 'Kiểm tra tổng kết',
        onSkip: () {},
        onRetry: () {},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: fallback),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bước này gặp gián đoạn dữ liệu học liệu'), findsOneWidget);
      expect(
        find.text('Nội dung bước Kiểm tra tổng kết đang được đồng bộ hoặc gặp lỗi hiển thị.'),
        findsOneWidget,
      );
    });
  });
}
