import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/constants/app_constants.dart';
import 'package:hi_chinese/core/startup/app_startup_provider.dart';
import 'package:hi_chinese/core/utils/app_lifecycle_manager.dart';
import 'package:hi_chinese/main.dart';

class _TestAppStartupNotifier extends AppStartupNotifier {
  @override
  AppStartupState build() {
    return const AppStartupState(isInitializing: false, isReady: true);
  }

  @override
  Future<void> initialize() async {}
}

void main() {
  testWidgets('HiChineseApp renders successfully with AppShell and 5 tabs', (WidgetTester tester) async {
    // Build app widget wrapped with ProviderScope for Riverpod ThemeModeNotifier
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStartupProvider.overrideWith(_TestAppStartupNotifier.new),
        ],
        child: const HiChineseApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    // Verify app title and 5 main tabs
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Học tập'), findsOneWidget);
    expect(find.text('AI Tutor'), findsAtLeastNWidgets(1));
    expect(find.text('Ôn tập'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
    expect(find.textContaining('Chuỗi học 5 ngày liên tiếp!'), findsOneWidget);
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
