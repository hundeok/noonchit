// lib/data/datasources/trade_cache_ds.dart
import 'package:hive/hive.dart';
import 'dart:async';
import '../models/trade_dto.dart';
import '../../domain/entities/trade.dart';
import '../../core/utils/logger.dart';
import '../../core/error/app_exception.dart';

/// Hive 기반 배치 정리 시스템을 적용한 거래 캐시 데이터소스
/// 
/// 🔧 개선사항:
/// - 배치 기반 캐시 정리로 성능 최적화
/// - 임계점 도달 시에만 정리 작업 수행
/// - 기존 API 호환성 유지
/// - 정리 작업 중 중복 실행 방지
class TradeCacheDataSource {
  // 📊 캐시 설정
  static const int _maxCacheSize = 1000;           // 목표 캐시 사이즈
  static const int _cleanupThreshold = 1200;       // 정리 시작 임계점 (20% 버퍼)
  static const int _cleanupBatchSize = 300;        // 한 번에 정리할 개수
  
  /// 🎯 주입받은 Box (이미 열려있다는 전제)
  final Box<TradeDto> _box;
  
  /// 🔒 정리 작업 중복 실행 방지 플래그
  bool _isCleaningUp = false;
  
  /// 📈 성능 모니터링용 (선택적)
  int _totalCacheOps = 0;
  int _cleanupCount = 0;
  
  /// 생성자: 이미 열린 Box를 주입받음
  TradeCacheDataSource(this._box);
  
  /// 🚀 Trade를 DTO로 변환해 저장 (배치 정리 적용)
  /// 
  /// 기존 API와 100% 호환성 유지
  /// Throws: [CacheException] if storage operation fails
  Future<void> cacheTrade(Trade trade) async {
    try {
      // 1. 데이터 저장 (기존과 동일)
      final dto = TradeDto(
        market: trade.market,
        price: trade.price,
        volume: trade.volume,
        side: trade.side,
        changePrice: trade.changePrice,
        changeState: trade.changeState,
        timestampMs: trade.timestampMs,
        sequentialId: trade.sequentialId,
      );
      
      await _box.put(trade.sequentialId, dto);
      _totalCacheOps++;
      
      // 2. 배치 정리 확인 (임계점 도달 시에만)
      if (_shouldTriggerCleanup()) {
        // 비동기로 정리 작업 수행 (블로킹 방지)
        unawaited(_performBatchCleanup());
      }
    } catch (e) {
      log.e('Failed to cache trade', e);
      throw AppException(
        'Failed to cache trade for market ${trade.market}',
        originalException: e is Exception ? e : Exception(e.toString()),
      );
    }
  }
  
  /// 🧹 배치 정리 트리거 조건 확인
  bool _shouldTriggerCleanup() {
    return _box.length > _cleanupThreshold && !_isCleaningUp;
  }
  
  /// 🔄 배치 정리 작업 수행
  Future<void> _performBatchCleanup() async {
    if (_isCleaningUp) return; // 중복 실행 방지
    
    _isCleaningUp = true;
    
    try {
      // 현재 상태 재확인 (동시성 이슈 방지)
      if (_box.length <= _maxCacheSize) {
        return;
      }
      
      // 제거할 개수 계산
      final currentSize = _box.length;
      final targetRemoveCount = currentSize - _maxCacheSize;
      final actualRemoveCount = targetRemoveCount.clamp(0, _cleanupBatchSize);
      
      if (actualRemoveCount > 0) {
        // 오래된 키부터 제거 (FIFO 방식)
        final keysToRemove = _box.keys
            .take(actualRemoveCount)
            .toList();
        
        await _box.deleteAll(keysToRemove);
        
        _cleanupCount++;
        
        log.d('🧹 Cache cleanup: ${keysToRemove.length} items removed, '
              'size: $currentSize → ${_box.length}');
      }
    } catch (e) {
      log.e('Cache cleanup failed', e);
    } finally {
      _isCleaningUp = false;
    }
  }
  
  /// 📋 캐시된 Trade 전부 반환 (기존 API 유지)
  List<Trade> getCachedTrades() {
    try {
      return _box.values.map((dto) => dto.toEntity()).toList();
    } catch (e) {
      log.w('Failed to get cached trades', e);
      return [];
    }
  }
  
  /// 🔄 최근 N개 Trade 반환 (새로운 유틸리티 메서드)
  List<Trade> getRecentTrades([int? limit]) {
    try {
      final allTrades = getCachedTrades();
      
      if (limit == null || limit >= allTrades.length) {
        return allTrades;
      }
      
      // timestampMs 기준으로 정렬 후 최신 N개 반환
      allTrades.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
      return allTrades.take(limit).toList();
    } catch (e) {
      log.w('Failed to get recent trades', e);
      return [];
    }
  }
  
  /// 🗑️ 캐시 클리어 (기존 API 유지)
  Future<void> clearCache() async {
    try {
      await _box.clear();
      _totalCacheOps = 0;
      _cleanupCount = 0;
      log.i('Cache cleared completely');
    } catch (e) {
      log.e('Failed to clear cache', e);
      throw AppException(
        'Failed to clear cache', 
        originalException: e is Exception ? e : Exception(e.toString())
      );
    }
  }
  
  /// 🔧 수동 정리 트리거 (필요시 외부에서 호출 가능)
  Future<void> forceCleanup() async {
    if (!_isCleaningUp) {
      await _performBatchCleanup();
    }
  }
  
  /// 📊 캐시 상태 정보 반환 (디버깅/모니터링용)
  Map<String, dynamic> getCacheStats() {
    return {
      'currentSize': _box.length,
      'maxSize': _maxCacheSize,
      'threshold': _cleanupThreshold,
      'totalOperations': _totalCacheOps,
      'cleanupCount': _cleanupCount,
      'isCleaningUp': _isCleaningUp,
      'utilizationPercent': (_box.length / _maxCacheSize * 100).toInt(),
    };
  }
  
  /// 🎛️ 런타임 설정 조정 (고급 사용자용)
  void adjustCacheSettings({
    int? maxSize,
    int? threshold,
    int? batchSize,
  }) {
    // Note: static const 값들은 런타임에 변경 불가하므로
    // 실제 구현에서는 인스턴스 변수로 변경 필요
    log.d('Runtime cache adjustment requested - implement if needed');
  }
}