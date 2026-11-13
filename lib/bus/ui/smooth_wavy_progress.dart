import 'package:flutter/material.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

/// A wavy progress indicator that eases toward each new progress value instead
/// of jumping when a download reports progress in bursts.
class SmoothWavyProgressIndicator extends StatelessWidget {
  const SmoothWavyProgressIndicator({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 350),
    this.linearSize = M3EProgressIndicatorSize.m,
    this.strokeWidth = 4,
    this.trackStrokeWidth = 4,
  });

  /// Progress from 0 to 1, or null for an indeterminate indicator.
  final double? value;
  final Duration duration;
  final M3EProgressIndicatorSize linearSize;
  final double strokeWidth;
  final double trackStrokeWidth;

  @override
  Widget build(BuildContext context) {
    final double? progress = value;
    if (progress == null) {
      return M3EProgressIndicator.linearWavy(
        value: null,
        linearSize: linearSize,
        strokeWidth: strokeWidth,
        trackStrokeWidth: trackStrokeWidth,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0).toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double animated, Widget? child) {
        return M3EProgressIndicator.linearWavy(
          value: animated,
          linearSize: linearSize,
          strokeWidth: strokeWidth,
          trackStrokeWidth: trackStrokeWidth,
        );
      },
    );
  }
}
