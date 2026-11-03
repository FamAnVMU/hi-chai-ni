import 'dart:convert';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'seed_data_validator.dart';
import 'seed_history_dao.dart';
import 'seed_models.dart';

class SeedValidationException implements Exception {
  final List<String> errors;
  SeedValidationException(this.errors);

  @override
  String toString() => 'SeedValidationException:\n${errors.join('\n')}';
}

class SeedLoader {
  final Database _db;
  final SeedHistoryDao _historyDao;

  SeedLoader(this._db) : _historyDao = SeedHistoryDao(_db);

  /// Computes SHA-256 checksum of raw content string.
  static String computeChecksum(String rawContent) {
    final bytes = utf8.encode(rawContent);
    return sha256.convert(bytes).toString();
  }

  /// Loads and seeds a dataset from a Flutter asset file path (e.g. 'assets/data/hsk_seed.json').
  Future<SeedResult> seedFromAsset(
    String assetPath, {
    AssetBundle? bundle,
    void Function(SeedProgress progress)? onProgress,
    int batchSize = 50,
  }) async {
    final stopwatch = Stopwatch()..start();
    final assetBundle = bundle ?? rootBundle;

    onProgress?.call(const SeedProgress(
      stage: SeedStage.validating,
      processedItems: 0,
      totalItems: 0,
      message: 'Loading seed asset from bundle...',
    ));

    final rawJson = await assetBundle.loadString(assetPath);
    return seedFromJsonString(
      rawJson,
      onProgress: onProgress,
      batchSize: batchSize,
      stopwatch: stopwatch,
    );
  }

  /// Seeds dataset from a raw JSON string.
  /// Fully idempotent: skips if checksum matches an already completed seed.
  /// Safe against interruptions: uses batch transactions and state logging.
  Future<SeedResult> seedFromJsonString(
    String rawJson, {
    void Function(SeedProgress progress)? onProgress,
    int batchSize = 50,
    Stopwatch? stopwatch,
  }) async {
    final sw = stopwatch ?? (Stopwatch()..start());

    // 1. Offload CPU-intensive JSON decoding, model mapping, and SHA-256 hashing to a background isolate
    // to guarantee 0ms UI thread blocking during app startup or asset updates.
    final (parsedBundle, computedHash, parseError) = await Isolate.run(() {
      try {
        final decoded = json.decode(rawJson) as Map<String, dynamic>;
        final bundle = SeedBundle.fromJson(decoded);
        final bytes = utf8.encode(rawJson);
        final hash = sha256.convert(bytes).toString();
        return (bundle, hash, null);
      } catch (e) {
        return (null, '', e.toString());
      }
    });

    if (parseError != null || parsedBundle == null) {
      final errorMsg = 'Failed to parse seed JSON string: $parseError';
      debugPrint('[SeedLoader] $errorMsg');
      return SeedResult.failed(error: errorMsg, duration: sw.elapsed);
    }

    return seedBundle(
      parsedBundle,
      checksum: computedHash,
      onProgress: onProgress,
      batchSize: batchSize,
      stopwatch: sw,
    );
  }

  /// Seeds a parsed [SeedBundle].
  Future<SeedResult> seedBundle(
    SeedBundle bundle, {
    required String checksum,
    void Function(SeedProgress progress)? onProgress,
    int batchSize = 50,
    Stopwatch? stopwatch,
  }) async {
    final sw = stopwatch ?? (Stopwatch()..start());
    final totalItems = bundle.totalItemCount;

    // 2. Check Idempotency via seed_history
    final existingEntry = await _historyDao.getEntry(bundle.bundleName);
    if (existingEntry != null &&
        existingEntry.status == 'completed' &&
        existingEntry.checksum == checksum &&
        existingEntry.version == bundle.version) {
      debugPrint(
        '[SeedLoader] Bundle "${bundle.bundleName}" (v${bundle.version}) already seeded with matching checksum. Skipping.',
      );
      onProgress?.call(SeedProgress(
        stage: SeedStage.completed,
        processedItems: totalItems,
        totalItems: totalItems,
        message: 'Dataset already up to date. Zero duplicates injected.',
      ));
      return SeedResult.skipped(
        reason: 'Bundle "${bundle.bundleName}" is already up to date.',
        duration: sw.elapsed,
      );
    }

    // 3. Strict Validation
    onProgress?.call(SeedProgress(
      stage: SeedStage.validating,
      processedItems: 0,
      totalItems: totalItems,
      message: 'Validating ${bundle.vocabularies.length} vocabs, ${bundle.grammarItems.length} grammar, ${bundle.readingPassages.length} reading...',
    ));

    final validation = SeedDataValidator.validateBundle(bundle);
    if (!validation.isValid) {
      final errorDetails = validation.errors.join('\n');
      debugPrint('[SeedLoader] Validation failed:\n$errorDetails');

      await _historyDao.recordFailed(
        bundleName: bundle.bundleName,
        errorMessage: 'Validation failed with ${validation.errors.length} error(s).',
      );

      return SeedResult.failed(
        error: 'Validation failed with ${validation.errors.length} error(s):\n${validation.errors.take(10).join('\n')}',
        duration: sw.elapsed,
      );
    }

    // Log warnings if any
    for (final warn in validation.warnings) {
      debugPrint('[SeedLoader:Warning] $warn');
    }

    // 4. Mark In-Progress
    await _historyDao.recordInProgress(
      bundleName: bundle.bundleName,
      version: bundle.version,
      checksum: checksum,
      totalItems: totalItems,
    );

    int processedCount = 0;
    final now = DateTime.now().toUtc().toIso8601String();

    try {
      // 5. Seed Vocabularies in Batches
      final vocabs = bundle.vocabularies;
      for (int i = 0; i < vocabs.length; i += batchSize) {
        final end = (i + batchSize < vocabs.length) ? i + batchSize : vocabs.length;
        final chunk = vocabs.sublist(i, end);

        await _db.transaction((txn) async {
          final batch = txn.batch();

          for (final v in chunk) {
            batch.rawInsert('''
              INSERT INTO ${DatabaseConstants.tableVocabularies} (
                id, simplified, traditional, pinyin, pinyin_clean, hanviet, hsk_level,
                frequency_rank, source, license, verification_status, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                simplified = excluded.simplified,
                traditional = excluded.traditional,
                pinyin = excluded.pinyin,
                pinyin_clean = excluded.pinyin_clean,
                hanviet = excluded.hanviet,
                hsk_level = excluded.hsk_level,
                frequency_rank = excluded.frequency_rank,
                source = excluded.source,
                license = excluded.license,
                verification_status = excluded.verification_status,
                updated_at = excluded.updated_at;
            ''', [
              v.id,
              v.simplified,
              v.traditional ?? v.simplified,
              v.pinyin,
              v.pinyinClean,
              v.hanviet,
              v.hskLevel,
              v.frequency,
              v.source ?? 'clem109;drkameleon;CVDICT;no7z',
              v.license ?? 'MIT;CC-BY-SA-4.0',
              'verified',
              now,
              now,
            ]);

            // Upsert into knowledge_registry for seamless learning pipeline integration
            final knowId = v.pinyinClean != null
                ? 'KNOW_VOCAB_${v.simplified}_${v.pinyinClean}'
                : 'KNOW_VOCAB_${v.simplified}';
            batch.rawInsert('''
              INSERT INTO ${DatabaseConstants.tableKnowledgeRegistry} (
                id, entity_type, canonical_id, hsk_level, title,
                package_id, created_at, updated_at
              ) VALUES (?, 'vocabulary', ?, ?, ?, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                hsk_level = excluded.hsk_level,
                updated_at = excluded.updated_at;
            ''', [
              knowId,
              v.simplified,
              v.hskLevel,
              v.simplified,
              bundle.bundleName,
              now,
              now,
            ]);

            for (final sense in v.senses) {
              final firstEx = sense.examples.isNotEmpty ? sense.examples.first : null;

              batch.rawInsert('''
                INSERT INTO ${DatabaseConstants.tableVocabularySenses} (
                  id, vocabulary_id, part_of_speech, meaning_vi, meaning_en,
                  example_cn, example_pinyin, example_vi, source, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  part_of_speech = excluded.part_of_speech,
                  meaning_vi = excluded.meaning_vi,
                  meaning_en = excluded.meaning_en,
                  example_cn = excluded.example_cn,
                  example_pinyin = excluded.example_pinyin,
                  example_vi = excluded.example_vi,
                  source = excluded.source,
                  updated_at = excluded.updated_at;
              ''', [
                sense.id,
                v.id,
                sense.partOfSpeech,
                sense.meaningVi,
                sense.meaningEn,
                firstEx?.zh,
                firstEx?.pinyin,
                firstEx?.vi,
                'CVDICT;CC-CEDICT',
                now,
                now,
              ]);

              // Insert all examples into vocabulary_examples table
              int exIdx = 1;
              for (final ex in sense.examples) {
                if (ex.zh.isEmpty) continue;
                final exId = 'EX_${sense.id}_$exIdx';
                batch.rawInsert('''
                  INSERT INTO ${DatabaseConstants.tableVocabularyExamples} (
                    id, vocabulary_id, sense_id, hsk_level, example_cn,
                    example_pinyin, example_vi, example_en, source, order_index,
                    created_at, updated_at
                  ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                  ON CONFLICT(id) DO UPDATE SET
                    example_cn = excluded.example_cn,
                    example_pinyin = excluded.example_pinyin,
                    example_vi = excluded.example_vi,
                    example_en = excluded.example_en,
                    updated_at = excluded.updated_at;
                ''', [
                  exId,
                  v.id,
                  sense.id,
                  v.hskLevel,
                  ex.zh,
                  ex.pinyin,
                  ex.vi,
                  null,
                  'no7z/hsk-sentences-audio;clem109',
                  exIdx,
                  now,
                  now,
                ]);
                exIdx++;
              }
            }
          }

          await batch.commit(noResult: true);
        });

        processedCount += chunk.length;
        onProgress?.call(SeedProgress(
          stage: SeedStage.seedingVocabularies,
          processedItems: processedCount,
          totalItems: totalItems,
          message: 'Seeded $processedCount / ${vocabs.length} vocabularies...',
        ));

        // Yield to event loop to avoid UI isolate hiccups
        await Future<void>.delayed(Duration.zero);
      }

      // 6. Seed Grammar Items
      final grammar = bundle.grammarItems;
      if (grammar.isNotEmpty) {
        await _db.transaction((txn) async {
          final batch = txn.batch();
          for (final g in grammar) {
            final examplesJson = json.encode(g.examples.map((e) => e.toJson()).toList());

            batch.rawInsert('''
              INSERT INTO ${DatabaseConstants.tableGrammarItems} (
                id, hsk_level, code, pattern, title_vi,
                explanation_vi, examples_json, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                hsk_level = excluded.hsk_level,
                code = excluded.code,
                pattern = excluded.pattern,
                title_vi = excluded.title_vi,
                explanation_vi = excluded.explanation_vi,
                examples_json = excluded.examples_json,
                updated_at = excluded.updated_at;
            ''', [
              g.id,
              g.hskLevel,
              g.code,
              g.pattern,
              g.title,
              g.explanationVi,
              examplesJson,
              now,
              now,
            ]);
          }
          await batch.commit(noResult: true);
        });

        processedCount += grammar.length;
        onProgress?.call(SeedProgress(
          stage: SeedStage.seedingGrammar,
          processedItems: processedCount,
          totalItems: totalItems,
          message: 'Seeded ${grammar.length} grammar points...',
        ));
      }

      // 7. Seed Reading Passages
      final reading = bundle.readingPassages;
      if (reading.isNotEmpty) {
        await _db.transaction((txn) async {
          final batch = txn.batch();
          for (final r in reading) {
            final questionsJson = json.encode(r.questions);

            batch.rawInsert('''
              INSERT INTO ${DatabaseConstants.tableReadingPassages} (
                id, hsk_level, title_cn, content_cn, pinyin,
                translation_vi, questions_json, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
              ON CONFLICT(id) DO UPDATE SET
                hsk_level = excluded.hsk_level,
                title_cn = excluded.title_cn,
                content_cn = excluded.content_cn,
                pinyin = excluded.pinyin,
                translation_vi = excluded.translation_vi,
                questions_json = excluded.questions_json,
                updated_at = excluded.updated_at;
            ''', [
              r.id,
              r.hskLevel,
              r.title,
              r.contentZh,
              r.pinyin,
              r.translationVi,
              questionsJson,
              now,
              now,
            ]);
          }
          await batch.commit(noResult: true);
        });

        processedCount += reading.length;
        onProgress?.call(SeedProgress(
          stage: SeedStage.seedingReading,
          processedItems: processedCount,
          totalItems: totalItems,
          message: 'Seeded ${reading.length} reading passages...',
        ));
      }

      // 8. Mark Completed
      await _historyDao.recordCompleted(
        bundleName: bundle.bundleName,
        appliedItems: processedCount,
      );

      sw.stop();
      debugPrint('[SeedLoader] Seeding completed in ${sw.elapsedMilliseconds}ms ($processedCount items).');

      onProgress?.call(SeedProgress(
        stage: SeedStage.completed,
        processedItems: processedCount,
        totalItems: totalItems,
        message: 'Completed in ${sw.elapsedMilliseconds}ms ($processedCount items).',
      ));

      return SeedResult.completed(
        totalItems: processedCount,
        duration: sw.elapsed,
      );
    } catch (e, stackTrace) {
      sw.stop();
      final errorMsg = 'Error during seed execution: $e';
      debugPrint('[SeedLoader] $errorMsg\n$stackTrace');

      await _historyDao.recordFailed(
        bundleName: bundle.bundleName,
        errorMessage: errorMsg,
        appliedItems: processedCount,
      );

      onProgress?.call(SeedProgress(
        stage: SeedStage.failed,
        processedItems: processedCount,
        totalItems: totalItems,
        message: errorMsg,
      ));

      return SeedResult.failed(
        error: errorMsg,
        duration: sw.elapsed,
        processedItems: processedCount,
      );
    }
  }
}
