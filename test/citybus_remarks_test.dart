import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/notice/citybus_remarks_service.dart';

String? remarksText(String source) {
  return parseCitybusRemarks(
    source,
  )?.map((CitybusRemarkLine line) => line.text).join('\n');
}

void main() {
  test('preserves formatting, links, and double newlines', () {
    const String source = r'''
      <div id="remarkitemlist"><font>
      Line 1<br><br><b>Bold</b> <a href="https://example.com">Link</a><br>Line 3
      </font></div>
      ''';
    final List<CitybusRemarkLine>? remarks = parseCitybusRemarks(source);
    expect(remarks, isNotNull);
    expect(remarksText(source), 'Line 1\n\nBold Link\nLine 3');
    final CitybusRemarkRun bold = remarks!
        .expand((CitybusRemarkLine line) => line.runs)
        .firstWhere((CitybusRemarkRun run) => run.text == 'Bold');
    expect(bold.bold, isTrue);
    final CitybusRemarkRun link = remarks
        .expand((CitybusRemarkLine line) => line.runs)
        .firstWhere((CitybusRemarkRun run) => run.text == 'Link');
    expect(link.href, 'https://example.com');
  });

  test('styles the fare header and keeps only the required removals', () {
    const String source = r'''
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
      ''';
    final List<CitybusRemarkLine> remarks = parseCitybusRemarks(source)!;
    final String text = remarks
        .map((CitybusRemarkLine line) => line.text)
        .join('\n');
    expect(text, contains('Fare Remark'));
    expect(text, isNot(contains('Fare Remark / Bus-Bus Interchange')));
    expect(text, contains('Adult Fare'));
    expect(text, contains('Tiu Keng Leng Station > Fo Tan \$13.1'));
    expect(text, contains('Tate\'s Cairn Tunnel Bus-Bus Interchange'));
    expect(text, contains('Government fare concession'));
    expect(text, isNot(contains('For details of Bus-Bus Interchange')));
    expect(text, isNot(contains('Click here for the coverage')));
    final CitybusRemarkLine header = remarks.firstWhere(
      (CitybusRemarkLine line) => line.text == 'Fare Remark',
    );
    expect(header.runs.every((CitybusRemarkRun run) => run.bold), isTrue);
    final CitybusRemarkLine adult = remarks.firstWhere(
      (CitybusRemarkLine line) => line.text == 'Adult Fare',
    );
    expect(adult.runs.every((CitybusRemarkRun run) => run.underline), isTrue);
  });

  test(
    'styles the Chinese fare header and keeps only the required removals',
    () {
      const String source = r'''
      <table id="remarkitemlist"><tr><td><font>
      車費備註 / 巴士轉乘計劃<br>
      成人收費<br>
      大老山隧道巴士轉乘站 &gt; 火炭 $6.7<br>
      巴士轉乘計劃<br>
      有關巴士轉乘車費優惠詳情，請按此。<br>
      按此瀏覽八達通巴士轉乘優惠計劃的適用範圍。<br>
      政府長者及合資格殘疾人士公共交通票價優惠。
      </font></td></tr></table>
      ''';
      final List<CitybusRemarkLine> remarks = parseCitybusRemarks(source)!;
      final String text = remarks
          .map((CitybusRemarkLine line) => line.text)
          .join('\n');
      expect(text, contains('車費備註'));
      expect(text, isNot(contains('車費備註 / 巴士轉乘計劃')));
      expect(text, contains('成人收費'));
      expect(text, contains('大老山隧道巴士轉乘站'));
      expect(text, contains('政府長者'));
      expect(text, isNot(contains('有關巴士轉乘車費優惠詳情')));
      expect(text, isNot(contains('按此瀏覽八達通巴士轉乘優惠計劃的適用範圍')));
      final CitybusRemarkLine header = remarks.firstWhere(
        (CitybusRemarkLine line) => line.text == '車費備註',
      );
      expect(header.runs.every((CitybusRemarkRun run) => run.bold), isTrue);
      final CitybusRemarkLine adult = remarks.firstWhere(
        (CitybusRemarkLine line) => line.text == '成人收費',
      );
      expect(adult.runs.every((CitybusRemarkRun run) => run.underline), isTrue);
    },
  );
}
