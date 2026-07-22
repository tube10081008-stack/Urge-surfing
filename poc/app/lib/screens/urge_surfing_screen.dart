import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../models/coping_skill.dart';
import '../models/exposure_media.dart';
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

  /// 긴 음성 가이드 재생 중 3분 자동종료를 억제(끊김 방지).
  bool _autoFinishSuppressed = false;

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
        // 음성 가이드 재생 중이면 자동 종료를 멈춘다(긴 오디오가 끊기지 않도록).
        // 한 번 억제되면 이후 다른 대처법으로 바꿔도 자동 종료하지 않음.
        if (_skill.kind == CopingKind.audioGuide) {
          _autoFinishSuppressed = true;
        } else if (!_autoFinishSuppressed) {
          _finish();
        }
      }
    });
  }

  void _selectSkill(CopingSkill skill) {
    setState(() => _skill = skill);
    ref.read(sessionControllerProvider.notifier).setCopingSkill(skill.key);
  }

  /// 가이드 회기 라벨(예: "상담사 음성 가이드 · 2회기" → "가이드 2회기").
  String _guideLabel(ExposureMedia g) {
    final match = RegExp(r'(\d+)\s*회기').firstMatch(g.title);
    return match != null ? '가이드 ${match.group(1)}회기' : '상담 음성';
  }

  /// 기본 대처법 + 등록된 상담 음성 가이드(회기별) 칩.
  List<CopingSkill> _skillsWith(List<ExposureMedia> guides) {
    return [
      ...kCopingSkills,
      for (final g in guides)
        CopingSkill(
          key: 'guide_${g.id}',
          label: _guideLabel(g),
          tagline: '상담사 음성과 함께 파도를 지나요',
          icon: Icons.headphones,
          kind: CopingKind.audioGuide,
        ),
    ];
  }

  /// key('guide_<id>')에 해당하는 가이드 미디어를 찾는다.
  ExposureMedia? _guideForSkill(List<ExposureMedia> guides) {
    for (final g in guides) {
      if ('guide_${g.id}' == _skill.key) return g;
    }
    return null;
  }

  /// 선택된 기술에 맞는 가이드 위젯.
  Widget _buildGuide(List<ExposureMedia> guides) {
    switch (_skill.kind) {
      case CopingKind.breathing:
        return BreathingGuide(
          key: ValueKey(_skill.key),
          inhale: _skill.inhale,
          hold1: _skill.hold1,
          exhale: _skill.exhale,
          hold2: _skill.hold2,
        );
      case CopingKind.steps:
        return StepGuide(
          key: ValueKey(_skill.key),
          steps: _skill.steps,
          stepSec: _skill.stepSec,
        );
      case CopingKind.audioGuide:
        final g = _guideForSkill(guides);
        return _AudioGuidePlayer(
          key: ValueKey(_skill.key),
          url: g?.mediaUrl ?? '',
          title: g?.title ?? '상담 음성 가이드',
        );
    }
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
    final remaining = (totalSec - _elapsed).clamp(0, totalSec);
    final isAudio = _skill.kind == CopingKind.audioGuide;
    final guides = ref.watch(guidesProvider).valueOrNull ?? const [];
    final skills = _skillsWith(guides);

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
                // 타이머 (음성 가이드 재생 중엔 시간 압박 대신 안내)
                Text(
                  isAudio ? '🎧' : _fmt(remaining),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5066),
                  ),
                ),
                Text(isAudio ? '음성 가이드에 집중하세요' : '남은 시간',
                    style: const TextStyle(color: Color(0xFF5A7A8C))),
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
                    itemCount: skills.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final skill = skills[i];
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
                _buildGuide(guides),
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

/// 상담사 음성 가이드 스트리밍 플레이어.
/// 칩 선택 시 자동 재생, 다른 기술로 바꾸면 위젯이 dispose 되며 정지된다.
class _AudioGuidePlayer extends StatefulWidget {
  final String url;
  final String title;

  const _AudioGuidePlayer({super.key, required this.url, required this.title});

  @override
  State<_AudioGuidePlayer> createState() => _AudioGuidePlayerState();
}

class _AudioGuidePlayerState extends State<_AudioGuidePlayer> {
  VideoPlayerController? _c;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!widget.url.startsWith('http')) {
      setState(() => _error = '가이드 URL이 없어요');
      return;
    }
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _c = c;
      await c.initialize();
      await c.play();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = '재생 실패: 네트워크를 확인해 주세요');
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF4F8FB0);
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.headphones, size: 44, color: accent),
          const SizedBox(height: 10),
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C5066),
            ),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.redAccent))
          else if (!_ready)
            const SizedBox(
              height: 40,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              ),
            )
          else
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _c!,
              builder: (context, v, _) {
                final pos = v.position;
                final dur = v.duration;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: dur.inMilliseconds == 0
                            ? 0
                            : pos.inMilliseconds / dur.inMilliseconds,
                        minHeight: 5,
                        backgroundColor: accent.withOpacity(0.12),
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                        IconButton(
                          iconSize: 40,
                          color: accent,
                          icon: Icon(v.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled),
                          onPressed: () =>
                              v.isPlaying ? _c!.pause() : _c!.play(),
                        ),
                        Text(_fmt(dur),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
