import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:hktransports/bus/model/favorite_group.dart';

void main() {
  test('favorite entries keep the selected stop', () {
    final FavoriteEntry entry = FavoriteEntry.parse('route-key|12');
    expect(entry.routeKey, 'route-key');
    expect(entry.seq, 12);
    expect(entry.storageKey, 'route-key|12');
  });

  test('old favorite entries fall back to the first stop', () {
    final FavoriteEntry entry = FavoriteEntry.parse('route-key');
    expect(entry.routeKey, 'route-key');
    expect(entry.seq, 0);
  });

  test('scheduled remarks are detected for the clock icon', () {
    const BusEta scheduled = BusEta(
      company: BusCompany.nlb,
      eta: null,
      remarkZh: '未開出',
      remarkEn: 'Scheduled',
      destZh: '',
      destEn: '',
      etaSeq: 1,
    );
    const BusEta normal = BusEta(
      company: BusCompany.kmb,
      eta: null,
      remarkZh: '',
      remarkEn: '',
      destZh: '',
      destEn: '',
      etaSeq: 1,
    );
    expect(scheduled.isScheduledLike, isTrue);
    expect(normal.isScheduledLike, isFalse);
  });

  test('delayed journeys expose the stop where the bus is stuck', () {
    const BusEta delayed = BusEta(
      company: BusCompany.kmb,
      eta: null,
      remarkZh: '受阻於翠林邨 (TK201)',
      remarkEn: 'Delayed journey from TSUI LAM ESTATE (TK201)',
      destZh: '',
      destEn: '',
      etaSeq: 1,
    );
    expect(delayed.isDelayedJourney, isTrue);
    expect(delayed.delayedFromStopCode, 'TK201');

    const Map<String, int> stopIndexByCode = {'TK201': 21};
    expect(
      delayed.canShowDelayedEta(
        stopIndex: 22,
        stopIndexByCode: stopIndexByCode,
        minutes: 4,
      ),
      isTrue,
    );
    expect(
      delayed.canShowDelayedEta(
        stopIndex: 22,
        stopIndexByCode: stopIndexByCode,
        minutes: 5,
      ),
      isFalse,
    );
    expect(
      delayed.canShowDelayedEta(
        stopIndex: 23,
        stopIndexByCode: stopIndexByCode,
        minutes: 2,
      ),
      isFalse,
    );
  });

  test('delayed journeys without a stuck stop only show a status', () {
    const BusEta delayed = BusEta(
      company: BusCompany.kmb,
      eta: null,
      remarkZh: '受阻於港運城',
      remarkEn: 'Delayed journey from ISLAND PLACE',
      destZh: '',
      destEn: '',
      etaSeq: 1,
    );
    expect(delayed.isDelayedJourney, isTrue);
    expect(delayed.delayedFromStopCode, isNull);
    expect(
      delayed.canShowDelayedEta(
        stopIndex: 22,
        stopIndexByCode: const {'TK201': 21},
        minutes: 1,
      ),
      isFalse,
    );
  });

  test('normal remarks are not treated as delayed journeys', () {
    const BusEta normal = BusEta(
      company: BusCompany.kmb,
      eta: null,
      remarkZh: '原定班次',
      remarkEn: 'Scheduled Bus',
      destZh: '',
      destEn: '',
      etaSeq: 1,
    );
    expect(normal.isDelayedJourney, isFalse);
    expect(normal.delayedFromStopCode, isNull);
  });
}
