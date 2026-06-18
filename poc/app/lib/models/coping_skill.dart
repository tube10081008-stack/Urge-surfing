import 'package:flutter/material.dart';

/// 대처 기술 종류.
/// - breathing: 호흡 가이드(확장/수축 원)
/// - steps: 단계별 안내(오감 그라운딩, 근육 이완 등)
enum CopingKind { breathing, steps }

/// 충동 파도타기 중 사용할 대처 기술 정의.
class CopingSkill {
  /// 백엔드 coping_skill 로 전송되는 값
  final String key;

  /// 칩 라벨
  final String label;

  /// 한 줄 설명
  final String tagline;

  final IconData icon;
  final CopingKind kind;

  // ── breathing 파라미터(초). hold2=0이면 마지막 멈춤 단계 생략 ──
  final int inhale;
  final int hold1;
  final int exhale;
  final int hold2;

  // ── steps 파라미터 ──
  final List<String> steps;
  final int stepSec;

  const CopingSkill({
    required this.key,
    required this.label,
    required this.tagline,
    required this.icon,
    required this.kind,
    this.inhale = 4,
    this.hold1 = 7,
    this.exhale = 8,
    this.hold2 = 0,
    this.steps = const [],
    this.stepSec = 16,
  });
}

/// 제공 대처 기술 목록(파도타기 화면에서 선택).
const List<CopingSkill> kCopingSkills = [
  CopingSkill(
    key: 'breathing_478',
    label: '4-7-8 호흡',
    tagline: '들이쉬기 4 · 멈추기 7 · 내쉬기 8',
    icon: Icons.air,
    kind: CopingKind.breathing,
    inhale: 4,
    hold1: 7,
    exhale: 8,
    hold2: 0,
  ),
  CopingSkill(
    key: 'box_breathing',
    label: '박스 호흡',
    tagline: '4-4-4-4 리듬으로 마음을 가다듬기',
    icon: Icons.crop_square,
    kind: CopingKind.breathing,
    inhale: 4,
    hold1: 4,
    exhale: 4,
    hold2: 4,
  ),
  CopingSkill(
    key: 'grounding_54321',
    label: '5-4-3-2-1 그라운딩',
    tagline: '오감으로 지금 여기에 집중하기',
    icon: Icons.spa,
    kind: CopingKind.steps,
    stepSec: 18,
    steps: [
      '눈에 보이는 것 5가지를 천천히 찾아보세요.',
      '들리는 소리 4가지에 귀 기울여 보세요.',
      '몸에 닿는 감촉 3가지를 느껴보세요.',
      '맡을 수 있는 냄새 2가지를 찾아보세요.',
      '느낄 수 있는 맛 1가지에 집중해 보세요.',
    ],
  ),
  CopingSkill(
    key: 'muscle_relaxation',
    label: '근육 이완',
    tagline: '긴장과 이완을 반복하며 몸 풀기',
    icon: Icons.self_improvement,
    kind: CopingKind.steps,
    stepSec: 15,
    steps: [
      '두 손을 5초간 꽉 쥐었다가 천천히 풀어 보세요.',
      '어깨를 귀 쪽으로 올려 힘을 줬다가 툭 내려놓으세요.',
      '눈과 얼굴을 찡그렸다가 부드럽게 펴 보세요.',
      '배에 힘을 줬다가 숨을 내쉬며 풀어 주세요.',
      '다리를 쭉 뻗어 힘을 줬다가 스르르 이완하세요.',
    ],
  ),
];
