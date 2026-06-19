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

  /// 에셋 식별자 (레거시: 파일 경로/식별자)
  final String assetRef;

  /// 실제 재생용 스트리밍 URL. 비어 있으면 플레이스홀더로 대체.
  final String mediaUrl;

  /// 노출 전 표시할 맞춤 주의 문구(비면 기본 문구 사용).
  final String contentWarning;

  const ExposureMedia({
    required this.id,
    required this.title,
    required this.mediaType,
    required this.category,
    required this.intensity,
    required this.assetRef,
    this.mediaUrl = '',
    this.contentWarning = '',
  });

  /// 재생 가능한 http(s) URL이 있는지.
  bool get hasPlayableUrl =>
      mediaUrl.startsWith('http://') || mediaUrl.startsWith('https://');

  factory ExposureMedia.fromJson(Map<String, dynamic> json) {
    return ExposureMedia(
      id: json['id'] as int,
      title: json['title'] as String? ?? '노출 자극',
      mediaType: json['media_type'] as String? ?? 'audio',
      category: json['category'] as String? ?? '',
      intensity: (json['intensity'] as num?)?.toInt() ?? 1,
      assetRef: json['asset_ref'] as String? ?? '',
      mediaUrl: json['media_url'] as String? ?? '',
      contentWarning: json['content_warning'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'media_type': mediaType,
        'category': category,
        'intensity': intensity,
        'asset_ref': assetRef,
        'media_url': mediaUrl,
        'content_warning': contentWarning,
      };
}
