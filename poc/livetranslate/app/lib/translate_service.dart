import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 통역 세션 상태.
enum TranslateState { idle, connecting, ready, reconnecting, error }

/// 릴레이를 경유한 실시간 음성 통역 서비스.
///
/// 흐름:
///   마이크(PCM16/16kHz) → WebSocket → 릴레이 → Gemini Live Translate
///   → 릴레이 → WebSocket → 스피커(PCM16/24kHz)
///
/// 녹음·재생 모두 flutter_sound 하나로 처리한다(federated 플러그인 의존성
/// 충돌 회피).
///
/// 중국(GFW) 환경 대비 복원력:
/// - **하트비트(ping/pong)**: GFW가 TCP는 살린 채 데이터만 끊는 경우를 감지.
/// - **워치독**: 일정 시간 수신이 없으면 죽은 연결로 보고 강제 재연결.
/// - **지수 백오프 자동 재연결**: 끊겨도 마이크/플레이어는 유지하고 소켓만 복구.
///
/// 릴레이 주소는 [relayBaseUrl] 로 주입한다(빌드 시 --dart-define).
/// 예: wss://my-relay.example.com  (중국 밖 VPS)
class TranslateService {
  /// 릴레이 WebSocket 기본 주소(빌드 시 --dart-define로 주입 가능).
  /// 런타임에 [start] 인자나 [relayUrl]로 덮어쓸 수 있다.
  static const String defaultRelayBaseUrl = String.fromEnvironment(
    'RELAY_BASE_URL',
    defaultValue: 'ws://10.0.2.2:8080', // Android 에뮬레이터 → 로컬 릴레이
  );

  /// 릴레이 접근 토큰 기본값(릴레이의 RELAY_TOKEN과 일치).
  static const String defaultRelayToken = String.fromEnvironment('RELAY_TOKEN');

  /// 실제 사용 중인 릴레이 주소/토큰(런타임 변경 가능).
  String relayUrl = defaultRelayBaseUrl;
  String token = defaultRelayToken;

  // 입력: Gemini Live API가 요구하는 16kHz mono PCM16.
  static const int _inputSampleRate = 16000;
  // 출력: Gemini가 내려주는 24kHz mono PCM16.
  static const int _outputSampleRate = 24000;

  // 복원력 파라미터.
  static const Duration _heartbeatInterval = Duration(seconds: 10);
  static const Duration _staleTimeout = Duration(seconds: 20);
  static const Duration _maxBackoff = Duration(seconds: 30);

  final _recorder = FlutterSoundRecorder();
  final _player = FlutterSoundPlayer();

  WebSocketChannel? _channel;
  StreamController<Uint8List>? _recordController;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<dynamic>? _wsSub;
  Timer? _heartbeatTimer;
  Timer? _watchdogTimer;
  Timer? _reconnectTimer;
  bool _playerOpened = false;
  bool _recorderOpened = false;

  // 세션 활성 여부(start~stop 사이). 재연결 루프의 가드.
  bool _active = false;
  int _reconnectAttempt = 0;
  DateTime _lastInbound = DateTime.now();

  // 재연결을 위해 시작 시 파라미터 보관.
  String _target = 'zh-CN';

  /// 상태 변화 알림.
  final _stateController = StreamController<TranslateState>.broadcast();
  Stream<TranslateState> get state => _stateController.stream;

  /// 수신 자막(있을 때) 알림.
  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcript => _transcriptController.stream;

  void _setState(TranslateState s) {
    if (!_stateController.isClosed) _stateController.add(s);
  }

  /// 통역 시작.
  ///
  /// [target] 번역 대상 언어코드(예: "zh-CN"). 입력 언어는 자동 감지된다.
  /// [relayUrl]/[token]을 주면 기본값 대신 사용한다(앱 내 입력 지원).
  Future<void> start({
    required String target,
    String? relayUrl,
    String? token,
  }) async {
    if (_active) return;
    _target = target;
    if (relayUrl != null && relayUrl.trim().isNotEmpty) {
      this.relayUrl = relayUrl.trim();
    }
    if (token != null) this.token = token.trim();
    _setState(TranslateState.connecting);

    if (!await Permission.microphone.request().isGranted) {
      _setState(TranslateState.error);
      throw StateError('마이크 권한이 필요합니다.');
    }

    _active = true;
    _reconnectAttempt = 0;
    await _openPlayer();
    await _startMic(); // 마이크는 한 번만 켜고 재연결과 무관하게 유지.
    _connect();
  }

  Future<void> _openPlayer() async {
    if (_playerOpened) return;
    await _player.openPlayer();
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: _outputSampleRate,
      interleaved: true,
      bufferSize: 8192,
    );
    _playerOpened = true;
  }

  Future<void> _startMic() async {
    if (!_recorderOpened) {
      await _recorder.openRecorder();
      _recorderOpened = true;
    }
    _recordController = StreamController<Uint8List>();
    _micSub = _recordController!.stream.listen((chunk) {
      // 연결돼 있을 때만 송신. 재연결 중 청크는 버린다(통역 공백 허용).
      final channel = _channel;
      if (channel != null) channel.sink.add(chunk);
    });
    await _recorder.startRecorder(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: _inputSampleRate,
      toStream: _recordController!.sink,
    );
  }

  void _connect() {
    final uri = Uri.parse('$relayUrl/ws/translate').replace(
      queryParameters: {
        'target': _target,
        if (token.isNotEmpty) 'token': token,
      },
    );

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    // 연결 성공 시점에 타이머 가동. 실패는 stream onError로도 잡히므로
    // 여기서는 성공 케이스만 처리한다.
    channel.ready.then((_) {
      if (!_active || _channel != channel) return;
      _lastInbound = DateTime.now();
      _startTimers();
    }).catchError((_) {/* onError/onDone에서 재연결 처리 */});

    _wsSub = channel.stream.listen(
      _onMessage,
      onError: (_) => _onDisconnected(channel),
      onDone: () => _onDisconnected(channel),
    );
  }

  void _onMessage(dynamic message) {
    _lastInbound = DateTime.now(); // 어떤 수신이든 연결 생존 신호.

    // 바이너리 = 번역된 오디오(PCM16/24kHz) → 즉시 재생.
    if (message is List<int>) {
      _player.uint8ListSink?.add(Uint8List.fromList(message));
      return;
    }
    // 텍스트(JSON) = 상태/자막/하트비트.
    if (message is String) {
      final data = jsonDecode(message) as Map<String, dynamic>;
      switch (data['type']) {
        case 'status':
          if (data['value'] == 'ready') {
            _reconnectAttempt = 0; // 성공적으로 붙었으니 백오프 리셋.
            _setState(TranslateState.ready);
          }
          break;
        case 'transcript':
          _transcriptController.add(data['text'] as String? ?? '');
          break;
        case 'pong':
          break; // _lastInbound 갱신으로 충분.
        case 'error':
          _setState(TranslateState.error);
          break;
      }
    }
  }

  void _startTimers() {
    _heartbeatTimer?.cancel();
    _watchdogTimer?.cancel();

    // 주기적 ping: 무음 구간에도 연결 생존을 확인.
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final channel = _channel;
      if (channel != null) {
        channel.sink.add(jsonEncode({'type': 'ping'}));
      }
    });

    // 워치독: 일정 시간 수신이 없으면(=pong도 안 옴) 죽은 연결로 간주.
    _watchdogTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_active) return;
      if (DateTime.now().difference(_lastInbound) > _staleTimeout) {
        _forceReconnect();
      }
    });
  }

  void _forceReconnect() {
    final channel = _channel;
    _teardownConnection();
    _onDisconnected(channel); // 동일 재연결 경로 재사용.
  }

  void _onDisconnected(WebSocketChannel? channel) {
    if (!_active) return;
    // 이미 다른 연결로 교체됐다면(중복 콜백) 무시.
    if (channel != null && channel != _channel && _channel != null) return;
    _teardownConnection();
    _scheduleReconnect();
  }

  void _teardownConnection() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _wsSub?.cancel();
    _wsSub = null;
    final ch = _channel;
    _channel = null;
    ch?.sink.close();
  }

  void _scheduleReconnect() {
    if (!_active) return;
    _reconnectTimer?.cancel();
    _setState(TranslateState.reconnecting);

    // 지수 백오프 + 지터(최대 30s).
    final exp = 1000 * (1 << _reconnectAttempt.clamp(0, 5)); // 1s..32s
    final capped = min(exp, _maxBackoff.inMilliseconds);
    final delay = Duration(milliseconds: capped + Random().nextInt(500));
    _reconnectAttempt++;

    _reconnectTimer = Timer(delay, () {
      if (_active) _connect();
    });
  }

  /// 통역 종료 및 연결/마이크 정리(플레이어/레코더 핸들은 유지).
  Future<void> stop() async {
    _active = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _teardownConnection();
    if (_recorderOpened && _recorder.isRecording) {
      await _recorder.stopRecorder();
    }
    await _micSub?.cancel();
    _micSub = null;
    await _recordController?.close();
    _recordController = null;
    _setState(TranslateState.idle);
  }

  /// 완전 해제(앱 종료/화면 dispose 시).
  Future<void> dispose() async {
    await stop();
    if (_playerOpened) {
      await _player.stopPlayer();
      await _player.closePlayer();
      _playerOpened = false;
    }
    if (_recorderOpened) {
      await _recorder.closeRecorder();
      _recorderOpened = false;
    }
    await _stateController.close();
    await _transcriptController.close();
  }
}
