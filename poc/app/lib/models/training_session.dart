/// 훈련 세션(Training Session) 모델.
/// 백엔드 `POST/PATCH /training-sessions` 응답에 대응한다.
class TrainingSession {
  final int id;

  /// 세션 종류: erp_exposure | urge_surfing
  final String sessionType;

  /// 연결된 노출 미디어 id (urge_surfing 단독 세션이면 null 가능)
  final int? mediaId;

  final String? startedAt;
  final String? endedAt;
  final bool completed;
  final int? durationSec;

  const TrainingSession({
    required this.id,
    required this.sessionType,
    this.mediaId,
    this.startedAt,
    this.endedAt,
    this.completed = false,
    this.durationSec,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'] as int,
      sessionType: json['session_type'] as String? ?? 'erp_exposure',
      mediaId: (json['media_id'] as num?)?.toInt(),
      startedAt: json['started_at'] as String?,
      endedAt: json['ended_at'] as String?,
      completed: json['completed'] as bool? ?? false,
      durationSec: (json['duration_sec'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_type': sessionType,
        if (mediaId != null) 'media_id': mediaId,
        'started_at': startedAt,
        'ended_at': endedAt,
        'completed': completed,
        'duration_sec': durationSec,
      };
}
