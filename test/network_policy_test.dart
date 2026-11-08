import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/data/network_policy.dart';
import 'package:hktransports/bus/state/app_settings.dart';

void main() {
  test('Wi-Fi only allows Wi-Fi and ethernet', () {
    expect(
      allowsAutoUpdateOn(AutoUpdateNetwork.wifiOnly, <ConnectivityResult>[
        ConnectivityResult.wifi,
      ]),
      isTrue,
    );
    expect(
      allowsAutoUpdateOn(AutoUpdateNetwork.wifiOnly, <ConnectivityResult>[
        ConnectivityResult.ethernet,
      ]),
      isTrue,
    );
    expect(
      allowsAutoUpdateOn(AutoUpdateNetwork.wifiOnly, <ConnectivityResult>[
        ConnectivityResult.mobile,
      ]),
      isFalse,
    );
  });

  test('Wi-Fi only permits a VPN when Wi-Fi is also available', () {
    expect(
      allowsAutoUpdateOn(AutoUpdateNetwork.wifiOnly, <ConnectivityResult>[
        ConnectivityResult.vpn,
        ConnectivityResult.wifi,
      ]),
      isTrue,
    );
    expect(
      allowsAutoUpdateOn(AutoUpdateNetwork.wifiOnly, <ConnectivityResult>[
        ConnectivityResult.vpn,
      ]),
      isFalse,
    );
  });

  test('Wi-Fi or mobile data allows any connected network', () {
    expect(
      allowsAutoUpdateOn(AutoUpdateNetwork.wifiOrMobile, <ConnectivityResult>[
        ConnectivityResult.mobile,
      ]),
      isTrue,
    );
    expect(
      allowsAutoUpdateOn(AutoUpdateNetwork.wifiOrMobile, <ConnectivityResult>[
        ConnectivityResult.wifi,
      ]),
      isTrue,
    );
    expect(
      allowsAutoUpdateOn(AutoUpdateNetwork.wifiOrMobile, <ConnectivityResult>[
        ConnectivityResult.none,
      ]),
      isFalse,
    );
  });

  test('no connectivity never allows an automatic update', () {
    expect(
      allowsAutoUpdateOn(AutoUpdateNetwork.wifiOrMobile, const []),
      isFalse,
    );
    expect(
      allowsAutoUpdateOn(AutoUpdateNetwork.wifiOnly, <ConnectivityResult>[
        ConnectivityResult.none,
      ]),
      isFalse,
    );
  });
}
