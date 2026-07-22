import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/life_compass.dart';
import '../state/session_controller.dart';

/// 삶의 나침반 화면 — 의미 있는 목표와 1/5/10년 계획을 적고 되새긴다.
/// 도박 충동의 기저(무료함·외로움)를 방향과 몰입으로 대체하기 위한 공간.
class CompassScreen extends ConsumerStatefulWidget {
  const CompassScreen({super.key});

  @override
  ConsumerState<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends ConsumerState<CompassScreen> {
  final _life = TextEditingController();
  final _study = TextEditingController();
  final _g1 = TextEditingController();
  final _g5 = TextEditingController();
  final _g10 = TextEditingController();

  bool _loaded = false;
  bool _saving = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await ref.read(apiClientProvider).fetchCompass();
      _life.text = c.lifeGoal;
      _study.text = c.studyDomain;
      _g1.text = c.goal1y;
      _g5.text = c.goal5y;
      _g10.text = c.goal10y;
    } catch (_) {
      // 불러오기 실패 시 빈 폼으로 시작
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [_life, _study, _g1, _g5, _g10]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _msg = null;
    });
    try {
      await ref.read(apiClientProvider).saveCompass(LifeCompass(
            lifeGoal: _life.text.trim(),
            studyDomain: _study.text.trim(),
            goal1y: _g1.text.trim(),
            goal5y: _g5.text.trim(),
            goal10y: _g10.text.trim(),
          ));
      ref.invalidate(compassProvider); // 다른 화면 리마인드 갱신
      if (mounted) setState(() => _msg = '저장했어요');
    } catch (e) {
      if (mounted) setState(() => _msg = '저장 실패: 네트워크를 확인해 주세요');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('삶의 나침반'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C5066),
        elevation: 0,
      ),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    '충동은 대개 무료함과 외로움에서 와요.\n그 자리를 방향과 몰입으로 채워봐요.',
                    style: TextStyle(
                        fontSize: 14, height: 1.6, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  _field(
                    _life,
                    icon: Icons.favorite_outline,
                    label: '의미 있는 삶의 목표',
                    hint: '나는 어떤 삶을 살고 싶은가 (가치 한두 줄)',
                    color: const Color(0xFFE0607A),
                  ),
                  _field(
                    _study,
                    icon: Icons.menu_book_outlined,
                    label: '1만 시간 학습 영역',
                    hint: '하루 3시간 몰입할 분야 · 자격/전문성',
                    color: const Color(0xFF4F8FB0),
                  ),
                  const SizedBox(height: 8),
                  const Text('기간별 목표',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C5066))),
                  const SizedBox(height: 12),
                  _field(_g1,
                      icon: Icons.looks_one_outlined,
                      label: '1년 목표',
                      hint: '올해 이루고 싶은 것',
                      color: const Color(0xFF3FA796)),
                  _field(_g5,
                      icon: Icons.looks_5_outlined,
                      label: '5년 목표',
                      hint: '5년 뒤의 나',
                      color: const Color(0xFF3FA796)),
                  _field(_g10,
                      icon: Icons.filter_9_plus_outlined,
                      label: '10년 목표',
                      hint: '10년 뒤 도달할 곳',
                      color: const Color(0xFF3FA796)),
                  const SizedBox(height: 8),
                  if (_msg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_msg!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _msg!.startsWith('저장했')
                                ? const Color(0xFF3FA796)
                                : Colors.redAccent,
                          )),
                    ),
                  SizedBox(
                    height: 54,
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
                          : const Text('저장',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _field(
    TextEditingController c, {
    required IconData icon,
    required String label,
    required String hint,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: c,
            maxLines: null,
            minLines: 1,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF2F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
