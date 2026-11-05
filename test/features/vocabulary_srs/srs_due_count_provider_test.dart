import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/home/domain/models/home_dashboard_data.dart';
import 'package:hi_chinese/features/home/domain/models/learning_streak.dart';
import 'package:hi_chinese/features/home/data/home_repository.dart';
import 'package:hi_chinese/features/home/presentation/providers/home_providers.dart';
import 'package:hi_chinese/features/profile/domain/models/user_profile.dart';
import 'package:hi_chinese/features/profile/presentation/providers/profile_providers.dart';
import 'package:hi_chinese/features/vocabulary_srs/data/srs_repository.dart';
import 'package:hi_chinese/features/vocabulary_srs/presentation/providers/srs_providers.dart';

class _FakeSrsRepository implements SrsRepository {
  int dueCount;
  bool shouldThrow = false;

  _FakeSrsRepository({this.dueCount = 5});

  @override
  Future<int> getDueCardsCount({
    String contentType = 'vocabulary',
    int? hskLevel,
    DateTime? asOf,
    Duration ttl = const Duration(seconds: 60),
    bool forceRefresh = false,
  }) async {
    if (shouldThrow) {
      throw Exception('Database query failure in getDueCardsCount');
    }
    return dueCount;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHomeRepository implements HomeRepository {
  int callCount = 0;

  @override
  Future<HomeDashboardData> getDashboardData({
    DateTime? evaluationTime,
    Duration? timeZoneOffset,
    String? learnerName,
    int? targetHskLevel,
    int dailyGoalWords = 15,
    int? dailyGoalMinutes,
  }) async {
    callCount++;
    return const HomeDashboardData(
      learnerName: 'Test Learner',
      greeting: 'Chào bạn!',
      streak: LearningStreak(
        currentStreak: 1,
        bestStreak: 5,
        hasStudiedToday: true,
      ),
      srsDueCount: 5,
      roadmap: RoadmapProgress(
        currentHskLevel: 1,
        levelTitle: 'HSK 1',
        totalVocabCount: 150,
        learnedVocabCount: 50,
        masteredVocabCount: 20,
        nextLessonTitle: 'Bài 1',
        nextLessonSnippet: 'Chào hỏi',
      ),
      recentActivities: [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestUserProfileNotifier extends UserProfileNotifier {
  final UserProfile profile;

  _TestUserProfileNotifier(this.profile);

  @override
  Future<UserProfile> build() async => profile;
}

void main() {
  group('SrsDueCountNotifier & Selective Home Subscription Tests (F-01)', () {
    late _FakeSrsRepository fakeSrsRepo;
    late _MockHomeRepository mockHomeRepo;
    late ProviderContainer container;

    setUp(() async {
      fakeSrsRepo = _FakeSrsRepository(dueCount: 5);
      mockHomeRepo = _MockHomeRepository();

      container = ProviderContainer(
        overrides: [
          srsRepositoryProvider.overrideWithValue(fakeSrsRepo),
          homeRepositoryProvider.overrideWithValue(mockHomeRepo),
          userProfileProvider.overrideWith(
            () => _TestUserProfileNotifier(UserProfile.defaultProfile()),
          ),
        ],
      );
      // Settle userProfileProvider first so dependent async providers have a stable profile
      await container.read(userProfileProvider.future);
    });

    tearDown(() {
      container.dispose();
    });

    test('1. SrsDueCountNotifier initializes with loading then emits data', () async {
      final recordedStates = <AsyncValue<int>>[];
      container.listen<AsyncValue<int>>(
        srsDueCountProvider,
        (prev, next) => recordedStates.add(next),
        fireImmediately: true,
      );

      // Initially loading
      expect(recordedStates.first, isA<AsyncLoading<int>>());

      // Await initial build completion
      final initialCount = await container.read(srsDueCountProvider.future);
      expect(initialCount, equals(5));
      expect(recordedStates.last, equals(const AsyncData<int>(5)));
    });

    test('2. refreshCount() does NOT emit intermediate AsyncLoading and updates data directly', () async {
      // 1. Initial build resolution
      await container.read(srsDueCountProvider.future);

      final stateLog = <AsyncValue<int>>[];
      container.listen<AsyncValue<int>>(
        srsDueCountProvider,
        (prev, next) => stateLog.add(next),
        fireImmediately: false,
      );

      // Update repo count to 3 and call refreshCount()
      fakeSrsRepo.dueCount = 3;
      await container.read(srsDueCountProvider.notifier).refreshCount();

      // Verify states emitted during refresh
      expect(stateLog.length, equals(1), reason: 'Should emit exactly one state update, not two');
      expect(stateLog.first, isA<AsyncData<int>>());
      expect(stateLog.first.value, equals(3));

      // Verify absolutely NO intermediate AsyncLoading state was emitted
      expect(
        stateLog.any((s) => s is AsyncLoading),
        isFalse,
        reason: 'refreshCount() must NOT emit an intermediate AsyncLoading state (F-01)',
      );
    });

    test('3. refreshCount() captures error into AsyncError without swallowing or crashing', () async {
      await container.read(srsDueCountProvider.future);

      fakeSrsRepo.shouldThrow = true;
      await container.read(srsDueCountProvider.notifier).refreshCount();

      final currentState = container.read(srsDueCountProvider);
      expect(currentState, isA<AsyncError<int>>());
      expect(currentState.error.toString(), contains('Database query failure'));
    });

    test('4. HomeDashboardNotifier selective subscription: does NOT rebuild when dueCount is unchanged', () async {
      // Ensure srsDueCountProvider has completed its initial build
      await container.read(srsDueCountProvider.future);

      // Initialize homeDashboardProvider
      final initialData = await container.read(homeDashboardProvider.future);
      expect(initialData, isNotNull);
      expect(mockHomeRepo.callCount, equals(1));

      // Trigger refreshCount() with the SAME count (5 -> 5)
      fakeSrsRepo.dueCount = 5;
      await container.read(srsDueCountProvider.notifier).refreshCount();

      // HomeDashboardNotifier should NOT have re-evaluated because val.value did not change
      expect(
        mockHomeRepo.callCount,
        equals(1),
        reason: 'HomeDashboardNotifier should not re-run getDashboardData when due count is unchanged',
      );

      // Now change dueCount (5 -> 2)
      fakeSrsRepo.dueCount = 2;
      await container.read(srsDueCountProvider.notifier).refreshCount();

      // Wait for homeDashboardProvider to re-evaluate
      await container.pump();
      await container.read(homeDashboardProvider.future);

      expect(
        mockHomeRepo.callCount,
        equals(2),
        reason: 'HomeDashboardNotifier must re-evaluate when due count actually changes',
      );
    });
  });
}
