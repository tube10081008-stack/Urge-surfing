import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learning_concept.dart';
import '../state/session_controller.dart';

/// 회복 학습 노트 — 5개 그룹의 학술 개념 카드를 보며 메모하며 공부한다.
class LearningNotesScreen extends ConsumerWidget {
  const LearningNotesScreen({super.key});

  static const _groupColors = {
    1: Color(0xFF4F8FB0),
    2: Color(0xFFD9534F),
    3: Color(0xFF7E6BB0),
    4: Color(0xFF3FA796),
    5: Color(0xFFE08A3C),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(learningConceptsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('회복 학습 노트'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C5066),
        elevation: 0,
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('개념을 불러오지 못했어요.\n네트워크를 확인해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5A7A8C))),
            ),
          ),
          data: (concepts) {
            // 그룹별 정렬·묶기
            final byGroup = <int, List<LearningConcept>>{};
            for (final c in concepts) {
              byGroup.putIfAbsent(c.groupNo, () => []).add(c);
            }
            final groups = byGroup.keys.toList()..sort();
            final doneCount = concepts.where((c) => c.hasNote).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('상담에서 배운 개념을 카드마다 짧게 필기하며 내 것으로 만들어요.',
                    style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Text('필기한 개념 $doneCount / ${concepts.length}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F8FB0))),
                const SizedBox(height: 12),
                for (final g in groups) ...[
                  _groupHeader(g, byGroup[g]!.first.groupTitle),
                  ...byGroup[g]!.map((c) => _card(context, ref, c)),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _groupHeader(int no, String title) {
    final color = _groupColors[no] ?? const Color(0xFF4F8FB0);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text('$no',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, LearningConcept c) {
    final color = _groupColors[c.groupNo] ?? const Color(0xFF4F8FB0);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFF7FAFC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => ConceptDetailScreen(concept: c)),
          );
          ref.invalidate(learningConceptsProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(c.title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2C5066))),
                  ),
                  Icon(
                    c.hasNote
                        ? Icons.edit_note
                        : Icons.chevron_right,
                    color: c.hasNote ? color : const Color(0xFFB0C4D0),
                  ),
                ],
              ),
              if (c.titleEn.isNotEmpty || c.originator.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [
                      if (c.titleEn.isNotEmpty) c.titleEn,
                      if (c.originator.isNotEmpty) c.originator,
                    ].join(' · '),
                    style:
                        TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                  ),
                ),
              const SizedBox(height: 6),
              Text(c.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, height: 1.4, color: Color(0xFF5A7A8C))),
              if (c.hasNote) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('✎ ${c.note}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: color)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 개념 상세 + 메모 편집(A5 반 페이지 분량).
class ConceptDetailScreen extends ConsumerStatefulWidget {
  final LearningConcept concept;
  const ConceptDetailScreen({super.key, required this.concept});

  @override
  ConsumerState<ConceptDetailScreen> createState() =>
      _ConceptDetailScreenState();
}

class _ConceptDetailScreenState extends ConsumerState<ConceptDetailScreen> {
  late final TextEditingController _note =
      TextEditingController(text: widget.concept.note);
  bool _saving = false;
  String? _msg;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _msg = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .saveLearningNote(widget.concept.id, _note.text.trim());
      ref.invalidate(learningConceptsProvider);
      if (mounted) setState(() => _msg = '저장했어요');
    } catch (_) {
      if (mounted) setState(() => _msg = '저장 실패: 네트워크를 확인해 주세요');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.concept;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('학습 카드'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C5066),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(c.groupTitle,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9AB4C2))),
            const SizedBox(height: 4),
            Text(c.title,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5066))),
            if (c.titleEn.isNotEmpty || c.originator.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    if (c.titleEn.isNotEmpty) c.titleEn,
                    if (c.originator.isNotEmpty) c.originator,
                  ].join(' · '),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            const SizedBox(height: 20),
            _block('요약', c.summary, const Color(0xFFF2F7FA)),
            if (c.connection.isNotEmpty) ...[
              const SizedBox(height: 12),
              _block('내 회복과의 연결', c.connection, const Color(0xFFF0F7F5)),
            ],
            const SizedBox(height: 24),
            const Text('내 메모',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C5066))),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 8,
              minLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '상담에서 배운 것, 내 경험, 떠오른 생각을 짧게 적어보세요.',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF7FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 12),
            if (_msg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_msg!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _msg!.startsWith('저장했')
                            ? const Color(0xFF3FA796)
                            : Colors.redAccent)),
              ),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F8FB0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('메모 저장',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _block(String label, String text, Color bg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5A7A8C))),
          const SizedBox(height: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 14.5, height: 1.6, color: Color(0xFF2C5066))),
        ],
      ),
    );
  }
}
