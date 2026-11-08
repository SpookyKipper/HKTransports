import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/ui/citybus_fare_label.dart';

void main() {
  test('formats proprietary fares without trailing zeroes', () {
    expect(formatCitybusFare(9.4), '9.4');
    expect(formatCitybusFare(6.5), '6.5');
    expect(formatCitybusFare(5), '5');
    expect(formatCitybusFare(0), '0');
    expect(formatCitybusFare(6.75), '6.75');
  });
}
