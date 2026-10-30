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

  String remark(String language) => language == 'en' ? remarkEn : remarkZh;

  String dest(String language) => language == 'en' ? destEn : destZh;

  bool get hasEta => eta != null;

  bool get isScheduledMark {
    final String en = remarkEn.toLowerCase();
    final String zh = remarkZh;
    return en.contains('scheduled') ||
        zh.contains('預定') ||
        zh.contains('原定') ||
        zh.contains('未開出');
  }

  bool get isScheduledLike => scheduled || isScheduledMark;

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
