import 'package:hktransports/app/app_version.dart';

const String kmbEtaSeedHex = String.fromEnvironment('KMB_ETA_SEED');

final bool kmbEtaSeedAvailable =
    appFlavor != 'foss' &&
    RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(kmbEtaSeedHex.trim());
