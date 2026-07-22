/// 삶의 나침반 모델.
/// 백엔드 `GET/PUT /compass` 에 대응한다.
class LifeCompass {
  /// 의미 있는 삶의 목표(가치 선언)
  final String lifeGoal;

  /// 1만 시간 학습 영역
  final String studyDomain;

  final String goal1y;
  final String goal5y;
  final String goal10y;

  const LifeCompass({
    this.lifeGoal = '',
    this.studyDomain = '',
    this.goal1y = '',
    this.goal5y = '',
    this.goal10y = '',
  });

  /// 하나라도 입력돼 있으면 true.
  bool get hasAny =>
      lifeGoal.isNotEmpty ||
      studyDomain.isNotEmpty ||
      goal1y.isNotEmpty ||
      goal5y.isNotEmpty ||
      goal10y.isNotEmpty;

  factory LifeCompass.fromJson(Map<String, dynamic> json) {
    return LifeCompass(
      lifeGoal: json['life_goal'] as String? ?? '',
      studyDomain: json['study_domain'] as String? ?? '',
      goal1y: json['goal_1y'] as String? ?? '',
      goal5y: json['goal_5y'] as String? ?? '',
      goal10y: json['goal_10y'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'life_goal': lifeGoal,
        'study_domain': studyDomain,
        'goal_1y': goal1y,
        'goal_5y': goal5y,
        'goal_10y': goal10y,
      };
}
