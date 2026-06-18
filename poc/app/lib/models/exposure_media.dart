/// 노출 자극(Exposure Media) 모델.
/// 백엔드 `GET /exposure-media` 응답 1건에 대응한다.
class ExposureMedia {
  final int id;

  /// 자극 제목 (예: "슬롯머신 릴 사운드")
  final String title;

  /// 미디어 종류 (audio | video | image)
  final String mediaType;

  /// 카테고리 (예: "슬롯")
  final String category;

  /// 자극 강도 (1~5). PoC에서는 노출 화면 배경 톤 등에 참고용으로 사용.
  final int intensity;

  /// 에셋 식별자 (PoC에서는 실제 바이너리 없이 플레이스홀더 시뮬레이션에 사용)
  final String assetRef;

  const ExposureMedia({
    required this.id,
    required this.title,
    required this.mediaType,
    required this.category,
    required this.intensity,
    required this.assetRef,
  });

  factory ExposureMedia.fromJson(Map<String, dynamic> json) {
    return ExposureMedia(
      id: json['id'] as int,
      title: json['title'] as String? ?? '노출 자극',
      mediaType: json['media_type'] as String? ?? 'audio',
      category: json['category'] as String? ?? '',
      intensity: (json['intensity'] as num?)?.toInt() ?? 1,
      assetRef: json['asset_ref'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'media_type': mediaType,
        'category': category,
        'intensity': intensity,
        'asset_ref': assetRef,
      };
}
