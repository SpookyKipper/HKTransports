import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';

String? departedEtaLabel(BusEta eta, AppSettings settings) {
  if (!eta.hasDepartedAt(DateTime.now().toUtc())) return null;
  return settings.text('正在離站', 'Leaving now');
}

/// Changes whenever the visible content of an ETA may change.
String etaDisplayKey(BusEta eta) {
  return <String>[
    eta.company.name,
    eta.etaSeq.toString(),
    eta.eta?.millisecondsSinceEpoch.toString() ?? '',
    eta.remarkZh,
    eta.remarkEn,
    eta.statusZh ?? '',
    eta.statusEn ?? '',
    eta.distanceKm?.toString() ?? '',
    eta.scheduled.toString(),
    eta.destZh,
    eta.destEn,
  ].join('|');
}
