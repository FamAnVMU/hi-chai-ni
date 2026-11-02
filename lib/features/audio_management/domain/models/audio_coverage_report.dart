/// Comprehensive statistical coverage report of audio assets across curriculum levels.
class AudioLevelCoverage {
  final int hskLevel;
  final String levelName;
  final int totalRequired;
  final int totalAvailable;
  final int totalMissing;
  final int totalVerified;
  final Map<String, int> typeBreakdown; // type -> count

  const AudioLevelCoverage({
    required this.hskLevel,
    required this.levelName,
    required this.totalRequired,
    required this.totalAvailable,
    required this.totalMissing,
    required this.totalVerified,
    required this.typeBreakdown,
  });

  double get coveragePercentage =>
      totalRequired == 0 ? 100.0 : ((totalAvailable / totalRequired) * 100).clamp(0.0, 100.0);
}

class AudioCoverageReport {
  final DateTime auditedAt;
  final int grandTotalRequired;
  final int grandTotalAvailable;
  final int grandTotalMissing;
  final int grandTotalVerified;
  final List<AudioLevelCoverage> levelCoverages;

  const AudioCoverageReport({
    required this.auditedAt,
    required this.grandTotalRequired,
    required this.grandTotalAvailable,
    required this.grandTotalMissing,
    required this.grandTotalVerified,
    required this.levelCoverages,
  });

  double get overallCoveragePercentage => grandTotalRequired == 0
      ? 100.0
      : ((grandTotalAvailable / grandTotalRequired) * 100).clamp(0.0, 100.0);
}
