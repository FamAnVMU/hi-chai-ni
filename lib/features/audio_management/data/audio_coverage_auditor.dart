import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../domain/models/audio_coverage_report.dart';

class AudioCoverageAuditor {
  final DatabaseExecutor _db;

  const AudioCoverageAuditor(this._db);

  /// Audits curriculum levels and database to generate an accurate coverage report.
  Future<AudioCoverageReport> auditCoverage() async {
    final now = DateTime.now().toUtc();
    final levelCoverages = <AudioLevelCoverage>[];

    int grandTotalReq = 0;
    int grandTotalAvail = 0;
    int grandTotalMiss = 0;
    int grandTotalVer = 0;

    // 1. Audit Pinyin Foundation (Level 0)
    // 23 initials + 36 finals + 5 tones + 50 core blend syllables = 114 required
    const pinyinRequired = 114;
    final pinyinAssets = await _db.query(
      DatabaseConstants.tableAudioAssets,
      where: 'hsk_level = 0 AND status = ?',
      whereArgs: ['ready'],
    );
    int pinyinVerified = 0;
    for (final row in pinyinAssets) {
      final path = row['local_path'] as String?;
      if (path != null && await File(path).exists()) {
        pinyinVerified++;
      }
    }
    final pinyinMissing = (pinyinRequired - pinyinVerified).clamp(0, pinyinRequired);
    levelCoverages.add(AudioLevelCoverage(
      hskLevel: 0,
      levelName: 'Pinyin Foundation',
      totalRequired: pinyinRequired,
      totalAvailable: pinyinAssets.length,
      totalMissing: pinyinMissing,
      totalVerified: pinyinVerified,
      typeBreakdown: {
        'initial': 23,
        'final': 36,
        'tone': 5,
        'syllable': 50,
      },
    ));
    grandTotalReq += pinyinRequired;
    grandTotalAvail += pinyinAssets.length;
    grandTotalMiss += pinyinMissing;
    grandTotalVer += pinyinVerified;

    // 2. Audit HSK 1 to HSK 6
    final standardHskReqs = {
      1: 150,  // HSK 1: 150 words + dialogues
      2: 150,  // HSK 2: 150 words + dialogues
      3: 300,  // HSK 3: 300 words + dialogues
      4: 600,  // HSK 4: 600 words + dialogues
      5: 1300, // HSK 5: 1300 words + reading
      6: 2500, // HSK 6: 2500 words + reading
    };

    for (int lvl = 1; lvl <= 6; lvl++) {
      final req = standardHskReqs[lvl] ?? 150;
      final assets = await _db.query(
        DatabaseConstants.tableAudioAssets,
        where: 'hsk_level = ? AND status = ?',
        whereArgs: [lvl, 'ready'],
      );

      int verified = 0;
      final typeMap = <String, int>{};
      for (final a in assets) {
        final type = a['audio_type'] as String? ?? 'vocab';
        typeMap[type] = (typeMap[type] ?? 0) + 1;

        final path = a['local_path'] as String?;
        if (path != null && await File(path).exists()) {
          verified++;
        }
      }

      final missing = (req - verified).clamp(0, req);
      levelCoverages.add(AudioLevelCoverage(
        hskLevel: lvl,
        levelName: 'HSK $lvl',
        totalRequired: req,
        totalAvailable: assets.length,
        totalMissing: missing,
        totalVerified: verified,
        typeBreakdown: typeMap,
      ));

      grandTotalReq += req;
      grandTotalAvail += assets.length;
      grandTotalMiss += missing;
      grandTotalVer += verified;
    }

    return AudioCoverageReport(
      auditedAt: now,
      grandTotalRequired: grandTotalReq,
      grandTotalAvailable: grandTotalAvail,
      grandTotalMissing: grandTotalMiss,
      grandTotalVerified: grandTotalVer,
      levelCoverages: levelCoverages,
    );
  }
}
