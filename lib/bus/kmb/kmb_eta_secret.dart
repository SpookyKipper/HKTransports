const String kmbEtaSeedHex = String.fromEnvironment('KMB_ETA_SEED');

final bool kmbEtaSeedAvailable = RegExp(
  r'^[0-9a-fA-F]{32}$',
).hasMatch(kmbEtaSeedHex.trim());
