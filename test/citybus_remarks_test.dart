import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/notice/citybus_remarks_service.dart';

void main() {
  test('removes the bound segment from a concession route key', () {
    expect(citybusRemarkInfoKey('798-B-TIK-1'), '798-TIK-1');
    expect(citybusRemarkInfoKey('798-F-FTC-1'), '798-FTC-1');
    expect(citybusRemarkInfoKey('invalid'), isNull);
  });

  test('keeps fare remarks and removes bus-bus interchange content', () {
    final String? remarks = parseCitybusRemarks(r'''
      <table id="remarkitemlist"><tr><td><html><body><font>
      Fare Remark / Bus-Bus Interchange<br>
      Adult Fare<br>
      Tiu Keng Leng Station &gt; Fo Tan $13.1<br>
      Tate's Cairn Tunnel Bus-Bus Interchange &gt; Fo Tan $6.7<br>
      <b>Bus-Bus Interchange</b><br>
      For details, <a href="https://www.citybus.com.hk/concession/en/route/798">click here</a>.<br>
      <a href="https://www.citybus.com.hk/concession/en/route">Click here for coverage of Bus-Bus Interchange schemes.</a><br>
      Fare shown excludes the Government fare concession.
      </font></body></html></td></tr></table>
      ''', zh: false);
    expect(remarks, isNotNull);
    expect(remarks, contains('Fare Remark'));
    expect(remarks, contains('Adult Fare'));
    expect(remarks, contains(r'$13.1'));
    expect(remarks, contains('Government fare concession'));
    expect(remarks, isNot(contains('Bus-Bus Interchange')));
    expect(remarks, isNot(contains('Tate\'s Cairn')));
    expect(remarks, isNot(contains('Click here for coverage')));
  });

  test('removes Chinese bus-bus interchange content', () {
    final String? remarks = parseCitybusRemarks(r'''
      <table id="remarkitemlist"><tr><td><font>
      車費備註 / 巴士轉乘計劃<br>
      成人收費 $13.1<br>
      大老山隧道巴士轉乘站 &gt; 火炭 $6.7<br>
      巴士轉乘計劃<br>
      有關巴士轉乘車費優惠詳情，請按此。<br>
      政府長者及合資格殘疾人士公共交通票價優惠。
      </font></td></tr></table>
      ''', zh: true);
    expect(remarks, isNotNull);
    expect(remarks, contains('車費備註'));
    expect(remarks, contains('成人收費'));
    expect(remarks, contains('政府長者'));
    expect(remarks, isNot(contains('巴士轉乘')));
    expect(remarks, isNot(contains('大老山')));
  });
}
