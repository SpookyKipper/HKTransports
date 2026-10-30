import 'package:flutter_test/flutter_test.dart';
import 'package:hktransports/bus/data/route_search.dart';

void main() {
  test('possible next characters after A', () {
    final List<String> routes = [
      'A11',
      'A12',
      'A13',
      'A14',
      'A15',
      'A21',
      'A31',
      'A41',
      'AEL',
      '1A',
      '2',
    ];
    expect(possibleRouteCharsFor(routes, 'A'), {'1', '2', '3', '4', 'E'});
  });

  test('empty prefix returns all possible first characters', () {
    expect(possibleRouteCharsFor(['1A', 'A11', 'E11', 'N21'], ''), {
      '1',
      'A',
      'E',
      'N',
    });
  });

  test('prefix matching is case insensitive and allows no match', () {
    expect(possibleRouteCharsFor(['A11', 'A12'], 'a'), {'1'});
    expect(possibleRouteCharsFor(['A11', 'A12'], 'A1'), {'1', '2'});
    expect(possibleRouteCharsFor(['A11', 'A12'], 'Z'), isEmpty);
  });

  test('non alphanumeric next characters are ignored', () {
    expect(possibleRouteCharsFor(['1-A', '1 B', '1A'], '1'), {'A'});
  });
}
