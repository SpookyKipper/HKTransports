import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/notice/citybus_remarks_service.dart';

String? remarksText(String source) {
  return parseCitybusRemarks(
    source,
  )?.map((CitybusRemarkLine line) => line.text).join('\n');
}

void main() {
  test('removes the bound segment from a concession route key', () {
    expect(citybusRemarkInfoKey('798-B-TIK-1'), '798-TIK-1');
    expect(citybusRemarkInfoKey('798-F-FTC-1'), '798-FTC-1');
    expect(citybusRemarkInfoKey('invalid'), isNull);
  });

  test('preserves formatting, links, and double newlines', () {
    final List<CitybusRemarkLine>? remarks = parseCitybusRemarks(r'''
      <div id="remarkitemlist"><font>
      Line 1<br><br><b>Bold</b> <a href="https://example.com">Link</a><br>Line 3
      </font></div>
      ''');
    expect(remarks, isNotNull);
    expect(
      remarksText(r'''
      <div id="remarkitemlist"><font>
      Line 1<br><br><b>Bold</b> <a href="https://example.com">Link</a><br>Line 3
      </font></div>
      '''),
      'Line 1\n\nBold Link\nLine 3',
    );
    final CitybusRemarkRun bold = remarks!
        .expand((CitybusRemarkLine line) => line.runs)
        .firstWhere((CitybusRemarkRun run) => run.text == 'Bold');
    expect(bold.bold, isTrue);
    final CitybusRemarkRun link = remarks
        .expand((CitybusRemarkLine line) => line.runs)
        .firstWhere((CitybusRemarkRun run) => run.text == 'Link');
    expect(link.href, 'https://example.com');
  });

  test(
    'keeps fare remarks and removes only the BBI section and coverage link',
    () {
      final String? remarks = remarksText(r'''
      <table id="remarkitemlist"><tr><td><html><body><font>
      Fare Remark / Bus-Bus Interchange<br>
      Adult Fare<br>
      Tiu Keng Leng Station &gt; Fo Tan $13.1<br>
      Tate's Cairn Tunnel Bus-Bus Interchange &gt; Fo Tan $6.7<br>
      <b>Bus-Bus Interchange</b><br>
      For details of Bus-Bus Interchange concession and discount, please <a href="https://www.citybus.com.hk/concession/en/route/798">click here</a>.<br>
      <a href="https://www.citybus.com.hk/concession/en/route">Click here for the coverage of relevant Bus-Bus Interchange Concession Schemes.</a><br>
      Fare shown excludes the Government fare concession.
      </font></body></html></td></tr></table>
      ''');
      expect(remarks, isNotNull);
      expect(remarks, contains('Fare Remark / Bus-Bus Interchange'));
      expect(remarks, contains('Adult Fare'));
      expect(remarks, contains('Tiu Keng Leng Station > Fo Tan \$13.1'));
      expect(remarks, contains('Tate\'s Cairn Tunnel Bus-Bus Interchange'));
      expect(remarks, contains('Government fare concession'));
      expect(remarks, isNot(contains('For details of Bus-Bus Interchange')));
      expect(remarks, isNot(contains('Click here for the coverage')));
    },
  );

  test('removes the Chinese BBI section and coverage link only', () {
    final String? remarks = remarksText(r'''
      <table id="remarkitemlist"><tr><td><font>
      車費備註 / 巴士轉乘計劃<br>
      成人收費 $13.1<br>
      大老山隧道巴士轉乘站 &gt; 火炭 $6.7<br>
      巴士轉乘計劃<br>
      有關巴士轉乘車費優惠詳情，請按此。<br>
      按此瀏覽八達通巴士轉乘優惠計劃的適用範圍。<br>
      政府長者及合資格殘疾人士公共交通票價優惠。
      </font></td></tr></table>
      ''');
    expect(remarks, isNotNull);
    expect(remarks, contains('車費備註 / 巴士轉乘計劃'));
    expect(remarks, contains('成人收費'));
    expect(remarks, contains('大老山隧道巴士轉乘站'));
    expect(remarks, contains('政府長者'));
    expect(remarks, isNot(contains('有關巴士轉乘車費優惠詳情')));
    expect(remarks, isNot(contains('按此瀏覽八達通巴士轉乘優惠計劃的適用範圍')));
  });
}
