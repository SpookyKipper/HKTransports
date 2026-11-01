import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/ui/citybus_route_name_subtitle.dart';

void main() {
  test('removes the peak notice and keeps the following route description', () {
    expect(stripCitybusPeakNotice('繁忙時間 星期一至五'), '');
    expect(stripCitybusPeakNotice('繁忙時間 星期一至五 大嶼山北部對外路線'), '大嶼山北部對外路線');
    expect(
      stripCitybusPeakNotice(
        'Peak only, Monday to Friday only, North Lantau External Routes',
      ),
      'North Lantau External Routes',
    );
    expect(stripCitybusPeakNotice('將沙線'), '將沙線');
  });
}
