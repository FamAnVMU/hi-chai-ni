/// Six discrete cognitive mastery states defined by rigorous learning science.
enum MasteryState {
  /// Learner has never encountered or seen this item in any syllabus or activity.
  unseen('unseen', labelVi: 'Chưa học'),

  /// Seen in context (e.g. read in a dialogue, passage, or warmup), but not yet taught.
  exposed('exposed', labelVi: 'Đã tiếp xúc'),

  /// Direct instruction received (e.g. studied vocabulary/grammar card), early acquisition.
  learning('learning', labelVi: 'Đang học'),

  /// Failed in recent practice, test, or SRS (inconsistent or unstable memory trace).
  unstable('unstable', labelVi: 'Chưa ổn định'),

  /// Demonstrated repeated correct application in exercises and practice (short-term grasp).
  familiar('familiar', labelVi: 'Quen thuộc'),

  /// Proven long-term retention over spaced intervals in SRS (long-term memory solidified).
  mastered('mastered', labelVi: 'Thành thạo');

  final String value;
  final String labelVi;
  const MasteryState(this.value, {required this.labelVi});

  static MasteryState fromString(String val) {
    for (final state in MasteryState.values) {
      if (state.value == val.toLowerCase()) return state;
    }
    // Backward compatibility mappings
    if (val == 'not_started') return MasteryState.unseen;
    if (val == 'completed') return MasteryState.familiar;
    if (val == 'in_progress') return MasteryState.learning;
    return MasteryState.unseen;
  }
}
