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

bool _isCitybusProprietary(BusEta eta) {
  if (eta.company != BusCompany.ctb) return false;
  return proprietaryClockLabel(eta) != null ||
      proprietaryMinutesLabel(eta) != null ||
      eta.distanceKm != null ||
      (eta.statusZh?.trim().isNotEmpty ?? false) ||
      (eta.statusEn?.trim().isNotEmpty ?? false);
}

bool _isKmbProprietary(BusEta eta) {
  return eta.company == BusCompany.kmb && eta.kmbProprietary;
}

/// KMB's proprietary board reports 0.0 km once the bus reaches the stop.
bool etaArrivedAtStop(BusEta eta) {
  return _isKmbProprietary(eta) && eta.distanceKm == 0;
}

/// The minute portion of an ETA row.
///
/// Citybus proprietary rows keep their literal minute text and special states.
/// Other rows show a dash once the ETA is at or before now, and "<1" for a
/// future arrival less than a minute away.
String? etaWaitLabel(
  BusEta eta,
  AppSettings settings,
  int? minutes, {
  bool atOrigin = false,
  bool shortMinuteUnit = false,
}) {
  final String minuteUnit = settings.text(shortMinuteUnit ? '分' : '分鐘', 'min');
  final bool citybusProprietary = _isCitybusProprietary(eta);
  if (_isKmbProprietary(eta)) {
    if (etaArrivedAtStop(eta)) {
      return settings.text('已到達', 'Arrived');
    }
    if (minutes != null && minutes < 1) {
      return eta.distanceKm != null ? '<1 $minuteUnit' : '- $minuteUnit';
    }
    return etaMinuteWaitLabel(eta.eta, minuteUnit);
  }
  if (!citybusProprietary) {
    if (atOrigin &&
        minutes != null &&
        minutes < 1 &&
        eta.company != BusCompany.ctb) {
      return settings.text('即場開出', 'Departing now');
    }
    return etaMinuteWaitLabel(eta.eta, minuteUnit);
  }

  if (_statusArrived(eta)) return null;
  final String? literal = proprietaryMinutesLabel(eta);
  final bool underOne =
      (minutes != null && minutes < 1) ||
      (literal != null && _literalUnderOneMinute(literal));
  if (_statusLeaving(eta)) {
    return '- $minuteUnit';
  }
  if (underOne) {
    return etaUnderOneWaitLabel(eta.distanceKm != null, minuteUnit);
  }
  if (literal != null) {
    return shortMinuteUnit ? literal.replaceAll('分鐘', '分') : literal;
  }
  if (minutes == null) return null;
  return '$minutes $minuteUnit';
}

String etaUnderOneWaitLabel(bool hasDistance, String minuteUnit) {
  return hasDistance ? '<1 $minuteUnit' : '- $minuteUnit';
}

String? etaMinuteWaitLabel(
  DateTime? etaTime,
  String minuteUnit, {
  DateTime? now,
}) {
  if (etaTime == null) return null;
  final DateTime reference = (now ?? DateTime.now()).toUtc();
  final Duration difference = etaTime.toUtc().difference(reference);
  if (difference.inMicroseconds <= 0) return '- $minuteUnit';
  if (difference.compareTo(const Duration(minutes: 1)) < 0) {
    return '<1 $minuteUnit';
  }
  return '${difference.inMinutes} $minuteUnit';
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
    eta.solarPowered.toString(),
    eta.occupancyPercent?.toString() ?? '',
    eta.occupancyMinPercent?.toString() ?? '',
    eta.occupancyMaxPercent?.toString() ?? '',
    eta.doubleWheelchair.toString(),
    eta.kmbProprietary.toString(),
  ].join('|');
}
