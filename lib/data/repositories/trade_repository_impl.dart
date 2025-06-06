// lib/data/repositories/trade_repository_impl.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/config/app_config.dart';
import '../../domain/entities/trade.dart';
import '../../domain/repositories/trade_repository.dart';
import '../datasources/trade_cache_ds.dart';
import '../datasources/trade_remote_ds.dart';
import '../processors/trade_aggregator.dart';

/// 예전 프로젝트 방식의 효율적인 배치 처리를 적용한 Repository
class TradeRepositoryImpl implements TradeRepository {
  final TradeRemoteDataSource _remote;
  final TradeCacheDataSource _cache;
  final TradeAggregator _aggregator;

  // 📊 내부 상태 관리 (예전 프로젝트 TradeNotifier 방식)
  final Map<double, List<Trade>> _filterLists = {};
  final Set<String> _seenIds = {};
  
  // 🎯 배치 처리를 위한 컨트롤러들
  final StreamController<List<Trade>> _filteredController = StreamController<List<Trade>>.broadcast();
  final StreamController<Trade> _aggregatedController = StreamController<Trade>.broadcast();
  
  // 🔥 핵심: 단일 스트림 관리
  Stream<Trade>? _masterStream;
  StreamSubscription<Trade>? _masterSubscription;
  Timer? _periodicFlushTimer;
  Timer? _batchUpdateTimer;
  
  // 🎯 동적 임계값 관리
  double _currentThreshold = 20000000.0; // 기본값: 2천만원
  
  // 성능 최적화 상수
  static const int _maxTrades = 200;
  static const int _maxCacheSize = 1000;
  static const Duration _batchUpdateInterval = Duration(milliseconds: 100);

  TradeRepositoryImpl(this._remote, this._cache)
      : _aggregator = TradeAggregator() {
    
    // 필터 리스트 초기화
    for (final filter in AppConfig.tradeFilters) {
      _filterLists[filter] = [];
    }
    
    // 주기적 플러시 타이머
    _periodicFlushTimer = Timer.periodic(
      AppConfig.globalResetInterval,
      (_) => _aggregator.flushTrades(onTradeProcessed: _handleProcessedTrade),
    );
  }

  /// 🔥 핵심: 마스터 스트림 초기화 (한 번만 호출)
  void _initializeMasterStream(List<String> markets) {
    if (_masterStream != null) return; // 이미 초기화됨
    
    debugPrint('TradeRepositoryImpl: initializing master stream for ${markets.length} markets');
    
    // 🎯 단일 스트림 생성 (브로드캐스트로 다른 Repository도 구독 가능)
    _masterStream = _remote.watch(markets).asBroadcastStream();
    
    // 🎯 단일 구독으로 모든 데이터 처리
    _masterSubscription = _masterStream!.listen(
      _processRawTrade,
      onError: (error, stackTrace) {
        debugPrint('Master stream error: $error');
        debugPrint('StackTrace: $stackTrace');
      },
      onDone: () {
        debugPrint('Master stream done');
      },
    );
  }

  @override
  Stream<Trade> watchTrades(List<String> markets) {
    debugPrint('TradeRepositoryImpl: watchTrades() - ${markets.length} markets');
    
    // 마스터 스트림 초기화
    _initializeMasterStream(markets);
    
    // 마스터 스트림 반환 (추가 구독 없음)
    return _masterStream!;
  }

  @override
  Stream<List<Trade>> watchFilteredTrades(double threshold, List<String> markets) {
    debugPrint('TradeRepositoryImpl: watchFilteredTrades() - threshold: $threshold');
    
    // 🎯 수정: 임계값 업데이트
    _currentThreshold = threshold;
    
    // 마스터 스트림 초기화
    _initializeMasterStream(markets);
    
    // 임계값이 변경되었으므로 즉시 재필터링
    _scheduleBatchUpdate();
    
    // 배치 처리된 결과 스트림 반환
    return _filteredController.stream;
  }

  @override
  Stream<Trade> watchAggregatedTrades() {
    return _aggregatedController.stream;
  }

  /// 🎯 새로 추가: 동적 임계값 업데이트
  @override
  void updateThreshold(double threshold) {
    if (_currentThreshold != threshold) {
      _currentThreshold = threshold;
      debugPrint('🎯 Threshold updated to: ${threshold.toStringAsFixed(0)}');
      
      // 즉시 재필터링 실행
      _scheduleBatchUpdate();
    }
  }
  
  /// 📥 원시 거래 데이터 처리 (예전 프로젝트 방식)
  void _processRawTrade(Trade trade) async {
    try {
      final key = '${trade.market}/${trade.sequentialId}';

      // 중복 처리 방지
      if (!_seenIds.add(key)) return;

      // 메모리 관리
      if (_seenIds.length > _maxCacheSize) {
        final removeCount = (_seenIds.length / 4).ceil();
        final toRemove = _seenIds.take(removeCount).toList();
        _seenIds.removeAll(toRemove);
      }

      // 캐시 저장
      await _cache.cacheTrade(trade);

      // 🔄 Aggregator를 통한 거래 처리
      _aggregator.processTrade(
        {
          'market': trade.market,
          'price': trade.price,
          'volume': trade.volume,
          'timestamp': trade.timestampMs,
          'isBuy': trade.isBuy,
          'sequential_id': trade.sequentialId,
        },
        onTradeProcessed: _handleProcessedTrade,
      );
      
    } catch (e, stackTrace) {
      debugPrint('_processRawTrade error: $e');
      debugPrint('StackTrace: $stackTrace');
    }
  }
  
  /// 🎯 집계된 거래 처리 및 필터링 (핵심 로직)
  void _handleProcessedTrade(Map<String, dynamic> processedTrade) {
    try {
      // Trade 엔티티로 변환
      final trade = Trade(
        market: processedTrade['market'] as String,
        price: processedTrade['price'] as double,
        volume: processedTrade['volume'] as double,
        side: (processedTrade['isBuy'] as bool) ? 'BID' : 'ASK',
        changePrice: 0.0,
        changeState: 'EVEN',
        timestampMs: processedTrade['timestamp'] as int,
        sequentialId: processedTrade['sequential_id'] as String,
      );
      
      // 집계된 거래 스트림에 추가
      if (!_aggregatedController.isClosed) {
        _aggregatedController.add(trade);
      }
      
      final total = trade.total;
      
      // 📋 각 필터에 해당하는 거래 추가
      for (final filter in AppConfig.tradeFilters) {
        if (total >= filter) {
          final list = _filterLists[filter]!;
          list.insert(0, trade);
          
          // 최대 거래 수 유지
          if (list.length > _maxTrades) {
            list.removeLast();
          }
        }
      }
      
      // 🚀 배치 업데이트 스케줄링 (과도한 UI 업데이트 방지)
      _scheduleBatchUpdate();
      
    } catch (e, stackTrace) {
      debugPrint('_handleProcessedTrade error: $e');
      debugPrint('StackTrace: $stackTrace');
    }
  }
  
  /// ⏰ 배치 업데이트 스케줄링 (예전 프로젝트의 _updateFilteredTrades 방식)
  void _scheduleBatchUpdate() {
    // 이미 스케줄된 업데이트가 있으면 리셋
    _batchUpdateTimer?.cancel();
    
    _batchUpdateTimer = Timer(_batchUpdateInterval, () {
      _updateFilteredTrades();
    });
  }
  
  /// 📊 필터링된 거래 목록 업데이트 (UI 업데이트)
  void _updateFilteredTrades() {
    try {
      // 🎯 수정: 동적 임계값 사용
      final threshold = _currentThreshold;
      
      final merged = <Trade>[];
      final seen = <String>{};

      // 🔍 임계값 이상의 모든 필터에서 거래 수집
      for (final filter in AppConfig.tradeFilters.where((f) => f >= threshold)) {
        for (final trade in _filterLists[filter] ?? <Trade>[]) {
          final id = '${trade.sequentialId}-${trade.timestampMs}';
          if (trade.total >= threshold && seen.add(id)) {
            merged.add(trade);
          }
        }
      }

      // 시간순 정렬 (최신 순)
      merged.sort((a, b) => b.timestampMs.compareTo(a.timestampMs));
      
      // 최대 거래 수로 제한
      final result = merged.take(_maxTrades).toList();
      
      // 🚀 UI에 업데이트 전송
      if (!_filteredController.isClosed) {
        _filteredController.add(result);
        
        if (kDebugMode && result.isNotEmpty) {
          debugPrint('🎯 Batch update: ${result.length} filtered trades (threshold: ${threshold.toStringAsFixed(0)})');
        }
      }
      
    } catch (e, stackTrace) {
      debugPrint('_updateFilteredTrades error: $e');
      debugPrint('StackTrace: $stackTrace');
    }
  }

  @override
  Future<void> dispose() async {
    debugPrint('TradeRepositoryImpl: dispose() called');
    
    // 타이머들 정리
    _periodicFlushTimer?.cancel();
    _batchUpdateTimer?.cancel();
    
    // 마스터 구독 정리
    await _masterSubscription?.cancel();
    _masterStream = null;
    
    // 컨트롤러들 정리
    await _filteredController.close();
    await _aggregatedController.close();
    
    // 데이터소스 정리 (remote만)
    await _remote.dispose();
    
    // 🗑️ TradeCacheDataSource.dispose() 제거 (HiveService가 Box 생명주기 관리)
    // await _cache.dispose();  // ← 제거됨
    
    // Aggregator 플러시
    _aggregator.flushTrades(onTradeProcessed: (_) {});
  }
}