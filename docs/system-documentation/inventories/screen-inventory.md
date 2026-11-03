# SCREEN INVENTORY – DANH MỤC MÀN HÌNH GIAO DIỆN

Tổng số màn hình khảo sát trong mã nguồn: **34 màn hình**.  
Toàn bộ giao diện tuân thủ phong cách **Clean Modern, White & Light Blue**.

---

## 1. 5 TAB ĐIỀU HƯỚNG CHÍNH (APP SHELL)

| STT | Tên màn hình | File Path | Tab Index | Dữ liệu & State Provider | Trạng thái |
| :---: | :--- | :--- | :---: | :--- | :---: |
| 1 | `HomeScreen` | `lib/features/home/presentation/screens/home_screen.dart` | 0 | `homeDashboardProvider`, `learningStreakProvider` | **IMPLEMENTED** |
| 2 | `LearningScreen` | `lib/features/learning/presentation/screens/learning_screen.dart` | 1 | `activeGoalProvider`, `curriculumLessonsProvider` | **IMPLEMENTED** |
| 3 | `AiTutorTabScreen` | `lib/features/ai_tutor/presentation/screens/ai_tutor_tab_screen.dart` | 2 (Center) | `aiTutorSessionsProvider`, `learnerContextProvider` | **IMPLEMENTED** |
| 4 | `ReviewScreen` | `lib/features/review/presentation/screens/review_screen.dart` | 3 | `dueFlashcardsProvider`, `srsStatsProvider` | **IMPLEMENTED** |
| 5 | `ProfileScreen` | `lib/features/profile/presentation/screens/profile_screen.dart` | 4 | `userProfileProvider`, `goalHistoryProvider` | **IMPLEMENTED** |

---

## 2. DANH MỤC CÁC MÀN HÌNH CHUYÊN SÂU THEO MODULE

### 2.1. Giáo trình & Học liệu
| Tên màn hình | File Path | Phương thức điều hướng | Tham số đầu vào | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| `CurriculumSyllabusScreen` | `lib/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart` | `Navigator.push` | `int hskLevel` | **IMPLEMENTED** |
| `LessonStudyScreen` | `lib/features/curriculum/presentation/screens/lesson_study_screen.dart` | `Navigator.push` | `String lessonId` | **IMPLEMENTED** |
| `LevelExitExamScreen` | `lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart` | `Navigator.push` | `String curriculumId` | **IMPLEMENTED** |
| `ContentPackManagerScreen`| `lib/features/content_packs/presentation/screens/content_pack_manager_screen.dart` | `Navigator.push` | Không | **IMPLEMENTED** |
| `AudioPackManagerScreen` | `lib/features/audio_management/presentation/screens/audio_pack_manager_screen.dart` | `Navigator.push` | Không | **IMPLEMENTED** |

### 2.2. Pinyin Foundation
| Tên màn hình | File Path | Phương thức điều hướng | Tham số đầu vào | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| `PinyinOverviewScreen` | `lib/features/pinyin_foundation/presentation/screens/pinyin_overview_screen.dart` | `Navigator.push` | Không | **IMPLEMENTED** |
| `PinyinLessonScreen` | `lib/features/pinyin_foundation/presentation/screens/pinyin_lesson_screen.dart` | `Navigator.push` | `PinyinUnit unit` | **IMPLEMENTED** |
| `PinyinPracticeScreen` | `lib/features/pinyin_foundation/presentation/screens/pinyin_practice_screen.dart` | `Navigator.push` | `List<PinyinExercise> exercises` | **IMPLEMENTED** |

### 2.3. Gia sư AI
| Tên màn hình | File Path | Phương thức điều hướng | Tham số đầu vào | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| `AiTutorTextChatScreen` | `lib/features/ai_tutor/presentation/screens/ai_tutor_text_chat_screen.dart` | `Navigator.push` | `TutorPersona persona`, `TutorScenario scenario` | **IMPLEMENTED** |
| `AiTutorVoiceChatScreen` | `lib/features/ai_tutor/presentation/screens/ai_tutor_voice_chat_screen.dart` | `Navigator.push` | `TutorPersona persona`, `TutorScenario scenario` | **IMPLEMENTED** |

### 2.4. Đánh giá Trình độ (Placement Test)
| Tên màn hình | File Path | Phương thức điều hướng | Tham số đầu vào | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| `PlacementTestIntroScreen` | `lib/features/placement_test/presentation/screens/placement_test_intro_screen.dart` | `Navigator.push` | Không | **IMPLEMENTED** |
| `PlacementTestFlowScreen` | `lib/features/placement_test/presentation/screens/placement_test_flow_screen.dart` | `Navigator.pushReplacement` | `String sessionId` | **IMPLEMENTED** |
| `PlacementTestResultScreen`| `lib/features/placement_test/presentation/screens/placement_test_result_screen.dart` | `Navigator.pushReplacement` | `CatAssessmentResult result` | **IMPLEMENTED** |

### 2.5. Phòng Lab Kỹ năng (Skill Labs)
| Tên màn hình | File Path | Phương thức điều hướng | Tham số đầu vào | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| `DictionaryScreen` | `lib/features/dictionary/presentation/screens/dictionary_screen.dart` | `Navigator.push` | `String? initialQuery` | **IMPLEMENTED** |
| `GrammarListScreen` | `lib/features/grammar/presentation/screens/grammar_list_screen.dart` | `Navigator.push` | `int? hskLevel` | **IMPLEMENTED** |
| `GrammarDetailScreen` | `lib/features/grammar/presentation/screens/grammar_detail_screen.dart` | `Navigator.push` | `String grammarCode` | **IMPLEMENTED** |
| `HanziWritingScreen` | `lib/features/hanzi_writing/presentation/screens/hanzi_writing_screen.dart` | `Navigator.push` | `String character` | **IMPLEMENTED** |
| `ListeningScreen` | `lib/features/listening/presentation/screens/listening_screen.dart` | `Navigator.push` | `int hskLevel` | **IMPLEMENTED** |
| `PronunciationLabScreen` | `lib/features/pronunciation/presentation/screens/pronunciation_lab_screen.dart` | `Navigator.push` | `String targetWord` | **IMPLEMENTED** |
| `ReadingPassageListScreen` | `lib/features/reading/presentation/screens/reading_passage_list_screen.dart` | `Navigator.push` | `int hskLevel` | **IMPLEMENTED** |
| `ReadingDetailScreen` | `lib/features/reading/presentation/screens/reading_detail_screen.dart` | `Navigator.push` | `String passageId` | **IMPLEMENTED** |
| `ShadowingScreen` | `lib/features/shadowing/presentation/screens/shadowing_screen.dart` | `Navigator.push` | `String sentenceId` | **IMPLEMENTED** |
| `PracticeSessionScreen` | `lib/features/practice/presentation/screens/practice_session_screen.dart` | `Navigator.push` | `String? topicTag`, `int? hskLevel` | **IMPLEMENTED** |

### 2.6. Cài đặt & Onboarding
| Tên màn hình | File Path | Phương thức điều hướng | Tham số đầu vào | Trạng thái |
| :--- | :--- | :--- | :--- | :---: |
| `RoadmapScreen` | `lib/features/roadmap/presentation/screens/roadmap_screen.dart` | `Navigator.push` | Không | **IMPLEMENTED** |
| `AiSettingsScreen` | `lib/features/settings/presentation/screens/ai_settings_screen.dart` | `Navigator.push` | Không | **IMPLEMENTED** |
| `OnboardingFlowScreen` | `lib/features/onboarding/presentation/screens/onboarding_flow_screen.dart` | Màn hình đầu tiên (nếu chưa xem) | Không | **IMPLEMENTED** |
| `OnboardingApiKeyScreen` | `lib/features/onboarding/presentation/screens/onboarding_api_key_screen.dart` | Trong Onboarding PageView | Không | **IMPLEMENTED** |
| `OnboardingPersonalizationScreen` | `lib/features/onboarding/presentation/screens/onboarding_personalization_screen.dart` | Trong Onboarding PageView | Không | **IMPLEMENTED** |
| `DesignSystemDemoScreen` | `lib/features/design_system/presentation/screens/design_system_demo_screen.dart` | Dành cho dev kiểm tra UI | Không | **IMPLEMENTED** |
