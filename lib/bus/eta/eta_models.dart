import 'package:hktransports/bus/model/bus_models.dart';

class BusEta {
  const BusEta({
    required this.company,
    required this.eta,
    required this.remarkZh,
    required this.remarkEn,
    required this.destZh,
    required this.destEn,
    required this.etaSeq,
    this.scheduled = false,
    this.platform,
    this.statusZh,
    this.statusEn,
    this.distanceKm,
    this.proprietaryTime,
    this.proprietaryMinutes,
    this.wheelchair = false,
  });

  final BusCompany company;
  final DateTime? eta;
  final String remarkZh;
  final String remarkEn;
  final String destZh;
  final String destEn;
  final int etaSeq;
  final bool scheduled;
  final String? platform;

  /// Live ETA status from a proprietary source, for example `未開出`.
  final String? statusZh;
  final String? statusEn;

  /// Distance to the stop reported by a proprietary source.
  final double? distanceKm;

  /// Literal time and minutes strings reported by a proprietary source.
  final String? proprietaryTime;
  final String? proprietaryMinutes;

  /// Whether the vehicle is wheelchair accessible.
  final bool wheelchair;

  String remark(String language) => language == 'en' ? remarkEn : remarkZh;

  String dest(String language) => language == 'en' ? destEn : destZh;

  String? status(String language) {
    final String? value = language == 'en' ? statusEn : statusZh;
    return value == null || value.trim().isEmpty ? null : value.trim();
  }

  String? distanceLabel(String language) {
    final double? value = distanceKm;
    if (value == null) return null;
    final String distance = value.toStringAsFixed(1);
    return language == 'en' ? '$distance km away' : '距離 $distance 公里';
  }

  bool get hasEta => eta != null;

  BusEta copyWith({
    String? statusZh,
    String? statusEn,
    double? distanceKm,
    String? proprietaryTime,
    String? proprietaryMinutes,
    int? etaSeq,
    bool? wheelchair,
  }) {
    return BusEta(
      company: company,
      eta: eta,
      remarkZh: remarkZh,
      remarkEn: remarkEn,
      destZh: destZh,
      destEn: destEn,
      etaSeq: etaSeq ?? this.etaSeq,
      scheduled: scheduled,
      platform: platform,
      statusZh: statusZh ?? this.statusZh,
      statusEn: statusEn ?? this.statusEn,
      distanceKm: distanceKm ?? this.distanceKm,
      proprietaryTime: proprietaryTime ?? this.proprietaryTime,
      proprietaryMinutes: proprietaryMinutes ?? this.proprietaryMinutes,
      wheelchair: wheelchair ?? this.wheelchair,
    );
  }

  bool hasDepartedAt(
    DateTime now, {
    Duration grace = const Duration(seconds: 30),
  }) {
    final DateTime? time = eta;
    if (time == null) return false;
    return now.toUtc().difference(time.toUtc()) >= grace;
  }

  bool get isScheduledMark {
    final String en = '$remarkEn ${statusEn ?? ''}'.toLowerCase();
    final String zh = '$remarkZh ${statusZh ?? ''}';
    return en.contains('scheduled') ||
        zh.contains('預定') ||
        zh.contains('原定') ||
        zh.contains('未開出') ||
        zh.contains('not yet departed');
  }

  bool get isScheduledLike => scheduled || isScheduledMark;

  bool shouldShowScheduleIcon(DateTime now) {
    if (!isScheduledLike) return false;
    final DateTime? time = eta;
    if (time == null) return true;
    if (hasDepartedAt(now)) return false;
    return time.toUtc().difference(now.toUtc()).inMinutes >= 1;
  }

  bool get isDelayedJourney {
    final String en = remarkEn.toLowerCase();
    return en.contains('delayed journey') ||
        remarkZh.contains('受阻於') ||
        remarkZh.contains('受困於');
  }

  String? get delayedFromStopCode {
    if (!isDelayedJourney) return null;
    final Match? match = RegExp(
      r'\(([A-Za-z]{2}\d{3}[a-z]?)\)',
    ).firstMatch(remarkEn.isNotEmpty ? remarkEn : remarkZh);
    return match?.group(1)?.toUpperCase();
  }

  bool canShowDelayedEta({
    required int stopIndex,
    required Map<String, int> stopIndexByCode,
    required int minutes,
  }) {
    if (!isDelayedJourney) return true;
    final String? code = delayedFromStopCode;
    final int? stuckIndex = code == null ? null : stopIndexByCode[code];
    return stuckIndex != null &&
        stopIndex == stuckIndex + 1 &&
        minutes >= 0 &&
        minutes < 5;
  }
}
