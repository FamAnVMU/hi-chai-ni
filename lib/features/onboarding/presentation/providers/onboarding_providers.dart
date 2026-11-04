import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_constants.dart';
import '../../../curriculum/data/placement_unlock_handler.dart';

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

class PersonalizationData {
  final String purpose;
  final bool showPinyin;
  final String pinyinPosition;
  final String scriptType;
  final String learningMethod;
  final double speechRate;
  final bool reminderEnabled;
  final String reminderTime;

  const PersonalizationData({
    this.purpose = 'dailyCommunication',
    this.showPinyin = true,
    this.pinyinPosition = 'above_hanzi',
    this.scriptType = 'simplified',
    this.learningMethod = 'contextual_lessons',
    this.speechRate = 1.0,
    this.reminderEnabled = true,
    this.reminderTime = '20:00',
  });
}

class OnboardingState {
  final bool isLoading;
  final bool isCompleted;
  final OnboardingStep currentStep;
  final bool hasSkippedAiSetup;
  final int? assessedHskLevel;
  final int dailyMinutes;
  final String focusSkill;
  final String learningPurpose;
  final bool showPinyin;
  final String pinyinPosition;
  final String scriptType;
  final String learningMethod;
  final double speechRate;
  final bool reminderEnabled;
  final String reminderTime;

  const OnboardingState({
    this.isLoading = false,
    this.isCompleted = false,
    this.currentStep = OnboardingStep.aiSetup,
    this.hasSkippedAiSetup = false,
    this.assessedHskLevel,
    this.dailyMinutes = 30,
    this.focusSkill = 'reading',
    this.learningPurpose = 'dailyCommunication',
    this.showPinyin = true,
    this.pinyinPosition = 'above_hanzi',
    this.scriptType = 'simplified',
    this.learningMethod = 'contextual_lessons',
    this.speechRate = 1.0,
    this.reminderEnabled = true,
    this.reminderTime = '20:00',
  });

  OnboardingState copyWith({
    bool? isLoading,
    bool? isCompleted,
    OnboardingStep? currentStep,
    bool? hasSkippedAiSetup,
    int? assessedHskLevel,
    int? dailyMinutes,
    String? focusSkill,
    String? learningPurpose,
    bool? showPinyin,
    String? pinyinPosition,
    String? scriptType,
    String? learningMethod,
    double? speechRate,
    bool? reminderEnabled,
    String? reminderTime,
  }) {
    return OnboardingState(
      isLoading: isLoading ?? this.isLoading,
      isCompleted: isCompleted ?? this.isCompleted,
      currentStep: currentStep ?? this.currentStep,
      hasSkippedAiSetup: hasSkippedAiSetup ?? this.hasSkippedAiSetup,
      assessedHskLevel: assessedHskLevel ?? this.assessedHskLevel,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      focusSkill: focusSkill ?? this.focusSkill,
      learningPurpose: learningPurpose ?? this.learningPurpose,
      showPinyin: showPinyin ?? this.showPinyin,
      pinyinPosition: pinyinPosition ?? this.pinyinPosition,
      scriptType: scriptType ?? this.scriptType,
      learningMethod: learningMethod ?? this.learningMethod,
      speechRate: speechRate ?? this.speechRate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  static const String keyOnboardingCompleted = 'onboarding_completed';
  static const String keyOnboardingStep = 'onboarding_current_step';
  static const String keyDailyMinutes = 'daily_learning_minutes';
  static const String keyPrioritySkill = 'priority_focus_skill';
  static const String keyLearningPurpose = 'learning_purpose';
  static const String keyShowPinyin = 'show_pinyin';
  static const String keyPinyinPosition = 'pinyin_position';
  static const String keyScriptType = 'script_type';
  static const String keyLearningMethod = 'preferred_learning_method';
  static const String keySpeechRate = 'speech_rate';
  static const String keyReminderEnabled = 'daily_reminder_enabled';
  static const String keyReminderTime = 'daily_reminder_time';
  static const String keyStartingHsk = 'starting_hsk_level';

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
      final purpose = map[keyLearningPurpose] ?? 'dailyCommunication';
      final showPinyin = (map[keyShowPinyin] ?? 'true') == 'true';
      final pinyinPos = map[keyPinyinPosition] ?? 'above_hanzi';
      final script = map[keyScriptType] ?? 'simplified';
      final method = map[keyLearningMethod] ?? 'contextual_lessons';
      final speech = double.tryParse(map[keySpeechRate] ?? '1.0') ?? 1.0;
      final reminder = (map[keyReminderEnabled] ?? 'true') == 'true';
      final reminderTime = map[keyReminderTime] ?? '20:00';
      final startingHsk = int.tryParse(map[keyStartingHsk] ?? '1');

      state = state.copyWith(
        isLoading: false,
        isCompleted: isCompleted,
        currentStep: isCompleted ? OnboardingStep.completed : OnboardingStep.fromIndex(stepIndex),
        dailyMinutes: dailyMinutes,
        focusSkill: focusSkill,
        learningPurpose: purpose,
        showPinyin: showPinyin,
        pinyinPosition: pinyinPos,
        scriptType: script,
        learningMethod: method,
        speechRate: speech,
        reminderEnabled: reminder,
        reminderTime: reminderTime,
        assessedHskLevel: startingHsk,
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
        if (hskLevel != null) {
          await db.insert(
            DatabaseConstants.tableAppSettings,
            {
              'key': keyStartingHsk,
              'value': hskLevel.toString(),
              'updated_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> completePersonalization({
    required int dailyMinutes,
    required String focusSkill,
    String learningPurpose = 'dailyCommunication',
    bool showPinyin = true,
    String pinyinPosition = 'above_hanzi',
    String scriptType = 'simplified',
    String learningMethod = 'contextual_lessons',
    double speechRate = 1.0,
    bool reminderEnabled = true,
    String reminderTime = '20:00',
  }) async {
    state = state.copyWith(
      isLoading: false,
      isCompleted: true,
      currentStep: OnboardingStep.completed,
      dailyMinutes: dailyMinutes,
      focusSkill: focusSkill,
      learningPurpose: learningPurpose,
      showPinyin: showPinyin,
      pinyinPosition: pinyinPosition,
      scriptType: scriptType,
      learningMethod: learningMethod,
      speechRate: speechRate,
      reminderEnabled: reminderEnabled,
      reminderTime: reminderTime,
    );

    try {
      if (AppDatabase.instance.isOpen) {
        final db = AppDatabase.instance.database;
        final nowUtc = DateTime.now().toUtc().toIso8601String();

        await db.transaction((txn) async {
          final settingsMap = {
            keyDailyMinutes: dailyMinutes.toString(),
            keyPrioritySkill: focusSkill,
            keyLearningPurpose: learningPurpose,
            keyShowPinyin: showPinyin.toString(),
            keyPinyinPosition: pinyinPosition,
            keyScriptType: scriptType,
            keyLearningMethod: learningMethod,
            keySpeechRate: speechRate.toString(),
            keyReminderEnabled: reminderEnabled.toString(),
            keyReminderTime: reminderTime,
            keyStartingHsk: (state.assessedHskLevel ?? 1).toString(),
            keyOnboardingStep: OnboardingStep.completed.stepIndex.toString(),
            keyOnboardingCompleted: 'true',
          };

          for (final entry in settingsMap.entries) {
            await txn.insert(
              DatabaseConstants.tableAppSettings,
              {
                'key': entry.key,
                'value': entry.value,
                'updated_at': nowUtc,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          final currentHsk = state.assessedHskLevel ?? 1;
          await txn.update(
            DatabaseConstants.tableUserProfiles,
            {
              'current_hsk_level': currentHsk,
              'daily_minutes': dailyMinutes,
              'purpose': learningPurpose,
              'updated_at': nowUtc,
            },
          );

          final targetHsk = (currentHsk < 6) ? currentHsk + 1 : 6;

          String purposeEnumName = 'dailyCommunication';
          if (learningPurpose == 'hskExam') {
            purposeEnumName = 'hskExam';
          } else if (learningPurpose == 'businessWork') {
            purposeEnumName = 'businessWork';
          } else if (learningPurpose == 'travelCulture') {
            purposeEnumName = 'travelCulture';
          }

          String timeframeEnumName = 'standard';
          if (dailyMinutes >= 45) {
            timeframeEnumName = 'express';
          } else if (dailyMinutes <= 15) {
            timeframeEnumName = 'relaxed';
          }

          final activeGoals = await txn.query(
            DatabaseConstants.tableLearnerGoals,
            where: 'is_active = 1',
            limit: 1,
          );

          if (activeGoals.isNotEmpty) {
            final existingId = activeGoals.first['id'] as String;
            await txn.update(
              DatabaseConstants.tableLearnerGoals,
              {
                'target_hsk_level': targetHsk,
                'purpose': purposeEnumName,
                'timeframe': timeframeEnumName,
                'daily_minutes': dailyMinutes,
                'updated_at': nowUtc,
              },
              where: 'id = ?',
              whereArgs: [existingId],
            );
          } else {
            await txn.insert(
              DatabaseConstants.tableLearnerGoals,
              {
                'id': 'goal_${DateTime.now().toUtc().microsecondsSinceEpoch}',
                'target_hsk_level': targetHsk,
                'purpose': purposeEnumName,
                'timeframe': timeframeEnumName,
                'daily_minutes': dailyMinutes,
                'is_active': 1,
                'created_at': nowUtc,
                'updated_at': nowUtc,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }

          final unlockHandler = PlacementUnlockHandler(txn);
          await unlockHandler.unlockForRecommendedLevel(currentHsk);

          await txn.insert(
            DatabaseConstants.tableAppSettings,
            {
              'key': 'roadmap_initialized',
              'value': 'true',
              'updated_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        });
      }
    } catch (_) {}
  }

  Future<void> previousStep() async {
    if (state.currentStep == OnboardingStep.personalization) {
      await setStep(OnboardingStep.placementTest);
    } else if (state.currentStep == OnboardingStep.placementTest) {
      await setStep(OnboardingStep.aiSetup);
    }
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
