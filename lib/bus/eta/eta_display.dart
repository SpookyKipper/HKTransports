import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';

String? departedEtaLabel(BusEta eta, AppSettings settings) {
  if (!eta.hasDepartedAt(DateTime.now().toUtc())) return null;
  return settings.text('正在離站', 'Leaving now');
}

String? proprietaryClockLabel(BusEta eta) {
  final String? value = eta.proprietaryTime?.trim();
  return value == null || value.isEmpty ? null : value;
}

String? proprietaryMinutesLabel(BusEta eta) {
  final String? value = eta.proprietaryMinutes?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

/// Citybus nwp3 normally supplies only a clock time. When it is within a
/// minute, show the established "<1 min" label instead of the generic
/// open-data "arriving" wording.
String? proprietaryWaitLabel(BusEta eta, AppSettings settings, int minutes) {
  final String? literal = proprietaryMinutesLabel(eta);
  if (literal != null) return literal;
  if (eta.proprietaryTime == null) return null;
  if (minutes < 1) return '<1 min';
  return '$minutes ${settings.text('分鐘', 'min')}';
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
