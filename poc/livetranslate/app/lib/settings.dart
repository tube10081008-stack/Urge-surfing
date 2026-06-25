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
    'hold': '탭하여 말하기',
    'speaking': '듣는 중… 말하세요',
    'connecting': '연결 중…',
    'reconnecting': '재연결 중…',
    'error': '오류 — 설정/네트워크 확인',
  },
  'zh-CN': {
    'hold': '点这里说话',
    'speaking': '正在聆听… 请说',
    'connecting': '连接中…',
    'reconnecting': '重新连接中…',
    'error': '出错 — 请检查设置/网络',
  },
  'zh-TW': {
    'hold': '點這裡說話',
    'speaking': '正在聆聽… 請說',
    'connecting': '連線中…',
    'reconnecting': '重新連線中…',
    'error': '發生錯誤 — 請檢查設定/網路',
  },
  'en': {
    'hold': 'Tap to talk',
    'speaking': 'Listening… speak now',
    'connecting': 'Connecting…',
    'reconnecting': 'Reconnecting…',
    'error': 'Error — check settings/network',
  },
  'ja': {
    'hold': 'タップして話す',
    'speaking': '聞いています… どうぞ',
    'connecting': '接続中…',
    'reconnecting': '再接続中…',
    'error': 'エラー — 設定/ネットワークを確認',
  },
};

/// 해당 언어의 칸 문구. 없으면 영어로 폴백.
String paneText(String lang, String key) =>
    (kPaneStrings[lang] ?? kPaneStrings['en']!)[key] ??
    kPaneStrings['en']![key]!;

/// 카테고리별 여행 문구(화자 언어 기준). 탭하면 상대 언어로 번역·음성 출력.
/// 카테고리당 6~8개, 합계 100개 미만. 한국어가 주 언어, 그 외는 영어로 폴백.
const Map<String, Map<String, List<String>>> kPhrasebook = {
  'ko': {
    '인사·기본': [
      '안녕하세요',
      '감사합니다',
      '죄송합니다',
      '네, 좋아요',
      '아니요, 괜찮아요',
      '잠시만요',
      '천천히 말해 주세요',
    ],
    '식당': [
      '메뉴 주세요',
      '이거 주세요',
      '맵지 않게 해주세요',
      '물 좀 주세요',
      '계산해 주세요',
      '포장해 주세요',
      '정말 맛있어요',
    ],
    '쇼핑·흥정': [
      '이거 얼마예요?',
      '너무 비싸요',
      '좀 깎아주세요',
      '카드 되나요?',
      '영수증 주세요',
      '다른 색 있어요?',
      '한 번 입어봐도 돼요?',
    ],
    '길찾기·교통': [
      '화장실이 어디예요?',
      '여기가 어디예요?',
      '지하철역이 어디예요?',
      '택시를 불러 주세요',
      '공항으로 가 주세요',
      '얼마나 걸려요?',
      '여기서 세워 주세요',
    ],
    '숙소': [
      '체크인하고 싶어요',
      '예약했어요',
      '와이파이 비밀번호가 뭐예요?',
      '방을 바꿔 주세요',
      '짐을 맡길 수 있어요?',
      '몇 시에 체크아웃이에요?',
    ],
    '응급·도움': [
      '도와주세요',
      '경찰을 불러 주세요',
      '병원이 어디예요?',
      '몸이 아파요',
      '길을 잃었어요',
      '한국어 할 줄 아는 사람 있어요?',
    ],
  },
  'en': {
    'Basics': [
      'Hello',
      'Thank you',
      'Sorry',
      'Yes, please',
      'No, thank you',
      'One moment',
      'Please speak slowly',
    ],
    'Restaurant': [
      'Menu, please',
      'I will have this',
      'Not spicy, please',
      'Water, please',
      'Check, please',
      'To go, please',
      'It is delicious',
    ],
    'Shopping': [
      'How much is this?',
      'Too expensive',
      'Can you lower the price?',
      'Do you take cards?',
      'Receipt, please',
      'Any other color?',
      'Can I try it on?',
    ],
    'Directions': [
      'Where is the restroom?',
      'Where am I?',
      'Where is the subway station?',
      'Please call a taxi',
      'To the airport, please',
      'How long does it take?',
      'Stop here, please',
    ],
    'Hotel': [
      'I want to check in',
      'I have a reservation',
      'What is the Wi-Fi password?',
      'Please change my room',
      'Can I leave my luggage?',
      'What time is checkout?',
    ],
    'Emergency': [
      'Help me',
      'Call the police',
      'Where is the hospital?',
      'I feel sick',
      'I am lost',
      'Does anyone speak English?',
    ],
  },
};

/// 화자 언어의 문구집. 없으면 영어로 폴백.
Map<String, List<String>> phrasebookFor(String lang) =>
    kPhrasebook[lang] ?? kPhrasebook['en']!;

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
