import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme.dart';
import 'core/utils/app_lifecycle_manager.dart';
import 'features/app_shell/presentation/screens/app_shell.dart';
import 'features/settings/settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure modern Android edge-to-edge layout & transparent status/navigation bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // Lock orientation to portrait for optimal mobile learning experience
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Android lifecycle observer to manage background audio release
  AppLifecycleManager.instance.initialize();

  // Configure bounded image cache to prevent memory pressure on Android devices
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB ceiling
  PaintingBinding.instance.imageCache.maximumSize = 100; // max 100 images in memory

  runApp(
    const ProviderScope(
      child: HiChineseApp(),
    ),
  );
}

class HiChineseApp extends ConsumerWidget {
  const HiChineseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      onGenerateRoute: (settings) => AppRouter.onGenerateRoute(settings, ref),
      home: const AppShell(),
    );
  }
}

