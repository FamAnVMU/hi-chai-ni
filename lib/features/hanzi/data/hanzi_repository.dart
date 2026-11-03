import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/models/hanzi_models.dart';
import 'hanzi_dao.dart';

abstract class HanziRepository {
  Future<HanziCharacter?> getCharacter(String character);
  Future<HanziCharacter?> getCharacterById(String id);
  Future<List<HanziCharacter>> getCharactersByHskLevel(int hskLevel, {int limit = 100, int offset = 0});
  Future<List<HanziCharacter>> searchCharacters(String query, {int limit = 50});
  Future<HanziWritingProgress?> getProgress(String character);
  Future<void> recordPracticeAttempt({
    required String character,
    required double accuracy,
    required int mistakes,
    required int strokeOrderErrors,
    required bool isTestMode,
  });
  Future<List<HanziWritingProgress>> getCharactersNeedingReview({int limit = 50});
  Future<List<HanziWritingProgress>> getRecentPracticed({int limit = 20});
  Future<int> ensureSeedLoaded({String assetPath = 'assets/data/hanzi_stroke_data.json'});
}

class DefaultHanziRepository implements HanziRepository {
  final HanziDao _dao;
  bool _isSeeded = false;

  DefaultHanziRepository(this._dao);

  @override
  Future<HanziCharacter?> getCharacter(String character) async {
    await _checkAndSeed();
    return _dao.getCharacter(character);
  }

  @override
  Future<HanziCharacter?> getCharacterById(String id) async {
    await _checkAndSeed();
    return _dao.getCharacterById(id);
  }

  @override
  Future<List<HanziCharacter>> getCharactersByHskLevel(
    int hskLevel, {
    int limit = 100,
    int offset = 0,
  }) async {
    await _checkAndSeed();
    return _dao.getCharactersByHskLevel(hskLevel, limit: limit, offset: offset);
  }

  @override
  Future<List<HanziCharacter>> searchCharacters(String query, {int limit = 50}) async {
    await _checkAndSeed();
    return _dao.searchCharacters(query, limit: limit);
  }

  @override
  Future<HanziWritingProgress?> getProgress(String character) async {
    return _dao.getProgress(character);
  }

  @override
  Future<void> recordPracticeAttempt({
    required String character,
    required double accuracy,
    required int mistakes,
    required int strokeOrderErrors,
    required bool isTestMode,
  }) async {
    final existing = await _dao.getProgress(character);
    final now = DateTime.now();

    final prevPractice = existing?.practiceCount ?? 0;
    final prevTest = existing?.testCount ?? 0;
    final prevMistakes = existing?.mistakesCount ?? 0;
    final prevOrderErrors = existing?.strokeOrderErrors ?? 0;
    final prevBest = existing?.bestAccuracyScore ?? 0.0;

    final newBest = accuracy > prevBest ? accuracy : prevBest;
    final hskLvl = existing?.hskLevel ?? 1;

    // Determine mastery level and spaced repetition interval
    String mastery;
    DateTime srsDue;

    if (isTestMode) {
      if (accuracy >= 90.0 && mistakes == 0) {
        mastery = 'mastered';
        srsDue = now.add(const Duration(days: 4));
      } else if (accuracy >= 75.0) {
        mastery = 'practiced';
        srsDue = now.add(const Duration(days: 2));
      } else {
        mastery = 'learning';
        srsDue = now.add(const Duration(hours: 6));
      }
    } else {
      mastery = existing?.masteryLevel == 'mastered' ? 'mastered' : 'learning';
      srsDue = existing?.srsDueDate ?? now.add(const Duration(days: 1));
    }

    final updated = HanziWritingProgress(
      id: 'progress_$character',
      character: character,
      hskLevel: hskLvl,
      practiceCount: isTestMode ? prevPractice : prevPractice + 1,
      testCount: isTestMode ? prevTest + 1 : prevTest,
      lastAccuracyScore: accuracy,
      bestAccuracyScore: newBest,
      mistakesCount: prevMistakes + mistakes,
      strokeOrderErrors: prevOrderErrors + strokeOrderErrors,
      lastPracticedAt: now,
      masteryLevel: mastery,
      isFavorite: existing?.isFavorite ?? false,
      srsDueDate: srsDue,
    );

    await _dao.saveProgress(updated);
  }

  @override
  Future<List<HanziWritingProgress>> getCharactersNeedingReview({int limit = 50}) async {
    return _dao.getCharactersNeedingReview(limit: limit);
  }

  @override
  Future<List<HanziWritingProgress>> getRecentPracticed({int limit = 20}) async {
    return _dao.getRecentPracticed(limit: limit);
  }

  @override
  Future<int> ensureSeedLoaded({String assetPath = 'assets/data/hanzi_stroke_data.json'}) async {
    final count = await _dao.countCharacters();
    if (count > 0) {
      _isSeeded = true;
      return count;
    }

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final rawChars = data['characters'] as List;

      final characters = rawChars
          .map((item) => HanziCharacter.fromJson(item as Map<String, dynamic>))
          .toList();

      await _dao.insertCharactersBatch(characters);
      _isSeeded = true;
      return characters.length;
    } catch (_) {
      // In tests or if asset not loaded, ignore
      return 0;
    }
  }

  Future<void> _checkAndSeed() async {
    if (!_isSeeded) {
      await ensureSeedLoaded();
    }
  }
}
