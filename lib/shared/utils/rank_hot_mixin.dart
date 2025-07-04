// lib/shared/utils/rank_hot_mixin.dart
import 'dart:collection';

/// 💡 메뉴별 HOT 상태 관리 상수
/// 🔥 Volume 메뉴 기준
class VolumeHotConfig {
  static const Duration keepDuration = Duration(seconds: 20);
  static const int rankJump = 15;
  static const Duration gracePeriod = Duration(seconds: 0);
  static const int minDataPoints = 60;
  static const bool blockFirstUpdate = true;
}

/// 🚀 Surge 메뉴 기준  
class SurgeHotConfig {
  static const Duration keepDuration = Duration(seconds: 20);
  static const int rankJump = 20;
  static const Duration gracePeriod = Duration(seconds: 0);
  static const int minDataPoints = 40;
  static const bool blockFirstUpdate = true;
}

/// 🏢 Sector 메뉴 기준
class SectorHotConfig {
  static const Duration keepDuration = Duration(seconds: 20);
  static const int rankJump = 5;
  static const Duration gracePeriod = Duration(seconds: 0);
  static const int minDataPoints = 5;
  static const bool blockFirstUpdate = true;
}

/// 🔧 HOT 설정 헬퍼
class HotConfigHelper {
  static Duration getKeepDuration(String menuType) {
    switch (menuType) {
      case 'volume': return VolumeHotConfig.keepDuration;
      case 'surge': return SurgeHotConfig.keepDuration;
      case 'sector': return SectorHotConfig.keepDuration;
      default: return VolumeHotConfig.keepDuration;
    }
  }
  
  static int getRankJump(String menuType) {
    switch (menuType) {
      case 'volume': return VolumeHotConfig.rankJump;
      case 'surge': return SurgeHotConfig.rankJump;
      case 'sector': return SectorHotConfig.rankJump;
      default: return VolumeHotConfig.rankJump;
    }
  }
  
  static Duration getGracePeriod(String menuType) {
    switch (menuType) {
      case 'volume': return VolumeHotConfig.gracePeriod;
      case 'surge': return SurgeHotConfig.gracePeriod;
      case 'sector': return SectorHotConfig.gracePeriod;
      default: return VolumeHotConfig.gracePeriod;
    }
  }
  
  static int getMinDataPoints(String menuType) {
    switch (menuType) {
      case 'volume': return VolumeHotConfig.minDataPoints;
      case 'surge': return SurgeHotConfig.minDataPoints;
      case 'sector': return SectorHotConfig.minDataPoints;
      default: return VolumeHotConfig.minDataPoints;
    }
  }
  
  static bool getBlockFirstUpdate(String menuType) {
    switch (menuType) {
      case 'volume': return VolumeHotConfig.blockFirstUpdate;
      case 'surge': return SurgeHotConfig.blockFirstUpdate;
      case 'sector': return SectorHotConfig.blockFirstUpdate;
      default: return VolumeHotConfig.blockFirstUpdate;
    }
  }
}

/// 🔥 HOT 상태 관리 전용 Mixin
/// 시간대별로 독립적인 HOT 상태 추적, 메뉴별 다른 기준 적용
mixin RankHotMixin {
  // 시간대별 HOT 상태 저장
  // {'1m': {'BTC': DateTime}, '5m': {'ETH': DateTime}}
  final Map<String, Map<String, DateTime>> _hotStates = HashMap();
  
  // 순위 추적용 (HOT 판단을 위해 필요)
  final Map<String, Map<String, int>> _previousRanks = HashMap();
  
  // 시간대별 Grace Period 시작 시간 추적
  // {'1m': DateTime, '5m': DateTime}
  final Map<String, DateTime> _timeFrameStartTimes = HashMap();

  /// 특정 시간대 초기화
  void initializeTimeFrame(String timeFrame) {
    _hotStates[timeFrame] ??= HashMap<String, DateTime>();
    _previousRanks[timeFrame] ??= HashMap<String, int>();
    
    // 🔥 Grace Period 시작 시간 기록
    _timeFrameStartTimes[timeFrame] = DateTime.now();
  }

  /// HOT 상태 확인 (메뉴별 다른 기준 적용) - 수정된 로직
  bool checkIfHot({
    required String key,
    required int currentRank,
    required String timeFrame,
    required String menuType, // 🔥 메뉴 타입 추가!
  }) {
    final hotMap = _hotStates[timeFrame] ??= HashMap<String, DateTime>();
    final rankMap = _previousRanks[timeFrame] ??= HashMap<String, int>();
    final now = DateTime.now();

    // 🔥 메뉴별 설정 가져오기
    final keepDuration = HotConfigHelper.getKeepDuration(menuType);
    final rankJump = HotConfigHelper.getRankJump(menuType);
    final gracePeriod = HotConfigHelper.getGracePeriod(menuType);
    final minDataPoints = HotConfigHelper.getMinDataPoints(menuType);
    final blockFirstUpdate = HotConfigHelper.getBlockFirstUpdate(menuType);

    // [수정 1] 이전 순위를 먼저 가져온 후,
    final previousRank = rankMap[key];
    
    // [수정 2] 다음 비교를 위해 현재 순위를 '무조건' 먼저 업데이트합니다.
    // 이렇게 하면 억제 조건으로 함수가 조기 종료되어도 순위 추적은 계속됩니다.
    rankMap[key] = currentRank;

    // --- 이제부터는 HOT '판정'만 수행 ---

    // 1. Grace Period 체크 (메뉴별)
    if (gracePeriod.inSeconds > 0 && _isInGracePeriod(timeFrame, gracePeriod)) {
      return false;
    }
    
    // 2. 최소 데이터 누적 체크 (메뉴별)
    if (minDataPoints > 0 && _getDataCount(timeFrame) < minDataPoints) {
      return false;
    }
      
    // 3. 첫 업데이트인지 확인 (메뉴별)
    if (previousRank == null) {
      if (blockFirstUpdate) {
        return false; // HOT 판정만 억제
      }
      return false;
    }
    
    // 4. 기존 HOT 상태 체크 (메뉴별 유지 시간)
    if (hotMap.containsKey(key)) {
      final hotStartTime = hotMap[key]!;
      if (now.difference(hotStartTime) < keepDuration) {
        return true; // 아직 HOT 상태 유지
      } else {
        hotMap.remove(key); // 시간 만료시 제거
      }
    }
    
    // 5. 새로운 HOT 조건 체크 (메뉴별 점프 기준)
    final currentRankJump = previousRank - currentRank;
    if (currentRankJump >= rankJump) {
      hotMap[key] = now; // HOT 시작 시간 기록
      return true;
    }
    
    return false;
  }

  /// 🔥 Grace Period 체크 (메뉴별 설정 적용)
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

  /// 특정 시간대의 HOT 아이템 목록
  List<String> getHotItems(String timeFrame) {
    final hotMap = _hotStates[timeFrame];
    if (hotMap == null) return [];
    
    final now = DateTime.now();
    final activeHotItems = <String>[];
    
    // 🔥 모든 메뉴 기준 중 가장 긴 유지 시간 사용 (안전하게)
    final maxKeepDuration = [
      VolumeHotConfig.keepDuration,
      SurgeHotConfig.keepDuration,
      SectorHotConfig.keepDuration,
    ].reduce((a, b) => a > b ? a : b);
    
    for (final entry in hotMap.entries) {
      if (now.difference(entry.value) < maxKeepDuration) {
        activeHotItems.add(entry.key);
      }
    }
    
    return activeHotItems;
  }

  /// 만료된 HOT 상태 정리
  void cleanupExpiredHotStates() {
    final now = DateTime.now();
    
    // 🔥 모든 메뉴 기준 중 가장 긴 유지 시간 사용
    final maxKeepDuration = [
      VolumeHotConfig.keepDuration,
      SurgeHotConfig.keepDuration,
      SectorHotConfig.keepDuration,
    ].reduce((a, b) => a > b ? a : b);
    
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

  /// 특정 시간대 HOT 데이터 초기화
  void clearTimeFrameHot(String timeFrame) {
    _hotStates[timeFrame]?.clear();
    _previousRanks[timeFrame]?.clear();
    
    // 🔥 Grace Period도 리셋
    _timeFrameStartTimes[timeFrame] = DateTime.now();
  }

  /// 모든 HOT 데이터 초기화
  void clearAllHot() {
    _hotStates.clear();
    _previousRanks.clear();
    _timeFrameStartTimes.clear();
  }

  /// 디버깅용 HOT 상태 정보 (메뉴별)
  Map<String, Map<String, dynamic>> getHotDebugInfo(String menuType) {
    final summary = <String, Map<String, dynamic>>{};
    
    // 🔥 메뉴별 설정 가져오기
    final gracePeriod = HotConfigHelper.getGracePeriod(menuType);
    final minDataPoints = HotConfigHelper.getMinDataPoints(menuType);
    final blockFirstUpdate = HotConfigHelper.getBlockFirstUpdate(menuType);
    
    for (final timeFrame in _hotStates.keys) {
      final hotItems = getHotItems(timeFrame);
      final isInGrace = gracePeriod.inSeconds > 0 ? _isInGracePeriod(timeFrame, gracePeriod) : false;
      final dataCount = _getDataCount(timeFrame);
      
      summary[timeFrame] = {
        'menuType': menuType, // 🔥 메뉴 타입
        'hotCount': hotItems.length,
        'hotItems': hotItems,
        'trackedCount': _previousRanks[timeFrame]?.length ?? 0,
        'isInGracePeriod': isInGrace,
        'dataCount': dataCount,
        'minDataPointsThreshold': minDataPoints, 
        'gracePeriodRemaining': _getGracePeriodRemaining(timeFrame, gracePeriod),
        'blockFirstUpdate': blockFirstUpdate,
        'rankJumpThreshold': HotConfigHelper.getRankJump(menuType), // 🔥 메뉴별 기준
        'keepDuration': HotConfigHelper.getKeepDuration(menuType), // 🔥 메뉴별 유지시간
      };
    }
    
    return summary;
  }

  /// 🔥 Grace Period 남은 시간 계산 (메뉴별)
  Duration? _getGracePeriodRemaining(String timeFrame, Duration gracePeriod) {
    if (gracePeriod.inSeconds == 0) return Duration.zero;
    
    final startTime = _timeFrameStartTimes[timeFrame];
    if (startTime == null) return null;
    
    final elapsed = DateTime.now().difference(startTime);
    final remaining = gracePeriod - elapsed;
    
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// 리소스 정리
  void disposeHot() {
    _hotStates.clear();
    _previousRanks.clear();
    _timeFrameStartTimes.clear();
  }
}