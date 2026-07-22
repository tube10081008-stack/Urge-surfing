import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/exposure_media.dart';
import '../models/training_session.dart';
import '../models/vas_trend.dart';

/// ApiClient 싱글턴 provider.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(client.dispose);
  return client;
});

/// 한 번의 훈련 흐름(노출 → 파도타기 → 결과)에 대한 상태.
class SessionState {
  /// 사용 중인 노출 자극
  final ExposureMedia? media;

  /// 생성된 훈련 세션 (백엔드 PK 포함)
  final TrainingSession? session;

  /// 사전 VAS (0~10), 미입력이면 null
  final int? preVas;

  /// 사후 VAS (0~10), 미입력이면 null
  final int? postVas;

  /// 파도타기 중 관측된 최고 갈망(peak urge). 기본은 preVas로 시작.
  final int? peakUrge;

  /// 파도타기 실제 소요 시간(초)
  final int durationSec;

  /// 사용한 대처 기술 (PoC: breathing 고정)
  final String copingSkill;

  /// 비동기 처리 중 여부
  final bool isLoading;

  /// 오류 메시지(있으면 표시)
  final String? error;

  const SessionState({
    this.media,
    this.session,
    this.preVas,
    this.postVas,
    this.peakUrge,
    this.durationSec = 0,
    this.copingSkill = 'breathing',
    this.isLoading = false,
    this.error,
  });

  /// 결과 자동 판정: 사후 갈망이 사전 대비 일정 수준 이상 낮아지면 success.
  /// (PoC 규칙) post <= pre - 2 또는 post <= 3 이면 success, 아니면 relapse.
  String get outcome {
    final pre = preVas ?? 0;
    final post = postVas ?? pre;
    if (post <= pre - 2 || post <= 3) return 'success';
    return 'relapse';
  }

  /// 갈망 감소량
  int get reduction {
    final pre = preVas ?? 0;
    final post = postVas ?? pre;
    return pre - post;
  }

  SessionState copyWith({
    ExposureMedia? media,
    TrainingSession? session,
    int? preVas,
    int? postVas,
    int? peakUrge,
    int? durationSec,
    String? copingSkill,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SessionState(
      media: media ?? this.media,
      session: session ?? this.session,
      preVas: preVas ?? this.preVas,
      postVas: postVas ?? this.postVas,
      peakUrge: peakUrge ?? this.peakUrge,
      durationSec: durationSec ?? this.durationSec,
      copingSkill: copingSkill ?? this.copingSkill,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 세션 흐름 컨트롤러.
class SessionController extends StateNotifier<SessionState> {
  final ApiClient _api;

  SessionController(this._api) : super(const SessionState());

  /// 새 훈련 흐름 시작 시 상태 초기화.
  void reset() => state = const SessionState();

  /// 사용할 노출 자극 선택.
  void selectMedia(ExposureMedia media) {
    state = state.copyWith(media: media, clearError: true);
  }

  /// 파도타기 대처 기술 선택(백엔드 coping_skill 로 전송).
  void setCopingSkill(String key) {
    state = state.copyWith(copingSkill: key);
  }

  /// 세션 생성(POST /training-sessions). PoC에서는 erp_exposure로 시작.
  Future<void> startSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final session = await _api.createSession(
        sessionType: 'erp_exposure',
        mediaId: state.media?.id,
      );
      state = state.copyWith(session: session, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '세션 생성 실패: $e');
    }
  }

  /// 사전 VAS 기록.
  Future<void> submitPreVas(int value) async {
    state = state.copyWith(
      preVas: value,
      peakUrge: value, // 파도타기 시작 시점의 갈망을 peak 초기값으로
      isLoading: true,
      clearError: true,
    );
    final sessionId = state.session?.id;
    if (sessionId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      await _api.recordVas(sessionId: sessionId, phase: 'pre', vasValue: value);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      // PoC: 네트워크 실패해도 로컬 흐름은 진행. 오류만 노출.
      state = state.copyWith(isLoading: false, error: '사전 VAS 전송 실패: $e');
    }
  }

  /// 파도타기 진행 결과(소요시간) 반영.
  void setUrgeSurfingDuration(int durationSec) {
    state = state.copyWith(durationSec: durationSec);
  }

  /// 사후 VAS 기록.
  Future<void> submitPostVas(int value) async {
    state = state.copyWith(postVas: value, isLoading: true, clearError: true);
    final sessionId = state.session?.id;
    if (sessionId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      await _api.recordVas(sessionId: sessionId, phase: 'post', vasValue: value);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '사후 VAS 전송 실패: $e');
    }
  }

  /// 최종 결과 전송: 세션 완료 + 파도타기 결과.
  /// 성공 여부와 무관하게 화면 흐름은 진행한다.
  Future<void> finishAndSubmit() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final sessionId = state.session?.id;
    if (sessionId == null) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      await _api.submitUrgeSurfing(
        sessionId: sessionId,
        peakUrge: state.peakUrge ?? state.preVas ?? 0,
        outcome: state.outcome,
        copingSkill: state.copingSkill,
        durationSec: state.durationSec,
      );
      await _api.completeSession(sessionId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '결과 전송 실패: $e');
    }
  }
}

/// 세션 컨트롤러 provider.
final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref.watch(apiClientProvider));
});

/// 노출 자극 목록 provider (GET /exposure-media).
/// 백엔드 미연결 시 기본 플레이스홀더 1종을 제공한다.
final exposureMediaProvider = FutureProvider<List<ExposureMedia>>((ref) async {
  final api = ref.watch(apiClientProvider);
  try {
    final list = await api.fetchExposureMedia();
    if (list.isNotEmpty) return list;
  } catch (_) {
    // 백엔드 미가동 시 PoC 데모를 위한 폴백
  }
  return const [
    ExposureMedia(
      id: 1,
      title: '슬롯머신 릴 사운드',
      mediaType: 'audio',
      category: '슬롯',
      intensity: 3,
      assetRef: 'slot_reel',
    ),
  ];
});

/// 홈에서 노출 자극으로 쓸 목록(상담 음성 가이드는 제외).
final exposureStimuliProvider =
    FutureProvider<List<ExposureMedia>>((ref) async {
  final list = await ref.watch(exposureMediaProvider.future);
  return list.where((m) => m.category != kGuideCategory).toList();
});

/// 파도타기 중 재생할 상담 음성 가이드 목록(회기별, id 순).
final guidesProvider = FutureProvider<List<ExposureMedia>>((ref) async {
  final list = await ref.watch(exposureMediaProvider.future);
  final guides = list
      .where((m) => m.category == kGuideCategory && m.hasPlayableUrl)
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  return guides;
});

/// 대시보드 VAS 추세 provider (GET /dashboard/vas-trend).
/// 진입할 때마다 최신 기록을 다시 불러온다.
final vasTrendProvider =
    FutureProvider.autoDispose<List<VasTrendPoint>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.fetchVasTrend();
});
