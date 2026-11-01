import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/notice/bbi_service.dart';

void main() {
  test('L1 means the first leg is free', () {
    expect(citybusDiscountLabel({'discount': 'L1'}, true), '首程免費');
    expect(citybusDiscountLabel({'discount': 'L1'}, false), 'First leg free');
  });

  test('existing Citybus discount labels remain mapped', () {
    expect(citybusDiscountLabel({'discount': 'L2'}, true), '次程免費');
    expect(
      citybusDiscountLabel({
        'discount': 'FR',
        'discountAmount': {'adult': '4.5'},
      }, true),
      '減收 \$4.5',
    );
    expect(
      citybusDiscountLabel({
        'discount': 'TF',
        'totalFare': {'adult': '8'},
      }, false),
      'Combined fare \$8',
    );
  });
}
