import 'package:flutter/material.dart';

/// The 5 primary tabs of HI Chinese.
enum AppTab {
  home(
    label: 'Trang chủ',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    semanticLabel: 'Tab Trang chủ',
  ),
  learning(
    label: 'Học tập',
    icon: Icons.school_outlined,
    activeIcon: Icons.school_rounded,
    semanticLabel: 'Tab Học tập theo lộ trình',
  ),
  aiTutor(
    label: 'AI Tutor',
    icon: Icons.auto_awesome_rounded,
    activeIcon: Icons.auto_awesome_rounded,
    semanticLabel: 'AI Tutor - Trợ lý gia sư tiếng Trung thông minh',
  ),
  review(
    label: 'Ôn tập',
    icon: Icons.psychology_outlined,
    activeIcon: Icons.psychology_rounded,
    semanticLabel: 'Tab Ôn tập lặp lại ngắt quãng SM-2',
  ),
  profile(
    label: 'Cá nhân',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    semanticLabel: 'Tab Thông tin cá nhân và cài đặt',
  );

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String semanticLabel;

  const AppTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.semanticLabel,
  });

  static AppTab fromIndex(int index) {
    if (index < 0 || index >= AppTab.values.length) {
      return AppTab.home;
    }
    return AppTab.values[index];
  }
}
