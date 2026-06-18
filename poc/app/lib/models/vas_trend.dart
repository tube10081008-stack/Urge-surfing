/// 대시보드 VAS 추세 한 점(하루치).
/// 백엔드 `GET /dashboard/vas-trend` 응답 1건에 대응한다.
class VasTrendPoint {
  /// 일자 (ISO: YYYY-MM-DD)
  final String day;

  /// 연습 전/후 평균 갈망(0~10)
  final double? avgPre;
  final double? avgPost;

  /// 평균 감소량 (avgPre - avgPost)
  final double? avgReduction;

  const VasTrendPoint({
    required this.day,
    this.avgPre,
    this.avgPost,
    this.avgReduction,
  });

  factory VasTrendPoint.fromJson(Map<String, dynamic> json) {
    return VasTrendPoint(
      day: json['day'] as String? ?? '',
      avgPre: (json['avg_pre'] as num?)?.toDouble(),
      avgPost: (json['avg_post'] as num?)?.toDouble(),
      avgReduction: (json['avg_reduction'] as num?)?.toDouble(),
    );
  }
}
