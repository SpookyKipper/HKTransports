import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/nlb/nlb_timetable_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const String _sampleHtml = '''
<div>
  <div></div>
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
  );
}

void main() {
  test('parses NLB timetable sections and notes', () {
    final NlbTimetable? timetable = parseNlbTimetable(_sampleHtml);

    expect(timetable, isNotNull);
    expect(timetable!.sections, hasLength(2));
    expect(timetable.sections[0].title, 'Monday to Saturday');
    expect(timetable.sections[0].rows, hasLength(2));
    expect(timetable.sections[0].rows[1].note, 'T');
    expect(timetable.notes, <String>['T via Mui Wo Old Town']);
  });

  test('uses the language-specific NLB page URL', () async {
    late Uri requested;
    final NlbTimetableService service = NlbTimetableService(
      client: MockClient((http.Request request) async {
        requested = request.url;
        return http.Response(_sampleHtml, 200);
      }),
    );

    final NlbTimetable? timetable = await service.fetch(_route(), 'en');

    expect(timetable, isNotNull);
    expect(requested.path, '/en/route/1');
    expect(requested.host, 'www.nlb.com.hk');
  });
}
