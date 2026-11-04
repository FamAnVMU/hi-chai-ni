import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/theme.dart';
import 'core/utils/app_lifecycle_manager.dart';
import 'core/utils/permission_helper.dart';
import 'features/app_shell/presentation/screens/app_shell.dart';
import 'features/design_system/presentation/screens/design_system_demo_screen.dart';
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

class HiChineseSkeletonScreen extends StatefulWidget {
  const HiChineseSkeletonScreen({super.key});

  @override
  State<HiChineseSkeletonScreen> createState() => _HiChineseSkeletonScreenState();
}

class _HiChineseSkeletonScreenState extends State<HiChineseSkeletonScreen> {
  String _permissionStatusText = 'Chưa kiểm tra';
  bool _isMicActive = false;

  @override
  void initState() {
    super.initState();
    // Register audio lifecycle safety hook
    AppLifecycleManager.instance.registerAudioSession(_onLifecycleStopAudio);
  }

  @override
  void dispose() {
    AppLifecycleManager.instance.unregisterAudioSession(_onLifecycleStopAudio);
    super.dispose();
  }

  void _onLifecycleStopAudio(String reason) {
    if (_isMicActive) {
      setState(() {
        _isMicActive = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Micro đã tự động tắt vì lý do an toàn: $reason'),
            backgroundColor: Colors.orange[800],
          ),
        );
      }
    }
  }

  Future<void> _handleMicFeaturePress() async {
    final result = await PermissionHelper.requestMicrophoneWithRationale(
      context,
      featureName: 'Luyện Phát Âm & AI Tutor',
    );

    setState(() {
      switch (result) {
        case AudioPermissionResult.granted:
          _permissionStatusText = 'Đã cấp quyền (Granted)';
          _isMicActive = true;
          break;
        case AudioPermissionResult.denied:
          _permissionStatusText = 'Bị từ chối (Denied)';
          _isMicActive = false;
          break;
        case AudioPermissionResult.permanentlyDenied:
          _permissionStatusText = 'Từ chối vĩnh viễn (Settings required)';
          _isMicActive = false;
          break;
        case AudioPermissionResult.restricted:
          _permissionStatusText = 'Bị giới hạn hệ thống (Restricted)';
          _isMicActive = false;
          break;
      }
    });

    if (result == AudioPermissionResult.granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quyền Micro sẵn sàng cho Luyện Phát Âm / AI Tutor'),
          backgroundColor: Color(0xFF1A2418),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final bottomPadding = mediaQuery.padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A2418),
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Design System Showcase',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DesignSystemDemoScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Cài Đặt AI & Kết Nối',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Center(
                child: Icon(
                  Icons.translate_rounded,
                  size: 64,
                  color: Color(0xFFA3D635),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chào mừng đến với HI Chinese',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ứng dụng học tiếng Trung Android Native độc lập\nOffline-first với SQLite & AI Tutor Gemini',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Quick Access to Design System Showcase
              HiCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DesignSystemDemoScreen()),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: AppRadius.borderMd,
                      ),
                      child: Icon(
                        Icons.palette_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Design System Showcase (Material 3)',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Xem mẫu bảng màu, font Việt-Trung, nút bấm, input, modal',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Safe Area & System UI Diagnostic Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2418),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.phonelink_setup_rounded, color: Color(0xFFA3D635), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Cấu Hình Edge-to-Edge & Safe Area',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '• Status Bar Inset: ${topPadding.toStringAsFixed(1)} dp (Notch/Cutout protection)',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Navigation Inset: ${bottomPadding.toStringAsFixed(1)} dp (Gesture Navigation bar)',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• Soft Input Mode: adjustResize (Bàn phím không đè nội dung)',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• Cleartext Traffic: false (Chỉ cho phép HTTPS/WSS an toàn)',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Permission & Lifecycle Diagnostic Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2418),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security_rounded, color: Color(0xFFA3D635), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Kiểm Tra Quyền & Lifecycle Âm Thanh',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Trạng thái quyền Micro: $_permissionStatusText',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isMicActive ? Colors.greenAccent : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isMicActive
                              ? 'Micro đang hoạt động (Tự ngắt khi background)'
                              : 'Micro đang tắt (Không ghi âm nền)',
                          style: TextStyle(
                            fontSize: 13,
                            color: _isMicActive ? Colors.greenAccent : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA3D635),
                        foregroundColor: const Color(0xFF121811),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _handleMicFeaturePress,
                      icon: const Icon(Icons.mic_none_rounded),
                      label: const Text(
                        'Yêu cầu Quyền Micro (Có Giải Thích Mục Đích)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
