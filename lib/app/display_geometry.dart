import 'package:flutter/services.dart';

class DisplayGeometry {
  static const MethodChannel _channel = MethodChannel(
    'com.spookysrv.hktransports/display',
  );

  static double physicalCornerRadius = 0;

  static Future<void> load() async {
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        final num? value = await _channel.invokeMethod<num>('getCornerRadius');
        final double radius = value?.toDouble() ?? 0;
        if (radius > 0) {
          physicalCornerRadius = radius;
          return;
        }
      } catch (_) {
        physicalCornerRadius = 0;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    physicalCornerRadius = 0;
  }
}
