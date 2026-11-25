import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../settings/presentation/screens/ai_settings_screen.dart';
import '../../../app_shell/presentation/providers/app_shell_providers.dart';
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

  /// Shared modal sheet for picking the active AI Tutor Persona.
  static Future<void> showPersonaSelectorSheet(BuildContext context, WidgetRef ref) {
    final activePersona = ref.read(activePersonaProvider);
    final voiceService = ref.read(voiceConversationServiceProvider);
    final theme = Theme.of(context);

    return showModalBottomSheet(
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
                        Expanded(
                          child: Text(
                            'Chọn Gia sư AI (Persona)',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
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
                          backgroundColor: isSelected ? bottomSheetCtx.hiAccentBg : bottomSheetCtx.hiInputSurface,
                          foregroundColor: isSelected ? bottomSheetCtx.hiAccentColor : bottomSheetCtx.hiSecondaryText,
                          child: Text(p.avatarLabel),
                        ),
                        title: Text(
                          '${p.nameZh} (${p.nameVi})',
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: bottomSheetCtx.hiPrimaryText,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.roleDescriptionVi,
                              style: TextStyle(fontSize: 11, color: bottomSheetCtx.hiSecondaryText),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (p.canPreview)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '• Hỗ trợ nghe thử mẫu giọng (TTS)',
                                  style: TextStyle(fontSize: 10, color: bottomSheetCtx.hiAccentColor),
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
                                        color: isPreviewing ? bottomSheetCtx.hiAccentColor : bottomSheetCtx.hiSecondaryText,
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
                              Icon(Icons.check_circle_rounded, color: bottomSheetCtx.hiAccentColor),
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

  @override
  ConsumerState<AiTutorTabScreen> createState() => _AiTutorTabScreenState();
}

class _AiTutorTabScreenState extends ConsumerState<AiTutorTabScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void deactivate() {
    _abortActiveVoiceAndAudio();
    super.deactivate();
  }

  @override
  void dispose() {
    _abortActiveVoiceAndAudio();
    super.dispose();
  }

  void _abortActiveVoiceAndAudio() {
    try {
      final voiceService = ref.read(voiceConversationServiceProvider);
      voiceService.stopListening();
      voiceService.cancelCurrentTurn();
    } catch (_) {}
  }

  void _showPersonaSelector() {
    AiTutorTabScreen.showPersonaSelectorSheet(context, ref);
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
                    itemBuilder: (itemCtx, index) {
                      final sc = TutorScenarios.all[index];
                      final isSelected = sc.code == activeScenario.code;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? itemCtx.hiAccentBg : itemCtx.hiInputSurface,
                          foregroundColor: isSelected ? itemCtx.hiAccentColor : itemCtx.hiSecondaryText,
                          child: Text('${index + 1}'),
                        ),
                        title: Text(
                          sc.titleVi,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: itemCtx.hiPrimaryText,
                          ),
                        ),
                        subtitle: Text(
                          sc.objectiveVi,
                          style: TextStyle(fontSize: 11, color: itemCtx.hiSecondaryText),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: itemCtx.hiAccentColor)
                            : null,
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

    // Stop microphone, TTS, and cancel streaming if user switches away to another tab
    ref.listen<AppTab>(selectedTabProvider, (prev, next) {
      if (prev == AppTab.aiTutor && next != AppTab.aiTutor) {
        _abortActiveVoiceAndAudio();
      }
    });

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.sm,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: SegmentedButton<AiTutorMode>(
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
            final nextMode = newSelection.first;
            if (nextMode == AiTutorMode.text) {
              _abortActiveVoiceAndAudio();
            }
            ref.read(aiTutorModeProvider.notifier).setMode(nextMode);
          },
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            textStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ),
        centerTitle: false,
        actions: [
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
        children: [
          AiTutorTextChatScreen(
            embeddedInTab: true,
            onSelectPersona: _showPersonaSelector,
          ),
          AiTutorVoiceChatScreen(
            embeddedInTab: true,
            onSelectPersona: _showPersonaSelector,
          ),
        ],
      ),
    );
  }
}
