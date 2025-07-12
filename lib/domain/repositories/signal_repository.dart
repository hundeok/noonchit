// lib/domain/repositories/signal_repository.dart

import '../entities/signal.dart';

/// 🚀 Signal Repository 인터페이스 V4.1 - 모달 지원 + 온라인 지표 연동
///
/// 주요 개선사항:
/// - 🆕 모달용 메서드 4개 추가
/// - 온라인 지표 시스템 헬스 체크
/// - 패턴별 고급 설정 지원
/// - 시스템 성능 모니터링
/// - 설정 내보내기/가져오기
/// - 실시간 다이버전스 감지
abstract class SignalRepository {
  // ==========================================================================
  // 기본 시그널 스트림 (기존 호환성)
  // ==========================================================================

  /// 특정 패턴의 시그널 스트림 감시
  Stream<List<Signal>> watchSignalsByPattern(
    PatternType patternType,
    List<String> markets,
  );

  /// 모든 패턴의 시그널 스트림 감시
  Stream<List<Signal>> watchAllSignals(List<String> markets);

  // ==========================================================================
  // 패턴 설정 관리 (기존 + V4.1 확장)
  // ==========================================================================

  /// 패턴별 임계값 업데이트
  void updatePatternThreshold(PatternType patternType, double threshold);

  /// 현재 설정된 패턴별 임계값 조회
  double getPatternThreshold(PatternType patternType);

  /// 패턴별 활성화/비활성화 설정
  void setPatternEnabled(PatternType patternType, bool enabled);

  /// 패턴 활성화 상태 조회
  bool isPatternEnabled(PatternType patternType);

  /// 감지된 시그널 목록 초기화
  void clearSignals(PatternType? patternType);

  // ==========================================================================
  // 🆕 V4.1 모달용 메서드 4개 (핵심 추가)
  // ==========================================================================

  /// 🆕 현재 패턴의 특정 임계값 조회 (모달에서 사용)
  double getCurrentThresholdValue(PatternType pattern, String key);

  /// 🆕 시스템 전체 활성화/비활성화
  void setSystemActive(bool active);

  /// 🆕 시스템 상태 조회
  Map<String, dynamic> getSystemStatus();

  /// 🆕 온라인 지표 헬스 상태 조회
  Map<String, dynamic> getOnlineMetricsHealth();

  /// 🆕 온라인 지표 리셋
  void resetOnlineMetrics([String? market]);

  // ==========================================================================
  // 🆕 V4.1 온라인 지표 확장 기능 (기존)
  // ==========================================================================

  /// 패턴별 고급 설정 업데이트 (zScoreThreshold, buyRatioMin 등)
  void updatePatternConfig(PatternType pattern, String key, double value);

  /// 패턴 프리셋 적용 (conservative, aggressive, balanced)
  void applyPatternPreset(String presetName);

  /// 패턴별 통계 정보 조회 (신호 개수, 마지막 감지 시간 등)
  Future<Map<String, dynamic>> getPatternStats(PatternType type);

  /// 전체 시스템 헬스 체크 (온라인 지표 포함)
  Future<Map<String, dynamic>> getSystemHealth();

  /// 마켓별 데이터 품질 조회 (온라인 지표 건강성 포함)
  Map<String, dynamic> getMarketDataQuality();

  /// 성능 메트릭스 실시간 모니터링
  Stream<Map<String, dynamic>> watchPerformanceMetrics();

  // ==========================================================================
  // 🆕 V4.1 설정 관리 (백테스팅, A/B 테스트 지원)
  // ==========================================================================

  /// 현재 설정 내보내기 (JSON 형태)
  Map<String, dynamic> exportConfiguration();

  /// 설정 가져오기 (백업 복원, 프리셋 적용)
  void importConfiguration(Map<String, dynamic> config);

  // ==========================================================================
  // 리소스 정리
  // ==========================================================================

  /// 리소스 정리 (온라인 지표 포함)
  Future<void> dispose();
}