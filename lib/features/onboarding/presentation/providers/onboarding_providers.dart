import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_constants.dart';

enum OnboardingStep {
  aiSetup(0),
  placementTest(1),
  personalization(2),
  completed(3);

  final int stepIndex;
  const OnboardingStep(this.stepIndex);

  static OnboardingStep fromIndex(int index) {
    return OnboardingStep.values.firstWhere(
      (e) => e.stepIndex == index,
      orElse: () => OnboardingStep.aiSetup,
    );
  }
}

class OnboardingState {
  final bool isLoading;
  final bool isCompleted;
  final OnboardingStep currentStep;
  final bool hasSkippedAiSetup;
  final int? assessedHskLevel;
  final int dailyMinutes;
  final String focusSkill;

  const OnboardingState({
    this.isLoading = false,
    this.isCompleted = false,
    this.currentStep = OnboardingStep.aiSetup,
    this.hasSkippedAiSetup = false,
    this.assessedHskLevel,
    this.dailyMinutes = 30,
    this.focusSkill = 'reading',
  });

  OnboardingState copyWith({
    bool? isLoading,
    bool? isCompleted,
    OnboardingStep? currentStep,
    bool? hasSkippedAiSetup,
    int? assessedHskLevel,
    int? dailyMinutes,
    String? focusSkill,
  }) {
    return OnboardingState(
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      currentStep: currentStep ?? this.currentStep,
      hasSkippedAiSetup: hasSkippedAiSetup ?? this.hasSkippedAiSetup,
      assessedHskLevel: assessedHskLevel ?? this.assessedHskLevel,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      focusSkill: focusSkill ?? this.focusSkill,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyOnboardingStep = 'onboarding_current_step';
  static const String keyDailyMinutes = 'daily_learning_minutes';
  static const String keyPrioritySkill = 'priority_focus_skill';

  @override
  OnboardingState build() {
    Future.microtask(() => _loadState());
    return const OnboardingState(isLoading: false);
  }

  Future<void> _loadState() async {
    try {
      if (!AppDatabase.instance.isOpen) {
        state = state.copyWith(
          isLoading: false,
          isCompleted: false,
          currentStep: OnboardingStep.aiSetup,
        );
        return;
      }

      final db = AppDatabase.instance.database;
      final settings = await db.query(DatabaseConstants.tableAppSettings);
      final map = <String, String>{};
      for (final row in settings) {
        final k = row['key'] as String?;
        final v = row['value'] as String?;
        if (k != null && v != null) {
          map[k] = v;
        }
      }

      final isCompleted = map[keyOnboardingCompleted] == 'true';
      final stepIndex = int.tryParse(map[keyOnboardingStep] ?? '0') ?? 0;
      final dailyMinutes = int.tryParse(map[keyDailyMinutes] ?? '30') ?? 30;
      final focusSkill = map[keyPrioritySkill] ?? 'reading';

      state = state.copyWith(
        isLoading: false,
        isCompleted: isCompleted,
        currentStep: isCompleted ? OnboardingStep.completed : OnboardingStep.fromIndex(stepIndex),
        dailyMinutes: dailyMinutes,
        focusSkill: focusSkill,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        isCompleted: false,
        currentStep: OnboardingStep.aiSetup,
      );
    }
  }

  Future<void> setStep(OnboardingStep step, {bool? skippedAi}) async {
    state = state.copyWith(
      currentStep: step,
      hasSkippedAiSetup: skippedAi ?? state.hasSkippedAiSetup,
    );

    try {
      if (AppDatabase.instance.isOpen) {
        final db = AppDatabase.instance.database;
        final nowUtc = DateTime.now().toUtc().toIso8601String();
        await db.insert(
          DatabaseConstants.tableAppSettings,
          {
            'key': keyOnboardingStep,
            'value': step.stepIndex.toString(),
            'updated_at': nowUtc,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}
  }

  Future<void> completePlacementTest([int? hskLevel]) async {
    state = state.copyWith(
      assessedHskLevel: hskLevel,
      currentStep: OnboardingStep.personalization,
    );

    try {
      if (AppDatabase.instance.isOpen) {
        final db = AppDatabase.instance.database;
        final nowUtc = DateTime.now().toUtc().toIso8601String();
        await db.insert(
          DatabaseConstants.tableAppSettings,
          {
            'key': keyOnboardingStep,
            'value': OnboardingStep.personalization.stepIndex.toString(),
            'updated_at': nowUtc,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}
  }

  Future<void> completePersonalization({
    required int dailyMinutes,
    required String focusSkill,
  }) async {
    state = state.copyWith(
      isLoading: false,
      isCompleted: true,
      currentStep: OnboardingStep.completed,
      dailyMinutes: dailyMinutes,
      focusSkill: focusSkill,
    );

    try {
      if (AppDatabase.instance.isOpen) {
        final db = AppDatabase.instance.database;
        final nowUtc = DateTime.now().toUtc().toIso8601String();

        await db.transaction((txn) async {
          await txn.insert(
            DatabaseConstants.tableAppSettings,
            {
              'key': keyDailyMinutes,
              'value': dailyMinutes.toString(),
              'updated_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await txn.insert(
            DatabaseConstants.tableAppSettings,
            {
              'key': keyPrioritySkill,
              'value': focusSkill,
              'updated_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await txn.insert(
            DatabaseConstants.tableAppSettings,
            {
              'key': keyOnboardingStep,
              'value': OnboardingStep.completed.stepIndex.toString(),
              'updated_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await txn.insert(
            DatabaseConstants.tableAppSettings,
            {
              'key': keyOnboardingCompleted,
              'value': 'true',
              'updated_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          final currentHsk = state.assessedHskLevel ?? 1;
          await txn.update(
            DatabaseConstants.tableUserProfiles,
            {
              'current_hsk_level': currentHsk,
              'daily_minutes': dailyMinutes,
              'updated_at': nowUtc,
            },
            where: 'id = ?',
            whereArgs: ['user_default'],
          );
        });
      }
    } catch (_) {}
  }

  Future<void> resetOnboarding() async {
    try {
      if (AppDatabase.instance.isOpen) {
        final db = AppDatabase.instance.database;
        final nowUtc = DateTime.now().toUtc().toIso8601String();
        await db.transaction((txn) async {
          await txn.insert(
            DatabaseConstants.tableAppSettings,
            {
              'key': keyOnboardingCompleted,
              'value': 'false',
              'updated_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await txn.insert(
            DatabaseConstants.tableAppSettings,
            {
              'key': keyOnboardingStep,
              'value': '0',
              'updated_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        });
      }
    } catch (_) {}

    state = const OnboardingState(
      isLoading: false,
      isCompleted: false,
      currentStep: OnboardingStep.aiSetup,
    );
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);
