import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/domain/models/lesson_flow_state.dart';
import 'package:hi_chinese/features/curriculum/presentation/providers/lesson_flow_providers.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/lesson_study_screen.dart';

CurriculumLesson _lesson(String id, List<LessonSegment> segments) {
  return CurriculumLesson(
    id: id,
    unitId: 'u1',
    orderIndex: 1,
    titleVi: 'Bài thử nghiệm',
    titleZh: '测试',
    pinyin: 'cè shì',
    status: LessonStatus.inProgress,
    isLocked: false,
    prerequisites: const [],
    segments: segments,
  );
}

LessonSegment _seg(String id, int order, String type, Map<String, dynamic> payload) {
  return LessonSegment(
    id: id,
    lessonId: 'l',
    stepOrder: order,
    segmentType: type,
    title: type,
    contentPayload: payload,
  );
}

Future<void> _pump(WidgetTester tester, CurriculumLesson lesson, {LessonStep? resume}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: LessonStudyScreen(lesson: lesson, resumeStep: resume),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _walkAllSteps(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    final next = find.text('Tiếp theo');
    if (next.evaluate().isEmpty) break;
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Crash at step ${i + 2}');
  }
}

void main() {
  group('LessonStudyScreen boundary payloads', () {
    testWidgets('1. Lesson with zero segments does not crash', (tester) async {
      await _pump(tester, _lesson('l_empty', const []));
      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsWidgets);
      await _walkAllSteps(tester);
    });

    testWidgets('2. Segments with empty payloads do not crash on any step', (tester) async {
      final lesson = _lesson('l_empty_payload', [
        _seg('s1', 1, 'warmup', <String, dynamic>{}),
        _seg('s2', 2, 'vocabulary', <String, dynamic>{}),
        _seg('s3', 3, 'grammar', <String, dynamic>{}),
        _seg('s4', 4, 'dialogue', <String, dynamic>{}),
        _seg('s5', 5, 'practice', <String, dynamic>{}),
        _seg('s6', 6, 'masteryCheck', <String, dynamic>{}),
      ]);
      await _pump(tester, lesson);
      expect(tester.takeException(), isNull);
      await _walkAllSteps(tester);
    });

    testWidgets('3. Payloads with wrong types or missing fields do not crash', (tester) async {
      final lesson = _lesson('l_bad_payload', [
        _seg('s1', 1, 'warmup', {'intro': 123}),
        _seg('s2', 2, 'vocabulary', {
          'words': [
            {'hanzi': '你'},
            'not-a-map',
            null,
          ],
        }),
        _seg('s3', 3, 'grammar', {
          'points': [
            {'title': 'Chỉ có tiêu đề'},
            42,
          ],
        }),
        _seg('s4', 4, 'dialogue', {'lines': 'invalid'}),
        _seg('s5', 5, 'practice', {
          'exercises': [
            {'id': 'ex1'},
          ],
        }),
        _seg('s6', 6, 'masteryCheck', {'exercises': null}),
      ]);
      await _pump(tester, lesson);
      expect(tester.takeException(), isNull);
      await _walkAllSteps(tester);
    });

    testWidgets('4. Untyped Map<dynamic,dynamic> items (JSON from SQLite) still render', (tester) async {
      final untypedWord = <dynamic, dynamic>{
        'hanzi': '学',
        'pinyin': 'xué',
        'meaning': 'học',
        'type': 'verb',
      };
      final untypedPoint = <dynamic, dynamic>{
        'title': 'Điểm ngữ pháp thử',
        'structure': 'S + V',
        'explanation': 'Giải thích.',
      };
      final lesson = _lesson('l_untyped', [
        _seg('s1', 1, 'warmup', {'intro': 'Xin chào'}),
        _seg('s2', 2, 'vocabulary', {
          'words': <dynamic>[untypedWord],
        }),
        _seg('s3', 3, 'grammar', {
          'points': <dynamic>[untypedPoint],
        }),
      ]);
      await _pump(tester, lesson);

      await tester.tap(find.text('Tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.text('学', skipOffstage: false), findsOneWidget);
      expect(find.text('học', skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('Tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.text('Điểm ngữ pháp thử', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('LessonStudyScreen re-entry', () {
    final lesson = _lesson('l_reentry', [
      _seg('s1', 1, 'warmup', {'intro': 'Chào mừng quay lại!'}),
      _seg('s2', 2, 'vocabulary', {
        'words': [
          {'hanzi': '你', 'pinyin': 'nǐ', 'meaning': 'bạn', 'type': 'pronoun'},
        ],
      }),
      _seg('s3', 3, 'grammar', {
        'points': [
          {'title': 'Ngữ pháp A', 'structure': 'x', 'explanation': 'y'},
        ],
      }),
    ]);

    testWidgets('5. Re-opening a half-finished lesson starts again at the warmup step', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navKey,
            home: const Scaffold(body: Text('home')),
          ),
        ),
      );

      // First visit: advance to step 3, then leave.
      navKey.currentState!.push(MaterialPageRoute(builder: (_) => LessonStudyScreen(lesson: lesson)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp theo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp theo'));
      await tester.pumpAndSettle();
      expect(find.text('Ngữ pháp A', skipOffstage: false), findsOneWidget);

      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      // Second visit: must be back at warmup (autoDispose state reset).
      navKey.currentState!.push(MaterialPageRoute(builder: (_) => LessonStudyScreen(lesson: lesson)));
      await tester.pumpAndSettle();
      expect(find.text('Chào mừng quay lại!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('6. lessonFlowNotifierProvider is auto-disposed and starts at warmup', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sub = container.listen(lessonFlowNotifierProvider('x'), (_, _) {});
      container.read(lessonFlowNotifierProvider('x').notifier).nextStep();
      container.read(lessonFlowNotifierProvider('x').notifier).nextStep();
      expect(container.read(lessonFlowNotifierProvider('x')).currentStep, LessonStep.grammar);
      sub.close();
      await Future<void>.delayed(Duration.zero);

      final fresh = container.read(lessonFlowNotifierProvider('x'));
      expect(fresh.currentStep, LessonStep.warmup);
    });

    testWidgets('7. resumeStep opens the lesson at the requested step', (tester) async {
      await _pump(tester, lesson, resume: LessonStep.vocabulary);
      expect(find.text('你', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
