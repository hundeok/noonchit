// lib/data/datasources/trade_cache_ds.dart

import 'package:hive/hive.dart';
import '../models/trade_dto.dart';
import '../../domain/entities/trade.dart';

/// Hive 기반 간단 거래 캐시 데이터소스
/// - HiveService에서 이미 열린 Box를 주입받아 사용
/// - Box 생명주기 관리는 HiveService가 담당
class TradeCacheDataSource {
  static const _maxCacheSize = 1000;

  /// 🎯 주입받은 Box (이미 열려있다는 전제)
  final Box<TradeDto> _box;
  
  /// 생성자: 이미 열린 Box를 주입받음
  TradeCacheDataSource(this._box);

  /// Trade를 DTO로 변환해 저장, 사이즈 초과 시 오래된 항목 제거
  Future<void> cacheTrade(Trade trade) async {
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
    
    // 최대 캐시 사이즈 관리
    if (_box.length > _maxCacheSize) {
      final toRemove = _box.keys.take(_box.length - _maxCacheSize);
      await _box.deleteAll(toRemove);
    }
  }

  /// 캐시된 Trade 전부 반환
  List<Trade> getCachedTrades() =>
      _box.values.map((dto) => dto.toEntity()).toList();

  /// 캐시 클리어
  Future<void> clearCache() => _box.clear();

  // 🗑️ Box lifecycle 관리 메서드들 제거:
  // - init() : HiveService가 담당
  // - dispose() : HiveService가 담당
}