import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_controller.dart';
import '../widgets/sos_button.dart';
import 'urge_surfing_screen.dart';

/// 노출(Exposure) 화면 — 플레이스홀더 시뮬레이션.
///
/// 실제 미디어 바이너리 없이 전체화면 색배경 + "슬롯머신 사운드 재생 중…" +
/// 잔여시간 + 중단 버튼으로 노출 자극을 모사한다.
/// 60초 자동 cap(자동 종료) 또는 사용자가 [충분히 견뎠어요]를 누르면 파도타기로 진행.
class ExposureScreen extends ConsumerStatefulWidget {
  const ExposureScreen({super.key});

  @override
  ConsumerState<ExposureScreen> createState() => _ExposureScreenState();
}

class _ExposureScreenState extends ConsumerState<ExposureScreen> {
  static const int capSec = 60; // 자동 종료 상한
  int _remaining = capSec;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _goToUrgeSurfing();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goToUrgeSurfing() {
    _timer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const UrgeSurfingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = ref.watch(sessionControllerProvider).media;
    final title = media?.title ?? '슬롯머신 릴 사운드';
    final mediaType = media?.mediaType ?? 'audio';

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A38), // 차분한 다크 톤
      floatingActionButton: const SosButton(),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.graphic_eq,
                      size: 72, color: Color(0xFF7FB7D4)),
                  const SizedBox(height: 24),
                  Text(
                    '$title 재생 중…',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '(${mediaType == 'audio' ? '사운드' : '영상'} 플레이스홀더 · 실제 미디어 없음)',
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    '$_remaining초',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '충동이 올라와도 괜찮아요. 그저 느끼며 바라보세요.',
                    style: TextStyle(color: Colors.white.withOpacity(0.75)),
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
                child: const Text('중단하고 파도타기로 넘어가기',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
