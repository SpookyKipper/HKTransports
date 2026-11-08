import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/traffic/traffic_news_service.dart';

TrafficNewsItem item(String zh, String en) {
  return TrafficNewsItem(description: <String>[zh, en], date: '19:16');
}

void main() {
  test('removes legacy notices duplicated by the current API', () {
    final List<TrafficNewsItem> current = <TrafficNewsItem>[
      item(
        '以下渡輪服務於2026年11月9日作出臨時調整：\n馬灣至中環的班次由巴士代替。',
        'The following ferry services are adjusted on 9 November 2026.',
      ),
    ];
    final List<TrafficNewsItem> legacy = <TrafficNewsItem>[
      item(
        '以下渡輪服務於2026年11月9日作出臨時調整： \n馬灣至中環的班次由巴士代替。',
        'The following ferry services are adjusted on 9 November 2026. ',
      ),
      item('較早前封閉的行車線現已解封。', 'The closed lane has reopened.'),
    ];

    final List<TrafficNewsItem> merged = mergeTrafficNews(current, legacy);

    expect(merged, hasLength(2));
    expect(merged.last.description.first, contains('行車線'));
  });

  test('ignores punctuation and whitespace when matching notices', () {
    final TrafficNewsItem current = item(
      '颱風期間，以下路線暫停服務。',
      'During the typhoon, the following routes are suspended.',
    );
    final TrafficNewsItem legacy = item(
      '颱風期間 以下路線暫停服務',
      'During the typhoon the following routes are suspended',
    );

    expect(
      mergeTrafficNews(<TrafficNewsItem>[current], <TrafficNewsItem>[legacy]),
      hasLength(1),
    );
  });
}
