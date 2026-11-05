import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/services.dart';
import '../domain/models/sentence_models.dart';
import 'sentence_dao.dart';

abstract class SentenceRepository {
  Future<SentenceItem?> getSentenceById(String id);
  Future<List<SentenceItem>> getSentencesByHskLevel(
    int hskLevel, {
    int limit = 50,
    int offset = 0,
    bool humanAudioOnly = false,
  });
  Future<List<SentenceItem>> searchSentences(String query, {int limit = 30});
  Future<SentencePracticeProgress?> getProgress(String sentenceId);
  Future<Map<String, SentencePracticeProgress>> getProgressForSentences(List<String> sentenceIds);
  Future<List<SentenceItem>> getSentencesByIds(List<String> sentenceIds);
  Future<void> recordPracticeAttempt({
    required String sentenceId,
    required String practiceType, // 'listening', 'shadowing', 'reading'
    required double score,
    String? recordedAudioPath,
  });
  Future<List<SentencePracticeProgress>> getSentencesNeedingReview({int limit = 50});
  Future<int> ensureSeedLoaded({String assetPath = 'assets/data/sentences_corpus.json'});
}

class DefaultSentenceRepository implements SentenceRepository {
  final SentenceDao _dao;
  bool _isSeeded = false;
  Future<int>? _seedingFuture;

  DefaultSentenceRepository(this._dao);

  @override
  Future<SentenceItem?> getSentenceById(String id) async {
    await _checkAndSeed();
    return _dao.getSentenceById(id);
  }

  @override
  Future<List<SentenceItem>> getSentencesByHskLevel(
    int hskLevel, {
    int limit = 50,
    int offset = 0,
    bool humanAudioOnly = false,
  }) async {
    await _checkAndSeed();
    return _dao.getSentencesByHskLevel(
      hskLevel,
      limit: limit,
      offset: offset,
      humanAudioOnly: humanAudioOnly,
    );
  }

  @override
  Future<List<SentenceItem>> searchSentences(String query, {int limit = 30}) async {
    await _checkAndSeed();
    return _dao.searchSentences(query, limit: limit);
  }

  @override
  Future<SentencePracticeProgress?> getProgress(String sentenceId) async {
    return _dao.getProgress(sentenceId);
  }

  @override
  Future<Map<String, SentencePracticeProgress>> getProgressForSentences(List<String> sentenceIds) async {
    return _dao.getProgressForSentences(sentenceIds);
  }

  @override
  Future<List<SentenceItem>> getSentencesByIds(List<String> sentenceIds) async {
    await _checkAndSeed();
    return _dao.getSentencesByIds(sentenceIds);
  }

  @override
  Future<void> recordPracticeAttempt({
    required String sentenceId,
    required String practiceType,
    required double score,
    String? recordedAudioPath,
  }) async {
    final existing = await _dao.getProgress(sentenceId);
    final now = DateTime.now();

    final prevListening = existing?.listeningAttempts ?? 0;
    final prevShadowing = existing?.shadowingAttempts ?? 0;
    final prevReading = existing?.readingAttempts ?? 0;
    final prevBest = existing?.bestScore ?? 0.0;
    final newBest = score > prevBest ? score : prevBest;

    String mastery;
    DateTime srsDue;

    if (score >= 85.0) {
      mastery = 'mastered';
      srsDue = now.add(const Duration(days: 3));
    } else if (score >= 60.0) {
      mastery = 'practiced';
      srsDue = now.add(const Duration(days: 1));
    } else {
      mastery = 'learning';
      srsDue = now.add(const Duration(hours: 6));
    }

    final updated = SentencePracticeProgress(
      id: 'prog_$sentenceId',
      sentenceId: sentenceId,
      hskLevel: existing?.hskLevel ?? 1,
      listeningAttempts: practiceType == 'listening' ? prevListening + 1 : prevListening,
      shadowingAttempts: practiceType == 'shadowing' ? prevShadowing + 1 : prevShadowing,
      readingAttempts: practiceType == 'reading' ? prevReading + 1 : prevReading,
      lastScore: score,
      bestScore: newBest,
      lastPracticedAt: now,
      lastShadowingAudioPath: recordedAudioPath ?? existing?.lastShadowingAudioPath,
      masteryLevel: mastery,
      srsDueDate: srsDue,
    );

    await _dao.saveProgress(updated);
  }

  @override
  Future<List<SentencePracticeProgress>> getSentencesNeedingReview({int limit = 50}) async {
    return _dao.getSentencesNeedingReview(limit: limit);
  }

  @override
  Future<int> ensureSeedLoaded({String assetPath = 'assets/data/sentences_corpus.json'}) async {
    if (_isSeeded) {
      return await _dao.countSentences();
    }
    if (_seedingFuture != null) {
      return await _seedingFuture!;
    }
    _seedingFuture = _performEnsureSeedLoaded(assetPath);
    try {
      return await _seedingFuture!;
    } finally {
      _seedingFuture = null;
    }
  }

  Future<int> _performEnsureSeedLoaded(String assetPath) async {
    final count = await _dao.countSentences();
    if (count > 0) {
      _isSeeded = true;
      return count;
    }

    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final sentences = await Isolate.run(() {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;
        final rawSentences = data['sentences'] as List<dynamic>;
        return rawSentences
            .map((item) => SentenceItem.fromJson(item as Map<String, dynamic>))
            .toList();
      });

      await _dao.insertSentencesBatch(sentences);
      _isSeeded = true;
      return sentences.length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _checkAndSeed() async {
    if (!_isSeeded) {
      await ensureSeedLoaded();
    }
  }
}
