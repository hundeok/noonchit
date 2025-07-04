// lib/domain/usecases/trade_usecase.dart

import '../../core/config/app_config.dart';
import '../entities/trade.dart';
import '../repositories/trade_repository.dart';

/// 🔥 TradeUsecase - 순수 계산 함수들만 담당 (리팩토링됨)
/// - 비즈니스 규칙 검증
/// - 데이터 변환 및 필터링 계산
/// - 상태 관리는 모두 Provider로 이전됨
class TradeUsecase {
  final TradeRepository _repository;

  // 성능 최적화 상수
  static const int maxTrades = 200;
  static const int maxCacheSize = 1000;

  TradeUsecase(this._repository);

  /// 🎯 필터링된 거래 목록 계산 (순수 함수)
  /// Provider에서 호출: usecase.calculateFilteredTrades(cache, threshold, false)
  List<Trade> calculateFilteredTrades(
    Map<double, List<Trade>> filterCache,
    double threshold,
    bool isRangeMode,
  ) {
    if (!isValidThreshold(threshold)) {
      return <Trade>[];
    }

    final merged = <Trade>[];
    final seen = <String>{};

    if (isRangeMode) {
      // 구간 모드: threshold ~ nextThreshold 사이의 거래만
      final nextThreshold = getNextThreshold(threshold);
      for (final filter in AppConfig.tradeFilters.where((f) => f >= threshold)) {
        final trades = filterCache[filter] ?? <Trade>[];
        for (final trade in trades) {
          final id = '${trade.sequentialId}-${trade.timestampMs}';
          final total = trade.total;
          if (total >= threshold && total < nextThreshold && seen.add(id)) {
            merged.add(trade);
          }
        }
      }
    } else {
      // 누적 모드: threshold 이상의 모든 거래
      for (final filter in AppConfig.tradeFilters.where((f) => f >= threshold)) {
        final trades = filterCache[filter] ?? <Trade>[];
        for (final trade in trades) {
          final id = '${trade.sequentialId}-${trade.timestampMs}';
          if (trade.total >= threshold && seen.add(id)) {
            merged.add(trade);
          }
        }
      }
    }

    // 시간 역순 정렬 후 최대 개수 제한
    merged.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return merged.take(maxTrades).toList();
  }

  /// 🎯 임계값 유효성 검증 (비즈니스 규칙)
  bool isValidThreshold(double threshold) {
    // 비즈니스 규칙: 임계값은 1만원 이상 100억원 이하
    const minThreshold = 10000.0; // 1만원
    const maxThreshold = 10000000000.0; // 100억원
    return threshold >= minThreshold && threshold <= maxThreshold;
  }

  /// 🎯 다음 임계값 찾기 (비즈니스 규칙)
  double getNextThreshold(double currentThreshold) {
    final sortedFilters = AppConfig.tradeFilters.toList()..sort();
    
    // 현재 임계값과 정확히 일치하는 필터 찾기
    for (int i = 0; i < sortedFilters.length; i++) {
      if (sortedFilters[i] == currentThreshold) {
        return i + 1 < sortedFilters.length 
            ? sortedFilters[i + 1] 
            : double.infinity;
      }
    }
    
    // 정확히 일치하지 않으면 다음으로 큰 필터 찾기
    for (final filter in sortedFilters) {
      if (filter > currentThreshold) {
        return filter;
      }
    }
    
    return double.infinity;
  }

  /// 🎯 구간 모드에서 거래가 범위에 포함되는지 확인 (비즈니스 규칙)
  bool isInRange(Trade trade, double minThreshold, double maxThreshold) {
    final total = trade.total;
    return total >= minThreshold && total < maxThreshold;
  }

  /// 🎯 거래 목록을 시간 역순으로 정렬 (순수 함수)
  List<Trade> sortTradesByTimeDesc(List<Trade> trades) {
    final sorted = List<Trade>.from(trades);
    sorted.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
    return sorted;
  }

  /// 🎯 거래 목록 크기 제한 (순수 함수)
  List<Trade> limitTradeCount(List<Trade> trades, [int? maxCount]) {
    final limit = maxCount ?? maxTrades;
    return trades.length > limit ? trades.take(limit).toList() : trades;
  }

  /// 🎯 유효한 거래인지 확인 (비즈니스 규칙)
  bool isValidTrade(Trade trade) {
    return trade.market.isNotEmpty &&
           trade.price > 0 &&
           trade.volume > 0 &&
           trade.timestampMs > 0 &&
           trade.sequentialId.isNotEmpty;
  }

  /// 🎯 거래 총액 계산 (비즈니스 규칙)
  double calculateTradeTotal(double price, double volume) {
    return price * volume;
  }

  /// 🎯 거래 시장이 KRW 마켓인지 확인 (비즈니스 규칙)
  bool isKrwMarket(String market) {
    return market.startsWith('KRW-');
  }

  /// 🎯 디버그 로그용 임계값 포맷팅 (유틸리티)
  String formatThreshold(double threshold) {
    return threshold.toStringAsFixed(0);
  }

  /// 🎯 모드 이름 가져오기 (유틸리티)
  String getModeName(bool isRangeMode) {
    return isRangeMode ? "구간" : "누적";
  }
}