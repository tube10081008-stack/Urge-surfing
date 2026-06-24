import 'package:flutter/material.dart';

import 'settings.dart';
import 'translate_service.dart';

/// 양방향 대화 통역 화면.
///
/// 식탁 맞은편 통역기 스타일: 화면을 위/아래로 나눠 두 사람이 각자
/// 자기 칸을 탭해 말한다. 위쪽 칸은 180° 회전되어 맞은편 상대가 똑바로 본다.
/// - 아래(나): 내 언어로 말하기 → 상대 언어 음성 출력
/// - 위(상대): 상대 언어로 말하기 → 내 언어 음성 출력
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _service = TranslateService();

  AppSettings? _settings;
  TranslateState _state = TranslateState.idle;
  String? _activeDir; // 'me' | 'other' | null

  @override
  void initState() {
    super.initState();
    _service.state.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await AppSettings.load();
    if (mounted) setState(() => _settings = s);
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

  Future<void> _tapDirection(String dir) async {
    final s = _settings;
    if (s == null) return;
    if (!s.isConfigured) {
      _openSettings(force: true);
      return;
    }

    // 내 칸: 내 언어로 말함 → 상대 언어로 출력(target=상대언어).
    // 상대 칸: 상대 언어로 말함 → 내 언어로 출력(target=내언어).
    final target = dir == 'me' ? s.otherLang : s.myLang;

    // 같은 칸 다시 탭 → 정지.
    if (_activeDir == dir && _running) {
      await _service.stop();
      if (mounted) setState(() => _activeDir = null);
      return;
    }

    try {
      if (!_running) {
        await _service.start(
          target: target,
          relayUrl: s.relayUrl,
          token: s.token,
        );
      } else {
        await _service.switchTarget(target); // 방향만 전환(마이크 유지).
      }
      if (mounted) setState(() => _activeDir = dir);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  String _hintFor(bool active) {
    if (!active) return '탭하여 말하기';
    return switch (_state) {
      TranslateState.connecting => '연결 중…',
      TranslateState.ready => '듣는 중 — 말하세요',
      TranslateState.reconnecting => '재연결 중…',
      TranslateState.error => '오류 — 설정/네트워크 확인',
      TranslateState.idle => '준비',
    };
  }

  Widget _pane({
    required String dir,
    required String spokenLang,
    required String outLang,
  }) {
    final active = _activeDir == dir;
    final scheme = Theme.of(context).colorScheme;
    final bg = active ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = active ? scheme.onPrimary : scheme.onSurfaceVariant;
    final spoken = kLanguages[spokenLang] ?? spokenLang;
    final out = kLanguages[outLang] ?? outLang;

    // 부모(Expanded)가 높이를 주므로 여기선 Expanded를 쓰지 않는다.
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _settings == null ? null : () => _tapDirection(dir),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(active ? Icons.mic : Icons.mic_none, size: 64, color: fg),
                const SizedBox(height: 12),
                Text('$spoken  →  $out',
                    style: TextStyle(
                        color: fg,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (active && _state == TranslateState.connecting)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: fg),
                    ),
                  ),
                Text(_hintFor(active),
                    style: TextStyle(color: fg, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('대화 통역'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '설정',
            onPressed: _running ? null : () => _openSettings(),
          ),
        ],
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!s.isConfigured)
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.errorContainer,
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '먼저 우측 상단 ⚙ 설정에서 릴레이 주소를 입력하세요.',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // 위: 상대 칸(180° 회전 — 맞은편에서 똑바로 보임)
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 2,
                    child: _pane(
                        dir: 'other',
                        spokenLang: s.otherLang,
                        outLang: s.myLang),
                  ),
                ),
                const Divider(height: 1),
                // 아래: 내 칸
                Expanded(
                  child: _pane(
                      dir: 'me', spokenLang: s.myLang, outLang: s.otherLang),
                ),
              ],
            ),
    );
  }

  void _openSettings({bool force = false}) {
    final s = _settings ??
        AppSettings(relayUrl: '', token: '', myLang: 'ko', otherLang: 'zh-CN');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SettingsSheet(
        initial: s,
        onSaved: (next) async {
          await next.save();
          if (mounted) setState(() => _settings = next);
        },
      ),
    );
  }
}

/// 설정 시트: 릴레이 주소/토큰 + 언어쌍.
class _SettingsSheet extends StatefulWidget {
  final AppSettings initial;
  final Future<void> Function(AppSettings) onSaved;
  const _SettingsSheet({required this.initial, required this.onSaved});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late final _url = TextEditingController(text: widget.initial.relayUrl);
  late final _token = TextEditingController(text: widget.initial.token);
  late String _my = widget.initial.myLang;
  late String _other = widget.initial.otherLang;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('설정', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            autocorrect: false,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: '릴레이 주소 (wss://...fly.dev)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            autocorrect: false,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '릴레이 토큰',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _langDropdown('내 언어', _my, (v) => setState(() => _my = v))),
              const SizedBox(width: 12),
              Expanded(
                  child: _langDropdown(
                      '상대 언어', _other, (v) => setState(() => _other = v))),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              widget.onSaved(AppSettings(
                relayUrl: _url.text,
                token: _token.text,
                myLang: _my,
                otherLang: _other,
              ));
              Navigator.of(context).pop();
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _langDropdown(String label, String value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: kLanguages.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}
