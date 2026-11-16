import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hktransports/bus/eta/clients/kmb_eta_client.dart';
import 'package:hktransports/bus/eta/eta_models.dart';
import 'package:hktransports/bus/kmb/kmb_eta_secret.dart';
import 'package:hktransports/bus/model/bus_models.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/stream/sic.dart';

class KmbEtaV3Client {
  KmbEtaV3Client({
    http.Client? client,
    String? seedHex,
    DateTime Function()? now,
    Uint8List Function()? randomBytes,
  }) : _client = client ?? http.Client(),
       _seed = _parseSeed(seedHex ?? kmbEtaSeedHex),
       _now = now ?? DateTime.now,
       _randomBytes = randomBytes;

  final http.Client _client;
  final Uint8List? _seed;
  final DateTime Function() _now;
  final Uint8List Function()? _randomBytes;
  final Random _secureRandom = Random.secure();

  bool get isConfigured => _seed != null;

  Future<Map<int, List<BusEta>>?> fetchRouteEtas(
    RouteEntry route, {
    required String language,
  }) async {
    final Uint8List? seed = _seed;
    if (seed == null) return null;

    final List<String>? stops = route.stops[BusCompany.kmb];
    if (stops == null || stops.isEmpty) return null;

    final int bound = _siteBound(route.boundFor(BusCompany.kmb));
    final int? serviceType = int.tryParse(route.serviceType.trim());
    if (bound == 0 || serviceType == null) return null;

    final String routeNumber = route.route.trim();
    if (routeNumber.isEmpty) return null;

    final List<int> siteSeqs = stops.length == 1
        ? const <int>[0]
        : <int>[
            for (int index = 0; index < stops.length - 1; index++) index,
            999,
          ];

    final Map<int, List<BusEta>> result = <int, List<BusEta>>{};
    for (int start = 0; start < siteSeqs.length; start += 32) {
      final int end = min(start + 32, siteSeqs.length);
      final List<int> chunk = siteSeqs.sublist(start, end);
      final List<dynamic>? rows = await _requestChunk(
        seed: seed,
        route: routeNumber,
        bound: bound,
        serviceType: serviceType,
        seqs: chunk,
        language: language,
      );
      if (rows == null) return null;

      for (final dynamic value in rows) {
        if (value is! Map<String, dynamic>) continue;
        if ((value['responsecode'] as num?)?.toInt() != 0) continue;
        final int? seq = (value['seq'] as num?)?.toInt();
        if (seq == null) continue;
        final int index = seq == 999 ? stops.length - 1 : seq;
        if (index < 0 || index >= stops.length) continue;
        result[index] = _parseEtaRows(route, value['eta']);
      }
    }
    return result;
  }

  Future<List<dynamic>?> _requestChunk({
    required Uint8List seed,
    required String route,
    required int bound,
    required int serviceType,
    required List<int> seqs,
    required String language,
  }) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      final Uint8List counter = Uint8List(16);
      final Uint8List random = _randomBytes?.call() ?? _random(6);
      if (random.length != 6) continue;
      counter.setRange(10, 16, random);
      final int ctr = _readUint48(random);

      final String timestamp = _timestamp(_now());
      final String apiKey = _hex(
        _encrypt(seed, counter, utf8.encode(timestamp)),
      );
      final String query =
          'lang=${language == 'en' ? 'en' : 'tc'}'
          '&route=${List<String>.filled(seqs.length, route).join(',')}'
          '&bound=${List<String>.filled(seqs.length, '$bound').join(',')}'
          '&service_type=${List<String>.filled(seqs.length, '$serviceType').join(',')}'
          '&stop_seq=${seqs.join(',')}'
          '&apiKey=$apiKey'
          '&ctr=$ctr';
      final String data = _hex(_encrypt(seed, counter, utf8.encode('?$query')));

      final http.Response response;
      try {
        response = await _client
            .post(
              Uri.parse('https://etav3.kmb.hk/?action=geteta'),
              headers: const <String, String>{
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, Object>{'d': data, 'ctr': ctr}),
            )
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        return null;
      }

      if (response.statusCode == 200) {
        try {
          final dynamic decoded = jsonDecode(
            utf8.decode(response.bodyBytes, allowMalformed: true),
          );
          return decoded is List<dynamic> ? decoded : null;
        } catch (_) {
          return null;
        }
      }
      if (response.statusCode != 403 || attempt == 1) return null;
    }
    return null;
  }

  List<BusEta> _parseEtaRows(RouteEntry route, dynamic raw) {
    if (raw is! List<dynamic>) return const <BusEta>[];
    final List<BusEta> result = <BusEta>[];
    for (int index = 0; index < raw.length; index++) {
      final dynamic value = raw[index];
      if (value is! Map<String, dynamic>) continue;
      final String display = (value['t'] ?? '').toString().trim();
      if (_isCitybusRow(display)) continue;
      final RegExpMatch? match = RegExp(
        r'^(\d{1,2}:\d{2})\s*(.*)$',
      ).firstMatch(display);
      final String clock = match?.group(1) ?? '';
      final String rawRemark = match?.group(2) ?? display;
      final bool solarPowered =
          display.contains('☘') || rawRemark.contains('☘');
      final String remark = _cleanRemark(rawRemark);
      final DateTime? eta =
          parseEtaTime(value['ex']?.toString()) ?? _parseClock(clock);
      final num? distance = value['dis'] is num
          ? value['dis'] as num
          : num.tryParse((value['dis'] ?? '').toString());
      result.add(
        BusEta(
          company: BusCompany.kmb,
          eta: eta,
          remarkZh: remark,
          remarkEn: remark,
          destZh: route.dest.zh,
          destEn: route.dest.en,
          etaSeq: index + 1,
          scheduled: _isScheduled(remark),
          distanceKm: distance == null ? null : distance.toDouble() / 1000.0,
          solarPowered: solarPowered,
          occupancyPercent: _occupancyPercent(value['ol']),
          doubleWheelchair: value['wifi']?.toString() == 'Y',
          kmbProprietary: true,
        ),
      );
    }
    return result;
  }

  DateTime? _parseClock(String clock) {
    final RegExpMatch? match = RegExp(
      r'^(\d{1,2}):(\d{2})$',
    ).firstMatch(clock.trim());
    if (match == null) return null;
    final int? hour = int.tryParse(match.group(1) ?? '');
    final int? minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    final DateTime now = hkNow();
    DateTime value = DateTime.utc(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).subtract(const Duration(hours: 8));
    final DateTime nowUtc = DateTime.now().toUtc();
    if (value.isBefore(nowUtc.subtract(const Duration(hours: 12)))) {
      value = value.add(const Duration(days: 1));
    }
    return value;
  }

  String _cleanRemark(String value) {
    String text = value.replaceAll('☘', '').trim();
    text = text.replaceFirst(
      RegExp(r'^(?:九巴|龍運|KMB|LWB|城巴|Citybus)(?:\s+|$)', caseSensitive: false),
      '',
    );
    text = text.replaceFirst(
      RegExp(r'\s+(?:九巴|龍運|KMB|LWB)$', caseSensitive: false),
      '',
    );
    return text.trim();
  }

  bool _isCitybusRow(String display) {
    return RegExp(
      r'(?:^|[\s·])(?:CTB|NWFB|Citybus|城巴)(?:$|[\s·])',
      caseSensitive: false,
    ).hasMatch(display);
  }

  int? _occupancyPercent(dynamic value) {
    switch (value?.toString()) {
      case 'E':
        return 0;
      case '2':
        return 20;
      case '5':
        return 50;
      case '8':
        return 80;
      case 'F':
        return 100;
      default:
        return null;
    }
  }

  bool _isScheduled(String remark) {
    final String lower = remark.toLowerCase();
    return lower.contains('scheduled') ||
        remark.contains('預定') ||
        remark.contains('原定');
  }

  int _siteBound(String? bound) {
    switch (bound) {
      case 'O':
        return 1;
      case 'I':
        return 2;
      default:
        return 0;
    }
  }

  Uint8List _random(int length) {
    final Uint8List bytes = Uint8List(length);
    for (int index = 0; index < length; index++) {
      bytes[index] = _secureRandom.nextInt(256);
    }
    return bytes;
  }

  int _readUint48(Uint8List bytes) {
    int value = 0;
    for (final int byte in bytes) {
      value = (value << 8) | byte;
    }
    return value;
  }

  String _timestamp(DateTime time) {
    final String value = time.toUtc().toIso8601String();
    return '${value.substring(0, 19)}Z';
  }

  Uint8List _encrypt(Uint8List seed, Uint8List counter, List<int> data) {
    final SICStreamCipher cipher = SICStreamCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(seed), counter));
    final Uint8List input = Uint8List.fromList(data);
    final Uint8List output = Uint8List(input.length);
    cipher.processBytes(input, 0, input.length, output, 0);
    return output;
  }

  String _hex(Uint8List bytes) {
    final StringBuffer result = StringBuffer();
    for (final int byte in bytes) {
      result.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return result.toString();
  }

  static Uint8List? _parseSeed(String value) {
    final String text = value.trim();
    if (!RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(text)) return null;
    final Uint8List result = Uint8List(16);
    for (int index = 0; index < 16; index++) {
      result[index] = int.parse(
        text.substring(index * 2, index * 2 + 2),
        radix: 16,
      );
    }
    return result;
  }
}
