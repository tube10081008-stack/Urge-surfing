/// 회복 학습 노트 개념 모델.
/// 백엔드 `GET/PATCH /learning-concepts` 에 대응한다.
class LearningConcept {
  final int id;
  final String key;
  final int groupNo;
  final String groupTitle;
  final String title;
  final String titleEn;
  final String originator;
  final String summary;
  final String connection;

  /// 사용자 메모(공부 필기)
  final String note;

  const LearningConcept({
    required this.id,
    this.key = '',
    this.groupNo = 1,
    this.groupTitle = '',
    this.title = '',
    this.titleEn = '',
    this.originator = '',
    this.summary = '',
    this.connection = '',
    this.note = '',
  });

  bool get hasNote => note.trim().isNotEmpty;

  factory LearningConcept.fromJson(Map<String, dynamic> json) {
    return LearningConcept(
      id: json['id'] as int,
      key: json['key'] as String? ?? '',
      groupNo: (json['group_no'] as num?)?.toInt() ?? 1,
      groupTitle: json['group_title'] as String? ?? '',
      title: json['title'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      originator: json['originator'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      connection: json['connection'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }
}
