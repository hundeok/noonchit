// lib/shared/utils/rank_hot_mixin.dart
import 'dart:collection';

/// 🎯 통합 HOT 설정 클래스
class HotConfig {
  final Duration keepDuration;
  final int rankJump;
  final Duration gracePeriod;
  final int minDataPoints;
  final bool blockFirstUpdate;

  const HotConfig({
    required this.keepDuration,
    required this.rankJump,
    required this.gracePeriod,
    required this.minDataPoints,
    required this.blockFirstUpdate,
  });
}

/// 🔧 간소화된 HOT 설정 관리자
class HotConfigManager {
  // 🎯 메뉴별 설정을 Map으로 통합 관리
  static const Map<String, HotConfig> _configs = {
    'volume': HotConfig(
      keepDuration: Duration(seconds: 20),
      rankJump: 15,
      gracePeriod: Duration(seconds: 0),
      minDataPoints: 60,
      blockFirstUpdate: true,
    ),
    'surge': HotConfig(
      keepDuration: Duration(seconds: 20),
      rankJump: 20,
      gracePeriod: Duration(seconds: 0),
      minDataPoints: 40,
      blockFirstUpdate: true,
    ),
    'sector': HotConfig(
      keepDuration: Duration(seconds: 20),
      rankJump: 5,
      gracePeriod: Duration(seconds: 0),
      minDataPoints: 20,
      blockFirstUpdate: true,
    ),
  };

  /// 🎯 메뉴별 설정 조회 (기본값: volume)
  static HotConfig getConfig(String menuType) {
    return _configs[menuType] ?? _configs['volume']!;
  }

  /// 🎯 모든 설정의 최대 유지 시간 조회
  static Duration getMaxKeepDuration() {
    return _configs.values
        .map((config) => config.keepDuration)
        .reduce((a, b) => a > b ? a : b);
  }

  /// 🎯 지원되는 메뉴 타입 목록
  static List<String> getSupportedMenuTypes() {
    return _configs.keys.toList();
  }

  /// 🎯 설정 추가/수정 (런타임 확장용)
  static void registerConfig(String menuType, HotConfig config) {
    // const Map을 사용하므로 런타임 수정은 불가하지만,
    // 필요시 _configs를 일반 Map으로 변경 가능
  }
}

/// 🔥 HOT 상태 관리 전용 Mixin (리팩토 버전)
/// ✅ Controller 호환성 100% 보장
mixin RankHotMixin {
  // 시간대별 HOT 상태 저장
  // {'1m': {'BTC': DateTime}, '5m': {'ETH': DateTime}}
  final Map<String, Map<String, DateTime>> _hotStates = HashMap();
  
  // 순위 추적용 (HOT 판단을 위해 필요)
  final Map<String, Map<String, int>> _previousRanks = HashMap();
  
  // 시간대별 Grace Period 시작 시간 추적
  // {'1m': DateTime, '5m': DateTime}
  final Map<String, DateTime> _timeFrameStartTimes = HashMap();

  /// ✅ 특정 시간대 초기화 (기존과 동일)
  void initializeTimeFrame(String timeFrame) {
    _hotStates[timeFrame] ??= HashMap<String, DateTime>();
    _previousRanks[timeFrame] ??= HashMap<String, int>();
    
    // 🔥 Grace Period 시작 시간 기록
    _timeFrameStartTimes[timeFrame] = DateTime.now();
  }

  /// ✅ HOT 상태 확인 (Controller 호환성 100% 보장)
  bool checkIfHot({
    required String key,
    required int currentRank,
    required String timeFrame,
    required String menuType, // 🔥 Controller에서 전달하는 String 파라미터
  }) {
    final hotMap = _hotStates[timeFrame] ??= HashMap<String, DateTime>();
    final rankMap = _previousRanks[timeFrame] ??= HashMap<String, int>();
    final now = DateTime.now();

    // 🎯 리팩토된 설정 조회 (내부 구현만 변경)
    final config = HotConfigManager.getConfig(menuType);

    // [수정 1] 이전 순위를 먼저 가져온 후,
    final previousRank = rankMap[key];
    
    // [수정 2] 다음 비교를 위해 현재 순위를 '무조건' 먼저 업데이트합니다.
    rankMap[key] = currentRank;

    // --- 이제부터는 HOT '판정'만 수행 ---

    // 1. Grace Period 체크
    if (config.gracePeriod.inSeconds > 0 && _isInGracePeriod(timeFrame, config.gracePeriod)) {
      return false;
    }
    
    // 2. 최소 데이터 누적 체크
    if (config.minDataPoints > 0 && _getDataCount(timeFrame) < config.minDataPoints) {
      return false;
    }
      
    // 3. 첫 업데이트인지 확인
    if (previousRank == null) {
      if (config.blockFirstUpdate) {
        return false; // HOT 판정만 억제
      }
      return false;
    }
    
    // 4. 기존 HOT 상태 체크
    if (hotMap.containsKey(key)) {
      final hotStartTime = hotMap[key]!;
      if (now.difference(hotStartTime) < config.keepDuration) {
        return true; // 아직 HOT 상태 유지
      } else {
        hotMap.remove(key); // 시간 만료시 제거
      }
    }
    
    // 5. 새로운 HOT 조건 체크
    final currentRankJump = previousRank - currentRank;
    if (currentRankJump >= config.rankJump) {
      hotMap[key] = now; // HOT 시작 시간 기록
      return true;
    }
    
    return false;
  }

  /// 🔥 Grace Period 체크
  bool _isInGracePeriod(String timeFrame, Duration gracePeriod) {
    final startTime = _timeFrameStartTimes[timeFrame];
    if (startTime == null) return false;
    
    final elapsed = DateTime.now().difference(startTime);
    return elapsed < gracePeriod;
  }

  /// 🔥 해당 시간대의 누적된 데이터 개수 체크
  int _getDataCount(String timeFrame) {
    final rankMap = _previousRanks[timeFrame];
    return rankMap?.length ?? 0;
  }

  /// ✅ 특정 시간대의 HOT 아이템 목록 (기존과 동일)
  List<String> getHotItems(String timeFrame) {
    final hotMap = _hotStates[timeFrame];
    if (hotMap == null) return [];
    
    final now = DateTime.now();
    final activeHotItems = <String>[];
    
    // 🎯 리팩토된 최대 유지 시간 조회
    final maxKeepDuration = HotConfigManager.getMaxKeepDuration();
    
    for (final entry in hotMap.entries) {
      if (now.difference(entry.value) < maxKeepDuration) {
        activeHotItems.add(entry.key);
      }
    }
    
    return activeHotItems;
  }

  /// ✅ 만료된 HOT 상태 정리 (기존과 동일)
  void cleanupExpiredHotStates() {
    final now = DateTime.now();
    
    // 🎯 리팩토된 최대 유지 시간 조회
    final maxKeepDuration = HotConfigManager.getMaxKeepDuration();
    
    for (final hotMap in _hotStates.values) {
      final expiredKeys = <String>[];
      
      for (final entry in hotMap.entries) {
        if (now.difference(entry.value) >= maxKeepDuration) {
          expiredKeys.add(entry.key);
        }
      }
      
      for (final key in expiredKeys) {
        hotMap.remove(key);
      }
    }
  }

  /// ✅ 특정 시간대 HOT 데이터 초기화 (기존과 동일)
  void clearTimeFrameHot(String timeFrame) {
    _hotStates[timeFrame]?.clear();
    _previousRanks[timeFrame]?.clear();
    
    // 🔥 Grace Period도 리셋
    _timeFrameStartTimes[timeFrame] = DateTime.now();
  }

  /// ✅ 모든 HOT 데이터 초기화 (기존과 동일)
  void clearAllHot() {
    _hotStates.clear();
    _previousRanks.clear();
    _timeFrameStartTimes.clear();
  }

  /// ✅ 디버깅용 HOT 상태 정보 (향상된 버전)
  Map<String, Map<String, dynamic>> getHotDebugInfo(String menuType) {
    final summary = <String, Map<String, dynamic>>{};
    
    // 🎯 리팩토된 설정 조회
    final config = HotConfigManager.getConfig(menuType);
    
    for (final timeFrame in _hotStates.keys) {
      final hotItems = getHotItems(timeFrame);
      final isInGrace = config.gracePeriod.inSeconds > 0 ? _isInGracePeriod(timeFrame, config.gracePeriod) : false;
      final dataCount = _getDataCount(timeFrame);
      
      summary[timeFrame] = {
        'menuType': menuType,
        'hotCount': hotItems.length,
        'hotItems': hotItems,
        'trackedCount': _previousRanks[timeFrame]?.length ?? 0,
        'isInGracePeriod': isInGrace,
        'dataCount': dataCount,
        'minDataPointsThreshold': config.minDataPoints,
        'gracePeriodRemaining': _getGracePeriodRemaining(timeFrame, config.gracePeriod),
        'blockFirstUpdate': config.blockFirstUpdate,
        'rankJumpThreshold': config.rankJump,
        'keepDuration': config.keepDuration,
        // 🎯 추가 정보
        'supportedMenuTypes': HotConfigManager.getSupportedMenuTypes(),
      };
    }
    
    return summary;
  }

  /// 🔥 Grace Period 남은 시간 계산
  Duration? _getGracePeriodRemaining(String timeFrame, Duration gracePeriod) {
    if (gracePeriod.inSeconds == 0) return Duration.zero;
    
    final startTime = _timeFrameStartTimes[timeFrame];
    if (startTime == null) return null;
    
    final elapsed = DateTime.now().difference(startTime);
    final remaining = gracePeriod - elapsed;
    
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// ✅ 리소스 정리 (기존과 동일)
  void disposeHot() {
    _hotStates.clear();
    _previousRanks.clear();
    _timeFrameStartTimes.clear();
  }
}