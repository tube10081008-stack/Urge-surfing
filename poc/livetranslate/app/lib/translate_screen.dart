import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'phrase_cache.dart';
import 'relay_api.dart';
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
  final _cache = PhraseCache();

  AppSettings? _settings;
  TranslateState _state = TranslateState.idle;
  String? _dir; // 현재 세션 방향 'me' | 'other'
  bool _holding = false; // 버튼을 누르고 있는 중인가(푸시투토크)
  bool _busy = false; // 문구/OCR 네트워크 처리 중

  RelayApi? _api() {
    final s = _settings;
    if (s == null || !s.isConfigured) return null;
    return RelayApi(s.relayUrl, s.token);
  }

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

  // 누르는 순간: 세션 시작/방향 전환 + 캡처 on(푸시투토크).
  Future<void> _pressDown(String dir) async {
    final s = _settings;
    if (s == null) return;
    if (!s.isConfigured) {
      _openSettings(force: true);
      return;
    }
    setState(() => _holding = true);
    _service.clearLastUtterance(); // 새 발화 시작 → 다시듣기 버퍼 초기화.

    // 내 칸: 내 언어로 말함 → 상대 언어로 출력(target=상대언어).
    // 상대 칸: 상대 언어로 말함 → 내 언어로 출력(target=내언어).
    final target = dir == 'me' ? s.otherLang : s.myLang;

    try {
      if (!_running) {
        await _service.start(
            target: target, relayUrl: s.relayUrl, token: s.token);
      } else if (_dir != dir) {
        await _service.switchTarget(target); // 방향만 전환(마이크 유지).
      }
      if (mounted) setState(() => _dir = dir);
      // 연결 대기 중 손을 뗐을 수 있으니, 여전히 누르고 있을 때만 캡처 on.
      _service.setCapturing(_holding);
    } catch (e) {
      _service.setCapturing(false);
      if (mounted) {
        setState(() => _holding = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  // 손을 떼는 순간: 캡처 off → 번역 음성 재생(마이크 차단으로 피드백 방지).
  void _release() {
    _service.setCapturing(false);
    if (mounted) setState(() => _holding = false);
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /// 텍스트를 대상 언어로 번역·음성 출력(문구/OCR 듣기 공용).
  Future<void> _speakText(String text, String targetLang) async {
    final api = _api();
    if (api == null) {
      _openSettings(force: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await api.speak(text, targetLang);
      await _service.playPcm(res.audio);
      _snack('🔊 ${res.translated}');
    } catch (e) {
      _snack('문구 음성 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ⭐ 자주 쓰는 문구 (카테고리 + 오프라인 캐시)
  void _onPresets() {
    final s = _settings;
    if (s == null || !s.isConfigured) {
      _openSettings(force: true);
      return;
    }
    final book = phrasebookFor(s.myLang);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (c, scroll) => Column(
          children: [
            ListTile(
              title: const Text('자주 쓰는 문구',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('탭하면 ${kAutonym[s.otherLang] ?? s.otherLang} 음성으로'),
              trailing: TextButton.icon(
                icon: const Icon(Icons.download_for_offline),
                label: const Text('오프라인 받기'),
                onPressed: () => _prefetchPresets(s.otherLang, book),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scroll,
                children: [
                  for (final entry in book.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                      child: Text(entry.key,
                          style: Theme.of(c).textTheme.labelLarge?.copyWith(
                              color: Theme.of(c).colorScheme.primary)),
                    ),
                    for (final p in entry.value)
                      ListTile(
                        dense: true,
                        title: Text(p),
                        trailing: const Icon(Icons.volume_up, size: 20),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _playPreset(p, s.otherLang);
                        },
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 문구 재생: 캐시 우선(오프라인). 없으면 온라인 /speak 후 캐시에 저장.
  Future<void> _playPreset(String text, String targetLang) async {
    final cached = await _cache.get(targetLang, text);
    if (cached != null) {
      await _service.playPcm(cached); // 네트워크 불필요
      _snack('🔊 (오프라인) $text');
      return;
    }
    final api = _api();
    if (api == null) {
      _openSettings(force: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await api.speak(text, targetLang);
      await _service.playPcm(res.audio);
      await _cache.put(targetLang, text, res.audio); // 다음엔 오프라인
      _snack('🔊 ${res.translated}');
    } catch (e) {
      _snack('문구 음성 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 현재 문구집 전체를 대상 언어로 미리 받아 캐시(오프라인 대비).
  Future<void> _prefetchPresets(
      String targetLang, Map<String, List<String>> book) async {
    final api = _api();
    if (api == null) return;
    final all = [for (final e in book.entries) ...e.value];
    final progress = ValueNotifier<int>(0);
    var cancelled = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('오프라인 음성 받기 (${kAutonym[targetLang] ?? targetLang})'),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, v, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Text('$v / ${all.length}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => cancelled = true,
            child: const Text('중지'),
          ),
        ],
      ),
    );

    var done = 0;
    for (final p in all) {
      if (cancelled) break;
      try {
        if (!await _cache.has(targetLang, p)) {
          final res = await api.speak(p, targetLang);
          await _cache.put(targetLang, p, res.audio);
        }
      } catch (_) {
        // 개별 실패는 건너뛴다.
      }
      progress.value = ++done;
    }
    if (mounted) Navigator.of(context).pop(); // 진행 다이얼로그 닫기
    progress.dispose();
    _snack('오프라인 음성 $done개 준비 완료');
  }

  // 📷 카메라 OCR 번역
  Future<void> _onCamera() async {
    final s = _settings;
    if (s == null || !s.isConfigured) {
      _openSettings(force: true);
      return;
    }
    final XFile? shot = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
    if (shot == null) return;
    final api = _api();
    if (api == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await shot.readAsBytes();
      final res = await api.ocr(bytes, s.myLang); // 내 언어로 읽기
      if (mounted) _showOcrResult(res.original, res.translated, s.myLang);
    } catch (e) {
      _snack('이미지 번역 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showOcrResult(String original, String translated, String myLang) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카메라 번역'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('원문', style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(original.isEmpty ? '(인식된 텍스트 없음)' : original),
              const Divider(height: 24),
              Text('번역', style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(translated),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
          if (translated.isNotEmpty)
            FilledButton.icon(
              icon: const Icon(Icons.volume_up),
              label: const Text('들려주기'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _speakText(translated, myLang);
              },
            ),
        ],
      ),
    );
  }

  // 🔁 마지막 통역 다시듣기
  Future<void> _onReplay() async {
    if (!_service.hasLastAudio) {
      _snack('다시 들을 통역이 없어요');
      return;
    }
    await _service.replayLast();
  }

  // active 칸의 상태 문구를 그 화자 언어(uiLang)로.
  String _hintFor(bool active, String uiLang) {
    if (!active) return paneText(uiLang, 'hold');
    return switch (_state) {
      TranslateState.connecting => paneText(uiLang, 'connecting'),
      TranslateState.ready => paneText(uiLang, 'speaking'),
      TranslateState.reconnecting => paneText(uiLang, 'reconnecting'),
      TranslateState.error => paneText(uiLang, 'error'),
      TranslateState.idle => paneText(uiLang, 'hold'),
    };
  }

  Widget _pane({
    required String dir,
    required String spokenLang,
    required String outLang,
  }) {
    // 이 칸을 쓰는 사람의 언어 = spokenLang. UI 문구를 그 언어로 보여준다.
    final uiLang = spokenLang;
    final active = _holding && _dir == dir;
    final scheme = Theme.of(context).colorScheme;
    final bg = active ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = active ? scheme.onPrimary : scheme.onSurfaceVariant;
    final spoken = kAutonym[spokenLang] ?? spokenLang;
    final out = kAutonym[outLang] ?? outLang;

    // 부모(Expanded)가 높이를 주므로 여기선 Expanded를 쓰지 않는다.
    // Listener로 '누르고 있는 동안만' 캡처(푸시투토크).
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Listener(
        onPointerDown:
            _settings == null ? null : (_) => _pressDown(dir),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(24),
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
                Text(_hintFor(active, uiLang),
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
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      bottomNavigationBar: s == null ? null : _bottomBar(),
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

  Widget _bottomBar() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _barButton(Icons.star, '문구', _busy ? null : _onPresets),
          _barButton(Icons.photo_camera, '카메라 번역', _busy ? null : _onCamera),
          _barButton(Icons.replay, '다시듣기', _busy ? null : _onReplay),
        ],
      ),
    );
  }

  Widget _barButton(IconData icon, String label, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
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
