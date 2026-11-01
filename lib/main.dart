import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        scaffoldBackgroundColor: const Color(0xFF121811),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFA3D635),
          onPrimary: Color(0xFF121811),
          surface: Color(0xFF1A2418),
          onSurface: Colors.white,
        ),
      ),
      home: const HiChineseSkeletonScreen(),
    );
  }
}

class HiChineseSkeletonScreen extends StatelessWidget {
  const HiChineseSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A2418),
      ),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 72,
                  color: Color(0xFFA3D635),
                ),
                SizedBox(height: 20),
                Text(
                  'Chào mừng đến với HI Chinese',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  'Ứng dụng học tiếng Trung Android Native độc lập\nOffline-first với SQLite & AI Tutor Gemini',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
