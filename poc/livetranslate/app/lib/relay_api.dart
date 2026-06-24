import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// 릴레이의 REST 엔드포인트(/speak, /ocr) 클라이언트.
///
/// WebSocket 주소(wss://·ws://)를 https://·http:// 로 바꿔 호출한다.
class RelayApi {
  final String wsBaseUrl; // 설정의 릴레이 주소(wss://host 또는 ws://host)
  final String token;

  RelayApi(this.wsBaseUrl, this.token);

  String get _httpBase {
    final b = wsBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (b.startsWith('wss://')) return 'https://${b.substring(6)}';
    if (b.startsWith('ws://')) return 'http://${b.substring(5)}';
    return b;
  }

  Uri _uri(String path) => Uri.parse(
      '$_httpBase$path${token.isNotEmpty ? '?token=${Uri.encodeComponent(token)}' : ''}');

  Uri _uriQ(String path, Map<String, String> params) =>
      Uri.parse('$_httpBase$path').replace(queryParameters: {
        ...params,
        if (token.isNotEmpty) 'token': token,
      });

  Map<String, String> get _json => {'Content-Type': 'application/json'};

  /// 환율 조회: 1 [base] = rate [quote].
  Future<({double rate, int ts})> rate(String base, String quote) async {
    final r = await http.get(_uriQ('/rate', {'base': base, 'quote': quote}));
    if (r.statusCode != 200) {
      throw Exception('rate ${r.statusCode}: ${r.body}');
    }
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return (rate: (d['rate'] as num).toDouble(), ts: (d['ts'] as num).toInt());
  }

  /// 흥정 문장 생성(대상 언어) + 음성.
  Future<({String text, Uint8List audio})> bargain(
      num amount, String currency, String targetLang) async {
    final r = await http.post(_uri('/bargain'),
        headers: _json,
        body: jsonEncode(
            {'amount': amount, 'currency': currency, 'targetLang': targetLang}));
    if (r.statusCode != 200) {
      throw Exception('bargain ${r.statusCode}: ${r.body}');
    }
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return (
      text: d['text'] as String? ?? '',
      audio: base64Decode(d['audio'] as String),
    );
  }

  /// 문구 텍스트 → 대상 언어 번역 + 음성(PCM16/24kHz).
  Future<({String translated, Uint8List audio})> speak(
      String text, String targetLang) async {
    final r = await http.post(_uri('/speak'),
        headers: _json,
        body: jsonEncode({'text': text, 'targetLang': targetLang}));
    if (r.statusCode != 200) {
      throw Exception('speak ${r.statusCode}: ${r.body}');
    }
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return (
      translated: d['translated'] as String? ?? '',
      audio: base64Decode(d['audio'] as String),
    );
  }

  /// 이미지(JPEG) 속 텍스트 인식 + 대상 언어 번역.
  Future<({String original, String translated})> ocr(
      Uint8List jpeg, String targetLang) async {
    final r = await http.post(_uri('/ocr'),
        headers: _json,
        body: jsonEncode(
            {'image': base64Encode(jpeg), 'targetLang': targetLang}));
    if (r.statusCode != 200) {
      throw Exception('ocr ${r.statusCode}: ${r.body}');
    }
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return (
      original: d['original'] as String? ?? '',
      translated: d['translated'] as String? ?? '',
    );
  }
}
