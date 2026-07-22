import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_controller.dart';
import '../widgets/sos_button.dart';
import 'dashboard_screen.dart';

/// 결과 화면.
/// 사전/사후 갈망(VAS)을 비교하고, outcome(success/relapse)을 자동 판정하여 보여준다.
/// 진입 시 결과를 백엔드로 전송(POST /urge-surfing + PATCH 완료)한다.
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 진입 직후 결과 전송.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionControllerProvider.notifier).finishAndSubmit();
    });
  }

  void _backToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionControllerProvider);
    final pre = state.preVas ?? 0;
    final post = state.postVas ?? pre;
    final success = state.outcome == 'success';

    final accent =
        success ? const Color(0xFF3FA796) : const Color(0xFFE08A3C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('오늘의 결과'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C5066),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: const SosButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Icon(
                success ? Icons.spa : Icons.self_improvement,
                size: 64,
                color: accent,
              ),
              const SizedBox(height: 16),
              Text(
                success ? '파도를 잘 넘겼어요' : '시도한 것만으로 충분해요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                success
                    ? '충동을 견뎌내고 갈망이 줄어들었어요. 이 경험을 기억해 주세요.'
                    : '오늘은 갈망이 크게 줄지 않았지만, 끝까지 함께한 것 자체가 중요한 연습이에요. '
                        '필요하면 1336에 도움을 요청해도 좋아요.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, height: 1.6, color: Colors.black87),
              ),
              const SizedBox(height: 32),

              // 전후 비교 카드
              Card(
                elevation: 0,
                color: const Color(0xFFF2F7FA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _VasBadge(label: '연습 전', value: pre),
                      const Icon(Icons.arrow_forward,
                          color: Color(0xFF5A7A8C)),
                      _VasBadge(label: '연습 후', value: post, highlight: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  state.reduction > 0
                      ? '갈망이 ${state.reduction}만큼 줄었어요'
                      : '갈망 변화 ${state.reduction}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // 삶의 나침반 리마인드 — 왜 이 파도를 넘겼는가
              ref.watch(compassProvider).maybeWhen(
                    data: (c) => c.lifeGoal.isEmpty
                        ? const SizedBox.shrink()
                        : Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBF3F5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.explore_outlined,
                                    color: Color(0xFFE0607A)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('오늘 이 파도를 넘긴 건',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF8A6B72))),
                                      const SizedBox(height: 4),
                                      Text(c.lifeGoal,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              height: 1.4,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2C5066))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
              const SizedBox(height: 12),
              if (state.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('결과를 전송하는 중…',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(state.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent)),
                ),

              const Spacer(),
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F8FB0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _backToHome,
                  child: const Text('홈으로',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                ),
                icon: const Icon(Icons.insights, size: 18),
                label: const Text('내 기록 보기'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4F8FB0),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// 전/후 VAS 값을 보여주는 작은 배지.
class _VasBadge extends StatelessWidget {
  final String label;
  final int value;
  final bool highlight;

  const _VasBadge({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        highlight ? const Color(0xFF3FA796) : const Color(0xFF5A7A8C);
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 8),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
