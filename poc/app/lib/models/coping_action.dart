import 'package:flutter/material.dart';

/// 상태 이동 행동(가이드 표) 모델.
/// 백엔드 `GET/POST /coping-actions` 에 대응한다.
class CopingAction {
  final int id;
  final String title;
  final String category;

  /// up=끌어올리기 · down=가라앉히기 · ground=중심잡기
  final String direction;
  final String note;

  /// 1=즉시 · 2=보통 · 3=시간·준비 필요
  final int effort;
  final bool isCustom;

  const CopingAction({
    required this.id,
    required this.title,
    this.category = '',
    this.direction = 'ground',
    this.note = '',
    this.effort = 1,
    this.isCustom = false,
  });

  factory CopingAction.fromJson(Map<String, dynamic> json) {
    return CopingAction(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      direction: json['direction'] as String? ?? 'ground',
      note: json['note'] as String? ?? '',
      effort: (json['effort'] as num?)?.toInt() ?? 1,
      isCustom: json['is_custom'] as bool? ?? false,
    );
  }
}

/// 방향(수용의 창 이동 목적) 표현.
class ActionDirection {
  final String key;
  final String emoji;
  final String label;
  final String hint;
  final Color color;

  const ActionDirection(
      this.key, this.emoji, this.label, this.hint, this.color);

  static const up = ActionDirection(
      'up', '⬆️', '끌어올리기', '무기력·무료할 때', Color(0xFFE08A3C));
  static const down = ActionDirection(
      'down', '⬇️', '가라앉히기', '긴장·충동일 때', Color(0xFF4F8FB0));
  static const ground = ActionDirection(
      'ground', '🌿', '중심잡기', '지금 여기로', Color(0xFF3FA796));

  static const all = [up, down, ground];

  static ActionDirection of(String key) =>
      all.firstWhere((d) => d.key == key, orElse: () => ground);
}
