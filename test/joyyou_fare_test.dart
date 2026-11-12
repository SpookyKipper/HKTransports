import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/fare/joyyou_fare.dart';
import 'package:hktransports/bus/model/bus_models.dart';

void main() {
  test('calculates JoyYou fares with nearest 10 cent rounding', () {
    final List<BusCompany> companies = <BusCompany>[BusCompany.ctb];
    String? fare(double adult) => calculateJoyYouFare(
      route: '690',
      companies: companies,
      adultFare: adult,
    );

    expect(fare(1.5), '1.5');
    expect(fare(6.8), '2.0');
    expect(fare(10), '2.0');
    expect(fare(10.8), '2.2');
    expect(fare(12.9), '2.6');
    expect(fare(20.2), '4.0');
    expect(fare(27.9), '5.6');
  });

  test('excludes A, NA, H, and P CTB/KMB routes', () {
    for (final String route in <String>['A22', 'NA21', 'H1', 'P960']) {
      expect(
        calculateJoyYouFare(
          route: route,
          companies: <BusCompany>[BusCompany.ctb, BusCompany.kmb],
          adultFare: 20,
        ),
        isNull,
        reason: route,
      );
    }
    expect(
      calculateJoyYouFare(
        route: '690',
        companies: <BusCompany>[BusCompany.ctb, BusCompany.kmb],
        adultFare: 17.8,
      ),
      '3.6',
    );
  });
}
