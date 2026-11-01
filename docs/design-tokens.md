# HI Chinese — Material 3 Design Tokens & Design System Specification

Tài liệu đặc tả toàn diện về Design Tokens, Quy chuẩn Trực quan và Thành phần UI Tái sử dụng (Reusable Components) cho ứng dụng **HI Chinese**, xây dựng trên nền tảng **Flutter Material 3**.

---

## 1. Nguyên Tắc Thiết Kế Cốt Lõi (Core Principles)

1. **Semantic Color Hierarchy (Hệ thống màu ngữ nghĩa)**:
   - Tuyệt đối không dùng màu Lime Green (`#A3D635`) làm nền cho toàn bộ màn hình hoặc khối lớn.
   - Màu Lime chỉ đóng vai trò **Primary Accent** trong Dark Theme và điểm nhấn tương tác quan trọng.
   - Nền Dark Theme tuân theo bảng màu **Dark Forest**: `#121811` (Scaffold background), `#1A2418` (Surface), `#243022` (Card surface).
   - Nền Light Theme tuân theo màu **Off-white**: `#F6FAF2` với thẻ màu trắng `#FFFFFF` và viền phân cách mờ.

2. **Offline-First Typography (Phông chữ độc lập không phụ thuộc mạng)**:
   - Tuyệt đối không tích hợp các thư viện tải font runtime như `google_fonts` (tránh phụ thuộc kết nối internet và giật lag khi mở app).
   - Sử dụng phông hệ thống bản địa tối ưu cho tiếng Trung và tiếng Việt:
     `['Noto Sans SC', 'PingFang SC', 'Heiti SC', 'Roboto', 'sans-serif']`.
   - Android tự động phân phối glyph Noto Sans SC cho chữ Hán Giản thể / Phồn thể và Roboto / Latin cho tiếng Việt có dấu thanh đầy đủ (`ệ`, `ẩ`, `ỹ`, `ớ`, `ừ`...).

3. **Accessibility & WCAG 2.2 Level AA**:
   - **Tương phản (Contrast Ratio)**: Mọi cặp màu chữ / nền chính đều vượt ngưỡng WCAG AA (tối thiểu 4.5:1 với body text và 3.0:1 với text lớn/bold). Nút Lime Green với chữ Dark Forest đạt độ tương phản vượt trội **> 10.8:1**.
   - **Touch Target (Vùng chạm cảm ứng)**: Mọi thành phần tương tác (nút, chip, icon button, text field) luôn đảm bảo kích thước tối thiểu **≥ 48x48 dp** theo chuẩn Android Accessibility.
   - **Text Scaling**: Không khóa cứng `textScaler`. Giao diện linh hoạt thích ứng khi người dùng phóng to font chữ trên cài đặt hệ điều hành (Accessibility Font Scale 1.5x - 2.0x).

4. **Smooth Riverpod Theme Switching**:
   - Quản lý trạng thái giao diện qua `themeModeProvider` (`Notifier<ThemeMode>`), cho phép chuyển đổi tức thì giữa **Dark Mode**, **Light Mode** và **System Default** mà không gây rebuild toàn bộ state không liên quan.

---

## 2. Bảng Màu (Color Tokens)

Class quản lý: [`AppColors`](file:///lib/core/theme/tokens/app_colors.dart)

### 2.1. Brand Palette Cơ Sở
| Token Name | Hex Code | Giá Trị RGB | Ứng Dụng |
| :--- | :--- | :--- | :--- |
| `limeGreen` | `#A3D635` | `Color(0xFFA3D635)` | Primary Action Accent, Hero Buttons, Active State |
| `limeGreenLight` | `#DCF59C` | `Color(0xFFDCF59C)` | Primary Container Light, Highlight Badges |
| `limeGreenDark` | `#5C8009` | `Color(0xFF5C8009)` | Dark Accent, High-contrast Outlines |
| `offWhite` | `#F6FAF2` | `Color(0xFFF6FAF2)` | Scaffold Background trong Light Theme |
| `darkForestBg` | `#121811` | `Color(0xFF121811)` | Scaffold Background trong Dark Theme |
| `darkForestSurface` | `#1A2418` | `Color(0xFF1A2418)` | Surface/AppBar/BottomSheet trong Dark Theme |
| `darkForestCard` | `#243022` | `Color(0xFF243022)` | Thẻ nội dung, Floating Containers trong Dark Theme |
| `darkForestBorder` | `#2E3D2B` | `Color(0xFF2E3D2B)` | Đường viền mảnh (1dp) bao quanh Card / Input |

### 2.2. Functional & Semantic Status Colors
| Trạng Thái | Light Container | Light Text/Icon | Dark Container | Dark Text/Icon | Mục Đích |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Success** | `#D7F5D9` | `#2E7D32` | `#1B381A` | `#81C784` | Trả lời đúng, thuộc từ vựng, kết nối AI thành công |
| **Warning** | `#FFE1B8` | `#B26A00` | `#3B2E15` | `#FFB74D` | Từ vựng sắp đến hạn ôn (SRS Due), cảnh báo quota |
| **Error** | `#FFDAD6` | `#BA1A1A` | `#3B1A1A` | `#FFB4AB` | Lỗi API, sai ngữ pháp tiếng Trung, mất kết nối |
| **Info** | `#BCEBEF` | `#386568` | `#1F4D50` | `#A0CFD2` | Ghi chú văn hóa, hướng dẫn học tập, mẹo phát âm |

---

## 3. Khoảng Cách (Spacing Tokens)

Class quản lý: [`AppSpacing`](file:///lib/core/theme/tokens/app_spacing.dart)

Hệ thống lưới chuẩn 4pt / 8pt:

| Token | Kích Thước | Ví Dụ Sử Dụng |
| :--- | :--- | :--- |
| `none` | 0.0 dp | Không lề |
| `xxs` | 2.0 dp | Micro gap giữa chữ Hán và Pinyin, viền huy hiệu |
| `xs` | 4.0 dp | Khoảng cách giữa icon và nhãn trong nút nhỏ, tag margin |
| `sm` | 8.0 dp | Khoảng cách giữa các chip, padding nội bộ chip |
| `md` | 12.0 dp | Khoảng cách giữa các dòng trong form, margin tiêu đề phụ |
| `lg` | 16.0 dp | Standard screen padding, lề trong của Card mặc định |
| `xl` | 20.0 dp | Khoảng cách giữa các nhóm bài học hoặc paragraph |
| `xxl` | 24.0 dp | Khoảng cách giữa các Section chính, padding Dialog |
| `xxxl` | 32.0 dp | Khoảng cách giữa Header lớn và nội dung |
| `huge` | 48.0 dp | Khoảng cách chân trang, vùng đệm cuộn an toàn |

---

## 4. Bán Kính Bo Góc (Corner Radius Tokens)

Class quản lý: [`AppRadius`](file:///lib/core/theme/tokens/app_radius.dart)

| Token | Bán Kính | Widget Áp Dụng |
| :--- | :--- | :--- |
| `xs` | 4.0 dp | Badge nhỏ, thanh chỉ số SRS |
| `sm` | 8.0 dp | `HiChip`, nút kích thước nhỏ (`HiButtonSize.sm`) |
| `md` | 12.0 dp | `HiButton`, `HiTextField`, Container phụ |
| `lg` | 16.0 dp | `HiCard`, Khung bài tập trắc nghiệm |
| `xl` | 24.0 dp | `HiDialog`, Top radius của `HiBottomSheet` |
| `full`| 999.0 dp | Pill-shaped badges, Avatar, thanh kéo Bottom Sheet Handle |

---

## 5. Độ Nổi & Đổ Bóng (Elevation & Shadows)

Class quản lý: [`AppElevation`](file:///lib/core/theme/tokens/app_elevation.dart)

- `level0` (0 dp): Thành phần phẳng, thẻ phẳng, nút ghost.
- `level1` (1 dp): Thẻ nghỉ, Chip nổi.
- `level2` (3 dp): Nút bấm ở trạng thái hover/pressed.
- `level3` (6 dp): FAB, Dropdown Menu.
- `level4` (8 dp): Bottom Navigation Bar, Bottom Sheets.
- `level5` (12 dp): Modal Dialogs, Cửa sổ cảnh báo nổi bật.

---

## 6. Kích Thước Thành Phần (Component Dimensions & Touch Targets)

Class quản lý: [`AppDimensions`](file:///lib/core/theme/tokens/app_dimensions.dart)

- **`minTouchTarget` = 48.0 dp**: Mọi widget tương tác đều có diện tích tối thiểu 48x48 dp.
- **Button Heights**:
  - `sm`: 36.0 dp (được bọc constraint 48dp ngoài vùng bấm).
  - `md`: 44.0 dp (chuẩn cho hầu hết màn hình).
  - `lg`: 52.0 dp (nút hành động chính toàn màn hình).
- **Input Min Height**: 48.0 dp.
- **Icon Sizes**: `xs: 14`, `sm: 18`, `md: 24`, `lg: 32`, `xl: 48`, `huge: 64`.

---

## 7. Phông Chữ & Hệ Thống Đa Ngữ (Typography Tokens)

Class quản lý: [`AppTypography`](file:///lib/core/theme/tokens/app_typography.dart)

### 7.1. Kiểu Chữ Học Tiếng Trung Chuyên Biệt
```dart
// 1. Chữ Hán lớn (Flashcard, luyện viết bút thuận, tập đọc)
AppTypography.hanziLarge(color: AppColors.limeGreen) // 40sp, weight: 600

// 2. Chữ Hán vừa (Câu hội thoại, từ vựng trong danh sách)
AppTypography.hanziMedium() // 24sp, weight: 500

// 3. Chữ Hán nhỏ (Văn bản dài, bài đọc hiểu)
AppTypography.hanziSmall() // 18sp, weight: 400

// 4. Pinyin kèm thanh điệu chuẩn
AppTypography.pinyin() // 14sp, letterSpacing: 0.5
AppTypography.pinyinLarge() // 18sp, letterSpacing: 0.75

// 5. Nghĩa tiếng Việt đầy đủ dấu thanh
AppTypography.vietnameseMeaning() // 15sp, height: 1.45
```

---

## 8. Danh Mục Thành Phần Tái Sử Dụng (Reusable Components)

Tất cả thành phần đều nằm tại `lib/core/theme/components/` và được export qua `lib/core/theme/theme.dart`:

| Thành phần | File | Mô tả & Cách Dùng |
| :--- | :--- | :--- |
| **`HiButton`** | `hi_button.dart` | Nút chuẩn với 4 biến thể (`primary`, `secondary`, `ghost`, `danger`), tích hợp loading spinner, tự động co giãn và đảm bảo touch target ≥ 48dp. |
| **`HiTextField`** | `hi_text_field.dart` | Ô nhập văn bản hỗ trợ label, placeholder, helperText, errorText, toggle ẩn/hiện mật khẩu, không làm cắt dấu tiếng Việt và pinyin. |
| **`HiCard`** | `hi_card.dart` | Thẻ bề mặt chuẩn Material 3, màu nền tự động theo theme, viền 1dp tinh tế, hỗ trợ sự kiện `onTap` với hiệu ứng sóng nước (Ink ripple). |
| **`HiChip`** | `hi_chip.dart` | Huy hiệu / thẻ lọc với các biến thể trạng thái (`neutral`, `success`, `warning`, `error`, `info`), hỗ trợ lựa chọn và xóa (`onDeleted`). |
| **`HiDialog`** | `hi_dialog.dart` | Hộp thoại thông báo và xác nhận, tích hợp sẵn phương thức gọi tiện dụng `HiDialog.show(...)`. |
| **`HiBottomSheet`**| `hi_bottom_sheet.dart`| Bảng trượt modal đáy màn hình với tay cầm kéo (drag handle) và phương thức `HiBottomSheet.show(...)`. |
| **`HiSnackBar`** | `hi_snackbar.dart` | Thanh thông báo nổi hỗ trợ 4 trạng thái ngữ nghĩa: `showSuccess`, `showError`, `showWarning`, `showInfo`. |
| **`HiLoadingIndicator`**| `hi_loading_indicator.dart`| Vòng quay tiến trình màu Lime kèm thông điệp hướng dẫn; thanh tiến trình `HiLinearProgress`. |
| **`HiEmptyState`** | `hi_empty_state.dart` | Khung hiển thị khi danh sách trống kèm hình minh họa và nút hành động. |
| **`HiErrorState`** | `hi_error_state.dart` | Khung thông báo lỗi kết nối / hệ thống kèm nút thử lại (`onRetry`). |

---

## 9. Màn Hình Trải Nghiệm Mẫu (Showcase Screen)

Màn hình [`DesignSystemDemoScreen`](file:///lib/features/design_system/presentation/screens/design_system_demo_screen.dart) minh họa trực tiếp:
- Chuyển đổi theme Light / Dark / System tức thì.
- Toàn bộ bảng màu mẫu.
- Hiển thị mẫu chữ Hán (`学`), Pinyin (`xué`) và tiếng Việt.
- Thử nghiệm các nút bấm ở mọi trạng thái (Loading, Disabled, Full width).
- Nhập liệu và kiểm tra validation form.
- Thử nghiệm mở `HiDialog`, `HiBottomSheet` và các loại `HiSnackBar`.

> [!IMPORTANT]
> **Quy định lập trình bắt buộc cho các giai đoạn tiếp theo**:
> Mọi màn hình bài học, giao diện chat AI, ôn tập SRS và cài đặt **phải dùng token từ `lib/core/theme/theme.dart`**.
> Không tự ý `Color(0x...)` ngẫu nhiên hoặc gán `height` nút bấm dưới `48.0` nếu không bọc touch target!
