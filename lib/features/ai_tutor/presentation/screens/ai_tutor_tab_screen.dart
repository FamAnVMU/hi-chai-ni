import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/tokens/app_colors.dart';
import '../../../../core/theme/tokens/app_spacing.dart';
import '../../../settings/presentation/screens/ai_settings_screen.dart';
import '../../domain/models/tutor_persona.dart';
import '../../domain/models/tutor_scenario.dart';
import '../providers/ai_tutor_providers.dart';
import 'ai_tutor_text_chat_screen.dart';
import 'ai_tutor_voice_chat_screen.dart';

/// Tab 2: AI Tutor Hub Screen.
/// Seamlessly unifies Text Chat and Voice Conversation while sharing
/// AI Tutor Engine, Context Builder, and SQLite session memory.
class AiTutorTabScreen extends ConsumerStatefulWidget {
  const AiTutorTabScreen({super.key});

  @override
  ConsumerState<AiTutorTabScreen> createState() => _AiTutorTabScreenState();
}

class _AiTutorTabScreenState extends ConsumerState<AiTutorTabScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  void _showPersonaSelector() {
    final activePersona = ref.read(activePersonaProvider);
    final voiceService = ref.read(voiceConversationServiceProvider);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (bottomSheetCtx, setSheetState) {
            final previewStatus = voiceService.previewStatus;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Chọn Gia sư AI (Persona)',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (previewStatus.isPlaying)
                          TextButton.icon(
                            icon: const Icon(Icons.stop_circle_outlined, size: 18),
                            label: const Text('Dừng thử giọng', style: TextStyle(fontSize: 12)),
                            onPressed: () async {
                              await voiceService.stopPersonaVoicePreview();
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...TutorPersonas.all.map((p) {
                      final isSelected = p.id == activePersona.id;
                      final isPreviewing = previewStatus.isPlaying && previewStatus.personaId == p.id.name;
                      final isLoading = previewStatus.isLoading && previewStatus.personaId == p.id.name;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? AppColors.primaryBlueLight : AppColors.inputBackground,
                          foregroundColor: isSelected ? AppColors.primaryBlueDark : AppColors.secondaryText,
                          child: Text(p.avatarLabel),
                        ),
                        title: Text(
                          '${p.nameZh} (${p.nameVi})',
                          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppColors.primaryText),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.roleDescriptionVi,
                              style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (p.canPreview)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  '• Hỗ trợ nghe thử mẫu giọng (TTS)',
                                  style: TextStyle(fontSize: 10, color: AppColors.primaryBlueDark),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p.canPreview)
                              IconButton(
                                icon: isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Icon(
                                        isPreviewing ? Icons.stop_rounded : Icons.volume_up_outlined,
                                        color: isPreviewing ? AppColors.primaryBlueDark : AppColors.secondaryText,
                                      ),
                                tooltip: isPreviewing ? 'Dừng phát' : 'Nghe thử giọng mẫu',
                                onPressed: () async {
                                  if (isPreviewing) {
                                    await voiceService.stopPersonaVoicePreview();
                                  } else {
                                    await voiceService.previewPersonaVoice(p);
                                    if (bottomSheetCtx.mounted && voiceService.previewStatus.isUnsupported) {
                                      ScaffoldMessenger.of(bottomSheetCtx).showSnackBar(
                                        SnackBar(
                                          content: Text(voiceService.previewStatus.message ?? 'Không thể nghe thử.'),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  }
                                  setSheetState(() {});
                                },
                              ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlueDark),
                          ],
                        ),
                        onTap: () async {
                          await voiceService.stopPersonaVoicePreview();
                          ref.read(activePersonaProvider.notifier).selectPersona(p);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                          }
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      voiceService.stopPersonaVoicePreview();
    });
  }

  void _showScenarioSelector() {
    final activeScenario = ref.read(activeScenarioProvider);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chọn Kịch bản luyện tập (Scenario)',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: ListView.builder(
                    itemCount: TutorScenarios.all.length,
                    itemBuilder: (context, index) {
                      final sc = TutorScenarios.all[index];
                      final isSelected = sc.code == activeScenario.code;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? AppColors.primaryBlueLight : AppColors.inputBackground,
                          foregroundColor: isSelected ? AppColors.primaryBlueDark : AppColors.secondaryText,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          sc.titleVi,
                          style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppColors.primaryText),
                        ),
                        subtitle: Text(
                          sc.objectiveVi,
                          style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                        ),
                        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryBlueDark) : null,
                        onTap: () {
                          ref.read(activeScenarioProvider.notifier).selectScenario(sc);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final mode = ref.watch(aiTutorModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: SegmentedButton<AiTutorMode>(
          segments: const [
            ButtonSegment<AiTutorMode>(
              value: AiTutorMode.text,
              label: Text('Nhắn tin'),
              icon: Icon(Icons.chat_bubble_outline_rounded, size: 16),
            ),
            ButtonSegment<AiTutorMode>(
              value: AiTutorMode.voice,
              label: Text('Hội thoại'),
              icon: Icon(Icons.record_voice_over_rounded, size: 16),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (Set<AiTutorMode> newSelection) {
            ref.read(aiTutorModeProvider.notifier).setMode(newSelection.first);
          },
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.face_retouching_natural_rounded),
            tooltip: 'Chọn Gia sư',
            onPressed: _showPersonaSelector,
          ),
          IconButton(
            icon: const Icon(Icons.topic_outlined),
            tooltip: 'Chọn Kịch bản',
            onPressed: _showScenarioSelector,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Cài đặt AI',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: mode == AiTutorMode.text ? 0 : 1,
        children: const [
          AiTutorTextChatScreen(),
          AiTutorVoiceChatScreen(),
        ],
      ),
    );
  }
}
