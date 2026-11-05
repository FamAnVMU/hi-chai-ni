// CONTRACT FILE – Thread 1 & Thread 4 Interface
//
// Mục đích: Định nghĩa tập hợp providers/types ĐƯỢC THỐNG NHẤT trước
// để Thread 1 (Core/DB) và Thread 4 (UI) có thể phát triển song song
// mà KHÔNG block nhau.
//
// ┌──────────────────────────────────────────────────────────────────┐
// │  Thread 1 chịu trách nhiệm: IMPLEMENT các provider bên dưới      │
// │  Thread 4 chịu trách nhiệm: CONSUME các provider bên dưới        │
// │  Thread 5 (CI): verify cả 2 phía sau khi merge                   │
// └──────────────────────────────────────────────────────────────────┘
//
// QUY TẮC:
// - Thread 1: thay thế stub bằng implementation thực tế trong file này
//   hoặc tạo file riêng và re-export ở đây.
// - Thread 4: chỉ import từ file này, KHÔNG import trực tiếp từ srs_providers.dart
//   cho các provider được định nghĩa trong contract này.
// - Khi Thread 1 hoàn thành implementation, Thread 4 không cần đổi import.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';

// ============================================================
// CONTRACT 1: hasCompletedLessonsProvider
// ============================================================
//
// ĐỊNH NGHĨA:
//   Trả về true nếu người dùng đã hoàn thành ít nhất 1 bài học thực sự.
//   Placement test KHÔNG được tính là bài học.
//
// Thread 4 dùng provider này để:
//   - Ẩn/hiện HomeSrsDueCard
//   - Guard "Ôn tập thẻ" tile trong Quick Actions
//   - Hiển thị empty state phù hợp trong ReviewScreen
//
// STUB (Thread 1 phải thay thế implementation này):
//   Hiện tại trả về false → Thread 4 build với assumption user chưa học gì.
//   Khi Thread 1 implement xong, behavior thực tế sẽ đúng.
//
/// Provider kiểm tra xem người dùng đã hoàn thành ít nhất 1 bài học hay chưa.
/// Placement test KHÔNG được tính là hoàn thành bài học.
///
/// Returns:
///   - [true]  → User đã học ít nhất 1 bài lesson (status = 'completed').
///   - [false] → User chưa học bài nào (user mới, hoặc chỉ làm placement test).
final hasCompletedLessonsProvider = FutureProvider<bool>((ref) async {
  // ── STUB IMPLEMENTATION ──────────────────────────────────────────────
  // TODO(Thread1): Thay thế stub này bằng query thực tế:
  //
  //   final db = AppDatabase.instance.database;
  //   final result = await db.rawQuery('''
  //     SELECT COUNT(*) as cnt FROM lesson_progress
  //     WHERE completion_score IS NOT NULL
  //     AND (source IS NULL OR source != 'placement_test')
  //   ''');
  //   final count = result.first['cnt'] as int? ?? 0;
  //   return count > 0;
  //
  // Trước khi implement, kiểm tra tên bảng và cột thực tế trong:
  //   lib/core/database/database_constants.dart
  // ─────────────────────────────────────────────────────────────────────
  if (!AppDatabase.instance.isOpen) return false;

  try {
    final db = AppDatabase.instance.database;
    // Stub: đếm lesson_progress có completion_score > 0 (không phải placement test)
    // Thread 1 phải xác nhận tên bảng, tên cột chính xác trước khi uncomment.
    // Tạm thời trả về false để Thread 4 build UI "chưa học gì" trước.
    final _ = db; // suppress unused warning
    return false; // ← Thread 1 thay dòng này
  } catch (_) {
    return false;
  }
});

// ============================================================
// CONTRACT 2: LearningPathType (re-export từ roadmap_models)
// ============================================================
//
// Thread 1 phải thêm enum LearningPathType vào:
//   lib/features/roadmap/domain/models/roadmap_models.dart
//
// Sau khi Thread 1 thêm vào, bỏ comment 2 dòng export bên dưới:
//
// export 'package:hi_chinese/features/roadmap/domain/models/roadmap_models.dart'
//     show LearningPathType, LearningPathTypeExtension;
//
// Thread 4 dùng LearningPathType để:
//   - Hiển thị option 'balanced' trong onboarding wizard
//   - Label lộ trình trong Profile
//
// STUB INLINE (tạm dùng đến khi Thread 1 export):

/// Kiểu lộ trình học tập.
/// [Thread 1]: Khi thêm vào roadmap_models.dart, xóa enum tạm này
/// và bỏ comment export bên trên.
enum LearningPathType {
  /// Tập trung vào 1 kỹ năng trọng điểm (default)
  focused,

  /// Học đều cân bằng tất cả 6 kỹ năng
  comprehensive,
}

extension LearningPathTypeExtension on LearningPathType {
  String get displayName {
    switch (this) {
      case LearningPathType.focused:
        return 'Trọng tâm 1 kỹ năng';
      case LearningPathType.comprehensive:
        return 'Toàn diện – Học đều 6 kỹ năng';
    }
  }

  String get description {
    switch (this) {
      case LearningPathType.focused:
        return 'Tập trung 40% thời gian vào kỹ năng ưu tiên.';
      case LearningPathType.comprehensive:
        return 'Phân bổ đều 6 kỹ năng: Từ vựng, Ngữ pháp, Đọc, Nghe, Nói, Viết.';
    }
  }

  /// Giá trị lưu vào DB / app_settings
  String get dbValue => name; // 'focused' | 'comprehensive'

  static LearningPathType fromDb(String? value) {
    return LearningPathType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LearningPathType.focused,
    );
  }
}

// ============================================================
// CONTRACT 3: HomeDashboardData phải có field hasCompletedLessons
// ============================================================
//
// Thread 1 phải thêm field vào:
//   lib/features/home/domain/models/home_dashboard_data.dart
//
//   class HomeDashboardData {
//     ...
//     final bool hasCompletedLessons;  // ← THÊM MỚI
//     ...
//     const HomeDashboardData({
//       ...
//       this.hasCompletedLessons = false,  // ← default false (safe)
//     });
//   }
//
// Thread 4 dùng data.hasCompletedLessons để render có điều kiện.
//
// Trước khi Thread 1 thêm field, Thread 4 phải dùng:
//   ref.watch(hasCompletedLessonsProvider).value ?? false
// thay vì data.hasCompletedLessons.
// Sau khi Thread 1 thêm, Thread 4 đổi sang data.hasCompletedLessons.
