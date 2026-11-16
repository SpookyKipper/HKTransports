import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/citybus_eta_status_client.dart';

void main() {
  test('parses the current nwp3 registration and result endpoints', () {
    const String popup = '''
      showblank();
      if (callweb('auto_02c219c8a43745bb8ee85cfda4ce140c.php?info=002917||798-FTC-1||1||O')=='OK')
        showeta();
    ''';
    final CitybusNwp3Registration? registration = parseCitybusNwp3Registration(
      popup,
    );
    expect(registration, isNotNull);
    expect(registration!.path, 'auto_02c219c8a43745bb8ee85cfda4ce140c.php');
    expect(registration.info, '002917||798-FTC-1||1||O');

    const String script = '''
      function showeta_bak(stopid, rdv, seq, bound){
        makeRequestref('auto_11111111111111111111111111111111.php?stopid='+stopid,'popupboxlist');
      }
      function showeta(){
        makeRequestref('auto_d302d8c29bdb4f169f2f727260ec02e3.php?l='+lang,'popupboxlist');
      }
      function showroute_eta_extra(stopid){
        makeRequest('auto_37af99947aff497180ecad7a80561add.php?l='+lang,'popupboxlist');
      }
    ''';
    expect(
      parseCitybusNwp3ResultPath(script),
      'auto_d302d8c29bdb4f169f2f727260ec02e3.php',
    );
  });

  test('decodes an encoded registration info value', () {
    final CitybusNwp3Registration? registration = parseCitybusNwp3Registration(
      "auto_02c219c8a43745bb8ee85cfda4ce140c.php?info=002917%7C%7C798-FTC-1%7C%7C1%7C%7CO",
    );
    expect(registration?.info, '002917||798-FTC-1||1||O');
  });

  test('ignores pages without dynamic nwp3 endpoints', () {
    expect(parseCitybusNwp3Registration('<div>no registration</div>'), isNull);
    expect(parseCitybusNwp3ResultPath('function showeta(){ return; }'), isNull);
  });

  test('parses Citybus nwp3 statuses in display order', () {
    final List<CitybusEtaStatus> statuses = parseCitybusEtaStatuses('''
      <div id="nextbus_listitem">
        <table><tr>
          <td><table><tr><td>22:10</td></tr></table></td>
          <td><table>
            <tr><td>往: 火炭(駿洋邨)</td></tr>
            <tr><td>未開出</td></tr>
            <tr><td>3分鐘</td></tr>
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
    expect(statuses[0].timeMinutes, 22 * 60 + 10);
    expect(statuses[0].timeText, '22:10');
    expect(statuses[0].minutesText, '3分鐘');
    expect(statuses[1].statusZh, isNull);
    expect(statuses[1].distanceKm, 1.2);
    expect(statuses[1].timeMinutes, 22 * 60 + 35);
  });

  test('extracts minutes from a combined status cell', () {
    final List<CitybusEtaStatus> statuses = parseCitybusEtaStatuses('''
      <div id="nextbus_listitem">
        <table><tr>
          <td><table><tr><td>22:10</td></tr></table></td>
          <td><table>
            <tr><td>往: 火炭(駿洋邨)</td></tr>
            <tr><td>3分鐘 未開出</td></tr>
          </table></td>
        </tr></table>
      </div>
    ''');

    expect(statuses, hasLength(1));
    expect(statuses.single.minutesText, '3分鐘');
    expect(statuses.single.statusZh, '未開出');
  });

  test('strips leading punctuation from a combined status cell', () {
    final List<CitybusEtaStatus> statuses = parseCitybusEtaStatuses('''
      <div id="nextbus_listitem">
        <table><tr>
          <td><table><tr><td>23:50</td></tr></table></td>
          <td><table>
            <tr><td>往: 蘇屋</td></tr>
            <tr><td>3分鐘, 尾班車 距離 0.8 公里</td></tr>
          </table></td>
        </tr></table>
      </div>
    ''');

    expect(statuses, hasLength(1));
    expect(statuses.single.minutesText, '3分鐘');
    expect(statuses.single.statusZh, '尾班車');
    expect(statuses.single.distanceKm, 0.8);
  });

  test('parses English nwp3 status text and distance', () {
    final List<CitybusEtaStatus> statuses = parseCitybusEtaStatuses('''
      <div id="nextbus_listitem">
        <table><tr>
          <td><table><tr><td>22:10</td></tr></table></td>
          <td><table>
            <tr><td>To: Central</td></tr>
            <tr><td>Not yet departed</td></tr>
            <tr><td>3 mins</td></tr>
          </table></td>
        </tr></table>
        <table><tr>
          <td><table><tr><td>23:50</td></tr></table></td>
          <td><table>
            <tr><td>To: Central</td></tr>
            <tr><td>3 mins, last bus Distance: 0.8 km</td></tr>
          </table></td>
        </tr></table>
      </div>
      ''', language: 'en');

    expect(statuses, hasLength(2));
    expect(statuses[0].statusEn, 'Not yet departed');
    expect(statuses[0].statusZh, '未開出');
    expect(statuses[0].minutesText, '3 mins');
    expect(statuses[1].statusEn, 'last bus');
    expect(statuses[1].statusZh, '尾班車');
    expect(statuses[1].distanceKm, 0.8);
  });

  test('parses distance with a colon', () {
    final List<CitybusEtaStatus> statuses = parseCitybusEtaStatuses('''
      <div id="nextbus_listitem">
        <table><tr>
          <td><table><tr><td>20:36</td></tr></table></td>
          <td><table>
            <tr><td>往: 機場</td></tr>
            <tr><td>距離: 1.3公里</td></tr>
          </table></td>
        </tr></table>
      </div>
    ''');

    expect(statuses, hasLength(1));
    expect(statuses.single.distanceKm, 1.3);
    expect(statuses.single.statusZh, isNull);
  });

  test('keeps literal less-than-one-minute text', () {
    final List<CitybusEtaStatus> statuses = parseCitybusEtaStatuses('''
      <div id="nextbus_listitem">
        <table><tr>
          <td><table><tr><td>22:10</td></tr></table></td>
          <td><table>
            <tr><td>往: 中環</td></tr>
            <tr><td>&lt;1 min</td></tr>
          </table></td>
        </tr></table>
      </div>
    ''');

    expect(statuses, hasLength(1));
    expect(statuses.single.minutesText, '<1 min');
  });

  test('strips the operator name from joint-route statuses', () {
    final List<CitybusEtaStatus> statuses = parseCitybusEtaStatuses('''
      <div id="nextbus_listitem">
        <table><tr>
          <td><table><tr><td>12:05</td></tr></table></td>
          <td><table>
            <tr><td>往: 康盛花園</td></tr>
            <tr><td>城巴 未開出</td></tr>
          </table></td>
        </tr></table>
        <table><tr>
          <td><table><tr><td>12:35</td></tr></table></td>
          <td><table>
            <tr><td>往: 康盛花園</td></tr>
            <tr><td>城巴 距離 1.2公里</td></tr>
          </table></td>
        </tr></table>
      </div>
    ''');

    expect(statuses, hasLength(2));
    expect(statuses[0].statusZh, '未開出');
    expect(statuses[0].statusEn, 'Not yet departed');
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
