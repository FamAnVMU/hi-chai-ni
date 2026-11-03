import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_constants.dart';
import '../../../../core/network/ai/ai_service.dart';
import '../../../../core/network/ai/security/ai_credential_storage.dart';
import '../../../placement_test/presentation/screens/placement_test_intro_screen.dart';
import 'onboarding_api_key_screen.dart';
import 'onboarding_personalization_screen.dart';

class OnboardingFlowScreen extends ConsumerStatefulWidget {
  final VoidCallback onOnboardingComplete;
  final AiCredentialStorage? credentialStorageOverride;

  const OnboardingFlowScreen({
    super.key,
    required this.onOnboardingComplete,
    this.credentialStorageOverride,
  });

  @override
  ConsumerState<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends ConsumerState<OnboardingFlowScreen> {
  int _currentStepIndex = 0;

  AiCredentialStorage get _storage =>
      widget.credentialStorageOverride ?? ref.read(aiCredentialStorageProvider);

  Future<bool> _onApiKeySaved(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      setState(() => _currentStepIndex = 1);
      return true;
    }

    final validationError = AiCredentialStorage.validateApiKey(cleanKey);
    if (validationError != null) {
      debugPrint('[Onboarding] API Key validation failed: $validationError');
      return false;
    }

    try {
      // 1. Save to secure storage and verify read-back
      await _storage.saveApiKey(cleanKey);

      // 2. Read back credential immediately to confirm persistence
      final verifiedKey = await _storage.getApiKey();
      if (verifiedKey == null || verifiedKey != cleanKey) {
        debugPrint('[Onboarding] Read-back verification failed for API key.');
        return false;
      }

      if (mounted) {
        setState(() => _currentStepIndex = 1);
      }
      return true;
    } catch (e) {
      debugPrint('[Onboarding] Error securely saving API key: $e');
      return false;
    }
  }

  void _onSkipApiKey() {
    setState(() => _currentStepIndex = 1);
  }

  void _onPlacementTestFinished([int? hskLevel]) {
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
