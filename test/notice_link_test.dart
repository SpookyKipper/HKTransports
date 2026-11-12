import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/app/notice_link.dart';

void main() {
  test('NLB news article URLs are web notices', () {
    expect(
      isNlbNewsUri(Uri.parse('https://www.nlb.com.hk/tc/news/658')),
      isTrue,
    );
    expect(
      isNlbNewsUri(Uri.parse('https://www.nlb.com.hk/en/news/658')),
      isTrue,
    );
    expect(
      isNlbNewsUri(Uri.parse('https://www.nlb.com.hk/route/1/fare-table')),
      isFalse,
    );
    expect(isNlbNewsUri(Uri.parse('https://example.com/tc/news/658')), isFalse);
  });
}
