import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/app_lifecycle_manager.dart';
import 'core/utils/permission_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure modern Android edge-to-edge layout & transparent status/navigation bars
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
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

  runApp(
    const ProviderScope(
      child: HiChineseApp(),
    ),
  );
}

class HiChineseApp extends StatelessWidget {
  const HiChineseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121811), // Dark Forest Background
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFA3D635), // Lime Green
          onPrimary: Color(0xFF121811),
          surface: Color(0xFF1A2418),
          onSurface: Colors.white,
        ),
      ),
      home: const HiChineseSkeletonScreen(),
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
