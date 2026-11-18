import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/notice/proprietary_notice_service.dart';

void main() {
  test('parses a Citybus stop notice without duplicating nested rows', () {
    const String html = '''
<div>
  <table>
    <tr>
      <td>乘客通告</td>
    </tr>
    <tr onclick="javascript:window.open('https://mobile.citybus.com.hk/pdf/E202600002a03.pdf');">
      <td colspan="2">
        <table>
          <tr><td><font>2026-10-09</font></td></tr>
          <tr><td>城巴新皇崗口岸路線B14 十月十二日啟航</td></tr>
          <tr><td>路線:A23</td></tr>
        </table>
      </td>
    </tr>
  </table>
</div>
''';

    final List<ProprietaryNotice> notices = parseCitybusNoticeHtml(html);

    expect(notices, hasLength(1));
    expect(notices.single.date, '2026-10-09');
    expect(notices.single.title, '城巴新皇崗口岸路線B14 十月十二日啟航');
    expect(notices.single.detail, '路線:A23');
    expect(
      notices.single.url,
      Uri.parse('https://mobile.citybus.com.hk/pdf/E202600002a03.pdf'),
    );
  });

  test('parses a Citybus route notice with its link on a cell', () {
    const String html = '''
<table>
  <tr>
    <td><img src="icon_notice.png">通告</td>
  </tr>
  <tr>
    <td onclick="javascript:window.open('https://mobile.citybus.com.hk/pdf/E1.pdf');">
      <font>2026-10-21</font><br>
      紅館演唱會散場路線
    </td>
  </tr>
</table>
''';

    final List<ProprietaryNotice> notices = parseCitybusNoticeHtml(html);

    expect(notices, hasLength(1));
    expect(notices.single.date, '2026-10-21');
    expect(notices.single.title, '紅館演唱會散場路線');
    expect(
      notices.single.url,
      Uri.parse('https://mobile.citybus.com.hk/pdf/E1.pdf'),
    );
  });

  test('parses a Citybus special notice and skips its header', () {
    const String html = '''
<div id="specialnotelist">
  <table>
    <tr>
      <td><img src="bupspecial-c.png" title="路線服務狀況"></td>
      <td>路線服務狀況</td>
      <td><img src="close-g.png" title="關閉"></td>
    </tr>
  </table>
  <table>
    <tr>
      <td><font>2026-10-29</font> 特別班次安排 <a href="/pdf/special.pdf">詳情</a></td>
    </tr>
  </table>
</div>
''';

    final List<ProprietaryNotice> notices = parseCitybusSpecialNoticeHtml(html);

    expect(notices, hasLength(1));
    expect(notices.single.date, '2026-10-29');
    expect(notices.single.title, '特別班次安排 詳情');
    expect(
      notices.single.url,
      Uri.parse('https://mobile.citybus.com.hk/pdf/special.pdf'),
    );
  });

  test('groups a Citybus special-notice form into one readable notice', () {
    const String html = '''
<div id="specialnotelist">
  <table>
    <tr>
      <td><img src="bupspecial-c.png" title="路線服務狀況"></td>
      <td>路線服務狀況</td>
      <td><img src="close-g.png" title="關閉"></td>
    </tr>
  </table>
  <table>
    <tr><td style="background-color:#dddddd"></td></tr>
    <tr><td style="font-weight:bold;">路線 Route</td></tr>
    <tr><td style="border-bottom:1px solid #cccccc;">E11B</td></tr>
    <tr><td style="font-weight:bold;">方向 Direction</td></tr>
    <tr><td style="border-bottom:1px solid #cccccc;">天后站 Tin Hau Station</td></tr>
    <tr><td style="font-weight:bold;">服務安排 Service Arrangement</td></tr>
    <tr><td style="border-bottom:1px solid #cccccc;">為配合道路工程，福逸樓巴士站將臨時停用。<br>In order to facilitate road works, the stop will be suspended.</td></tr>
    <tr><td style="font-weight:bold;">停用巴士站 Suspended Bus Stop</td></tr>
    <tr><td style="border-bottom:1px solid #cccccc;">1. 逸東邨福逸樓, 裕東路<br>1. Fuk Yat House Yat Tung Estate, Yu Tung Road</td></tr>
    <tr><td style="font-weight:bold;">臨時巴士站 Temporary Bus Stop</td></tr>
    <tr><td style="border-bottom:1px solid #cccccc;">不設臨時站<br>No Temporary Bus Stop</td></tr>
    <tr><td style="background-color:#dddddd"></td></tr>
  </table>
</div>
''';

    final List<ProprietaryNotice> notices = parseCitybusSpecialNoticeHtml(html);

    expect(notices, hasLength(1));
    expect(notices.single.title, 'E11B');
    expect(notices.single.direction, '天后站 Tin Hau Station');
    expect(notices.single.detail, contains('服務安排 Service Arrangement:'));
    expect(notices.single.detail, contains('停用巴士站 Suspended Bus Stop:'));
    expect(notices.single.detail, contains('臨時巴士站 Temporary Bus Stop:'));
    expect(notices.single.detail, contains('\n'));
    expect(notices.single.detail, isNot(contains('路線 Route:')));
    expect(notices.single.detail, isNot(contains('方向 Direction:')));
  });

  test('returns no notices for the Citybus empty state', () {
    const String html = '''
<table>
  <tr>
    <td>現時沒有乘客通告</td>
  </tr>
</table>
''';

    expect(parseCitybusNoticeHtml(html), isEmpty);
  });
}
