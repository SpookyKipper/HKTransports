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
    this.solarPowered = false,
    this.occupancyPercent,
    this.occupancyMinPercent,
    this.occupancyMaxPercent,
    this.doubleWheelchair = false,
    this.kmbProprietary = false,
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

  /// Whether the source row marks this vehicle as solar-powered.
  final bool solarPowered;

  /// Midpoint of the passenger-load range reported by the source.
  final int? occupancyPercent;

  /// Lower bound of the passenger-load range.
  final int? occupancyMinPercent;

  /// Upper bound of the passenger-load range.
  final int? occupancyMaxPercent;

  /// Whether the source marks this vehicle as double-wheelchair accessible.
  final bool doubleWheelchair;

  /// Whether the row came from the KMB proprietary ETA feed.
  final bool kmbProprietary;

  /// Whether the vehicle is wheelchair accessible.
  final bool wheelchair;

  String remark(String language) =>
      normalizeEtaStatusText(language == 'en' ? remarkEn : remarkZh, language);

  String dest(String language) => language == 'en' ? destEn : destZh;

  String? status(String language) {
    final String? value = language == 'en' ? statusEn : statusZh;
    if (value == null || value.trim().isEmpty) return null;
    return normalizeEtaStatusText(value, language);
  }

  String? distanceLabel(String language) {
    final double? value = distanceKm;
    if (value == null) return null;
    if (kmbProprietary && value == 0) return null;
    final String distance = value.toStringAsFixed(1);
    return language == 'en' ? '$distance km away' : '距離 $distance 公里';
  }

  String? occupancyLabel(String language) {
    final int? value = occupancyPercent;
    if (value == null) return null;
    final int? min = occupancyMinPercent;
    final int? max = occupancyMaxPercent;
    if (min == null || max == null || min == max) {
      return language == 'en' ? '$value% full' : '載客 $value%';
    }
    return language == 'en' ? '$min% - $max% full' : '載客 $min% - $max%';
  }

  bool get hasEta => eta != null;

  BusEta copyWith({
    String? statusZh,
    String? statusEn,
    double? distanceKm,
    String? proprietaryTime,
    String? proprietaryMinutes,
    int? etaSeq,
    bool? solarPowered,
    int? occupancyPercent,
    int? occupancyMinPercent,
    int? occupancyMaxPercent,
    bool? doubleWheelchair,
    bool? kmbProprietary,
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
      solarPowered: solarPowered ?? this.solarPowered,
      occupancyPercent: occupancyPercent ?? this.occupancyPercent,
      occupancyMinPercent: occupancyMinPercent ?? this.occupancyMinPercent,
      occupancyMaxPercent: occupancyMaxPercent ?? this.occupancyMaxPercent,
      doubleWheelchair: doubleWheelchair ?? this.doubleWheelchair,
      kmbProprietary: kmbProprietary ?? this.kmbProprietary,
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

String normalizeEtaStatusText(String value, String language) {
  if (language == 'en') {
    return value.replaceAll('Scheduled Bus', 'Scheduled');
  }
  return value.replaceAll('原定班次', '預定班次');
}
