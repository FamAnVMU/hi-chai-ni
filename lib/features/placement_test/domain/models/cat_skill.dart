/// The 6 core Chinese language competency skills assessed in the CAT Placement Test.
enum CatSkill {
  vocabulary,
  grammar,
  reading,
  listening,
  writing,
  speaking;

  String get labelVi {
    switch (this) {
      case CatSkill.vocabulary:
        return 'Từ vựng';
      case CatSkill.grammar:
        return 'Ngữ pháp';
      case CatSkill.reading:
        return 'Đọc hiểu';
      case CatSkill.listening:
        return 'Nghe hiểu';
      case CatSkill.writing:
        return 'Kỹ năng Viết';
      case CatSkill.speaking:
        return 'Phát âm & Nói';
    }
  }

  String get descriptionVi {
    switch (this) {
      case CatSkill.vocabulary:
        return 'Đo lường dung lượng vốn từ, khả năng nhận diện nghĩa và kết hợp từ theo cấp độ.';
      case CatSkill.grammar:
        return 'Đánh giá cấu trúc câu, trật tự từ, liên từ và các mẫu câu trọng điểm.';
      case CatSkill.reading:
        return 'Khả năng đọc hiểu ngữ cảnh, suy luận ý chính và xử lý thông tin đoạn văn ngắn.';
      case CatSkill.listening:
        return 'Nhận diện thanh điệu, từ vựng và phản xạ thông tin qua âm thanh hội thoại.';
      case CatSkill.writing:
        return 'Đánh giá phân tách: nhận diện chữ Hán, phiên âm Pinyin và thứ tự nét viết.';
      case CatSkill.speaking:
        return 'Khảo sát khả năng phát âm, thanh mẫu, vận mẫu và độ tự nhiên khi nói.';
    }
  }
}

/// Distinct sub-types for the Writing skill to strictly prevent mixing scores
/// between character recognition, pinyin input, and stroke order writing.
enum WritingSubType {
  characterRecognition,
  pinyinTranscription,
  strokeOrderWriting;

  String get labelVi {
    switch (this) {
      case WritingSubType.characterRecognition:
        return 'Nhận diện chữ Hán';
      case WritingSubType.pinyinTranscription:
        return 'Phiên âm Pinyin';
      case WritingSubType.strokeOrderWriting:
        return 'Quy tắc & Thứ tự nét';
    }
  }
}

/// Evaluation mode for Speaking skill to prevent false tone scoring without audio acoustic analysis.
enum SpeakingEvaluationMode {
  /// Evaluated with acoustic audio pitch / duration analysis
  acousticAudioAnalyzed,

  /// Skipped by user or microphone unavailable — MUST NOT be scored as zero (0)
  unassessedMissingAudio,

  /// Learner explicitly opted out of the speaking section
  skippedByUser;

  String get labelVi {
    switch (this) {
      case SpeakingEvaluationMode.acousticAudioAnalyzed:
        return 'Đã phân tích âm học';
      case SpeakingEvaluationMode.unassessedMissingAudio:
        return 'Chưa đủ dữ liệu đánh giá phát âm';
      case SpeakingEvaluationMode.skippedByUser:
        return 'Đã bỏ qua phần nói';
    }
  }
}
