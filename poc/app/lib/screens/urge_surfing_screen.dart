import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/coping_skill.dart';
import '../state/session_controller.dart';
import '../widgets/breathing_guide.dart';
import '../widgets/sos_button.dart';
import '../widgets/step_guide.dart';
import '../widgets/wave_painter.dart';
import 'vas_input_screen.dart';

/// 충동 파도타기(Urge Surfing) 화면 — P0의 핵심.
///
/// - 3분(180초) 타이머. 진행도(progress)에 따라 파도 진폭이 1.0→0.15로 감쇠.
/// - 하단: 파도 애니메이션(점점 잔잔해짐)
/// - 중앙: 4-7-8 호흡 가이드(확장/수축 원)
/// - 상단: 진행도에 따라 바뀌는 실시간 코칭 자막
/// 타이머 종료(또는 [지금 마치기])하면 사후 VAS로 진행.
class UrgeSurfingScreen extends ConsumerStatefulWidget {
  const UrgeSurfingScreen({super.key});

  @override
  ConsumerState<UrgeSurfingScreen> createState() => _UrgeSurfingScreenState();
}

class _UrgeSurfingScreenState extends ConsumerState<UrgeSurfingScreen> {
  static const int totalSec = 180; // 3분
  int _elapsed = 0;
  Timer? _timer;

  /// 현재 선택된 대처 기술(기본: 4-7-8 호흡).
  CopingSkill _skill = kCopingSkills.first;

  /// 진행도에 따라 보여줄 코칭 자막(시간 구간별).
  static const List<({double until, String text})> _coaching = [
    (until: 0.15, text: '지금 느끼는 충동을 그대로 알아차려 보세요. 밀어내지 않아도 괜찮아요.'),
    (until: 0.35, text: '파도가 가장 높은 지점이에요. 호흡의 리듬에 집중해 보세요.'),
    (until: 0.55, text: '충동은 영원하지 않아요. 보이시나요? 파도가 조금씩 낮아지고 있어요.'),
    (until: 0.8, text: '잘하고 있어요. 충동을 견뎌낸 이 순간을 기억하세요.'),
    (until: 1.01, text: '거의 다 왔어요. 파도가 잔잔해지듯, 충동도 지나가고 있어요.'),
  ];

  @override
  void initState() {
    super.initState();
    // 기본 대처 기술을 세션에 반영(백엔드 coping_skill 전송용).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionControllerProvider.notifier).setCopingSkill(_skill.key);
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= totalSec) {
        _finish();
      }
    });
  }

  void _selectSkill(CopingSkill skill) {
    setState(() => _skill = skill);
    ref.read(sessionControllerProvider.notifier).setCopingSkill(skill.key);
  }

  /// 선택된 기술에 맞는 가이드 위젯.
  Widget _buildGuide() {
    if (_skill.kind == CopingKind.breathing) {
      return BreathingGuide(
        key: ValueKey(_skill.key),
        inhale: _skill.inhale,
        hold1: _skill.hold1,
        exhale: _skill.exhale,
        hold2: _skill.hold2,
      );
    }
    return StepGuide(
      key: ValueKey(_skill.key),
      steps: _skill.steps,
      stepSec: _skill.stepSec,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double get _progress => (_elapsed / totalSec).clamp(0.0, 1.0);

  String get _coachText {
    for (final c in _coaching) {
      if (_progress < c.until) return c.text;
    }
    return _coaching.last.text;
  }

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(1, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _finish() {
    _timer?.cancel();
    final controller = ref.read(sessionControllerProvider.notifier);
    controller.setUrgeSurfingDuration(_elapsed);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const VasInputScreen(phase: VasPhase.post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = totalSec - _elapsed;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF3F8),
      floatingActionButton: const SosButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: Stack(
        children: [
          // 하단 파도 애니메이션 (진행도에 따라 감쇠)
          Positioned.fill(
            child: WaveAnimation(progress: _progress),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                // 타이머
                Text(
                  _fmt(remaining),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5066),
                  ),
                ),
                const Text('남은 시간',
                    style: TextStyle(color: Color(0xFF5A7A8C))),
                const SizedBox(height: 8),

                // 진행 바
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.6),
                      color: const Color(0xFF4F8FB0),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 실시간 코칭 자막
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      _coachText,
                      key: ValueKey(_coachText),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Color(0xFF2C5066),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // 대처 기술 선택(가로 스크롤 칩)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: kCopingSkills.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final skill = kCopingSkills[i];
                      final selected = skill.key == _skill.key;
                      return ChoiceChip(
                        avatar: Icon(
                          skill.icon,
                          size: 18,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF4F8FB0),
                        ),
                        label: Text(skill.label),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor: const Color(0xFF4F8FB0),
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF2C5066),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(0xFFCBDDE7)),
                        ),
                        onSelected: (_) => _selectSkill(skill),
                      );
                    },
                  ),
                ),

                const Spacer(),

                // 중앙 대처 기술 가이드(선택에 따라 전환)
                _buildGuide(),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    _skill.tagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF5A7A8C), fontSize: 13),
                  ),
                ),

                const Spacer(),

                // 마치기 버튼
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2C5066),
                      side: const BorderSide(color: Color(0xFF4F8FB0)),
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Colors.white.withOpacity(0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _finish,
                    child: const Text('지금 마치기',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
