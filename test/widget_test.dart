import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/constants/app_constants.dart';
import 'package:hi_chinese/core/utils/app_lifecycle_manager.dart';
import 'package:hi_chinese/main.dart';

void main() {
  testWidgets('HiChineseApp renders successfully with diagnostic components', (WidgetTester tester) async {
    // Build app widget
    await tester.pumpWidget(const HiChineseApp());

    // Verify app title and welcome message
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('Chào mừng đến với HI Chinese'), findsOneWidget);
    expect(find.textContaining('Cấu Hình Edge-to-Edge & Safe Area'), findsOneWidget);
    expect(find.textContaining('Kiểm Tra Quyền & Lifecycle Âm Thanh'), findsOneWidget);
  });

  test('AppLifecycleManager halts active audio sessions on app pause', () {
    final manager = AppLifecycleManager.instance;
    manager.initialize();

    String? stopReason;
    void onMustStop(String reason) {
      stopReason = reason;
    }

    manager.registerAudioSession(onMustStop);

    // Simulate app going to background (e.g. incoming call or switching app)
    manager.didChangeAppLifecycleState(AppLifecycleState.paused);

    expect(stopReason, isNotNull);
    expect(stopReason, contains('App backgrounded'));

    // Cleanup
    manager.unregisterAudioSession(onMustStop);
    manager.dispose();
  });
}
