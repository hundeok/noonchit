// core/utils/bottom_line_constants.dart
// 🔥 바텀라인 시스템 - 모든 설정값과 상수 정의

/// 바텀라인 시스템 전체 설정값
class BottomLineConstants {
  // 🚫 인스턴스 생성 방지
  BottomLineConstants._();

  // ══════════════════════════════════════════════════════════════════════════════
  // ⏰ 타이머 & 주기 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// 바텀라인 새로고침 간격 (초) - AI 호출 주기
  static const int refreshIntervalSeconds = 30;

  /// 바텀라인 표시 간격 (초) - UI 전환 주기  
  static const int displayIntervalSeconds = 18;

  /// 스냅샷 생성 최소 간격 (초)
  static const int minSnapshotIntervalSeconds = 15;

  /// 메모리 정리 간격 (분)
  static const int cleanupIntervalMinutes = 5;

  /// 베이스라인 갱신 간격 (시간)
  static const int baselineRefreshHours = 1;

  // ══════════════════════════════════════════════════════════════════════════════
  // 💰 거래 임계값 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// 고액거래 임계값 (원) - 2천만원
  static const double largeTradeThreshold = 20000000.0;

  /// 초대형거래 임계값 (원) - 1억원  
  static const double megaTradeThreshold = 100000000.0;

  /// 스마트머니 룰 최소 고액거래 횟수
  static const int smartMoneyMinTradeCount = 3;

  /// 볼륨 급증 임계값 (%) - 200% 이상
  static const double volumeSpikeThreshold = 200.0;

  /// 급등/급락 임계값 (%) - 10% 이상
  static const double surgeThreshold = 10.0;

  /// 섹터 로테이션 임계값 (%p) - 7%p 이상
  static const double sectorRotationThreshold = 7.0;

  // ══════════════════════════════════════════════════════════════════════════════
  // 📊 인사이트 점수 계산 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// 인사이트 생성 최소 점수
  static const double minInsightScore = 1.0;

  /// 긴급 인사이트 임계값
  static const double urgentInsightThreshold = 2.5;

  /// 최고 인사이트 점수 (정규화용)
  static const double maxInsightScore = 5.0;

  /// 점수 계산 가중치 - 가격 변화
  static const double scorePriceChangeWeight = 0.3;

  /// 점수 계산 가중치 - 볼륨 변화
  static const double scoreVolumeChangeWeight = 0.25;

  /// 점수 계산 가중치 - 고액거래
  static const double scoreLargeTradeWeight = 0.25;

  /// 점수 계산 가중치 - 섹터 변화
  static const double scoreSectorChangeWeight = 0.2;

  // ══════════════════════════════════════════════════════════════════════════════
  // 🔄 메모리 관리 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// 최근 거래 최대 보관 개수
  static const int maxRecentTrades = 1000;

  /// 최근 고액거래 최대 보관 개수
  static const int maxRecentLargeTrades = 100;

  /// 시장별 최대 추적 개수
  static const int maxTrackedMarkets = 200;

  /// 섹터별 최대 추적 개수
  static const int maxTrackedSectors = 20;

  /// 시장 비활성 제거 시간 (분) - 5분간 거래 없으면 제거
  static const int marketInactiveMinutes = 5;

  /// 캐시된 스냅샷 최대 개수
  static const int maxCachedSnapshots = 3;

  // ══════════════════════════════════════════════════════════════════════════════
  // 🎨 UI 큐 관리 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// 바텀라인 큐 최대 크기
  static const int maxQueueSize = 12;

  /// 큐 부족 임계값 (이하일 때 새로 생성)
  static const int queueRefillThreshold = 4;

  /// 긴급 아이템 최대 개수
  static const int maxUrgentItems = 3;

  /// 일반 아이템 최대 개수
  static const int maxNormalItems = 9;

  /// 플레이스홀더 아이템 개수
  static const int placeholderItemCount = 3;

  // ══════════════════════════════════════════════════════════════════════════════
  // 🤖 AI 서비스 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// OpenAI API 타임아웃 (초)
  static const int openAITimeoutSeconds = 10;

  /// AI 재시도 최대 횟수
  static const int aiMaxRetryCount = 2;

  /// AI 재시도 간격 (초)
  static const int aiRetryDelaySeconds = 1;

  /// GPT 모델명 (일반)
  static const String gptModelNormal = 'gpt-3.5-turbo';

  /// GPT 모델명 (긴급)
  static const String gptModelUrgent = 'gpt-4';

  /// 바텀라인 최대 길이 (글자)
  static const int maxHeadlineLength = 120;

  /// 바텀라인 최소 길이 (글자)
  static const int minHeadlineLength = 15;

  /// AI 생성 배치 크기
  static const int aiBatchSize = 5;

  // ══════════════════════════════════════════════════════════════════════════════
  // 📝 로깅 & 디버깅 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// 바텀라인 로깅 활성화
  static const bool enableLogging = true;

  /// 성능 모니터링 활성화
  static const bool enablePerformanceMonitoring = true;

  /// 메모리 사용량 로깅 활성화
  static const bool enableMemoryLogging = false;

  /// AI 호출 로깅 활성화
  static const bool enableAILogging = true;

  /// 디버그 모드에서만 상세 로깅
  static bool get enableDetailedLogging => 
    enableLogging && const bool.fromEnvironment('dart.vm.product') == false;

  // ══════════════════════════════════════════════════════════════════════════════
  // 🎛️ 룰 시스템 설정
  // ══════════════════════════════════════════════════════

  /// 룰별 가중치 설정
  static const Map<String, double> ruleWeights = {
    'smart_money': 1.0,      // 스마트머니 룰
    'volume_spike': 0.8,     // 볼륨 급증 룰
    'surge_chain': 0.7,      // 연쇄 급등 룰  
    'sector_rotation': 0.8,  // 섹터 로테이션 룰
    'fallback': 0.3,         // 폴백 룰
  };

  /// 룰별 활성화 상태
  static const Map<String, bool> ruleEnabled = {
    'smart_money': true,
    'volume_spike': true,
    'surge_chain': true,
    'sector_rotation': true,
    'fallback': true,
  };

  /// 인사이트 생성 최대 개수 (AI 비용 절약)
  static const int maxInsightsPerSnapshot = 5;

  /// 룰 실행 타임아웃 (밀리초)
  static const int ruleExecutionTimeoutMs = 1000;

  // ══════════════════════════════════════════════════════════════════════════════
  // 🚨 에러 처리 & 대체 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// 연속 에러 허용 횟수
  static const int maxConsecutiveErrors = 3;

  /// 에러 후 대기 시간 (초)
  static const int errorBackoffSeconds = 30;

  /// AI 실패 시 대체 메시지 사용 여부
  static const bool useFallbackMessages = true;

  /// 네트워크 연결 체크 간격 (초)
  static const int connectionCheckIntervalSeconds = 60;

  /// 데이터 부족 시 플레이스홀더 표시 여부
  static const bool showPlaceholderWhenNoData = true;

  // ══════════════════════════════════════════════════════════════════════════════
  // 🎨 UI 애니메이션 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// 바텀라인 전환 애니메이션 시간 (밀리초)
  static const int transitionAnimationMs = 300;

  /// 마퀴 텍스트 스크롤 속도 (픽셀/초)
  static const double marqueeScrollSpeed = 50.0;

  /// 긴급 바텀라인 깜빡임 간격 (밀리초)
  static const int urgentBlinkIntervalMs = 1000;

  /// 바텀라인 높이 (픽셀)
  static const double bottomLineHeight = 50.0;

  // ══════════════════════════════════════════════════════════════════════════════
  // 📱 플랫폼별 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// 안드로이드 최적화 설정
  static const Map<String, dynamic> androidOptimizations = {
    'reduce_animations': false,
    'battery_optimization': true,
    'background_processing': true,
  };

  /// iOS 최적화 설정
  static const Map<String, dynamic> iosOptimizations = {
    'background_app_refresh': true,
    'memory_pressure_handling': true,
    'smooth_animations': true,
  };

  // ══════════════════════════════════════════════════════════════════════════════
  // 🔢 수치 포맷팅 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// 금액 표시 단위 (억원)
  static const double amountUnit = 100000000.0;

  /// 소수점 자리수 - 가격
  static const int priceDecimalPlaces = 1;

  /// 소수점 자리수 - 퍼센트
  static const int percentDecimalPlaces = 1;

  /// 소수점 자리수 - 볼륨
  static const int volumeDecimalPlaces = 1;

  /// 큰 수 표시 임계값 (억)
  static const double largeNumberThreshold = 1.0;

  // ══════════════════════════════════════════════════════════════════════════════
  // 🎯 개발/테스트 설정
  // ══════════════════════════════════════════════════════════════════════════════

  /// 개발 모드에서 타이머 가속화 (배수)
  static const double devModeSpeedMultiplier = 1.0;

  /// 테스트 모드에서 AI 호출 비활성화
  static const bool disableAIInTest = true;

  /// 목업 데이터 사용 여부
  static const bool useMockData = false;

  /// 성능 벤치마킹 활성화
  static const bool enableBenchmarking = false;

  // ══════════════════════════════════════════════════════════════════════════════
  // 🔧 헬퍼 메서드들
  // ══════════════════════════════════════════════════════════════════════════════

  /// 현재 환경에 맞는 타이머 간격 반환
  static Duration getRefreshInterval() {
    const base = Duration(seconds: refreshIntervalSeconds);
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      // 개발 모드에서는 가속화
      return Duration(seconds: (base.inSeconds / devModeSpeedMultiplier).round());
    }
    return base;
  }

  /// 현재 환경에 맞는 표시 간격 반환
  static Duration getDisplayInterval() {
    const base = Duration(seconds: displayIntervalSeconds);
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      return Duration(seconds: (base.inSeconds / devModeSpeedMultiplier).round());
    }
    return base;
  }

  /// 룰이 활성화되어 있는지 확인
  static bool isRuleEnabled(String ruleId) {
    return ruleEnabled[ruleId] ?? false;
  }

  /// 룰의 가중치 반환
  static double getRuleWeight(String ruleId) {
    return ruleWeights[ruleId] ?? 0.0;
  }

  /// 금액을 억원 단위로 포맷팅
  static String formatAmount(double amount) {
    final amountInEok = amount / amountUnit;
    return '${amountInEok.toStringAsFixed(priceDecimalPlaces)}억원';
  }

  /// 퍼센트 포맷팅
  static String formatPercent(double percent) {
    return '${percent.toStringAsFixed(percentDecimalPlaces)}%';
  }

  /// 현재 설정 요약 반환 (디버깅용)
  static Map<String, dynamic> getConfigSummary() {
    return {
      'refresh_interval': refreshIntervalSeconds,
      'display_interval': displayIntervalSeconds,
      'large_trade_threshold': formatAmount(largeTradeThreshold),
      'max_queue_size': maxQueueSize,
      'max_recent_trades': maxRecentTrades,
      'ai_timeout': openAITimeoutSeconds,
      'logging_enabled': enableLogging,
      'rules_enabled': ruleEnabled.values.where((e) => e).length,
      'memory_limits': {
        'markets': maxTrackedMarkets,
        'trades': maxRecentTrades,
        'large_trades': maxRecentLargeTrades,
      },
    };
  }

  /// 시스템 상태 검증
  static bool validateConfig() {
    // 기본적인 설정값 검증
    if (refreshIntervalSeconds <= 0) return false;
    if (displayIntervalSeconds <= 0) return false;
    if (maxQueueSize <= 0) return false;
    if (largeTradeThreshold <= 0) return false;
    
    // 타이머 간격 검증 (표시 간격 < 새로고침 간격)
    if (displayIntervalSeconds >= refreshIntervalSeconds) return false;
    
    // 큐 크기 검증
    if (queueRefillThreshold >= maxQueueSize) return false;
    
    // 가중치 검증 (0 ~ 1 범위)
    for (final weight in ruleWeights.values) {
      if (weight < 0.0 || weight > 1.0) return false;
    }
    
    return true;
  }
}