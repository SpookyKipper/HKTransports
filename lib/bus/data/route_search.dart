final RegExp _routeCharPattern = RegExp(r'[A-Z0-9]');

/// Returns the characters that can follow [prefix] in at least one route
/// number. Non-alphanumeric characters are ignored.
Set<String> possibleRouteCharsFor(
  Iterable<String> routeNumbers,
  String prefix,
) {
  final String normalised = prefix.trim().toUpperCase();
  final Set<String> result = {};
  for (final String raw in routeNumbers) {
    final String number = raw.trim().toUpperCase();
    if (number.length <= normalised.length) continue;
    if (!number.startsWith(normalised)) continue;
    final String next = number.substring(
      normalised.length,
      normalised.length + 1,
    );
    if (_routeCharPattern.hasMatch(next)) {
      result.add(next);
    }
  }
  return result;
}
