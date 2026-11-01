import 'package:flutter/material.dart';
import '../../../../core/theme/tokens/app_colors.dart';
import '../../../../core/theme/tokens/app_radius.dart';

/// Realtime animated audio waveform visualizer responding to mic amplitude levels.
class WaveformVisualizer extends StatelessWidget {
  final double amplitude; // 0.0 to 1.0
  final bool isRecording;
  final Duration duration;

  const WaveformVisualizer({
    super.key,
    required this.amplitude,
    required this.isRecording,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final seconds = (duration.inMilliseconds / 1000).toStringAsFixed(1);

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkForestSurface : theme.colorScheme.surfaceContainerHighest.withAlpha(90),
        borderRadius: AppRadius.borderMd,
        border: Border.all(
          color: isRecording ? AppColors.limeGreen.withAlpha(120) : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Waveform bars
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(24, (index) {
                // Generate varied heights based on current amplitude
                final offsetMultiplier = (1.0 + (index % 4) * 0.25);
                final barHeight = isRecording
                    ? (12.0 + (amplitude * 44.0 * offsetMultiplier)).clamp(8.0, 56.0)
                    : 6.0;

                final isCenter = index >= 8 && index <= 16;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: 3.5,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: isRecording
                        ? (isCenter ? AppColors.limeGreen : AppColors.limeGreen.withAlpha(160))
                        : theme.colorScheme.outlineVariant,
                    borderRadius: AppRadius.borderFull,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          // Duration indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRecording ? Colors.redAccent : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRecording ? 'Đang thu âm...' : 'Sẵn sàng thu âm',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
              Text(
                '${seconds}s',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
