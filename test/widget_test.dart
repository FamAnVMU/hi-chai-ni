import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/constants/app_constants.dart';
import 'package:hi_chinese/main.dart';

void main() {
  testWidgets('HiChineseApp skeleton smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HiChineseApp());

    // Verify that the title and welcome text are present.
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('Chào mừng đến với HI Chinese'), findsOneWidget);
  });
}
