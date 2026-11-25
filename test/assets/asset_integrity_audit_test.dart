import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OPT-09 Asset & Content Integrity Audit Tests', () {
    test('1. All MP3 files under assets/audio/ are non-empty non-stub audio (> 4500 bytes)', () {
      final audioDir = Directory('assets/audio');
      expect(audioDir.existsSync(), isTrue, reason: 'assets/audio directory must exist');

      final mp3Files = audioDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.mp3'))
          .toList();

      expect(mp3Files, isNotEmpty, reason: 'At least one MP3 asset must exist');

      final silentOrTooSmall = <String>[];
      for (final file in mp3Files) {
        final size = file.lengthSync();
        if (size <= 4500) {
          silentOrTooSmall.add('${file.path} (${size}B)');
        }
      }

      expect(
        silentOrTooSmall,
        isEmpty,
        reason: 'Silent/stub MP3 files (<= 4500B) found: $silentOrTooSmall',
      );
    });

    test('2. Every literal assets/audio/...mp3 reference in lib/ resolves to a valid audio file', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue);

      final mp3LiteralPattern = RegExp(r'assets/audio/[A-Za-z0-9_./-]+\.mp3');
      final referencedPaths = <String>{};

      for (final entity in libDir.listSync(recursive: true).whereType<File>()) {
        if (!entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        for (final match in mp3LiteralPattern.allMatches(content)) {
          referencedPaths.add(match.group(0)!);
        }
      }

      expect(referencedPaths, isNotEmpty);

      final brokenRefs = <String>[];
      for (final assetPath in referencedPaths) {
        final file = File(assetPath);
        if (!file.existsSync() || file.lengthSync() <= 4500) {
          brokenRefs.add(assetPath);
        }
      }

      expect(
        brokenRefs,
        isEmpty,
        reason: 'Broken or stub audio references found in lib/: $brokenRefs',
      );
    });

    test('3. graded_reading_passages.json has 0 broken audio links and balanced answer indices (0..3)', () {
      final readingFile = File('assets/data/graded_reading_passages.json');
      expect(readingFile.existsSync(), isTrue);

      final decoded = json.decode(readingFile.readAsStringSync());
      final passages = decoded is List
          ? decoded
          : (decoded as Map<String, dynamic>)['passages'] as List<dynamic>;

      expect(passages, isNotEmpty);

      final brokenAudio = <String>[];
      final answerCounts = <int, int>{};
      int totalQuestions = 0;

      for (final rawPassage in passages) {
        final passage = rawPassage as Map<String, dynamic>;
        final audioUri = (passage['audio_uri'] ?? passage['audioUri'] ?? '') as String;
        if (audioUri.startsWith('assets/audio/')) {
          final audioFile = File(audioUri);
          if (!audioFile.existsSync() || audioFile.lengthSync() <= 4500) {
            brokenAudio.add('${passage['id']}: $audioUri');
          }
        }

        final questions = passage['questions'] as List<dynamic>? ?? const [];
        for (final rawQ in questions) {
          final q = rawQ as Map<String, dynamic>;
          final answer = q['answer'];
          if (answer is int) {
            answerCounts[answer] = (answerCounts[answer] ?? 0) + 1;
            totalQuestions++;
          }
        }
      }

      expect(brokenAudio, isEmpty, reason: 'Broken reading audio links: $brokenAudio');
      expect(totalQuestions, greaterThan(0));
      for (final idx in [0, 1, 2, 3]) {
        expect(
          answerCounts[idx] ?? 0,
          greaterThan(0),
          reason: 'Option index $idx must appear in graded_reading_passages questions ($answerCounts)',
        );
        expect(
          (answerCounts[idx] ?? 0) / totalQuestions,
          lessThan(0.5),
          reason: 'Answer distribution must not be skewed >= 50% on index $idx ($answerCounts)',
        );
      }
    });

    test('4. Content packs HSK 1..6 parse cleanly with non-empty manifest and curriculum', () {
      for (var level = 1; level <= 6; level++) {
        final packFile = File('assets/data/content_packs/hsk$level/hsk${level}_pack_v1.json');
        expect(packFile.existsSync(), isTrue, reason: 'Missing pack file for HSK $level');

        final decoded = json.decode(packFile.readAsStringSync()) as Map<String, dynamic>;
        final manifest = decoded['manifest'] as Map<String, dynamic>?;
        final curriculum = decoded['curriculum'] as Map<String, dynamic>?;

        expect(manifest, isNotNull, reason: 'HSK $level pack missing manifest');
        expect(manifest, isNotEmpty, reason: 'HSK $level manifest is empty');
        expect(curriculum, isNotNull, reason: 'HSK $level pack missing curriculum');
        expect(curriculum, isNotEmpty, reason: 'HSK $level curriculum is empty');
      }
    });
  });
}
