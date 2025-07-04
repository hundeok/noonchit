// lib/domain/repositories/trade_repository.dart
import '../entities/trade.dart';

/// Provides streams of trade data and handles resource cleanup.
abstract class TradeRepository {
 /// Streams raw [Trade] events for the given list of market codes.
 Stream<Trade> watchTrades(List<String> markets);
 
 /// Streams lists of [Trade] filtered by a minimum total trade value.
 /// => markets 파라미터 추가
 Stream<List<Trade>> watchFilteredTrades(double threshold, List<String> markets);
 
 /// Streams aggregated [Trade] events over a merge window.
 Stream<Trade> watchAggregatedTrades();
 
 /// 🎯 새로 추가: 동적 임계값 업데이트
 void updateThreshold(double threshold);
 
 /// 🆕 새로 추가: 구간/누적 모드 업데이트
 void updateRangeMode(bool isRangeMode);
 
 /// Releases any held resources (e.g., WebSocket connections, Hive boxes).
 Future<void> dispose();
}