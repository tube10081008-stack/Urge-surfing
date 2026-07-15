import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_controller.dart';
import '../widgets/sos_button.dart';
import 'dashboard_screen.dart';
import 'vas_input_screen.dart';

/// 홈 화면.
/// 노출 자극을 불러와 1종을 선택하고, [세션 시작]으로 흐름을 연다.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _startFlow(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(sessionControllerProvider.notifier);
    controller.reset();

    // 노출 자극 선택(첫 번째 자극 사용 — P0는 1종, 음성 가이드는 제외)
    final mediaList = await ref.read(exposureStimuliProvider.future);
    if (mediaList.isNotEmpty) {
      controller.selectMedia(mediaList.first);
    }

    // 세션 생성
    await controller.startSession();

    if (!context.mounted) return;
    // 사전 VAS 화면으로 이동
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const VasInputScreen(phase: VasPhase.pre),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAsync = ref.watch(exposureStimuliProvider);
    final state = ref.watch(sessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('마음 파도타기'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF2F7FA),
        foregroundColor: const Color(0xFF2C5066),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.insights),
            tooltip: '내 기록',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: const SosButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                '충동은 파도와 같아요',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C5066),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '밀려오는 충동을 억누르지 않고, 가만히 바라보며 지나가도록 '
                '함께 연습해요. 잘하고 못하고는 없어요. 오늘 한 번의 시도가 중요해요.',
                style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
              ),
              const SizedBox(height: 32),

              // 오늘의 노출 자극 카드
              Card(
                elevation: 0,
                color: const Color(0xFFF2F7FA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: mediaAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Text('자극을 불러오지 못했어요: $e'),
                    data: (list) {
                      if (list.isEmpty) {
                        return const Text('등록된 노출 자극이 없어요.');
                      }
                      final m = list.first;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('오늘의 노출 연습',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF5A7A8C))),
                          const SizedBox(height: 6),
                          Text(m.title,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('카테고리 ${m.category} · 강도 ${m.intensity}/5',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const Spacer(),

              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),

              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F8FB0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: state.isLoading
                      ? null
                      : () => _startFlow(context, ref),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('세션 시작',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
