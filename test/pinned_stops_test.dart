import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/state/pinned_stops.dart';

void main() {
  test('pins and unpins stations by route and sequence', () {
    final PinnedStopsController controller = PinnedStopsController();
    const PinnedStation station = PinnedStation(routeKey: '690+1', seq: 3);

    expect(controller.stations, isEmpty);
    controller.toggle(station);
    expect(controller.stations.single, station);
    expect(controller.contains('690+1', 3), isTrue);

    controller.toggle(station);
    expect(controller.stations, isEmpty);
    expect(controller.contains('690+1', 3), isFalse);
  });

  test('removing a station leaves other pins intact', () {
    final PinnedStopsController controller = PinnedStopsController();
    const PinnedStation first = PinnedStation(routeKey: '690+1', seq: 0);
    const PinnedStation second = PinnedStation(routeKey: '690+1', seq: 4);

    controller.toggle(first);
    controller.toggle(second);
    controller.remove(first);

    expect(controller.stations, [second]);
  });
}
