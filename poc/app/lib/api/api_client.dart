import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/exposure_media.dart';
import '../models/training_session.dart';
import '../models/vas_record.dart';
import '../models/vas_trend.dart';

/// 백엔드 REST 클라이언트.
///
/// Base URL은 [baseUrl] 상수에서 변경한다.
/// - Android 에뮬레이터에서 로컬 백엔드 접속 시: http://10.0.2.2:8000/api/v1
/// - iOS 시뮬레이터 / 데스크톱 / 웹: http://localhost:8000/api/v1
class ApiClient {
  /// 백엔드 기본 주소.
  ///
  /// 빌드 시 `--dart-define=API_BASE_URL=https://api.example.com/api/v1` 로 주입한다.
  /// 미주입 시 로컬 개발 기본값(localhost) 사용.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://urge-surfing-api.onrender.com/api/v1',
  );

  final http.Client _http;

  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  Map<String, String> get _jsonHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// 공통 응답 처리: 2xx면 디코딩, 아니면 예외.
  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw ApiException(res.statusCode, res.body);
  }

  /// GET /exposure-media → 노출 자극 목록
  Future<List<ExposureMedia>> fetchExposureMedia() async {
    final res = await _http.get(_uri('/exposure-media'), headers: _jsonHeaders);
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => ExposureMedia.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /training-sessions → 세션 생성
  /// [sessionType]: erp_exposure | urge_surfing
  Future<TrainingSession> createSession({
    required String sessionType,
    int? mediaId,
  }) async {
    final res = await _http.post(
      _uri('/training-sessions'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'session_type': sessionType,
        if (mediaId != null) 'media_id': mediaId,
      }),
    );
    return TrainingSession.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// PATCH /training-sessions/{id} → 세션 완료 처리
  Future<TrainingSession> completeSession(int sessionId) async {
    final res = await _http.patch(
      _uri('/training-sessions/$sessionId'),
      headers: _jsonHeaders,
      body: jsonEncode({'completed': true}),
    );
    return TrainingSession.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// POST /training-sessions/{id}/vas → VAS 점수 기록
  Future<VasRecord> recordVas({
    required int sessionId,
    required String phase, // pre | post
    required int vasValue, // 0~10
  }) async {
    final res = await _http.post(
      _uri('/training-sessions/$sessionId/vas'),
      headers: _jsonHeaders,
      body: jsonEncode({'phase': phase, 'vas_value': vasValue}),
    );
    return VasRecord.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// POST /urge-surfing → 파도타기 결과 전송
  /// [outcome]: success | relapse | aborted
  Future<Map<String, dynamic>> submitUrgeSurfing({
    required int sessionId,
    required int peakUrge,
    required String outcome,
    required String copingSkill,
    required int durationSec,
  }) async {
    final res = await _http.post(
      _uri('/urge-surfing'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'session_id': sessionId,
        'peak_urge': peakUrge,
        'outcome': outcome,
        'coping_skill': copingSkill,
        'duration_sec': durationSec,
      }),
    );
    return (_decode(res) as Map<String, dynamic>);
  }

  /// GET /dashboard/vas-trend → 일자별 갈망 추세
  Future<List<VasTrendPoint>> fetchVasTrend() async {
    final res = await _http.get(
      _uri('/dashboard/vas-trend'),
      headers: _jsonHeaders,
    );
    final data = _decode(res) as List<dynamic>;
    return data
        .map((e) => VasTrendPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void dispose() => _http.close();
}

/// API 오류 표현.
class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
