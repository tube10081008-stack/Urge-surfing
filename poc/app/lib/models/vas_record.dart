/// VAS(Visual Analog Scale) 갈망 점수 기록 모델.
/// 백엔드 `POST /training-sessions/{id}/vas` 응답에 대응한다.
///
/// phase: "pre"(노출 전) | "post"(파도타기 후)
/// vasValue: 0~10 정수 (0=갈망 없음, 10=참기 매우 어려움)
class VasRecord {
  final int? id;
  final String phase;
  final int vasValue;
  final String? recordedAt;

  const VasRecord({
    this.id,
    required this.phase,
    required this.vasValue,
    this.recordedAt,
  });

  factory VasRecord.fromJson(Map<String, dynamic> json) {
    return VasRecord(
      id: (json['id'] as num?)?.toInt(),
      phase: json['phase'] as String? ?? 'pre',
      vasValue: (json['vas_value'] as num?)?.toInt() ?? 0,
      recordedAt: json['recorded_at'] as String?,
    );
  }

  /// 요청 바디 생성용. (id/recorded_at은 서버가 부여)
  Map<String, dynamic> toJson() => {
        'phase': phase,
        'vas_value': vasValue,
      };
}
