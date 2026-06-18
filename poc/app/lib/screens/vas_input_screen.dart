import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session_controller.dart';
import '../widgets/sos_button.dart';
import '../widgets/vas_slider.dart';
import 'exposure_screen.dart';
import 'result_screen.dart';

enum VasPhase { pre, post }

/// 사전/사후 VAS 입력 화면.
/// - pre: 입력 후 노출 화면으로 진행
/// - post: 입력 후 결과 화면으로 진행
class VasInputScreen extends ConsumerStatefulWidget {
  final VasPhase phase;

  const VasInputScreen({super.key, required this.phase});

  @override
  ConsumerState<VasInputScreen> createState() => _VasInputScreenState();
}

class _VasInputScreenState extends ConsumerState<VasInputScreen> {
  int _value = 5;

  bool get _isPre => widget.phase == VasPhase.pre;

  String get _title => _isPre ? '지금 갈망은 어느 정도인가요?' : '지금은 어떤가요?';

  String get _subtitle => _isPre
      ? '노출 연습을 시작하기 전, 지금 느끼는 도박 충동의 세기를 표시해 주세요.'
      : '파도타기를 마친 지금, 남아있는 충동의 세기를 표시해 주세요. 변화가 작아도 괜찮아요.';

  Future<void> _next() async {
    final controller = ref.read(sessionControllerProvider.notifier);
    if (_isPre) {
      await controller.submitPreVas(_value);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ExposureScreen()),
      );
    } else {
      await controller.submitPostVas(_value);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ResultScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionControllerProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isPre ? '사전 갈망 체크' : '사후 갈망 체크'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2C5066),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: const SosButton(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(_title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C5066))),
              const SizedBox(height: 10),
              Text(_subtitle,
                  style: const TextStyle(
                      fontSize: 15, height: 1.6, color: Colors.black87)),
              const Spacer(),
              VasSlider(
                value: _value,
                onChanged: (v) => setState(() => _value = v),
              ),
              const Spacer(),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(state.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent)),
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
                  onPressed: state.isLoading ? null : _next,
                  child: state.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(_isPre ? '노출 연습 시작' : '결과 보기',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
