import 'package:flutter/material.dart';

import 'translate_service.dart';

/// 실시간 음성 통역 화면.
///
/// 언어를 고르고 [말하기 시작]을 누르면 마이크 음성이 릴레이를 거쳐
/// Gemini Live Translate로 번역되어 상대 언어 음성으로 재생된다.
class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _service = TranslateService();

  // 지원 언어(데모용 일부). value는 Gemini 언어코드.
  static const _languages = <String, String>{
    '중국어(간체)': 'zh-CN',
    '영어': 'en',
    '일본어': 'ja',
    '한국어': 'ko',
  };

  String _target = 'zh-CN';
  TranslateState _state = TranslateState.idle;
  final List<String> _transcripts = [];

  @override
  void initState() {
    super.initState();
    _service.state.listen((s) => setState(() => _state = s));
    _service.transcript.listen((t) {
      if (t.trim().isEmpty) return;
      setState(() => _transcripts.add(t));
    });
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  bool get _running =>
      _state == TranslateState.connecting ||
      _state == TranslateState.ready ||
      _state == TranslateState.reconnecting;

  Future<void> _toggle() async {
    if (_running) {
      await _service.stop();
      return;
    }
    try {
      setState(() => _transcripts.clear());
      await _service.start(target: _target);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String get _statusLabel => switch (_state) {
        TranslateState.idle => '대기 중',
        TranslateState.connecting => '연결 중…',
        TranslateState.ready => '통역 중 — 말씀하세요',
        TranslateState.reconnecting => '재연결 중… (네트워크 복구 대기)',
        TranslateState.error => '오류 — 릴레이/네트워크 확인',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('실시간 음성 통역')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('번역 대상 언어'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _target,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _languages.entries
                  .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
                  .toList(),
              onChanged: _running
                  ? null
                  : (v) => setState(() => _target = v ?? _target),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                _statusLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _transcripts.isEmpty
                  ? const Center(
                      child: Text(
                        '자막이 여기에 표시됩니다',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      itemCount: _transcripts.length,
                      itemBuilder: (_, i) {
                        // 최신이 아래로 오도록 역순 표시.
                        final text = _transcripts[_transcripts.length - 1 - i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(text),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(_running ? Icons.stop : Icons.mic),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: _running ? Colors.red : null,
              ),
              label: Text(_running ? '중지' : '말하기 시작'),
            ),
          ],
        ),
      ),
    );
  }
}
