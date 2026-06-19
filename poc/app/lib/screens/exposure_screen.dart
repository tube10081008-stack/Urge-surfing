import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/exposure_media.dart';
import '../state/session_controller.dart';
import '../widgets/sos_button.dart';
import 'urge_surfing_screen.dart';

/// 노출(Exposure) 화면.
///
/// 미디어에 재생 가능한 URL이 있으면 실제 영상/오디오/이미지를 재생하고,
/// 없으면 색배경 플레이스홀더로 모사한다. 진입 시 주의(콘텐츠 경고)를 먼저 띄운다.
/// 60초 자동 cap 또는 사용자가 직접 마치면 파도타기로 진행.
class ExposureScreen extends ConsumerStatefulWidget {
  const ExposureScreen({super.key});

  @override
  ConsumerState<ExposureScreen> createState() => _ExposureScreenState();
}

class _ExposureScreenState extends ConsumerState<ExposureScreen> {
  static const int capSec = 60; // 자동 종료 상한
  int _remaining = capSec;
  Timer? _timer;

  VideoPlayerController? _controller;
  bool _videoReady = false;
  bool _started = false;
  String? _mediaError;

  ExposureMedia? get _media => ref.read(sessionControllerProvider).media;

  @override
  void initState() {
    super.initState();
    // 첫 프레임 후 콘텐츠 경고 → 동의 시 재생 시작.
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirmAndStart());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _confirmAndStart() async {
    final media = _media;
    final warning = (media?.contentWarning.isNotEmpty ?? false)
        ? media!.contentWarning
        : '실제 도박 자극이 재생됩니다. 충동이 올라올 수 있어요.\n'
            '힘들면 언제든 멈추거나 도움요청(1336)을 누르세요.';

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE08A3C)),
            SizedBox(width: 8),
            Text('잠깐, 마음의 준비'),
          ],
        ),
        content: Text(warning, style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('그만두기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('준비됐어요'),
          ),
        ],
      ),
    );

    if (ok != true) {
      if (mounted) Navigator.of(context).pop(); // 사전 VAS 화면으로 복귀
      return;
    }

    setState(() => _started = true);
    _startTimer();
    await _initMediaIfNeeded();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) _goToUrgeSurfing();
    });
  }

  Future<void> _initMediaIfNeeded() async {
    final media = _media;
    if (media == null || !media.hasPlayableUrl) return;
    // 이미지는 build에서 Image.network 로 처리. 영상/오디오만 컨트롤러 필요.
    if (media.mediaType == 'image') return;

    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(media.mediaUrl));
      _controller = c;
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(1.0);
      await c.play();
      if (mounted) setState(() => _videoReady = true);
    } catch (e) {
      if (mounted) setState(() => _mediaError = '$e');
    }
  }

  void _goToUrgeSurfing() {
    _timer?.cancel();
    _controller?.pause();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const UrgeSurfingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;
    final title = media?.title ?? '슬롯머신 릴 사운드';

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A38),
      floatingActionButton: const SosButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MediaArea(
                    media: media,
                    controller: _controller,
                    videoReady: _videoReady,
                    started: _started,
                    error: _mediaError,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '$title',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$_remaining초',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '충동이 올라와도 괜찮아요. 그저 느끼며 바라보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.75)),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _goToUrgeSurfing,
                child: const Text('충분히 견뎠어요 · 파도타기로',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 미디어 표시 영역: 영상/이미지/오디오/플레이스홀더 분기.
class _MediaArea extends StatelessWidget {
  final ExposureMedia? media;
  final VideoPlayerController? controller;
  final bool videoReady;
  final bool started;
  final String? error;

  const _MediaArea({
    required this.media,
    required this.controller,
    required this.videoReady,
    required this.started,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final type = media?.mediaType ?? 'audio';
    final hasUrl = media?.hasPlayableUrl ?? false;

    // 재생 오류 또는 URL 없음 → 플레이스홀더(기존 모사)
    if (!hasUrl || error != null) {
      return _placeholder(
        type,
        note: error != null
            ? '(재생 오류 · 플레이스홀더로 대체)'
            : '(${type == 'audio' ? '사운드' : '영상'} 플레이스홀더 · 실제 미디어 없음)',
      );
    }

    // 영상
    if (type == 'video') {
      if (videoReady && controller != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 48,
            child: AspectRatio(
              aspectRatio: controller!.value.aspectRatio == 0
                  ? 16 / 9
                  : controller!.value.aspectRatio,
              child: VideoPlayer(controller!),
            ),
          ),
        );
      }
      return _loading();
    }

    // 이미지
    if (type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          media!.mediaUrl,
          width: MediaQuery.of(context).size.width - 48,
          fit: BoxFit.cover,
          loadingBuilder: (c, child, p) =>
              p == null ? child : _loading(),
          errorBuilder: (c, e, s) =>
              _placeholder('image', note: '(이미지 로드 실패)'),
        ),
      );
    }

    // 오디오 (video_player로 재생 중, 화면엔 비주얼라이저)
    if (videoReady) {
      return _audioVisual('재생 중…');
    }
    return _loading();
  }

  Widget _audioVisual(String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.graphic_eq, size: 72, color: Color(0xFF7FB7D4)),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _placeholder(String type, {required String note}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          type == 'audio' ? Icons.graphic_eq : Icons.movie_creation_outlined,
          size: 72,
          color: const Color(0xFF7FB7D4),
        ),
        const SizedBox(height: 8),
        Text(note, style: TextStyle(color: Colors.white.withOpacity(0.6))),
      ],
    );
  }

  Widget _loading() {
    return const SizedBox(
      height: 120,
      child: Center(
        child: CircularProgressIndicator(color: Color(0xFF7FB7D4)),
      ),
    );
  }
}
