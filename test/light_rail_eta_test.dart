import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/clients/lightrail_eta_client.dart';

void main() {
  test('formats light rail car counts without box glyphs', () {
    expect(
      formatLightRailRemark(trainLength: 2, routeRemark: '', english: false),
      '2卡',
    );
    expect(
      formatLightRailRemark(trainLength: 2, routeRemark: '', english: true),
      '2 cars',
    );
    expect(
      formatLightRailRemark(trainLength: 1, routeRemark: '', english: true),
      '1 car',
    );
  });

  test('keeps genuine light rail remarks alongside car count', () {
    expect(
      formatLightRailRemark(
        trainLength: 2,
        routeRemark: '特別班次',
        english: false,
      ),
      '2卡 · 特別班次',
    );
  });

  test('removes replacement and control characters from remarks', () {
    expect(cleanLightRailRemark('abc\uFFFD\u0000 def'), 'abc def');
    expect(cleanLightRailRemark(null), '');
  });
}
