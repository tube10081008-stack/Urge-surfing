import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/coping_action.dart';
import '../state/session_controller.dart';

/// 상태 이동 행동 가이드(표) — 무엇이 나를 창 안으로 데려오는지 보고 골라 실험한다.
///
/// [initialDirection]이 주어지면(지금 상태 기반) 그 방향으로 먼저 필터링한다.
/// 항목을 탭하면 그 행동 제목을 반환(Navigator.pop)해 체크인에 채운다.
class ActionGuideScreen extends ConsumerStatefulWidget {
  final String? initialDirection;

  const ActionGuideScreen({super.key, this.initialDirection});

  @override
  ConsumerState<ActionGuideScreen> createState() => _ActionGuideScreenState();
}

class _ActionGuideScreenState extends ConsumerState<ActionGuideScreen> {
  String? _filter; // null=전체, 'up'/'down'/'ground'

  @override
  void initState() {
    super.initState();
    _filter = widget.initialDirection;
  }

  @override
  Widget build(BuildContext context) {
    final actionsAsync = ref.watch(copingActionsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('행동 가이드'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C5066),
        elevation: 0,
      ),
      body: SafeArea(
        child: actionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('가이드를 불러오지 못했어요.\n네트워크를 확인해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5A7A8C))),
            ),
          ),
          data: (all) => _body(all),
        ),
      ),
    );
  }

  Widget _body(List<CopingAction> all) {
    final filtered =
        _filter == null ? all : all.where((a) => a.direction == _filter).toList();

    // 분류별 그룹핑
    final byCategory = <String, List<CopingAction>>{};
    for (final a in filtered) {
      byCategory.putIfAbsent(a.category, () => []).add(a);
    }

    return Column(
      children: [
        // 방향 필터
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SizedBox(
            height: 62,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(null, '전체', '', const Color(0xFF7A93A8)),
                for (final d in ActionDirection.all)
                  _filterChip(d.key, '${d.emoji} ${d.label}', d.hint, d.color),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '탭하면 그 행동으로 실험을 시작해요. 다녀와서 다시 상태를 체크하면 효과가 기록됩니다.',
                style: TextStyle(
                    fontSize: 13, height: 1.5, color: Color(0xFF5A7A8C)),
              ),
              const SizedBox(height: 12),
              for (final entry in byCategory.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(entry.key,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C5066))),
                ),
                ...entry.value.map(_actionCard),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String? key, String label, String hint, Color color) {
    final selected = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.14) : const Color(0xFFF2F7FA),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? color : const Color(0xFFE1EAF0),
                width: selected ? 1.5 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? color : const Color(0xFF2C5066))),
              if (hint.isNotEmpty)
                Text(hint,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(CopingAction a) {
    final dir = ActionDirection.of(a.direction);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFF7FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).pop(a.title),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dir.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(dir.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(a.title,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2C5066))),
                        ),
                        const SizedBox(width: 6),
                        _effortBadge(a.effort),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(a.note,
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Color(0xFF5A7A8C))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB0C4D0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _effortBadge(int effort) {
    const labels = {1: '즉시', 2: '보통', 3: '준비'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0F4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(labels[effort] ?? '',
          style: const TextStyle(fontSize: 10, color: Color(0xFF5A7A8C))),
    );
  }
}
