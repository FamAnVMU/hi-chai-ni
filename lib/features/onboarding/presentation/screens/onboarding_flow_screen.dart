import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/dao/curriculum_dao.dart';
import '../../../../core/database/dao/user_saved_words_dao.dart';
import '../../../../core/database/database_constants.dart';
import '../../../placement_test/presentation/screens/placement_test_intro_screen.dart';
import 'onboarding_api_key_screen.dart';
import 'onboarding_personalization_screen.dart';

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  final VoidCallback onOnboardingComplete;

  const OnboardingFlowScreen({
    super.key,
    required this.onOnboardingComplete,
  });

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  int _currentStepIndex = 0;
  String? _savedApiKey;

  void _onApiKeySaved(String apiKey) async {
    _savedApiKey = apiKey;
    final db = AppDatabase.instance.database;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      DatabaseConstants.tableAppSettings,
      {
        'key': 'gemini_api_key',
        'value': apiKey,
        'updated_at': nowIso,
      },
    );
    setState(() => _currentStepIndex = 1);
  }

  void _onSkipApiKey() {
    setState(() => _currentStepIndex = 1);
  }

  void _onPlacementTestFinished() {
    setState(() => _currentStepIndex = 2);
  }

  void _onPersonalizationComplete(int dailyMinutes, String focusSkill) async {
    final db = AppDatabase.instance.database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // Persist to user profiles & app settings
    await db.insert(
      DatabaseConstants.tableAppSettings,
      {
        'key': 'daily_learning_minutes',
        'value': dailyMinutes.toString(),
        'updated_at': nowIso,
      },
    );
    await db.insert(
      DatabaseConstants.tableAppSettings,
      {
        'key': 'priority_focus_skill',
        'value': focusSkill,
        'updated_at': nowIso,
      },
    );
    await db.insert(
      DatabaseConstants.tableAppSettings,
      {
        'key': 'onboarding_completed',
        'value': 'true',
        'updated_at': nowIso,
      },
    );

    widget.onOnboardingComplete();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStepIndex == 0) {
      return OnboardingApiKeyScreen(
        onSkip: _onSkipApiKey,
        onSaveApiKey: _onApiKeySaved,
      );
    }

    if (_currentStepIndex == 1) {
      return PlacementTestIntroScreen(
        onTestComplete: _onPlacementTestFinished,
      );
    }

    return OnboardingPersonalizationScreen(
      onComplete: _onPersonalizationComplete,
    );
  }
}
