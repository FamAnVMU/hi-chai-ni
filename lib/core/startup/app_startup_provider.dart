import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import 'app_startup_state.dart';

export 'app_startup_state.dart';

/// Notifier managing the global initialization sequence for HI Chinese.
///
/// Ensures:
/// 1. SQLite database and migrations are executed.
/// 2. Performance PRAGMAs (WAL mode, 8MB cache) are activated.
/// 3. Catches and exposes initialization failures with retry capability.
class AppStartupNotifier extends Notifier<AppStartupState> {
  @override
  AppStartupState build() {
    // Automatically trigger initialization on startup
    Future.microtask(() => initialize());
    return const AppStartupState(
      isInitializing: true,
      isReady: false,
      statusMessage: 'Đang khởi động hệ thống cơ sở dữ liệu...',
    );
  }

  Future<void> initialize() async {
    state = state.copyWith(
      isInitializing: true,
      isReady: false,
      error: null,
      statusMessage: 'Đang kết nối cơ sở dữ liệu SQLite offline...',
    );

    try {
      // 1. Initialize SQLite engine and run pending migrations
      await AppDatabase.instance.open();

      state = state.copyWith(
        statusMessage: 'Đang chuẩn bị bộ nhớ đệm và dữ liệu từ điển...',
      );

      // Brief yield to allow smooth rendering of splash transition
      await Future<void>.delayed(const Duration(milliseconds: 100));

      state = state.copyWith(
        isInitializing: false,
        isReady: true,
        error: null,
        statusMessage: 'Hệ thống sẵn sàng',
      );
    } catch (e, stackTrace) {
      debugPrint('[AppStartup] Initialization error: $e\n$stackTrace');
      state = state.copyWith(
        isInitializing: false,
        isReady: false,
        error: 'Không thể khởi tạo cơ sở dữ liệu: ${e.toString()}',
        statusMessage: 'Khởi tạo thất bại',
      );
    }
  }
}

final appStartupProvider = NotifierProvider<AppStartupNotifier, AppStartupState>(
  AppStartupNotifier.new,
);
