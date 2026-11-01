import '../models/cat_skill.dart';

/// Test specification blueprint defining rules, constraints, and stopping criteria
/// for the HI Chinese Computerized Adaptive Placement Test.
class CatBlueprint {
  final String version;

  /// Minimum total items required across the entire assessment.
  final int minTotalItems;

  /// Maximum total items allowed (fatigue control on mobile).
  final int maxTotalItems;

  /// Minimum items per assessed skill.
  final int minItemsPerSkill;

  /// Maximum items per skill.
  final int maxItemsPerSkill;

  /// Target standard error of measurement for early skill termination.
  final double targetStandardError;

  /// Maximum consecutive incorrect answers at lowest difficulty before early exit.
  final int maxConsecutiveLowestFailures;

  /// Sequence in which skills are evaluated.
  final List<CatSkill> skillSequence;

  const CatBlueprint({
    this.version = 'v1.0',
    this.minTotalItems = 12,
    this.maxTotalItems = 30,
    this.minItemsPerSkill = 2,
    this.maxItemsPerSkill = 5,
    this.targetStandardError = 0.35,
    this.maxConsecutiveLowestFailures = 3,
    this.skillSequence = const [
      CatSkill.vocabulary,
      CatSkill.grammar,
      CatSkill.reading,
      CatSkill.listening,
      CatSkill.writing,
      CatSkill.speaking,
    ],
  });
}
