import 'package:shared_preferences/shared_preferences.dart';

import 'translate_service.dart';

/// 지원 언어(코드 → 표시명). Gemini 언어코드 기준.
const Map<String, String> kLanguages = {
  'ko': '한국어',
  'zh-CN': '중국어(간체)',
  'zh-TW': '중국어(번체)',
  'en': '영어',
  'ja': '일본어',
};

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
