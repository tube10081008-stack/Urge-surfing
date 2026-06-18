import 'package:flutter/material.dart';

/// 호흡 가이드(확장/수축 원).
///
/// 한 사이클 = 들이쉬기 → 멈추기 → 내쉬기 → (선택)멈추기.
/// - 기본값은 4-7-8 호흡(들숨4·멈춤7·날숨8, 마지막 멈춤 없음).
/// - 박스 호흡은 4-4-4-4 (hold2=4)로 사용.
/// 중앙 텍스트로 현재 단계와 카운트를 안내한다.
enum _BreathPhase { inhale, hold, exhale }

class BreathingGuide extends StatefulWidget {
  final Color color;

  /// 각 단계 길이(초). hold2=0이면 마지막 멈춤 단계는 생략.
  final int inhale;
  final int hold1;
  final int exhale;
  final int hold2;

  const BreathingGuide({
    super.key,
    this.color = const Color(0xFF7FB7D4),
    this.inhale = 4,
    this.hold1 = 7,
    this.exhale = 8,
    this.hold2 = 0,
  });

  @override
  State<BreathingGuide> createState() => _BreathingGuideState();
}

class _BreathingGuideState extends State<BreathingGuide>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  int get _cycleSec =>
      widget.inhale + widget.hold1 + widget.exhale + widget.hold2;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _cycleSec),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 진행 비율(0~1)을 받아 현재 단계와 원 크기 비율(0.4~1.0)을 계산.
  ({_BreathPhase phase, double scale, int countdown}) _compute(double t) {
    final elapsed = t * _cycleSec;
    final i = widget.inhale;
    final h1 = widget.hold1;
    final e = widget.exhale;

    if (elapsed < i) {
      final local = elapsed / i; // 0→1
      return (
        phase: _BreathPhase.inhale,
        scale: 0.4 + 0.6 * local,
        countdown: (i - elapsed).ceil(),
      );
    } else if (elapsed < i + h1) {
      final local = elapsed - i;
      return (
        phase: _BreathPhase.hold,
        scale: 1.0,
        countdown: (h1 - local).ceil(),
      );
    } else if (elapsed < i + h1 + e) {
      final local = elapsed - i - h1; // 0→e
      return (
        phase: _BreathPhase.exhale,
        scale: 1.0 - 0.6 * (local / e),
        countdown: (e - local).ceil(),
      );
    } else {
      // hold2 (박스 호흡의 날숨 후 멈춤)
      final local = elapsed - i - h1 - e;
      return (
        phase: _BreathPhase.hold,
        scale: 0.4,
        countdown: (widget.hold2 - local).ceil(),
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
