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
