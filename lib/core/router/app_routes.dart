class AppRoutes {
  AppRoutes._();

  static const String root = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String learning = '/learning';
  static const String aiTutor = '/ai-tutor';
  static const String review = '/review';
  static const String profile = '/profile';
  static const String designSystem = '/design-system';
  static const String aiSettings = '/ai-settings';

  static const List<String> protectedRoutes = [
    home,
    learning,
    aiTutor,
    review,
    profile,
  ];
}
