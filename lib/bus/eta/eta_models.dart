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
    return en.contains('scheduled') || zh.contains('預定') || zh.contains('原定');
  }
}
