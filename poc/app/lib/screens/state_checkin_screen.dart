import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/state_checkin.dart';
import '../state/session_controller.dart';
import 'action_guide_screen.dart';
import 'pendulum_practice_screen.dart';

/// 신경계 상태 체크 화면 — 수용의 창(WoT) 위 내 위치를 기록한다.
///
/// 상담 과제 흐름: 충동=신호 → 지금 각성도(1~5) → 몸 어디서·어떤 감각·왜 →
/// 상태를 옮길 행동 선택 → (행동 후) 다시 체크해 전후 비교.
class StateCheckinScreen extends ConsumerStatefulWidget {
  const StateCheckinScreen({super.key});

  @override
  ConsumerState<StateCheckinScreen> createState() =>
      _StateCheckinScreenState();
}

class _StateCheckinScreenState extends ConsumerState<StateCheckinScreen> {
  static const List<String> kBodyParts = [
    '가슴', '명치·배', '목·어깨', '머리', '손·팔', '다리', '얼굴·턱', '온몸', '잘 모르겠음',
  ];
  static const List<String> kSensations = [
    '두근거림', '답답함·조임', '열감', '떨림·저림', '묵직함', '텅 빈 느낌',
    '안절부절', '뻐근함', '잘 모르겠음',
  ];

  /// 상태를 옮기는 행동 메뉴(상담 과제 목록 기반).
  static const List<String> kActions = [
    '산책', '등산', '테니스', '공부', '책읽기', '글쓰기',
    '호흡·스트레칭', '샤워', '사람과 연결(전화·만남)', '파도타기 훈련',
  ];

  int? _arousal;
  String _bodyPart = '';
  String _sensation = '';
  String _action = '';
  final _trigger = TextEditingController();
  bool _saving = false;

  /// 각성도 → 가이드 필터 방향(저각성은 끌어올리기, 과각성은 가라앉히기).
  String? get _directionForArousal {
    final a = _arousal;
    if (a == null) return null;
    if (a <= 2) return 'up';
    if (a >= 4) return 'down';
    return 'ground';
  }

  Future<void> _openGuide() async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            ActionGuideScreen(initialDirection: _directionForArousal),
      ),
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() => _action = picked);
    }
  }

  @override
  void dispose() {
    _trigger.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_arousal == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).createStateCheckin(
            arousal: _arousal!,
            bodyPart: _bodyPart,
            sensation: _sensation,
            trigger: _trigger.text.trim(),
            action: _action,
          );
      ref.invalidate(checkinsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_action.isEmpty
              ? '기록했어요. 신호를 알아차린 것만으로 충분해요 🙂'
              : '기록했어요. "$_action" 다녀와서 다시 체크해 주세요 🙂'),
        ),
      );
      setState(() {
        _arousal = null;
        _bodyPart = '';
        _sensation = '';
        _action = '';
        _trigger.clear();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 실패: 네트워크를 확인해 주세요')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _recheck(StateCheckin checkin, int value) async {
    try {
      await ref.read(apiClientProvider).recheckState(checkin.id, value);
      ref.invalidate(checkinsProvider);
      if (!mounted) return;
      final moved = checkin.arousal != value && value == 3;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(moved
              ? '창 안으로 돌아왔네요. "${checkin.action}"이(가) 효과가 있었어요 🌿'
              : '재체크 완료. 전후를 비교해 보세요.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('재체크 실패: 네트워크를 확인해 주세요')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkinsAsync = ref.watch(checkinsProvider);
    final checkins = checkinsAsync.valueOrNull ?? const <StateCheckin>[];
    final pending =
        checkins.where((c) => c.needsRecheck).toList(growable: false);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('지금 나 · 상태 체크'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C5066),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // 행동 후 재체크 카드(미완료 체크인이 있으면)
            if (pending.isNotEmpty) ...[
              _RecheckCard(checkin: pending.first, onPick: _recheck),
              const SizedBox(height: 24),
            ],

            const Text(
              '충동은 없애야 할 적이 아니라 신호예요.\n지금 내 신경계가 어디쯤인지 살펴봐요.',
              style:
                  TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            // 지금 바로 진정이 필요할 때 — 진자 연습
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3FA796),
                side: const BorderSide(color: Color(0xFF9BD3C9)),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const PendulumPracticeScreen()),
              ),
              icon: const Icon(Icons.waves, size: 20),
              label: const Text('🌊 지금 진정이 필요하면 · 진자 연습',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),

            _sectionTitle('1. 지금 어디쯤인가요?'),
            const SizedBox(height: 10),
            ...ArousalLevel.all.map(_arousalOption),
            const SizedBox(height: 24),

            _sectionTitle('2. 몸 어디에서 느껴지나요?'),
            const SizedBox(height: 10),
            _chips(kBodyParts, _bodyPart, (v) => setState(() => _bodyPart = v)),
            const SizedBox(height: 20),

            _sectionTitle('3. 어떤 감각인가요?'),
            const SizedBox(height: 10),
            _chips(
                kSensations, _sensation, (v) => setState(() => _sensation = v)),
            const SizedBox(height: 20),

            _sectionTitle('4. 무엇이 이 신호를 불렀을까요? (선택)'),
            const SizedBox(height: 10),
            TextField(
              controller: _trigger,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                hintText: '예) 혼자 있는 저녁, 문득 허전함',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF2F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            _sectionTitle('5. 상태를 옮겨줄 행동 하나를 고르면?'),
            const SizedBox(height: 10),
            _chips(kActions, _action, (v) => setState(() => _action = v)),
            const SizedBox(height: 12),
            // 51가지 행동 가이드 — 지금 상태에 맞춰 추천
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F8FB0),
                side: const BorderSide(color: Color(0xFFCBDDE7)),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _openGuide,
              icon: const Icon(Icons.menu_book_outlined, size: 20),
              label: Text(
                _arousal == null
                    ? '행동 가이드에서 찾기 (51가지)'
                    : '지금 상태에 맞는 행동 찾기 →',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (_action.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 18, color: Color(0xFF3FA796)),
                    const SizedBox(width: 6),
                    Text('선택: $_action',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C5066))),
                  ],
                ),
              ),
            const SizedBox(height: 28),

            SizedBox(
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F8FB0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: (_arousal == null || _saving) ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('기록하기',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),

            // 최근 기록(전→후)
            if (checkins.isNotEmpty) ...[
              const SizedBox(height: 32),
              _sectionTitle('최근 기록'),
              const SizedBox(height: 10),
              ...checkins.take(7).map((c) => _HistoryRow(checkin: c)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2C5066),
        ),
      );

  Widget _arousalOption(ArousalLevel level) {
    final selected = _arousal == level.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _arousal = level.value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? level.color.withOpacity(0.14)
                : const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? level.color : const Color(0xFFE1EAF0),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(level.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Text(
                level.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? level.color : const Color(0xFF2C5066),
                ),
              ),
              const Spacer(),
              if (selected) Icon(Icons.check_circle, color: level.color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chips(
      List<String> options, String value, ValueChanged<String> onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o),
            selected: value == o,
            showCheckmark: false,
            selectedColor: const Color(0xFF4F8FB0),
            backgroundColor: const Color(0xFFF2F7FA),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: value == o ? Colors.white : const Color(0xFF2C5066),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFDCE8EF)),
            ),
            // 다시 누르면 해제
            onSelected: (_) => onPick(value == o ? '' : o),
          ),
      ],
    );
  }
}

/// 행동 후 재체크 카드.
class _RecheckCard extends StatelessWidget {
  final StateCheckin checkin;
  final void Function(StateCheckin, int) onPick;

  const _RecheckCard({required this.checkin, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final before = ArousalLevel.of(checkin.arousal);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0DFC4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${checkin.action}" 후 지금은 어디쯤인가요?',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C5066),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '이전: ${before.emoji} ${before.label}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final level in ArousalLevel.all)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onPick(checkin, level.value),
                  child: Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: level.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(level.emoji,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 2),
                        Text('${level.value}',
                            style: TextStyle(
                                fontSize: 11, color: level.color)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 최근 기록 한 줄(전 → 후).
class _HistoryRow extends StatelessWidget {
  final StateCheckin checkin;
  const _HistoryRow({required this.checkin});

  String get _time {
    final raw = checkin.createdAt;
    if (raw == null || raw.length < 16) return '';
    // ISO 'YYYY-MM-DDTHH:mm...' → 'MM/DD HH:mm'
    return '${raw.substring(5, 7)}/${raw.substring(8, 10)} '
        '${raw.substring(11, 16)}';
  }

  @override
  Widget build(BuildContext context) {
    final before = ArousalLevel.of(checkin.arousal);
    final after = checkin.arousalAfter != null
        ? ArousalLevel.of(checkin.arousalAfter!)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(_time,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Text(before.emoji, style: const TextStyle(fontSize: 18)),
          if (after != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.arrow_forward,
                  size: 14, color: Color(0xFF9AB4C2)),
            ),
            Text(after.emoji, style: const TextStyle(fontSize: 18)),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [
                if (checkin.bodyPart.isNotEmpty) checkin.bodyPart,
                if (checkin.action.isNotEmpty) checkin.action,
              ].join(' · '),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF5A7A8C)),
            ),
          ),
        ],
      ),
    );
  }
}
