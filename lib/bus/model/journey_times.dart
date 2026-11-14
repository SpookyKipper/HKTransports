/// Time-of-day profiles for precomputed stop-to-stop journey times.
///
/// Route data may include:
///
/// ```json
/// "journeyTimes": {
///   "weekdayPeak": [120, 95, ...],
///   "weekdayOffPeak": [105, 85, ...],
///   "weekend": [110, 90, ...]
/// }
/// ```
///
/// Values are travel time in seconds for each adjacent pair in the route's
/// primary stop list. They are raw observations; the UI applies the same 10%
/// margin used by HK Bus ETA for acceleration, braking and passenger stops.
enum JourneyTimeProfile { weekdayPeak, weekdayOffPeak, weekend }

extension JourneyTimeProfileInfo on JourneyTimeProfile {
  static const Map<JourneyTimeProfile, String> _keys =
      <JourneyTimeProfile, String>{
        JourneyTimeProfile.weekdayPeak: 'weekdayPeak',
        JourneyTimeProfile.weekdayOffPeak: 'weekdayOffPeak',
        JourneyTimeProfile.weekend: 'weekend',
      };

  String get key => _keys[this]!;
}

class RouteJourneyTimes {
  const RouteJourneyTimes(this.profiles);

  final Map<JourneyTimeProfile, List<int>> profiles;

  factory RouteJourneyTimes.fromJson(Map<String, dynamic> json) {
    final Map<JourneyTimeProfile, List<int>> profiles = {};
    for (final JourneyTimeProfile profile in JourneyTimeProfile.values) {
      final List<int>? seconds = _parseSeconds(json[profile.key]);
      if (seconds != null) profiles[profile] = seconds;
    }
    return RouteJourneyTimes(
      Map<JourneyTimeProfile, List<int>>.unmodifiable(profiles),
    );
  }

  /// Returns the segment times for the current Hong Kong time, or null when the
  /// route data has no matching profile.
  List<int>? segmentSecondsFor(DateTime hkNow, {required bool holiday}) {
    final JourneyTimeProfile profile = profileFor(hkNow, holiday: holiday);
    return profiles[profile];
  }

  static JourneyTimeProfile profileFor(
    DateTime hkNow, {
    required bool holiday,
  }) {
    final int weekday = hkNow.weekday;
    if (holiday || weekday == DateTime.saturday || weekday == DateTime.sunday) {
      return JourneyTimeProfile.weekend;
    }
    final int hour = hkNow.hour;
    final bool peak = (hour >= 7 && hour < 10) || (hour >= 17 && hour < 20);
    return peak
        ? JourneyTimeProfile.weekdayPeak
        : JourneyTimeProfile.weekdayOffPeak;
  }

  static List<int>? _parseSeconds(Object? value) {
    if (value is! List || value.isEmpty) return null;
    final List<int> result = [];
    for (final Object? entry in value) {
      final int? seconds = entry is num
          ? entry.toInt()
          : int.tryParse(entry?.toString() ?? '');
      if (seconds == null || seconds <= 0) return null;
      result.add(seconds);
    }
    return List<int>.unmodifiable(result);
  }
}
