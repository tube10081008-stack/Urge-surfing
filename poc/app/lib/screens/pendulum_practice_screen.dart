import 'dart:async';

import 'package:flutter/material.dart';

/// 진자 연습 가이드 — 소매틱(SE)의 진자운동·적정화를 직접 해보는 인터랙티브 화면.
///
/// 흐름: 소개 → 자원(닻) 정하기 → 진자 왕복(불편함 관찰 ↔ 자원으로 복귀, 자동 리듬)
/// → 마무리(변화 알아차리기). 압도되지 않게 '작게, 리듬 있게'가 원칙.
class PendulumPracticeScreen extends StatefulWidget {
  const PendulumPracticeScreen({super.key});

  @override
  State<PendulumPracticeScreen> createState() => _PendulumPracticeScreenState();
}

enum _Phase { intro, resource, practice, done }

class _PendulumPracticeScreenState extends State<PendulumPracticeScreen>
    with SingleTickerProviderStateMixin {
  static const int _halfSec = 12; // 한쪽에 머무는 시간(초)
  static const int _targetCycles = 3; // 왕복(불편→자원) 반복 횟수

  static const List<String> _resources = [
    '발바닥이 바닥에 닿은 느낌',
    '숨 쉴 때 배의 오르내림',
    '두 손을 맞잡은 따뜻함',
    '등이 의자에 닿은 느낌',
    '주변에서 들리는 소리',
  ];

  final _discomfortColor = const Color(0xFFE08A3C); // 불편함 관찰(주황)
  final _resourceColor = const Color(0xFF3FA796); // 자원·안정(초록)

  _Phase _phase = _Phase.intro;
  String _resource = _resources.first;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  Timer? _timer;
  bool _inDiscomfort = true; // true=불편함 관찰, false=자원으로 복귀
  int _tick = 0;
  int _cyclesDone = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _startPractice() {
    setState(() {
      _phase = _Phase.practice;
      _inDiscomfort = true;
      _tick = 0;
      _cyclesDone = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _tick++;
        if (_tick >= _halfSec) {
          _tick = 0;
          if (!_inDiscomfort) {
            // 자원 국면을 막 끝냄 = 한 왕복 완료
            _cyclesDone++;
          }
          _inDiscomfort = !_inDiscomfort;
          if (_cyclesDone >= _targetCycles && !_inDiscomfort) {
            // 목표 왕복 후, 자원에서 안정된 채로 마무리 가능
          }
        }
      });
    });
  }

  void _finish() {
    _timer?.cancel();
    setState(() => _phase = _Phase.done);
  }

  bool get _canFinish => _cyclesDone >= _targetCycles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3F8),
      appBar: AppBar(
        title: const Text('진자 연습'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF2C5066),
        elevation: 0,
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.intro => _intro(),
          _Phase.resource => _resourcePick(),
          _Phase.practice => _practice(),
          _Phase.done => _done(),
        },
      ),
    );
  }

  // ── 소개 ──────────────────────────────
  Widget _intro() {
    return _pad(
      children: [
        const SizedBox(height: 8),
        const Icon(Icons.waves, size: 56, color: Color(0xFF4F8FB0)),
        const SizedBox(height: 16),
        const Text('충동을 없애지 않고, 지나가게 둡니다',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C5066))),
        const SizedBox(height: 16),
        _info(
          '불편한 감각에 아주 조금 다가갔다가(적정화), 안전한 감각으로 다시 돌아오기'
          '(자원)를 리듬처럼 반복해요. 이 왕복이 신경계에 "이 파도는 지나간다"를 '
          '가르쳐, 견딜 수 있는 범위를 넓혀줍니다.',
        ),
        const SizedBox(height: 12),
        _info(
          '⚠️ 벅차오르면 언제든 멈추고 자원(발바닥·호흡)으로 돌아오세요. 그건 실패가 '
          '아니라 "용량이 컸다"는 신호예요. 강한 트라우마는 상담사와 함께 다뤄요.',
        ),
        const Spacer(),
        _primaryButton('시작하기', () => setState(() => _phase = _Phase.resource)),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── 자원 정하기 ───────────────────────
  Widget _resourcePick() {
    return _pad(
      children: [
        const SizedBox(height: 8),
        const Text('먼저, 돌아올 자리(자원)를 정해요',
            style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C5066))),
        const SizedBox(height: 8),
        const Text('불편함에서 언제든 돌아올 수 있는, 편안하거나 중립적인 몸의 감각이에요.',
            style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
        const SizedBox(height: 20),
        ..._resources.map((r) {
          final sel = _resource == r;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _resource = r),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: sel
                      ? _resourceColor.withOpacity(0.14)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: sel ? _resourceColor : const Color(0xFFDCE8EF),
                      width: sel ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Icon(sel ? Icons.anchor : Icons.circle_outlined,
                        size: 20,
                        color: sel
                            ? _resourceColor
                            : const Color(0xFFB0C4D0)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(r,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w500,
                                color: const Color(0xFF2C5066)))),
                  ],
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        _primaryButton('이 자원으로 시작', _startPractice),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── 진자 왕복 ─────────────────────────
  Widget _practice() {
    final color = _inDiscomfort ? _discomfortColor : _resourceColor;
    final remaining = _halfSec - _tick;
    final title = _inDiscomfort ? '불편함에 살짝 주의를 둬요' : '자원으로 부드럽게 돌아와요';
    final guide = _inDiscomfort
        ? '충동이 있는 곳에 가장자리만 살짝. "조인다·뜨겁다·묵직하다"처럼 감각의 언어로만, '
            '판단 없이 바라봐요.'
        : '이제 "$_resource"에 주의를 옮겨요. 여기서 잠시 안전하게 머물러요.';

    return Column(
      children: [
        const SizedBox(height: 8),
        Text('왕복 $_cyclesDone / $_targetCycles',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5A7A8C))),
        const SizedBox(height: 20),
        // 진자 위치 표시(불편 ← → 자원)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Text('불편', style: TextStyle(fontSize: 12, color: _discomfortColor)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOut,
                    alignment: _inDiscomfort
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
              Text('자원', style: TextStyle(fontSize: 12, color: _resourceColor)),
            ],
          ),
        ),
        const Spacer(),
        // 중앙 호흡하는 원
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final scale = 0.85 + 0.15 * _pulse.value;
            final d = 200.0 * scale;
            return Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  color.withOpacity(0.9),
                  color.withOpacity(0.3),
                ]),
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: 28,
                      spreadRadius: 4),
                ],
              ),
              child: Center(
                child: Text('$remaining',
                    style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2C5066))),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(guide,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, height: 1.6, color: Color(0xFF5A7A8C))),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            children: [
              if (_canFinish)
                _primaryButton('충분해요 · 마무리하기', _finish)
              else
                Text('$_targetCycles번 왕복 후 마무리할 수 있어요',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              TextButton(
                onPressed: _finish,
                child: const Text('지금 멈추기',
                    style: TextStyle(color: Color(0xFF5A7A8C))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 마무리 ────────────────────────────
  Widget _done() {
    return _pad(
      children: [
        const Spacer(),
        Icon(Icons.spa, size: 64, color: _resourceColor),
        const SizedBox(height: 16),
        const Text('잘 지나왔어요',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C5066))),
        const SizedBox(height: 12),
        _info(
          '지금 몸은 처음보다 어떤가요? "조금 풀렸다", "따뜻해졌다", "그대로다" — 무엇이든 '
          '괜찮아요. 이 미세한 변화를 알아차리는 것이, 신경계에 "파도는 지나간다"를 새기는 '
          '마무리예요.',
        ),
        const SizedBox(height: 12),
        _info('충동은 없애야 할 적이 아니라, 타고 넘을 수 있는 파도예요. 오늘도 한 번 넘으셨어요.'),
        const Spacer(),
        _primaryButton('마치기', () => Navigator.of(context).pop()),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _phase = _Phase.intro),
          child: const Text('한 번 더', style: TextStyle(color: Color(0xFF5A7A8C))),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── 공용 ──────────────────────────────
  Widget _pad({required List<Widget> children}) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _info(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14, height: 1.6, color: Color(0xFF2C5066))),
      );

  Widget _primaryButton(String label, VoidCallback onTap) => SizedBox(
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4F8FB0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onTap,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ),
      );
}
