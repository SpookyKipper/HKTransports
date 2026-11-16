import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/eta_service.dart';
import 'package:hktransports/bus/model/bus_models.dart';

void main() {
  test(
    'uses Citybus proprietary only for enabled joint KMB/Citybus routes',
    () {
      expect(
        shouldUseCitybusProprietaryOnly(
          companies: <BusCompany>[BusCompany.kmb, BusCompany.ctb],
          citybusProprietaryEnabled: true,
        ),
        isTrue,
      );
    },
  );

  test('does not use the joint fallback when proprietary ETA is off', () {
    expect(
      shouldUseCitybusProprietaryOnly(
        companies: <BusCompany>[BusCompany.kmb, BusCompany.ctb],
        citybusProprietaryEnabled: false,
      ),
      isFalse,
    );
  });

  test('does not use the joint fallback for single-operator routes', () {
    expect(
      shouldUseCitybusProprietaryOnly(
        companies: <BusCompany>[BusCompany.kmb],
        citybusProprietaryEnabled: true,
      ),
      isFalse,
    );
    expect(
      shouldUseCitybusProprietaryOnly(
        companies: <BusCompany>[BusCompany.ctb],
        citybusProprietaryEnabled: true,
      ),
      isFalse,
    );
  });
}
