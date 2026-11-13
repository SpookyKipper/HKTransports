import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/nlb/nlb_timetable_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _sampleHtml = '''
<div>
  <div></div>
  <div id="route-fare">
    <div></div>
    <div>
      <div>
        <div class="ck-content">
          <h2>Fare note example</h2>
          <h2>&nbsp;</h2>
          <p>Second line</p>
        </div>
      </div>
    </div>
  </div>
  <ol class="relative w-full space-y-0 ms-3">
    <li>
      <p class="text-sm">第 1 站</p>
      <div><div><p class="text-lg">梅窩碼頭</p></div></div>
      <p class="text-xs">梅窩碼頭</p>
      <dl>
        <div><dt>平日車資:</dt><dd>12.7</dd></div>
        <div><dt>假日車資:</dt><dd>21.4</dd></div>
      </dl>
    </li>
    <li>
      <p class="text-sm">第 7 站</p>
      <div><div><p class="text-lg">荔枝園</p></div></div>
      <p class="text-xs">嶼南道</p>
      <dl>
        <div><dt>平日車資:</dt><dd>12.7</dd></div>
        <div><dt>假日車資:</dt><dd>21.4</dd></div>
      </dl>
    </li>
  </ol>
  <div class="space-y-3">
    <div>
      <h3>Route notice</h3>
      <p>發佈日期 : 2026-05-07</p>
      <a href="/tc/news/630">閱讀更多</a>
    </div>
    <div>
      <h3>Second route notice</h3>
      <p>發佈日期 : 2026-05-08</p>
      <a href="/tc/news/631">閱讀更多</a>
    </div>
  </div>
  <section class="space-y-4">
    <div></div>
    <div>
      <div>
        <div>
          <div class="ck-content" aria-label="Timetable">
            <p>Monday to Saturday</p>
            <table>
              <tr><td>06:00</td><td></td></tr>
              <tr><td>06:35</td><td>T</td></tr>
            </table>
            <p>Sunday &amp; Public Holiday</p>
            <table>
              <tr><td>06:30</td><td></td></tr>
              <tr><td>07:15</td><td>T</td></tr>
            </table>
            <p>T via Mui Wo Old Town</p>
          </div>
        </div>
      </div>
    </div>
  </section>
</div>
''';

RouteEntry _route() {
  return RouteEntry(
    key: '1+1+test',
    slug: '1-nlb',
    route: '1',
    serviceType: '1',
    companies: const <BusCompany>[BusCompany.nlb],
    orig: const Terminal(en: 'Mui Wo', zh: '梅窩'),
    dest: const Terminal(en: 'Tai O', zh: '大澳'),
    stops: const <BusCompany, List<String>>{
      BusCompany.nlb: <String>['A', 'B'],
    },
    bound: const <BusCompany, String>{BusCompany.nlb: 'O'},
    seq: 2,
    nlbId: '123',
  );
}

void main() {
  test('extracts the NLB timetable HTML without parsing it', () {
    final String? html = parseNlbTimetableHtml(_sampleHtml);

    expect(html, isNotNull);
    expect(html, contains('Monday to Saturday'));
    expect(html, contains('<table>'));
    expect(html, contains('T via Mui Wo Old Town'));
    expect(html, contains('nlb-timetable-legend'));
    expect(html, isNot(contains('nlb-fare-note')));
    expect(html, isNot(contains('Fare note example')));
    expect(html, contains('備註'));
    expect(html!.indexOf('備註'), lessThan(html.indexOf('Monday to Saturday')));
  });

  test('parses all NLB route name spans', () {
    final String? name = parseNlbRouteName('''
      <div class="mt-3">
        <p>全程行車時間約為 34 分鐘</p>
        <span>上午繁忙時間服務, 上課日服務</span>
        <span>循環線</span>
      </div>
    ''');

    expect(name, '上午繁忙時間服務, 上課日服務 · 循環線');
  });

  test('returns no NLB route name without name spans', () {
    expect(
      parseNlbRouteName('<div class="mt-3"><p>Journey time</p></div>'),
      isNull,
    );
  });

  test('parses all NLB route notice cards', () {
    final List<NlbRouteNotice> notices = parseNlbRouteNotices('''
      <div class="space-y-3">
        <div>
          <div><h3>嶼巴路線B6S延續學生及小童優惠</h3></div>
          <p>發佈日期 : 2026-05-07</p>
          <a href="/tc/news/630">閱讀更多</a>
        </div>
        <div>
          <div><h3>長者免費乘車日</h3></div>
          <p>發佈日期 : 2026-05-08</p>
          <a href="/tc/news/631">閱讀更多</a>
        </div>
      </div>
      ''', baseUri: Uri.parse('https://www.nlb.com.hk/tc/route/111'));

    expect(notices, hasLength(2));
    expect(notices.first.title, '嶼巴路線B6S延續學生及小童優惠');
    expect(notices.first.date, '發佈日期 : 2026-05-07');
    expect(notices.first.url, Uri.parse('https://www.nlb.com.hk/tc/news/630'));
    expect(notices.last.title, '長者免費乘車日');
    expect(notices.last.url, Uri.parse('https://www.nlb.com.hk/tc/news/631'));
  });

  test('parses NLB stop fares and nearby locations', () {
    final NlbRoutePageData? data = parseNlbRouteData('''
      <ol class="relative w-full space-y-0 ms-3">
        <li>
          <p class="text-sm">第 1 站</p>
          <div><div><p class="text-lg">梅窩碼頭</p></div></div>
          <p class="text-xs">梅窩碼頭</p>
          <dl>
            <div><dt>平日車資:</dt><dd>12.7</dd></div>
            <div><dt>假日車資:</dt><dd>21.4</dd></div>
          </dl>
        </li>
        <li>
          <p class="text-sm">第 7 站</p>
          <div><div><p class="text-lg">荔枝園</p></div></div>
          <p class="text-xs">嶼南道</p>
          <dl>
            <div><dt>平日車資:</dt><dd>12.7</dd></div>
            <div><dt>假日車資:</dt><dd>21.4</dd></div>
          </dl>
        </li>
      </ol>
    ''');

    expect(data, isNotNull);
    expect(data!.stops, hasLength(2));
    expect(data.stops[1]?.name, '梅窩碼頭');
    expect(data.stops[1]?.weekdayFare, '12.7');
    expect(data.stops[1]?.holidayFare, '21.4');
    expect(data.stops[7]?.location, '嶼南道');
  });

  test('parses the NLB fare note without blank lines', () {
    final NlbRoutePageData? data = parseNlbRouteData(_sampleHtml);

    expect(data?.fareNote, 'Fare note example\nSecond line');
  });

  test('fetches one NLB page for timetable, fares, and notices', () async {
    int requests = 0;
    final NlbTimetableService service = NlbTimetableService(
      client: MockClient((http.Request request) async {
        requests++;
        return http.Response.bytes(utf8.encode(_sampleHtml), 200);
      }),
    );

    await service.prefetchPage(_route(), 'tc');
    expect(requests, 1);

    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      service.fetchTimetableHtml(_route(), 'tc'),
      service.fetchRouteData(_route(), 'tc'),
      service.fetchRouteNotices(_route(), 'tc'),
    ]);

    expect(results[0], isNotNull);
    expect(results[1], isNotNull);
    expect((results[2]! as List<NlbRouteNotice>), hasLength(2));
    expect(requests, 1);

    await service.fetchRouteNotices(_route(), 'tc');
    await service.fetchRouteData(_route(), 'tc');
    await service.fetchTimetableHtml(_route(), 'tc');
    expect(requests, 1);
  });

  test('uses the language-specific NLB page URL', () async {
    late Uri requested;
    final NlbTimetableService service = NlbTimetableService(
      client: MockClient((http.Request request) async {
        requested = request.url;
        return http.Response.bytes(utf8.encode(_sampleHtml), 200);
      }),
    );

    final String? html = await service.fetchTimetableHtml(_route(), 'en');

    expect(html, isNotNull);
    expect(html, contains('Notes'));
    expect(requested.path, '/en/route/123');
    expect(requested.host, 'www.nlb.com.hk');
  });
}
