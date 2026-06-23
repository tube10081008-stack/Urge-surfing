import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 통역 세션 상태.
enum TranslateState { idle, connecting, ready, error }

/// 릴레이를 경유한 실시간 음성 통역 서비스.
///
/// 흐름:
///   마이크(PCM16/16kHz) → WebSocket → 릴레이 → Gemini Live Translate
///   → 릴레이 → WebSocket → 스피커(PCM16/24kHz)
///
/// 릴레이 주소는 [relayBaseUrl] 로 주입한다(빌드 시 --dart-define).
/// 예: wss://my-relay.example.com  (중국 밖 VPS)
class TranslateService {
  /// 릴레이 WebSocket 기본 주소. 끝에 경로/쿼리는 붙이지 않는다.
  static const String relayBaseUrl = String.fromEnvironment(
    'RELAY_BASE_URL',
    defaultValue: 'ws://10.0.2.2:8080', // Android 에뮬레이터 → 로컬 릴레이
  );

  /// 릴레이 접근 토큰(릴레이의 RELAY_TOKEN과 일치).
  static const String relayToken = String.fromEnvironment('RELAY_TOKEN');

  // 입력: Gemini Live API가 요구하는 16kHz mono PCM16.
  static const int _inputSampleRate = 16000;
  // 출력: Gemini가 내려주는 24kHz mono PCM16.
  static const int _outputSampleRate = 24000;

  final _recorder = AudioRecorder();
  final _player = FlutterSoundPlayer();

  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<dynamic>? _wsSub;
  bool _playerOpened = false;

  /// 상태 변화 알림.
  final _stateController = StreamController<TranslateState>.broadcast();
  Stream<TranslateState> get state => _stateController.stream;

  /// 수신 자막(있을 때) 알림.
  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcript => _transcriptController.stream;

  /// 통역 시작.
  ///
  /// [target] 번역 대상 언어코드(예: "zh-CN").
  /// [source] 입력 언어 힌트(선택). null이면 자동 감지.
  Future<void> start({required String target, String? source}) async {
    _stateController.add(TranslateState.connecting);

    if (!await Permission.microphone.request().isGranted) {
      _stateController.add(TranslateState.error);
      throw StateError('마이크 권한이 필요합니다.');
    }

    await _openPlayer();
    _connect(target: target, source: source);
    await _startMic();
  }

  Future<void> _openPlayer() async {
    if (_playerOpened) return;
    await _player.openPlayer();
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: _outputSampleRate,
      interleaved: true,
    );
    _playerOpened = true;
  }

  void _connect({required String target, String? source}) {
    final uri = Uri.parse('$relayBaseUrl/ws/translate').replace(
      queryParameters: {
        'target': target,
        if (source != null) 'source': source,
        if (relayToken.isNotEmpty) 'token': relayToken,
      },
    );

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    _wsSub = channel.stream.listen(
      _onMessage,
      onError: (_) => _stateController.add(TranslateState.error),
      onDone: () => _stateController.add(TranslateState.idle),
    );
  }

  void _onMessage(dynamic message) {
    // 바이너리 = 번역된 오디오(PCM16/24kHz) → 즉시 재생.
    if (message is List<int>) {
      _player.foodSink?.add(FoodData(Uint8List.fromList(message)));
      return;
    }
    // 텍스트(JSON) = 상태/자막.
    if (message is String) {
      final data = jsonDecode(message) as Map<String, dynamic>;
      switch (data['type']) {
        case 'status':
          if (data['value'] == 'ready') {
            _stateController.add(TranslateState.ready);
          }
          break;
        case 'transcript':
          _transcriptController.add(data['text'] as String? ?? '');
          break;
        case 'error':
          _stateController.add(TranslateState.error);
          break;
      }
    }
  }

  Future<void> _startMic() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _inputSampleRate,
        numChannels: 1,
      ),
    );
    _micSub = stream.listen((chunk) {
      // 원시 PCM16 청크를 그대로 릴레이로 송신(바이너리 프레임).
      _channel?.sink.add(chunk);
    });
  }

  /// 통역 종료 및 리소스 정리.
  Future<void> stop() async {
    await _micSub?.cancel();
    _micSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _wsSub?.cancel();
    _wsSub = null;
    await _channel?.sink.close();
    _channel = null;
    _stateController.add(TranslateState.idle);
  }

  /// 완전 해제(앱 종료/화면 dispose 시).
  Future<void> dispose() async {
    await stop();
    if (_playerOpened) {
      await _player.stopPlayer();
      await _player.closePlayer();
      _playerOpened = false;
    }
    await _recorder.dispose();
    await _stateController.close();
    await _transcriptController.close();
  }
}
