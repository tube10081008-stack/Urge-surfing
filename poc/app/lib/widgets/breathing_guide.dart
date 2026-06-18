import 'package:flutter/material.dart';

/// 4-7-8 호흡 가이드.
///
/// 한 사이클 = 들이쉬기 4초 → 멈추기 7초 → 내쉬기 8초 (총 19초).
/// - 들이쉬기: 원이 작게→크게 확장
/// - 멈추기: 큰 상태 유지
/// - 내쉬기: 원이 크게→작게 수축
/// 중앙 텍스트로 현재 단계와 카운트를 안내한다.
enum _BreathPhase { inhale, hold, exhale }

class BreathingGuide extends StatefulWidget {
  final Color color;

  const BreathingGuide({super.key, this.color = const Color(0xFF7FB7D4)});

  @override
  State<BreathingGuide> createState() => _BreathingGuideState();
}

class _BreathingGuideState extends State<BreathingGuide>
    with TickerProviderStateMixin {
  static const int inhaleSec = 4;
  static const int holdSec = 7;
  static const int exhaleSec = 8;
  static const int cycleSec = inhaleSec + holdSec + exhaleSec; // 19

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: cycleSec),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 진행 비율(0~1)을 받아 현재 단계와 원 크기 비율(0.4~1.0)을 계산.
  ({_BreathPhase phase, double scale, int countdown}) _compute(double t) {
    final elapsed = t * cycleSec; // 0~19초
    if (elapsed < inhaleSec) {
      final local = elapsed / inhaleSec; // 0→1
      return (
        phase: _BreathPhase.inhale,
        scale: 0.4 + 0.6 * local,
        countdown: (inhaleSec - elapsed).ceil(),
      );
    } else if (elapsed < inhaleSec + holdSec) {
      final local = elapsed - inhaleSec;
      return (
        phase: _BreathPhase.hold,
        scale: 1.0,
        countdown: (holdSec - local).ceil(),
      );
    } else {
      final local = elapsed - inhaleSec - holdSec; // 0→8
      return (
        phase: _BreathPhase.exhale,
        scale: 1.0 - 0.6 * (local / exhaleSec),
        countdown: (exhaleSec - local).ceil(),
      );
    }
  }

  String _label(_BreathPhase p) {
    switch (p) {
      case _BreathPhase.inhale:
        return '들이쉬기';
      case _BreathPhase.hold:
        return '멈추기';
      case _BreathPhase.exhale:
        return '내쉬기';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final s = _compute(_controller.value);
        const maxDiameter = 180.0;
        final diameter = maxDiameter * s.scale;
        return SizedBox(
          width: maxDiameter,
          height: maxDiameter,
          child: Center(
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.color.withOpacity(0.9),
                    widget.color.withOpacity(0.35),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.4),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _label(s.phase),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.countdown}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
