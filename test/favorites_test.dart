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
}
