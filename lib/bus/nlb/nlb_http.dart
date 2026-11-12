import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

class NlbHttp {
  static Future<SecurityContext>? _securityContextFuture;

  static Future<String?> get(Uri uri, {Map<String, String>? headers}) async {
    final Uint8List? bytes = await getBytes(uri, headers: headers);
    if (bytes == null) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  static Future<Uint8List?> getBytes(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final SecurityContext context = await (_securityContextFuture ??=
        _createSecurityContext());
    final SecureSocket socket = await SecureSocket.connect(
      uri.host,
      443,
      context: context,
      supportedProtocols: const <String>['http/1.1'],
      timeout: const Duration(seconds: 20),
    );
    try {
      final String target = uri.hasQuery
          ? '${uri.path}?${uri.query}'
          : uri.path;
      final Map<String, String> requestHeaders = <String, String>{
        'Host': uri.host,
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
        'Connection': 'close',
        ...?headers,
      };
      final StringBuffer request = StringBuffer()
        ..write('GET ')
        ..write(target)
        ..write(' HTTP/1.1\r\n');
      for (final MapEntry<String, String> header in requestHeaders.entries) {
        request
          ..write(header.key)
          ..write(': ')
          ..write(header.value)
          ..write('\r\n');
      }
      request.write('\r\n');
      socket.add(latin1.encode(request.toString()));
      await socket.flush();
      final List<int> bytes = await socket
          .fold<List<int>>(<int>[], (List<int> data, List<int> chunk) {
            data.addAll(chunk);
            return data;
          })
          .timeout(const Duration(seconds: 25));
      return _decodeResponse(bytes);
    } finally {
      socket.destroy();
    }
  }

  static Future<SecurityContext> _createSecurityContext() async {
    final ByteData data = await rootBundle.load(
      'assets/certs/godaddy_g2_bundle.pem',
    );
    return SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificatesBytes(data.buffer.asUint8List());
  }
}

Uint8List? _decodeResponse(List<int> bytes) {
  int headerEnd = -1;
  for (int index = 0; index + 3 < bytes.length; index++) {
    if (bytes[index] == 13 &&
        bytes[index + 1] == 10 &&
        bytes[index + 2] == 13 &&
        bytes[index + 3] == 10) {
      headerEnd = index;
      break;
    }
  }
  if (headerEnd < 0) return null;
  final String headerText = latin1.decode(bytes.sublist(0, headerEnd));
  final List<String> lines = headerText.split('\r\n');
  if (lines.isEmpty) return null;
  final List<String> statusParts = lines.first.split(' ');
  if (statusParts.length < 2 || statusParts[1] != '200') return null;
  final Map<String, String> headers = <String, String>{};
  for (final String line in lines.skip(1)) {
    final int colon = line.indexOf(':');
    if (colon <= 0) continue;
    headers[line.substring(0, colon).trim().toLowerCase()] = line
        .substring(colon + 1)
        .trim();
  }
  final List<int> body = bytes.sublist(headerEnd + 4);
  if (headers['content-encoding']?.toLowerCase().contains('gzip') ?? false) {
    return Uint8List.fromList(gzip.decode(body));
  }
  if (headers['transfer-encoding']?.toLowerCase().contains('chunked') ??
      false) {
    final List<int>? decoded = _decodeChunked(body);
    if (decoded == null) return null;
    return Uint8List.fromList(decoded);
  }
  final int? length = int.tryParse(headers['content-length'] ?? '');
  final List<int> content = length != null && length <= body.length
      ? body.sublist(0, length)
      : body;
  return Uint8List.fromList(content);
}

List<int>? _decodeChunked(List<int> body) {
  final List<int> result = <int>[];
  int offset = 0;
  int lineEnd(int start) {
    for (int index = start; index + 1 < body.length; index++) {
      if (body[index] == 13 && body[index + 1] == 10) return index;
    }
    return -1;
  }

  while (offset < body.length) {
    final int end = lineEnd(offset);
    if (end < 0) return null;
    final String sizeText = latin1
        .decode(body.sublist(offset, end))
        .split(';')
        .first
        .trim();
    final int? size = int.tryParse(sizeText, radix: 16);
    if (size == null) return null;
    offset = end + 2;
    if (size == 0) return result;
    if (offset + size > body.length) return null;
    result.addAll(body.sublist(offset, offset + size));
    offset += size;
    if (offset + 1 < body.length &&
        body[offset] == 13 &&
        body[offset + 1] == 10) {
      offset += 2;
    }
  }
  return result;
}
