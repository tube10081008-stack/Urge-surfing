import 'package:shared_preferences/shared_preferences.dart';

import 'translate_service.dart';

/// 지원 언어(코드 → 한국어 표시명). 설정 드롭다운용.
const Map<String, String> kLanguages = {
  'ko': '한국어',
  'zh-CN': '중국어(간체)',
  'zh-TW': '중국어(번체)',
  'en': '영어',
  'ja': '일본어',
};

/// 각 언어의 자기 언어 표기(autonym). 누가 보든 알아보도록 칸 라벨에 사용.
const Map<String, String> kAutonym = {
  'ko': '한국어',
  'zh-CN': '中文(简体)',
  'zh-TW': '中文(繁體)',
  'en': 'English',
  'ja': '日本語',
};

/// 칸 UI 문구를 그 화자의 언어로 제공(상대 배려).
const Map<String, Map<String, String>> kPaneStrings = {
  'ko': {
    'hold': '꾹 눌러 말하기',
    'speaking': '말하는 중… 손 떼면 통역',
    'connecting': '연결 중…',
    'reconnecting': '재연결 중…',
    'error': '오류 — 설정/네트워크 확인',
  },
  'zh-CN': {
    'hold': '按住说话',
    'speaking': '正在聆听… 松开后翻译',
    'connecting': '连接中…',
    'reconnecting': '重新连接中…',
    'error': '出错 — 请检查设置/网络',
  },
  'zh-TW': {
    'hold': '按住說話',
    'speaking': '正在聆聽… 放開後翻譯',
    'connecting': '連線中…',
    'reconnecting': '重新連線中…',
    'error': '發生錯誤 — 請檢查設定/網路',
  },
  'en': {
    'hold': 'Hold to talk',
    'speaking': 'Listening… release to translate',
    'connecting': 'Connecting…',
    'reconnecting': 'Reconnecting…',
    'error': 'Error — check settings/network',
  },
  'ja': {
    'hold': '押して話す',
    'speaking': '話してください… 離すと翻訳',
    'connecting': '接続中…',
    'reconnecting': '再接続中…',
    'error': 'エラー — 設定/ネットワークを確認',
  },
};

/// 해당 언어의 칸 문구. 없으면 영어로 폴백.
String paneText(String lang, String key) =>
    (kPaneStrings[lang] ?? kPaneStrings['en']!)[key] ??
    kPaneStrings['en']![key]!;

/// 앱 설정(릴레이 주소/토큰 + 대화 언어쌍). SharedPreferences에 저장.
class AppSettings {
  String relayUrl;
  String token;
  String myLang; // 내 언어 코드
  String otherLang; // 상대 언어 코드

  AppSettings({
    required this.relayUrl,
    required this.token,
    required this.myLang,
    required this.otherLang,
  });

  static const _kUrl = 'relayUrl';
  static const _kToken = 'relayToken';
  static const _kMy = 'myLang';
  static const _kOther = 'otherLang';

  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return AppSettings(
      relayUrl: p.getString(_kUrl) ?? TranslateService.defaultRelayBaseUrl,
      token: p.getString(_kToken) ?? TranslateService.defaultRelayToken,
      myLang: p.getString(_kMy) ?? 'ko',
      otherLang: p.getString(_kOther) ?? 'zh-CN',
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUrl, relayUrl.trim());
    await p.setString(_kToken, token.trim());
    await p.setString(_kMy, myLang);
    await p.setString(_kOther, otherLang);
  }

  /// 릴레이 주소가 비어있으면 아직 설정 전.
  bool get isConfigured => relayUrl.trim().isNotEmpty &&
      !relayUrl.contains('my-relay.example.com');
}
