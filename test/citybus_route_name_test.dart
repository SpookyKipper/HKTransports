import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/cache/citybus_route_name_service.dart';

String html(String note) {
  return '''
  <html><body><table><tbody><tr>
    <td id="stopname_0">
      <table><tbody><tr>
        <td><table><tbody><tr><td><font>798</font></td></tr></tbody></table></td>
        <td></td>
        <td><table><tbody>
          <tr><td>To: Fo Tan (Chun Yeung Estate)</td></tr>
          <tr><td><font>$note</font></td></tr>
        </tbody></table></td>
      </tr></tbody></table>
    </td>
  </tr></tbody></table></body></html>
  ''';
}

void main() {
  test('parses and strips the Citybus prefix from an English route name', () {
    expect(
      parseCitybusRouteName(html('Citybus, Tseung Sha Line'), english: true),
      'Tseung Sha Line',
    );
  });

  test('parses and strips the Chinese Citybus prefix', () {
    expect(parseCitybusRouteName(html('城巴, 將沙線'), english: false), '將沙線');
  });

  test('returns null when only the company name is present', () {
    expect(parseCitybusRouteName(html('Citybus'), english: true), isNull);
  });

  test('does not fetch Cityflyer A/NA routes', () async {
    const CitybusRouteNameService service = CitybusRouteNameService();
    expect(await service.routeName('A21', 'en'), isNull);
    expect(await service.routeName('NA21', 'en'), isNull);
  });
}
