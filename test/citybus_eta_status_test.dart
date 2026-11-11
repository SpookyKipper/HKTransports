import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/citybus_eta_status_client.dart';

void main() {
  test('parses Citybus nwp3 statuses in display order', () {
    final List<CitybusEtaStatus> statuses = parseCitybusEtaStatuses('''
      <div id="nextbus_listitem">
        <table><tr>
          <td><table><tr><td>22:10</td></tr></table></td>
          <td><table>
            <tr><td>往: 火炭(駿洋邨)</td></tr>
            <tr><td>未開出</td></tr>
          </table></td>
        </tr></table>
        <table><tr>
          <td><table><tr><td>22:35</td></tr></table></td>
          <td><table>
            <tr><td>往: 火炭(駿洋邨)</td></tr>
            <tr><td>距離 1.2公里</td></tr>
          </table></td>
        </tr></table>
      </div>
    ''');

    expect(statuses, hasLength(2));
    expect(statuses[0].statusZh, '未開出');
    expect(statuses[0].statusEn, 'Not yet departed');
    expect(statuses[0].distanceKm, isNull);
    expect(statuses[1].statusZh, isNull);
    expect(statuses[1].distanceKm, 1.2);
  });

  test('strips a UTF-8 BOM and caps the rows at three', () {
    final String row = '''
      <table><tr>
        <td><table><tr><td>22:10</td></tr></table></td>
        <td><table>
          <tr><td>往: 中環</td></tr>
          <tr><td>正在前往</td></tr>
        </table></td>
      </tr></table>
    ''';
    final List<CitybusEtaStatus> statuses = parseCitybusEtaStatuses(
      '\uFEFF<div id="nextbus_listitem">$row$row$row$row</div>',
    );

    expect(statuses, hasLength(3));
    expect(statuses.first.statusEn, 'En route');
  });

  test('returns no statuses when nwp3 has no prediction', () {
    expect(
      parseCitybusEtaStatuses('<div id="nextbus">未能提供預計抵站時間</div>'),
      isEmpty,
    );
    expect(parseCitybusEtaStatuses(''), isEmpty);
  });
}
