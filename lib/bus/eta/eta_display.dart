import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';

String? proprietaryClockLabel(BusEta eta) {
  final String? value = eta.proprietaryTime?.trim();
  return value == null || value.isEmpty ? null : value;
}

String? proprietaryMinutesLabel(BusEta eta) {
  final String? value = eta.proprietaryMinutes?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

bool _statusArrived(BusEta eta) {
  final String text = '${eta.statusZh ?? ''} ${eta.statusEn ?? ''}'
      .toLowerCase();
  return text.contains('已到達') ||
      text.contains('已到站') ||
      text.contains('arrived');
}

bool _statusLeaving(BusEta eta) {
  final String text = '${eta.statusZh ?? ''} ${eta.statusEn ?? ''}'
      .toLowerCase();
  return text.contains('正在離') ||
      text.contains('正在離開') ||
      text.contains('leaving');
}

bool _literalUnderOneMinute(String literal) {
  final String text = literal.toLowerCase();
  return text.contains('<') ||
      text.contains('少於') ||
      text.contains('即將到達') ||
      text.contains('arriving') ||
      text.contains('正在離') ||
      text.contains('leaving');
}

/// The minute portion of an ETA row.
///
/// Citybus rows with a live distance keep the literal "<1 分鐘" indication.
/// Once Citybus reports that the bus has arrived, the minute portion is hidden.
/// Other operators use a dash for under-one-minute and departed states.
String? etaWaitLabel(
  BusEta eta,
  AppSettings settings,
  int? minutes, {
  bool atOrigin = false,
  bool shortMinuteUnit = false,
}) {
  final String minuteUnit = settings.text(shortMinuteUnit ? '分' : '分鐘', 'min');
  final bool citybus = eta.company == BusCompany.ctb;
  if (citybus && _statusArrived(eta)) return null;
  final String? literal = proprietaryMinutesLabel(eta);
  final bool underOne =
      (minutes != null && minutes < 1) ||
      (literal != null && _literalUnderOneMinute(literal));
  if (atOrigin && minutes != null && minutes < 1 && !citybus) {
    return settings.text('即場開出', 'Departing now');
  }
  if (citybus && _statusLeaving(eta)) {
    return '- $minuteUnit';
  }
  if (underOne) {
    if (citybus && eta.distanceKm != null) {
      return '<1 $minuteUnit';
    }
    return '- $minuteUnit';
  }
  if (literal != null) {
    return shortMinuteUnit ? literal.replaceAll('分鐘', '分') : literal;
  }
  if (minutes == null) return null;
  return '$minutes $minuteUnit';
}

/// Changes whenever the base ETA content changes, excluding live status.
String etaDisplayKey(BusEta eta) {
  return <String>[
    eta.company.name,
    eta.etaSeq.toString(),
    eta.eta?.millisecondsSinceEpoch.toString() ?? '',
    eta.remarkZh,
    eta.remarkEn,
    eta.scheduled.toString(),
    eta.platform ?? '',
    eta.destZh,
    eta.destEn,
    eta.proprietaryTime ?? '',
    eta.proprietaryMinutes ?? '',
  ].join('|');
}

/// Changes whenever the appended live status or distance changes.
String etaLiveStatusKey(BusEta eta) {
  return <String>[
    eta.statusZh ?? '',
    eta.statusEn ?? '',
    eta.distanceKm?.toString() ?? '',
  ].join('|');
}
