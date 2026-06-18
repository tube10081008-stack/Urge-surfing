import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 충동 '파도'를 그리는 CustomPainter.
///
/// - 시간이 흐를수록 진폭(amplitude)이 [maxAmplitude](1.0) → [minAmplitude](0.15)로
///   선형 감쇠하여 파도가 점점 잔잔해진다. (충동도 결국 가라앉는다는 은유)
/// - 여러 겹의 사인파를 위상차를 두고 겹쳐 자연스러운 바다 느낌을 낸다.
class WavePainter extends CustomPainter {
  /// 0.0 → 1.0 으로 반복되는 애니메이션 위상(파도가 옆으로 흐르는 효과).
  final double phase;

  /// 0.0(시작) → 1.0(종료)로 진행되는 세션 진행도. 진폭 감쇠에 사용.
  final double progress;

  /// 파도 색상
  final Color color;

  static const double maxAmplitude = 1.0; // 최대 진폭 비율
  static const double minAmplitude = 0.15; // 최소 진폭 비율(완전히 0은 아님)

  const WavePainter({
    required this.phase,
    required this.progress,
    this.color = const Color(0xFF4F8FB0),
  });

  /// 현재 진행도에 따른 진폭 비율(1.0 → 0.15 선형 감쇠).
  double get amplitudeFactor {
    final p = progress.clamp(0.0, 1.0);
    return maxAmplitude - (maxAmplitude - minAmplitude) * p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height * 0.55; // 수면 기준선
    final maxAmp = size.height * 0.28; // 픽셀 단위 최대 진폭
    final amp = maxAmp * amplitudeFactor;

    // 3겹의 파도를 서로 다른 진폭/주파수/위상으로 겹친다.
    _drawWaveLayer(
      canvas,
      size,
      baseline: baseline,
      amplitude: amp,
      wavelength: size.width,
      phaseShift: phase * 2 * math.pi,
      opacity: 0.55,
    );
    _drawWaveLayer(
      canvas,
      size,
      baseline: baseline + amp * 0.25,
      amplitude: amp * 0.7,
      wavelength: size.width * 0.66,
      phaseShift: phase * 2 * math.pi + math.pi / 2,
      opacity: 0.4,
    );
    _drawWaveLayer(
      canvas,
      size,
      baseline: baseline + amp * 0.5,
      amplitude: amp * 0.45,
      wavelength: size.width * 0.5,
      phaseShift: -phase * 2 * math.pi + math.pi,
      opacity: 0.3,
    );
  }

  void _drawWaveLayer(
    Canvas canvas,
    Size size, {
    required double baseline,
    required double amplitude,
    required double wavelength,
    required double phaseShift,
    required double opacity,
  }) {
    final path = Path()..moveTo(0, size.height);

    // x축을 따라 사인파 곡선을 촘촘히 샘플링.
    const step = 4.0;
    final k = 2 * math.pi / wavelength; // 각주파수
    for (double x = 0; x <= size.width; x += step) {
      final y = baseline + amplitude * math.sin(k * x + phaseShift);
      if (x == 0) {
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path
      ..lineTo(size.width, size.height)
      ..close();

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(opacity),
          color.withOpacity(opacity * 0.6),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color;
  }
}

/// 파도 애니메이션 위젯. AnimationController로 [phase]를 반복 구동한다.
/// [progress]는 외부(타이머)에서 0→1로 주입한다.
class WaveAnimation extends StatefulWidget {
  final double progress;
  final Color color;

  const WaveAnimation({
    super.key,
    required this.progress,
    this.color = const Color(0xFF4F8FB0),
  });

  @override
  State<WaveAnimation> createState() => _WaveAnimationState();
}

class _WaveAnimationState extends State<WaveAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 4초 주기로 파도가 한 번 흘러가도록 반복.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: WavePainter(
            phase: _controller.value,
            progress: widget.progress,
            color: widget.color,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}
