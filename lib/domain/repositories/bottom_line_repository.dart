// domain/repositories/bottom_line_repository.dart
// 🏛️ 바텀라인 Repository 인터페이스 - Clean Architecture

import '../entities/bottom_line.dart';
import '../../core/utils/bottom_line_queue.dart';

/// 바텀라인 데이터 접근을 위한 Repository 인터페이스
/// 
/// 실제 데이터 소스(Provider, API, DB 등)와 비즈니스 로직을 분리하여
/// 테스트 가능하고 유지보수하기 쉬운 구조를 제공합니다.
abstract class BottomLineRepository {
  
  // ══════════════════════════════════════════════════════════════════════════════
  // 📊 실시간 데이터 스트림
  // ══════════════════════════════════════════════════════════════════════════════

  /// 실시간 바텀라인 아이템 스트림
  /// 
  /// AI 생성된 바텀라인들이 실시간으로 제공됩니다.
  /// 30초마다 새로운 배치가 생성되어 큐에 추가됩니다.
  Stream<List<BottomLineItem>> getBottomLineStream();

  /// 현재 표시 중인 바텀라인 아이템 스트림
  /// 
  /// 18초마다 다음 아이템으로 자동 전환됩니다.
  Stream<BottomLineItem?> getCurrentBottomLineStream();

  /// 바텀라인 큐 상태 스트림
  /// 
  /// 큐의 현재 상태(normal, urgent, empty 등)를 실시간으로 제공합니다.
  Stream<BottomLineQueueState> getQueueStateStream();

  // ══════════════════════════════════════════════════════════════════════════════
  // 📥 현재 상태 조회
  // ══════════════════════════════════════════════════════════════════════════════

  /// 현재 생성된 바텀라인 아이템들 조회
  /// 
  /// AI가 마지막으로 생성한 바텀라인 배치를 반환합니다.
  Future<List<BottomLineItem>> getCurrentBottomLines();

  /// 현재 표시 중인 바텀라인 아이템 조회
  /// 
  /// 사용자가 현재 보고 있는 바텀라인을 반환합니다.
  Future<BottomLineItem?> getCurrentDisplayItem();

  /// 현재 큐 상태 조회
  /// 
  /// 큐 길이, 긴급 아이템 개수, 다음 표시까지 남은 시간 등을 포함합니다.
  Future<Map<String, dynamic>> getCurrentQueueStatus();

  // ══════════════════════════════════════════════════════════════════════════════
  // 🎛️ 큐 제어
  // ══════════════════════════════════════════════════════════════════════════════

  /// 다음 바텀라인으로 수동 전환
  /// 
  /// 18초를 기다리지 않고 즉시 다음 아이템을 표시합니다.
  Future<void> showNextBottomLine();

  /// 현재 바텀라인 스킵
  /// 
  /// 현재 아이템을 건너뛰고 다음 아이템을 표시합니다.
  Future<void> skipCurrentBottomLine();

  /// 바텀라인 표시 일시정지/재개
  /// 
  /// [paused]가 true면 일시정지, false면 재개합니다.
  Future<void> pauseBottomLine(bool paused);

  /// 바텀라인 표시 속도 변경
  /// 
  /// [speedMultiplier]: 1.0(기본), 2.0(2배속), 0.5(0.5배속) 등
  Future<void> setBottomLineSpeed(double speedMultiplier);

  // ══════════════════════════════════════════════════════════════════════════════
  // 📊 인사이트 및 스냅샷 조회
  // ══════════════════════════════════════════════════════════════════════════════

  /// 현재 생성된 인사이트들 조회
  /// 
  /// AI 생성 전 원본 인사이트 데이터를 반환합니다.
  Future<List<CandidateInsight>> getCurrentInsights();

  /// 최신 시장 스냅샷 조회
  /// 
  /// 바텀라인 생성의 기반이 되는 시장 데이터를 반환합니다.
  Future<MarketSnapshot?> getLatestMarketSnapshot();

  /// 스냅샷 히스토리 조회
  /// 
  /// 최근 N개의 스냅샷을 반환합니다.
  Future<List<MarketSnapshot>> getSnapshotHistory({int limit = 5});

  // ══════════════════════════════════════════════════════════════════════════════
  // 🔄 강제 새로고침 및 재생성
  // ══════════════════════════════════════════════════════════════════════════════

  /// 바텀라인 강제 새로고침
  /// 
  /// 30초를 기다리지 않고 즉시 새로운 바텀라인을 생성합니다.
  Future<List<BottomLineItem>> refreshBottomLines();

  /// AI 재생성 요청
  /// 
  /// 현재 인사이트를 기반으로 AI 바텀라인을 다시 생성합니다.
  Future<List<BottomLineItem>> regenerateWithAI();

  /// 스냅샷 강제 생성
  /// 
  /// 현재 시장 데이터로 새로운 스냅샷을 즉시 생성합니다.
  Future<MarketSnapshot?> forceGenerateSnapshot();

  // ══════════════════════════════════════════════════════════════════════════════
  // 📊 통계 및 모니터링
  // ══════════════════════════════════════════════════════════════════════════════

  /// 바텀라인 시스템 통계 조회
  /// 
  /// 생성된 아이템 수, 표시 횟수, 큐 성능 등의 통계를 반환합니다.
  Future<Map<String, dynamic>> getBottomLineStats();

  /// AI 서비스 통계 조회
  /// 
  /// OpenAI API 호출 횟수, 성공률, 응답시간 등을 반환합니다.
  Future<Map<String, dynamic>> getAIServiceStats();

  /// 인사이트 엔진 통계 조회
  /// 
  /// 룰별 실행 횟수, 성공률, 처리 시간 등을 반환합니다.
  Future<Map<String, dynamic>> getInsightEngineStats();

  /// 데이터 애그리게이터 통계 조회
  /// 
  /// 처리된 거래 수, 메모리 사용량, 시장 추적 현황 등을 반환합니다.
  Future<Map<String, dynamic>> getAggregatorStats();

  // ══════════════════════════════════════════════════════════════════════════════
  // 🔧 설정 및 관리
  // ══════════════════════════════════════════════════════════════════════════════

  /// 바텀라인 시스템 활성화/비활성화
  /// 
  /// [enabled]가 false면 바텀라인 생성 및 표시를 중단합니다.
  Future<void> setBottomLineEnabled(bool enabled);

  /// AI 서비스 활성화/비활성화
  /// 
  /// [enabled]가 false면 AI 생성 대신 템플릿 기반 대체 헤드라인을 사용합니다.
  Future<void> setAIServiceEnabled(bool enabled);

  /// 캐시 및 메모리 정리
  /// 
  /// 만료된 데이터를 정리하고 메모리 사용량을 최적화합니다.
  Future<void> clearCache();

  /// 통계 데이터 리셋
  /// 
  /// 모든 통계를 초기화합니다.
  Future<void> resetStats();

  // ══════════════════════════════════════════════════════════════════════════════
  // 🧪 테스트 및 디버깅
  // ══════════════════════════════════════════════════════════════════════════════

  /// OpenAI 연결 테스트
  /// 
  /// AI 서비스가 정상적으로 작동하는지 확인합니다.
  Future<bool> testAIConnection();

  /// 데이터 연결 상태 확인
  /// 
  /// 업비트 데이터가 정상적으로 수신되고 있는지 확인합니다.
  Future<bool> checkDataConnection();

  /// 시스템 상태 검증
  /// 
  /// 전체 바텀라인 시스템의 건강상태를 확인합니다.
  Future<Map<String, dynamic>> validateSystemHealth();

  /// 디버그 리포트 생성
  /// 
  /// 개발자용 상세 디버그 정보를 생성합니다.
  Future<Map<String, dynamic>> generateDebugReport();

  // ══════════════════════════════════════════════════════════════════════════════
  // 🎯 고급 기능
  // ══════════════════════════════════════════════════════════════════════════════

  /// 특정 룰 활성화/비활성화
  /// 
  /// 개별 인사이트 룰을 제어합니다.
  Future<void> setRuleEnabled(String ruleId, bool enabled);

  /// 사용자 정의 바텀라인 추가
  /// 
  /// 수동으로 바텀라인 아이템을 큐에 추가합니다.
  Future<void> addCustomBottomLine(BottomLineItem item);

  /// 긴급 바텀라인 추가
  /// 
  /// 긴급 아이템을 큐 맨 앞에 추가합니다.
  Future<void> addUrgentBottomLine(BottomLineItem item);

  /// 바텀라인 히스토리 조회
  /// 
  /// 과거에 표시된 바텀라인들을 조회합니다.
  Future<List<BottomLineItem>> getBottomLineHistory({int limit = 20});

  /// 인사이트 룰 성능 분석
  /// 
  /// 각 룰의 성능과 효과를 분석합니다.
  Future<Map<String, dynamic>> analyzeRulePerformance();

  // ══════════════════════════════════════════════════════════════════════════════
  // 🔌 리소스 관리
  // ══════════════════════════════════════════════════════════════════════════════

  /// Repository 리소스 정리
  /// 
  /// 스트림 구독, 타이머 등을 정리합니다.
  Future<void> dispose();
}