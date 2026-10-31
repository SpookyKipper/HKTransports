import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/state/app_settings.dart';

String? departedEtaLabel(BusEta eta, AppSettings settings) {
  if (!eta.hasDepartedAt(DateTime.now().toUtc())) return null;
  return settings.text('已離站', 'Departed');
}
