import 'package:flutter/material.dart';

/// 신경계 상태 체크인 모델.
/// 백엔드 `POST/PATCH/GET /state-checkins` 에 대응한다.
class StateCheckin {
  final int id;

  /// 각성도 1~5 (1=무기력 … 3=창 안 … 5=과각성)
  final int arousal;
  final String bodyPart;
  final String sensation;
  final String trigger;
  final String action;

  /// 행동 후 재체크 값(없으면 미완료)
  final int? arousalAfter;
  final String? createdAt;

  const StateCheckin({
    required this.id,
    required this.arousal,
    this.bodyPart = '',
    this.sensation = '',
    this.trigger = '',
    this.action = '',
    this.arousalAfter,
    this.createdAt,
  });

  bool get needsRecheck => action.isNotEmpty && arousalAfter == null;

  factory StateCheckin.fromJson(Map<String, dynamic> json) {
    return StateCheckin(
      id: json['id'] as int,
      arousal: (json['arousal'] as num).toInt(),
      bodyPart: json['body_part'] as String? ?? '',
      sensation: json['sensation'] as String? ?? '',
      trigger: json['trigger'] as String? ?? '',
      action: json['action'] as String? ?? '',
      arousalAfter: (json['arousal_after'] as num?)?.toInt(),
      createdAt: json['created_at'] as String?,
    );
  }
}

/// 각성도 단계 표현(라벨·이모지·색).
class ArousalLevel {
  final int value;
  final String emoji;
  final String label;
  final Color color;

  const ArousalLevel(this.value, this.emoji, this.label, this.color);

  static const List<ArousalLevel> all = [
    ArousalLevel(1, '🧊', '무기력·멍함', Color(0xFF7A93A8)),
    ArousalLevel(2, '🌫️', '가라앉음·무료함', Color(0xFF9AB4C2)),
    ArousalLevel(3, '🌿', '안정 · 창 안', Color(0xFF3FA796)),
    ArousalLevel(4, '⚡', '긴장·들뜸', Color(0xFFE08A3C)),
    ArousalLevel(5, '🔥', '과각성·충동', Color(0xFFD9534F)),
  ];

  static ArousalLevel of(int value) =>
      all.firstWhere((a) => a.value == value, orElse: () => all[2]);
}
