// Title casing for names that are provided in uppercase by the KMB API.
//
// The special cases mirror the shared hkbus toProperCase rules:
// https://github.com/hkbus/notice/blob/gh-pages/toProperCase.json
const List<String> _specialCases = [
  '1st',
  'and',
  'apm',
  'AsiaWorld-Expo',
  'AsiaWorld Expo',
  'BBI',
  'CAD',
  'CCC',
  "Choi Wan St. Joseph's School",
  'CICTA',
  'CITIC',
  'CLP',
  'CNT',
  'DHL',
  'EKCC',
  'EMSD',
  'FCA',
  'for the',
  'for',
  'GO PARK',
  'GTC',
  'H.K.',
  'H.K.U.S.T.',
  'H.K.U.S.T',
  'HACTL',
  'HK',
  'HKCEC',
  'HKCECE',
  'HKFYG',
  'HKSYU',
  'HKU',
  'HQ',
  'HSBC',
  'HZMB',
  'IFC',
  'II',
  'iSquare',
  'i.UniQ',
  'IVE',
  'JPC',
  'KLN',
  'KMB',
  'Li K.S.',
  'LMC',
  'LOHAS',
  'LR',
  'MacLehose',
  'MEGA Plus',
  'MTR',
  'near',
  'Ngau Chi Wan Market',
  'NOVO LAND',
  'of the',
  'of',
  'OSH',
  'PARK YOHO',
  'QESOSA',
  'S.K.H.',
  'S.L.Y.',
  'SKYCITY',
  'SkyCity Marriott',
  'SL',
  'SOGO',
  'St.',
  'STK',
  'Sub-station',
  'T.K.O.',
  'TKO',
  'TWGHs',
  'UC',
  'YMCA',
  'YOHO',
  'YOHO MALL',
  'YOHO MIX',
];

final List<String> _sortedSpecialCases = [..._specialCases]
  ..sort((a, b) => b.length.compareTo(a.length));

final RegExp _wordPattern = RegExp(r"[A-Za-z]+(?:'[A-Za-z]+)*");
final RegExp _codePattern = RegExp(r'([A-Za-z]{1,2})(\d{1,3})([A-Za-z])?');
final RegExp _bbiSeparatorPattern = RegExp(
  r'\bBBI\b[ \t]*[-\u2013\u2014][ \t]*',
  caseSensitive: false,
);

String toProperCase(String text) {
  if (text.isEmpty) return text;
  final String protected = _protectSpecialCases(text);
  final String titled = _titleCaseWords(protected);
  final String coded = _applyCodeCase(titled);
  return _normaliseBbi(_restoreSpecialCases(coded));
}

String _normaliseBbi(String text) {
  return text.replaceAll(_bbiSeparatorPattern, 'BBI - ');
}

String _protectSpecialCases(String text) {
  final String lower = text.toLowerCase();
  final StringBuffer result = StringBuffer();
  int cursor = 0;

  while (cursor < text.length) {
    int? bestIndex;
    String? bestValue;

    for (final String value in _sortedSpecialCases) {
      final String needle = value.toLowerCase();
      int index = lower.indexOf(needle, cursor);
      while (index >= 0) {
        final bool beforeOk =
            index == 0 || !_isWordChar(text.codeUnitAt(index - 1));
        final bool afterOk =
            index + value.length >= text.length ||
            !_isWordChar(text.codeUnitAt(index + value.length));
        if (beforeOk && afterOk) {
          if (bestIndex == null ||
              index < bestIndex ||
              (index == bestIndex && value.length > bestValue!.length)) {
            bestIndex = index;
            bestValue = value;
          }
          break;
        }
        index = lower.indexOf(needle, index + 1);
      }
    }

    if (bestIndex == null || bestValue == null) {
      result.write(text.substring(cursor));
      break;
    }

    result.write(text.substring(cursor, bestIndex));
    result.write(_placeholder(_specialCases.indexOf(bestValue)));
    cursor = bestIndex + bestValue.length;
  }

  return result.toString();
}

String _titleCaseWords(String text) {
  return text.replaceAllMapped(_wordPattern, (Match match) {
    final String word = match.group(0)!;
    final bool afterDigit =
        match.start > 0 && _isDigit(text.codeUnitAt(match.start - 1));
    if (afterDigit) return word.toLowerCase();

    final int apostrophe = word.indexOf("'");
    if (apostrophe == 1 && word.length > 2) {
      return word[0].toUpperCase() +
          word[1] +
          word[2].toUpperCase() +
          word.substring(3).toLowerCase();
    }
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  });
}

String _applyCodeCase(String text) {
  return text.replaceAllMapped(_codePattern, (Match match) {
    final String letters = match.group(1)!.toUpperCase();
    final String digits = match.group(2)!;
    final String suffix = match.group(3)?.toLowerCase() ?? '';
    return '$letters$digits$suffix';
  });
}

String _restoreSpecialCases(String text) {
  return text.replaceAllMapped(RegExp('\uE000(\\d+)\uE001'), (Match match) {
    final int index = int.parse(match.group(1)!);
    return _specialCases[index];
  });
}

String _placeholder(int index) => '\uE000$index\uE001';

bool _isWordChar(int codeUnit) {
  return (codeUnit >= 48 && codeUnit <= 57) ||
      (codeUnit >= 65 && codeUnit <= 90) ||
      (codeUnit >= 97 && codeUnit <= 122);
}

bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
