import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hktransports/bus/state/app_settings.dart';

class AutoUpdateNetworkPolicy {
  const AutoUpdateNetworkPolicy._();

  static Future<bool> allows(AutoUpdateNetwork network) async {
    try {
      final List<ConnectivityResult> results = await Connectivity()
          .checkConnectivity();
      return allowsAutoUpdateOn(network, results);
    } catch (error) {
      debugPrint('Unable to check network for auto update: $error');
      return network == AutoUpdateNetwork.wifiOrMobile;
    }
  }
}

bool allowsAutoUpdateOn(
  AutoUpdateNetwork network,
  Iterable<ConnectivityResult> results,
) {
  final Set<ConnectivityResult> available = results.toSet();
  if (available.isEmpty || available.contains(ConnectivityResult.none)) {
    return false;
  }
  switch (network) {
    case AutoUpdateNetwork.wifiOnly:
      return available.contains(ConnectivityResult.wifi) ||
          available.contains(ConnectivityResult.ethernet);
    case AutoUpdateNetwork.wifiOrMobile:
      return true;
  }
}
