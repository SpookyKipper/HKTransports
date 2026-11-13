import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/ui/nlb_fare_label.dart';

void main() {
  test('hides zero NLB holiday fares', () {
    expect(isZeroNlbFare('0'), isTrue);
    expect(isZeroNlbFare('0.0'), isTrue);
    expect(isZeroNlbFare('0.00'), isTrue);
    expect(isZeroNlbFare(r'$0'), isTrue);
    expect(isZeroNlbFare('0.1'), isFalse);
    expect(isZeroNlbFare('12.7'), isFalse);
    expect(isZeroNlbFare(''), isFalse);
    expect(isZeroNlbFare(null), isFalse);
  });
}
