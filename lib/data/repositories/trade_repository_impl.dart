// lib/data/repositories/trade_repository_impl.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/trade.dart';
import '../../domain/repositories/trade_repository.dart';
import '../datasources/trade_cache_ds.dart';
import '../datasources/trade_remote_ds.dart';

/// 🔥 TradeRepository - 순수한 데이터 계층만 담당 (Volume 패턴)
/// - DataSource와 1:1 매핑
/// - Cache 저장
/// - 브로드캐스트 스트림 제공
/// - 모든 비즈니스 로직은 TradeUsecase에서 처리
class TradeRepositoryImpl implements TradeRepository {
  final TradeRemoteDataSource _remote;
  final TradeCacheDataSource _cache;

  // 🎯 핵심: 단일 스트림 관리
  Stream<Trade>? _masterStream;
  List<String> _currentMarkets = [];
  bool _disposed = false;

  TradeRepositoryImpl(this._remote, this._cache);

  /// 🔥 핵심: 마스터 스트림 제공 (TradeUsecase가 구독)
  @override
  Stream<Trade> watchTrades(List<String> markets) {
    if (_disposed) {
      throw StateError('TradeRepository has been disposed');
    }

    debugPrint('TradeRepository: watchTrades() - ${markets.length} markets');

    // 마켓이 바뀌면 새 스트림 생성
    if (!_marketsEqual(_currentMarkets, markets)) {
      debugPrint('TradeRepository: Creating new master stream for ${markets.length} markets');
      _currentMarkets = List.from(markets);
      
      _masterStream = _remote.watch(markets)
          .asyncMap((trade) async {
            // 🎯 Cache에 저장 (단순한 부수 효과)
            try {
              await _cache.cacheTrade(trade);
            } catch (e) {
              debugPrint('Cache error (ignored): $e');
            }
            return trade;
          })
          .asBroadcastStream();
    }

    return _masterStream!;
  }

  /// ✅ Volume처럼 빈 구현 (TradeUsecase에서 처리)
  @override
  Stream<List<Trade>> watchFilteredTrades(double threshold, List<String> markets) {
    if (_disposed) {
      return const Stream.empty();
    }
    
    debugPrint('TradeRepository: watchFilteredTrades() - $threshold, ${markets.length} markets');
    return _remote.watch(markets)
        .map((trade) => <Trade>[])  // 빈 리스트 반환 (실제 로직은 Usecase에)
        .asBroadcastStream();
  }

  /// ✅ Volume처럼 빈 구현 (TradeUsecase에서 처리)
  @override
  Stream<Trade> watchAggregatedTrades() {
    return const Stream.empty();
  }

  /// ✅ Volume처럼 빈 구현 (TradeUsecase에서 처리)
  @override
  void updateThreshold(double threshold) {
    // TradeUsecase에서 처리
  }

  /// ✅ Volume처럼 빈 구현 (TradeUsecase에서 처리)
  @override
  void updateRangeMode(bool isRangeMode) {
    // TradeUsecase에서 처리
  }

  /// 🎯 마켓 리스트 비교 (순서 무관)
  bool _marketsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = Set<String>.from(a);
    final setB = Set<String>.from(b);
    return setA.containsAll(setB) && setB.containsAll(setA);
  }

  /// 🧹 리소스 정리
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    
    debugPrint('TradeRepository: dispose() called');
    _disposed = true;
    
    // 스트림 정리
    _masterStream = null;
    _currentMarkets.clear();
    
    // DataSource 정리
    await _remote.dispose();
    
    debugPrint('TradeRepository: dispose completed');
  }
}