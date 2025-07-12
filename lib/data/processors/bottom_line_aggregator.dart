// data/processors/bottom_line_aggregator.dart
// 🔄 바텀라인 데이터 애그리게이터 - 실시간 누적 & 스냅샷 생성

import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import '../../core/utils/bottom_line_circular_buffer.dart';
import '../../core/utils/bottom_line_constants.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/bottom_line.dart';
import '../../domain/entities/trade.dart';
import '../../domain/entities/volume.dart';
import '../../domain/entities/surge.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 📊 실시간 시장 통계 클래스들
// ══════════════════════════════════════════════════════════════════════════════

/// 시장별 실시간 집계 통계 (메모리 효율적)
@immutable
class RealtimeMarketStats {
  final String market;
  final double totalVolume;           // 누적 거래량
  final double totalAmount;           // 누적 거래대금
  final int tradeCount;               // 총 거래 횟수
  final double basePrice;             // 시작 가격 (급등/급락 계산용)
  final double currentPrice;          // 현재 가격
  final double highPrice;             // 최고가
  final double lowPrice;              // 최저가
  final int largeTradeCount;          // 고액거래 횟수
  final DateTime firstTradeTime;      // 첫 거래 시간
  final DateTime lastTradeTime;       // 마지막 거래 시간
  final double weightedAvgPrice;      // 거래량 가중 평균가

  const RealtimeMarketStats({
    required this.market,
    required this.totalVolume,
    required this.totalAmount,
    required this.tradeCount,
    required this.basePrice,
    required this.currentPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.largeTradeCount,
    required this.firstTradeTime,
    required this.lastTradeTime,
    required this.weightedAvgPrice,
  });

  /// 초기 통계 생성
  factory RealtimeMarketStats.initial(Trade firstTrade) {
    return RealtimeMarketStats(
      market: firstTrade.market,
      totalVolume: firstTrade.volume,
      totalAmount: firstTrade.total,
      tradeCount: 1,
      basePrice: firstTrade.price,
      currentPrice: firstTrade.price,
      highPrice: firstTrade.price,
      lowPrice: firstTrade.price,
      largeTradeCount: firstTrade.total >= BottomLineConstants.largeTradeThreshold ? 1 : 0,
      firstTradeTime: DateTime.fromMillisecondsSinceEpoch(firstTrade.timestampMs),
      lastTradeTime: DateTime.fromMillisecondsSinceEpoch(firstTrade.timestampMs),
      weightedAvgPrice: firstTrade.price,
    );
  }

  /// 새 거래 추가하여 통계 업데이트
  RealtimeMarketStats addTrade(Trade trade) {
    final newTotalVolume = totalVolume + trade.volume;
    final newTotalAmount = totalAmount + trade.total;
    final newTradeCount = tradeCount + 1;
    final newLargeTradeCount = largeTradeCount + 
      (trade.total >= BottomLineConstants.largeTradeThreshold ? 1 : 0);
    
    // 거래량 가중 평균가 계산
    final newWeightedAvgPrice = newTotalVolume > 0
      ? (weightedAvgPrice * totalVolume + trade.price * trade.volume) / newTotalVolume
      : trade.price;

    return RealtimeMarketStats(
      market: market,
      totalVolume: newTotalVolume,
      totalAmount: newTotalAmount,
      tradeCount: newTradeCount,
      basePrice: basePrice, // 변경하지 않음 (시작점 유지)
      currentPrice: trade.price,
      highPrice: math.max(highPrice, trade.price),
      lowPrice: math.min(lowPrice, trade.price),
      largeTradeCount: newLargeTradeCount,
      firstTradeTime: firstTradeTime, // 변경하지 않음
      lastTradeTime: DateTime.fromMillisecondsSinceEpoch(trade.timestampMs),
      weightedAvgPrice: newWeightedAvgPrice,
    );
  }

  /// 가격 변화율 계산
  double get changePercent {
    if (basePrice <= 0) return 0.0;
    return ((currentPrice - basePrice) / basePrice) * 100;
  }

  /// 변동성 계산 (고가-저가 범위)
  double get volatilityPercent {
    if (lowPrice <= 0) return 0.0;
    return ((highPrice - lowPrice) / lowPrice) * 100;
  }

  /// 거래 활발도 (분당 거래 횟수)
  double get tradesPerMinute {
    final duration = lastTradeTime.difference(firstTradeTime);
    if (duration.inMinutes == 0) return tradeCount.toDouble();
    return tradeCount / duration.inMinutes;
  }

  /// 고액거래 비율
  double get largeTradeRatio {
    if (tradeCount == 0) return 0.0;
    return largeTradeCount / tradeCount;
  }

  /// 활성도 여부 (최근 5분 내 거래)
  bool get isActive {
    return DateTime.now().difference(lastTradeTime).inMinutes < 5;
  }

  /// Trade Entity로 변환
  Trade toTradeEntity() {
    return Trade(
      market: market,
      price: currentPrice,
      volume: totalVolume,
      side: 'BID', // 기본값
      changePrice: currentPrice - basePrice,
      changeState: changePercent > 0 ? 'RISE' : (changePercent < 0 ? 'FALL' : 'EVEN'),
      timestampMs: lastTradeTime.millisecondsSinceEpoch,
      sequentialId: 'aggregated_${market}_${lastTradeTime.millisecondsSinceEpoch}',
    );
  }

  /// Volume Entity로 변환
  Volume toVolumeEntity() {
    return Volume(
      market: market,
      totalVolume: totalVolume,
      lastUpdatedMs: lastTradeTime.millisecondsSinceEpoch,
      timeFrame: 'realtime',
      timeFrameStartMs: firstTradeTime.millisecondsSinceEpoch,
    );
  }

  /// Surge Entity로 변환
  Surge toSurgeEntity() {
    return Surge(
      market: market,
      changePercent: changePercent,
      basePrice: basePrice,
      currentPrice: currentPrice,
      lastUpdatedMs: lastTradeTime.millisecondsSinceEpoch,
      timeFrame: 'realtime',
      timeFrameStartMs: firstTradeTime.millisecondsSinceEpoch,
    );
  }

  @override
  String toString() {
    return 'MarketStats($market: ${tradeCount}trades, ${changePercent.toStringAsFixed(1)}%, ${(totalAmount/100000000).toStringAsFixed(1)}억)';
  }
}

/// 섹터별 실시간 집계 통계
@immutable
class RealtimeSectorStats {
  final String sector;
  final double totalVolume;
  final double totalAmount;
  final Set<String> activeMarkets;
  final DateTime firstUpdateTime;
  final DateTime lastUpdateTime;
  final int marketCount;

  const RealtimeSectorStats({
    required this.sector,
    required this.totalVolume,
    required this.totalAmount,
    required this.activeMarkets,
    required this.firstUpdateTime,
    required this.lastUpdateTime,
    required this.marketCount,
  });

  /// 초기 섹터 통계 생성
  factory RealtimeSectorStats.initial(String sector, String market, double volume, double amount) {
    final now = DateTime.now();
    return RealtimeSectorStats(
      sector: sector,
      totalVolume: volume,
      totalAmount: amount,
      activeMarkets: {market},
      firstUpdateTime: now,
      lastUpdateTime: now,
      marketCount: 1,
    );
  }

  /// 마켓 데이터 추가
  RealtimeSectorStats addMarketData(String market, double volume, double amount) {
    final newActiveMarkets = Set<String>.from(activeMarkets)..add(market);
    
    return RealtimeSectorStats(
      sector: sector,
      totalVolume: totalVolume + volume,
      totalAmount: totalAmount + amount,
      activeMarkets: newActiveMarkets,
      firstUpdateTime: firstUpdateTime,
      lastUpdateTime: DateTime.now(),
      marketCount: newActiveMarkets.length,
    );
  }

  /// Volume Entity로 변환
  Volume toVolumeEntity() {
    return Volume(
      market: 'SECTOR-$sector',
      totalVolume: totalVolume,
      lastUpdatedMs: lastUpdateTime.millisecondsSinceEpoch,
      timeFrame: 'realtime',
      timeFrameStartMs: firstUpdateTime.millisecondsSinceEpoch,
    );
  }

  @override
  String toString() {
    return 'SectorStats($sector: ${marketCount}markets, ${(totalAmount/100000000).toStringAsFixed(1)}억)';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🔄 바텀라인 실시간 데이터 애그리게이터 (메인 클래스)
// ══════════════════════════════════════════════════════════════════════════════

/// 바텀라인용 실시간 데이터 애그리게이터 - 메모리 효율적 누적 처리
class BottomLineAggregator {
  // 📊 실시간 통계 저장소
  final Map<String, RealtimeMarketStats> _marketStats = <String, RealtimeMarketStats>{};
  final Map<String, RealtimeSectorStats> _sectorStats = <String, RealtimeSectorStats>{};
  
  // 🔄 순환 버퍼들 (메모리 효율적)
  late final TradeCircularBuffer _recentTrades;
  late final StringCircularBuffer _recentLargeTrades;
  late final TimeBasedCircularBuffer<String> _marketActivity;
  
  // 📸 스냅샷 캐시
  final Queue<MarketSnapshot> _snapshotHistory = Queue<MarketSnapshot>();
  MarketSnapshot? _lastSnapshot;
  MarketSnapshot? _baselineSnapshot;
  
  // ⏰ 시간 관리
  late final DateTime _startTime;
  DateTime? _lastSnapshotTime;
  DateTime? _lastCleanupTime;
  int _snapshotCounter = 0;
  
  // 📊 성능 통계
  int _totalTradesProcessed = 0;
  int _totalSnapshotsGenerated = 0;
  Duration _totalProcessingTime = Duration.zero;

  BottomLineAggregator() : _startTime = DateTime.now() {
    _initializeBuffers();
    
    if (BottomLineConstants.enableLogging) {
      log.d('🔄 BottomLine Aggregator initialized at $_startTime');
    }
  }

  void _initializeBuffers() {
    _recentTrades = BottomLineBufferFactory.createTradeBuffer();
    _recentLargeTrades = BottomLineBufferFactory.createLargeTradeBuffer();
    _marketActivity = BottomLineBufferFactory.createTimeBasedBuffer<String>(
      BottomLineConstants.maxTrackedMarkets,
      const Duration(minutes: 10), // 10분 TTL
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 📊 실시간 데이터 추가 (메인 로직)
  // ══════════════════════════════════════════════════════════════════════════════

  /// 실시간 거래 데이터 추가 및 통계 업데이트
  void addRealtimeTrade(Trade trade) {
    final stopwatch = Stopwatch()..start();
    
    try {
      // 🔄 순환 버퍼에 추가
      final tradeMap = _tradeToMap(trade);
      _recentTrades.add(tradeMap);
      
      // 📊 시장별 통계 업데이트
      _updateMarketStats(trade);
      
      // 🏷️ 섹터별 통계 업데이트
      _updateSectorStats(trade);
      
      // 🎯 고액거래 추적
      if (trade.total >= BottomLineConstants.largeTradeThreshold) {
        _recentLargeTrades.add('${trade.market}:${trade.total.toInt()}:${trade.timestampMs}');
      }
      
      // 📈 시장 활동 추적
      _marketActivity.addData(trade.market);
      
      // 🗑️ 주기적 정리
      _performPeriodicCleanup();
      
      // 📊 통계 업데이트
      _totalTradesProcessed++;
      stopwatch.stop();
      _totalProcessingTime += stopwatch.elapsed;
      
      if (BottomLineConstants.enableDetailedLogging && _totalTradesProcessed % 100 == 0) {
        log.d('📊 Processed ${_totalTradesProcessed} trades, ${_marketStats.length} markets tracked');
      }
      
    } catch (e, stackTrace) {
      stopwatch.stop();
      log.e('🚨 Trade processing failed: $e', e, stackTrace);
    }
  }

  /// Trade를 Map으로 변환 (CircularBuffer 호환)
  Map<String, dynamic> _tradeToMap(Trade trade) {
    return {
      'market': trade.market,
      'price': trade.price,
      'volume': trade.volume,
      'amount': trade.total,
      'timestamp': trade.timestampMs,
      'side': trade.side,
    };
  }

  /// 시장별 통계 업데이트
  void _updateMarketStats(Trade trade) {
    final market = trade.market;
    
    if (_marketStats.containsKey(market)) {
      _marketStats[market] = _marketStats[market]!.addTrade(trade);
    } else {
      _marketStats[market] = RealtimeMarketStats.initial(trade);
    }
  }

  /// 섹터별 통계 업데이트
  void _updateSectorStats(Trade trade) {
    final sector = _classifyMarketSector(trade.market);
    
    if (_sectorStats.containsKey(sector)) {
      _sectorStats[sector] = _sectorStats[sector]!
        .addMarketData(trade.market, trade.volume, trade.total);
    } else {
      _sectorStats[sector] = RealtimeSectorStats.initial(
        sector, trade.market, trade.volume, trade.total);
    }
  }

  /// 시장 섹터 분류 (기존 SectorClassification 활용)
  String _classifyMarketSector(String market) {
    final ticker = market.replaceFirst('KRW-', '');
    
    // 메이저 코인
    if (['BTC', 'ETH'].contains(ticker)) {
      return 'Major';
    }
    
    // 레이어1 블록체인
    if (['SOL', 'ADA', 'AVAX', 'DOT', 'MATIC'].contains(ticker)) {
      return 'Layer1';
    }
    
    // DeFi 토큰
    if (['UNI', 'AAVE', 'COMP', 'SUSHI', 'CRV'].contains(ticker)) {
      return 'DeFi';
    }
    
    // 메타버스/게임
    if (['SAND', 'MANA', 'AXS', 'ENJ'].contains(ticker)) {
      return 'Metaverse';
    }
    
    // AI/빅데이터
    if (['FET', 'OCEAN', 'GRT'].contains(ticker)) {
      return 'AI';
    }
    
    // 기본값
    return 'Altcoin';
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 📸 스냅샷 생성 (30초마다)
  // ══════════════════════════════════════════════════════════════════════════════

  /// 스냅샷 생성 필요 여부 확인
  bool shouldGenerateSnapshot() {
    if (_lastSnapshotTime == null) return true;
    
    final elapsed = DateTime.now().difference(_lastSnapshotTime!);
    return elapsed.inSeconds >= BottomLineConstants.refreshIntervalSeconds;
  }

  /// 실시간 통계에서 마켓 스냅샷 생성
  MarketSnapshot? generateRealtimeSnapshot() {
    if (!shouldGenerateSnapshot()) return null;
    
    final stopwatch = Stopwatch()..start();
    
    try {
      final now = DateTime.now();
      
      // 📊 각 타입별 Entity 생성
      final trades = _generateTradeEntities();
      final volumes = _generateVolumeEntities();
      final surges = _generateSurgeEntities();
      final sectors = _generateSectorVolumeEntities();
      
      // 📈 델타 계산 (이전 스냅샷 대비)
      final deltas = _calculateDeltas();
      
      // 📸 스냅샷 생성
      final snapshot = MarketSnapshot(
        timestamp: now,
        timeFrame: 'min5', // TimeFrame.min5 대신 문자열 사용
        topTrades: trades,
        topVolumes: volumes,
        surges: surges,
        sectorVolumes: sectors,
        volChangePct: deltas['volume'] ?? {},
        sectorShareDelta: deltas['sector'] ?? {},
        priceDelta: deltas['price'] ?? {},
      );
      
      // 📦 스냅샷 캐싱
      _cacheSnapshot(snapshot);
      
      // ⏰ 시간 업데이트
      _lastSnapshotTime = now;
      _snapshotCounter++;
      
      // 📊 통계 업데이트
      _totalSnapshotsGenerated++;
      stopwatch.stop();
      _totalProcessingTime += stopwatch.elapsed;
      
      if (BottomLineConstants.enableLogging) {
        log.d('📸 Snapshot #$_snapshotCounter generated: ${trades.length}T/${volumes.length}V/${surges.length}S/${sectors.length}SEC (${stopwatch.elapsedMilliseconds}ms)');
      }
      
      return snapshot;
      
    } catch (e, stackTrace) {
      stopwatch.stop();
      log.e('🚨 Snapshot generation failed: $e', e, stackTrace);
      return null;
    }
  }

  /// 실시간 통계에서 Trade 엔티티들 생성
  List<Trade> _generateTradeEntities() {
    // 고액거래 중심으로 최근 거래들 선택
    final largeTrades = _recentTrades.largeTrades;
    
    // 시장별로 그룹핑하여 중복 제거
    final marketTrades = <String, Map<String, dynamic>>{};
    for (final trade in largeTrades) {
      final market = trade['market'] as String;
      if (!marketTrades.containsKey(market) || 
          (trade['amount'] as double) > (marketTrades[market]!['amount'] as double)) {
        marketTrades[market] = trade;
      }
    }
    
    // Trade 엔티티로 변환
    final trades = marketTrades.values.map((tradeMap) {
      return Trade(
        market: tradeMap['market'] as String,
        price: tradeMap['price'] as double,
        volume: tradeMap['volume'] as double,
        side: tradeMap['side'] as String? ?? 'BID',
        changePrice: 0.0, // 계산 필요시 추가
        changeState: 'EVEN', // 계산 필요시 추가
        timestampMs: tradeMap['timestamp'] as int,
        sequentialId: 'agg_${tradeMap['market']}_${tradeMap['timestamp']}',
      );
    }).toList();
    
    // 거래대금 순 정렬
    trades.sort((a, b) => b.total.compareTo(a.total));
    
    return trades.take(50).toList();
  }

  /// 실시간 통계에서 Volume 엔티티들 생성
  List<Volume> _generateVolumeEntities() {
    final volumes = _marketStats.values
      .where((stats) => stats.isActive && stats.totalVolume > 0)
      .map((stats) => stats.toVolumeEntity())
      .toList();
    
    // 볼륨 순 정렬
    volumes.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    
    return volumes.take(50).toList();
  }

  /// 실시간 통계에서 Surge 엔티티들 생성
  List<Surge> _generateSurgeEntities() {
    final surges = _marketStats.values
      .where((stats) => stats.isActive && stats.changePercent.abs() > 0.1)
      .map((stats) => stats.toSurgeEntity())
      .toList();
    
    // 변화율 절댓값 순 정렬 (급등이 먼저)
    surges.sort((a, b) {
      if (a.changePercent > 0 && b.changePercent < 0) return -1;
      if (a.changePercent < 0 && b.changePercent > 0) return 1;
      return b.changePercent.abs().compareTo(a.changePercent.abs());
    });
    
    return surges;
  }

  /// 실시간 통계에서 섹터 Volume 엔티티들 생성
  List<Volume> _generateSectorVolumeEntities() {
    final sectorVolumes = _sectorStats.values
      .where((stats) => stats.totalVolume > 0)
      .map((stats) => stats.toVolumeEntity())
      .toList();
    
    // 볼륨 순 정렬
    sectorVolumes.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    
    return sectorVolumes.take(10).toList();
  }

  /// 이전 스냅샷 대비 델타 계산
  Map<String, Map<String, double>> _calculateDeltas() {
    if (_lastSnapshot == null) {
      return {'volume': {}, 'sector': {}, 'price': {}};
    }
    
    // 볼륨 변화율 계산
    final volChangePct = <String, double>{};
    for (final stats in _marketStats.values) {
      final prevVolume = _lastSnapshot!.topVolumes
        .where((v) => v.market == stats.market)
        .firstOrNull?.totalVolume ?? 0.0;
      
      if (prevVolume > 0) {
        volChangePct[stats.market] = 
          ((stats.totalVolume - prevVolume) / prevVolume) * 100;
      }
    }
    
    // 섹터 점유율 변화 계산
    final sectorShareDelta = <String, double>{};
    final currentTotalVolume = _sectorStats.values
      .fold<double>(0, (sum, stats) => sum + stats.totalVolume);
    
    if (currentTotalVolume > 0) {
      for (final stats in _sectorStats.values) {
        final currentShare = (stats.totalVolume / currentTotalVolume) * 100;
        
        final prevTotalVolume = _lastSnapshot!.sectorVolumes
          .fold<double>(0, (sum, v) => sum + v.totalVolume);
        final prevSectorVolume = _lastSnapshot!.sectorVolumes
          .where((v) => v.market == 'SECTOR-${stats.sector}')
          .firstOrNull?.totalVolume ?? 0.0;
        
        if (prevTotalVolume > 0) {
          final prevShare = (prevSectorVolume / prevTotalVolume) * 100;
          sectorShareDelta['SECTOR-${stats.sector}'] = currentShare - prevShare;
        }
      }
    }
    
    // 가격 변화율
    final priceDelta = <String, double>{};
    for (final stats in _marketStats.values) {
      priceDelta[stats.market] = stats.changePercent;
    }
    
    return {
      'volume': volChangePct,
      'sector': sectorShareDelta,
      'price': priceDelta,
    };
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 💾 스냅샷 캐싱 및 관리
  // ══════════════════════════════════════════════════════════════════════════════

  /// 스냅샷 캐싱
  void _cacheSnapshot(MarketSnapshot snapshot) {
    _lastSnapshot = snapshot;
    
    // 첫 번째 스냅샷을 베이스라인으로 설정
    _baselineSnapshot ??= snapshot;
    
    // 스냅샷 히스토리 관리 (최대 3개)
    _snapshotHistory.addLast(snapshot);
    while (_snapshotHistory.length > BottomLineConstants.maxCachedSnapshots) {
      _snapshotHistory.removeFirst();
    }
  }

  /// 마지막 스냅샷 반환
  MarketSnapshot? getLastSnapshot() => _lastSnapshot;

  /// 베이스라인 스냅샷 반환
  MarketSnapshot? getBaselineSnapshot() => _baselineSnapshot;

  /// 스냅샷 히스토리 반환
  List<MarketSnapshot> getSnapshotHistory() => _snapshotHistory.toList();

  /// 베이스라인 스냅샷 갱신 (1시간마다)
  void refreshBaseline() {
    if (_lastSnapshot != null) {
      _baselineSnapshot = _lastSnapshot;
      
      if (BottomLineConstants.enableLogging) {
        log.d('📍 Baseline snapshot refreshed');
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 🗑️ 메모리 관리 및 정리
  // ══════════════════════════════════════════════════════════════════════════════

  /// 주기적 정리 수행
  void _performPeriodicCleanup() {
    final now = DateTime.now();
    
    // 5분마다 정리
    if (_lastCleanupTime == null || 
        now.difference(_lastCleanupTime!).inMinutes >= BottomLineConstants.cleanupIntervalMinutes) {
      _performCleanup();
      _lastCleanupTime = now;
    }
    
    // 1시간마다 베이스라인 갱신
    if (_baselineSnapshot != null &&
        now.difference(_baselineSnapshot!.timestamp).inHours >= BottomLineConstants.baselineRefreshHours) {
      refreshBaseline();
    }
  }

  /// 메모리 정리 실행
  void _performCleanup() {
    final beforeSize = getMemoryUsageEstimate();
    int removedMarkets = 0;
    int removedSectors = 0;
    
    // 비활성 시장 제거
    final inactiveMarkets = _marketStats.entries
      .where((entry) => !entry.value.isActive)
      .map((entry) => entry.key)
      .toList();
    
    for (final market in inactiveMarkets) {
      _marketStats.remove(market);
      removedMarkets++;
    }
    
    // 빈 섹터 제거
    final emptySectors = _sectorStats.entries
      .where((entry) => entry.value.totalVolume == 0)
      .map((entry) => entry.key)
      .toList();
    
    for (final sector in emptySectors) {
      _sectorStats.remove(sector);
      removedSectors++;
    }
    
    // 순환 버퍼 정리 (자동)
    _marketActivity.removeExpired();
    
    final afterSize = getMemoryUsageEstimate();
    
    if (BottomLineConstants.enableLogging && (removedMarkets > 0 || removedSectors > 0)) {
      log.d('🗑️ Cleanup completed: -${removedMarkets}markets, -${removedSectors}sectors, ${beforeSize}B→${afterSize}B');
    }
  }

  /// 메모리 사용량 추정
  int getMemoryUsageEstimate() {
    int total = 0;
    
    // 시장별 통계
    total += _marketStats.length * 300; // ~300바이트 per market
    
    // 섹터별 통계
    total += _sectorStats.length * 200; // ~200바이트 per sector
    
    // 순환 버퍼들
    total += _recentTrades.estimatedMemoryBytes;
    total += _recentLargeTrades.estimatedMemoryBytes;
    total += _marketActivity.estimatedMemoryBytes;
    
    // 스냅샷 히스토리
    total += _snapshotHistory.length * 10000; // ~10KB per snapshot
    
    return total;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 📊 통계 및 모니터링
  // ══════════════════════════════════════════════════════════════════════════════

  /// 전체 애그리게이터 통계
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final uptimeMinutes = now.difference(_startTime).inMinutes;
    
    final avgProcessingTime = _totalTradesProcessed > 0
      ? _totalProcessingTime.inMicroseconds / _totalTradesProcessed
      : 0.0;
    
    final tradesPerMinute = uptimeMinutes > 0
      ? _totalTradesProcessed / uptimeMinutes
      : 0.0;
    
    return {
      'uptime_minutes': uptimeMinutes,
      'total_trades_processed': _totalTradesProcessed,
      'total_snapshots_generated': _totalSnapshotsGenerated,
      'trades_per_minute': tradesPerMinute.toStringAsFixed(1),
      'avg_processing_time_us': avgProcessingTime.toStringAsFixed(1),
      'markets_tracked': _marketStats.length,
      'sectors_tracked': _sectorStats.length,
      'active_markets': _marketStats.values.where((s) => s.isActive).length,
      'memory_usage_bytes': getMemoryUsageEstimate(),
      'last_snapshot': _lastSnapshotTime?.toIso8601String() ?? 'Never',
      'last_cleanup': _lastCleanupTime?.toIso8601String() ?? 'Never',
      'snapshot_counter': _snapshotCounter,
      'cache_sizes': {
        'recent_trades': _recentTrades.length,
        'large_trades': _recentLargeTrades.length,
        'market_activity': _marketActivity.length,
        'snapshot_history': _snapshotHistory.length,
      },
    };
  }

  /// 시장별 상세 통계
  Map<String, dynamic> getMarketStats() {
    final marketStats = <String, Map<String, dynamic>>{};
    
    for (final entry in _marketStats.entries) {
      final stats = entry.value;
      marketStats[entry.key] = {
        'total_volume': stats.totalVolume,
        'total_amount': (stats.totalAmount / 100000000).toStringAsFixed(1), // 억원
        'trade_count': stats.tradeCount,
        'change_percent': stats.changePercent.toStringAsFixed(2),
        'volatility_percent': stats.volatilityPercent.toStringAsFixed(2),
        'large_trade_count': stats.largeTradeCount,
        'large_trade_ratio': (stats.largeTradeRatio * 100).toStringAsFixed(1),
        'trades_per_minute': stats.tradesPerMinute.toStringAsFixed(1),
        'is_active': stats.isActive,
        'current_price': stats.currentPrice,
        'price_range': '${stats.lowPrice} ~ ${stats.highPrice}',
        'first_trade': stats.firstTradeTime.toIso8601String(),
        'last_trade': stats.lastTradeTime.toIso8601String(),
      };
    }
    
    return marketStats;
  }

  /// 섹터별 상세 통계
  Map<String, dynamic> getSectorStats() {
    final sectorStats = <String, Map<String, dynamic>>{};
    
    for (final entry in _sectorStats.entries) {
      final stats = entry.value;
      sectorStats[entry.key] = {
        'total_volume': stats.totalVolume,
        'total_amount': (stats.totalAmount / 100000000).toStringAsFixed(1), // 억원
        'market_count': stats.marketCount,
        'active_markets': stats.activeMarkets.toList(),
        'first_update': stats.firstUpdateTime.toIso8601String(),
        'last_update': stats.lastUpdateTime.toIso8601String(),
      };
    }
    
    return sectorStats;
  }

  /// 성능 메트릭
  Map<String, dynamic> getPerformanceMetrics() {
    final now = DateTime.now();
    final uptimeSeconds = now.difference(_startTime).inSeconds;
    
    return {
      'uptime_seconds': uptimeSeconds,
      'throughput': {
        'trades_per_second': uptimeSeconds > 0 ? _totalTradesProcessed / uptimeSeconds : 0.0,
        'snapshots_per_hour': uptimeSeconds > 0 ? (_totalSnapshotsGenerated * 3600) / uptimeSeconds : 0.0,
      },
      'efficiency': {
        'avg_trade_processing_us': _totalTradesProcessed > 0 
          ? _totalProcessingTime.inMicroseconds / _totalTradesProcessed 
          : 0.0,
        'memory_per_market_bytes': _marketStats.isNotEmpty 
          ? getMemoryUsageEstimate() / _marketStats.length 
          : 0,
        'active_market_ratio': _marketStats.isNotEmpty
          ? _marketStats.values.where((s) => s.isActive).length / _marketStats.length
          : 0.0,
      },
      'quality': {
        'data_completeness': _calculateDataCompleteness(),
        'market_coverage': _calculateMarketCoverage(),
        'temporal_consistency': _calculateTemporalConsistency(),
      },
    };
  }

  /// 데이터 완전성 계산
  double _calculateDataCompleteness() {
    if (_marketStats.isEmpty) return 0.0;
    
    int completeMarkets = 0;
    for (final stats in _marketStats.values) {
      // 완전한 데이터 기준: 거래 5회 이상 + 가격 변화 있음
      if (stats.tradeCount >= 5 && stats.currentPrice != stats.basePrice) {
        completeMarkets++;
      }
    }
    
    return completeMarkets / _marketStats.length;
  }

  /// 시장 커버리지 계산
  double _calculateMarketCoverage() {
    // 활성 시장의 비율
    if (_marketStats.isEmpty) return 0.0;
    
    final activeMarkets = _marketStats.values.where((s) => s.isActive).length;
    return activeMarkets / _marketStats.length;
  }

  /// 시간적 일관성 계산
  double _calculateTemporalConsistency() {
    // 최근 데이터의 신선도
    if (_marketStats.isEmpty) return 0.0;
    
    final now = DateTime.now();
    int freshMarkets = 0;
    
    for (final stats in _marketStats.values) {
      final age = now.difference(stats.lastTradeTime).inMinutes;
      if (age <= 5) { // 5분 이내 데이터
        freshMarkets++;
      }
    }
    
    return freshMarkets / _marketStats.length;
  }

  /// 상위 시장 순위 (다양한 기준)
  Map<String, List<String>> getTopMarkets() {
    final allStats = _marketStats.values.where((s) => s.isActive).toList();
    
    return {
      'by_volume': (allStats.toList()
        ..sort((a, b) => b.totalVolume.compareTo(a.totalVolume)))
        .take(10)
        .map((s) => s.market)
        .toList(),
      
      'by_amount': (allStats.toList()
        ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount)))
        .take(10)
        .map((s) => s.market)
        .toList(),
      
      'by_change': (allStats.toList()
        ..sort((a, b) => b.changePercent.abs().compareTo(a.changePercent.abs())))
        .take(10)
        .map((s) => s.market)
        .toList(),
      
      'by_trades': (allStats.toList()
        ..sort((a, b) => b.tradeCount.compareTo(a.tradeCount)))
        .take(10)
        .map((s) => s.market)
        .toList(),
      
      'by_large_trades': (allStats.toList()
        ..sort((a, b) => b.largeTradeCount.compareTo(a.largeTradeCount)))
        .take(10)
        .map((s) => s.market)
        .toList(),
    };
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // 🔧 유틸리티 메서드들
  // ══════════════════════════════════════════════════════════════════════════════

  /// 특정 시장의 상세 정보 조회
  RealtimeMarketStats? getMarketDetails(String market) {
    return _marketStats[market];
  }

  /// 특정 섹터의 상세 정보 조회
  RealtimeSectorStats? getSectorDetails(String sector) {
    return _sectorStats[sector];
  }

  /// 최근 고액거래 목록 조회
  List<String> getRecentLargeTrades({int limit = 20}) {
    return _recentLargeTrades.items.reversed.take(limit).toList();
  }

  /// 최근 활성 시장 목록 조회
  List<String> getRecentActiveMarkets({int limit = 20}) {
    return _marketActivity.validData.reversed.toSet().take(limit).toList();
  }

  /// 시장 활성도 히트맵 데이터
  Map<String, int> getMarketActivityHeatmap() {
    final heatmap = <String, int>{};
    
    for (final market in _marketActivity.validData) {
      heatmap[market] = (heatmap[market] ?? 0) + 1;
    }
    
    return heatmap;
  }

  /// 데이터 상태 검증
  Map<String, dynamic> validateDataIntegrity() {
    final issues = <String>[];
    final warnings = <String>[];
    
    // 기본 데이터 존재 여부
    if (_marketStats.isEmpty) {
      issues.add('No market data available');
    }
    
    // 시간 일관성 체크
    final now = DateTime.now();
    for (final entry in _marketStats.entries) {
      final stats = entry.value;
      
      // 미래 시간 체크
      if (stats.lastTradeTime.isAfter(now)) {
        issues.add('Future timestamp detected in ${entry.key}');
      }
      
      // 첫 거래보다 마지막 거래가 이전인 경우
      if (stats.lastTradeTime.isBefore(stats.firstTradeTime)) {
        issues.add('Invalid time sequence in ${entry.key}');
      }
      
      // 너무 오래된 데이터
      if (now.difference(stats.lastTradeTime).inHours > 1) {
        warnings.add('Stale data in ${entry.key} (${now.difference(stats.lastTradeTime).inHours}h old)');
      }
      
      // 비정상적인 가격 데이터
      if (stats.currentPrice <= 0 || stats.basePrice <= 0) {
        issues.add('Invalid price data in ${entry.key}');
      }
      
      // 비정상적인 볼륨 데이터
      if (stats.totalVolume < 0) {
        issues.add('Negative volume in ${entry.key}');
      }
    }
    
    return {
      'is_valid': issues.isEmpty,
      'issues': issues,
      'warnings': warnings,
      'markets_checked': _marketStats.length,
      'sectors_checked': _sectorStats.length,
      'check_timestamp': now.toIso8601String(),
    };
  }

  /// 통계 리셋
  void resetStats() {
    _totalTradesProcessed = 0;
    _totalSnapshotsGenerated = 0;
    _totalProcessingTime = Duration.zero;
    _snapshotCounter = 0;
    
    if (BottomLineConstants.enableLogging) {
      log.d('📊 Aggregator stats reset');
    }
  }

  /// 전체 데이터 리셋 (시작 시점 재설정)
  void resetAllData() {
    _marketStats.clear();
    _sectorStats.clear();
    _recentTrades.clear();
    _recentLargeTrades.clear();
    _marketActivity.clear();
    _snapshotHistory.clear();
    
    _lastSnapshot = null;
    _baselineSnapshot = null;
    _lastSnapshotTime = null;
    _lastCleanupTime = null;
    
    resetStats();
    
    if (BottomLineConstants.enableLogging) {
      log.d('🔄 Aggregator completely reset');
    }
  }

  /// 디버그 정보 생성
  Map<String, dynamic> generateDebugReport() {
    return {
      'aggregator_info': {
        'start_time': _startTime.toIso8601String(),
        'uptime': DateTime.now().difference(_startTime).toString(),
        'version': '1.0.0',
      },
      'data_summary': getStats(),
      'performance': getPerformanceMetrics(),
      'top_markets': getTopMarkets(),
      'integrity_check': validateDataIntegrity(),
      'memory_breakdown': {
        'market_stats': '${_marketStats.length} × 300B = ${_marketStats.length * 300}B',
        'sector_stats': '${_sectorStats.length} × 200B = ${_sectorStats.length * 200}B',
        'recent_trades': '${_recentTrades.estimatedMemoryBytes}B',
        'large_trades': '${_recentLargeTrades.estimatedMemoryBytes}B',
        'market_activity': '${_marketActivity.estimatedMemoryBytes}B',
        'snapshots': '${_snapshotHistory.length} × 10KB = ${_snapshotHistory.length * 10000}B',
        'total_estimated': '${getMemoryUsageEstimate()}B',
      },
      'buffer_states': {
        'recent_trades': _recentTrades.stats,
        'large_trades': _recentLargeTrades.stats,
        'market_activity': _marketActivity.stats,
      },
    };
  }

  /// 리소스 정리
  void dispose() {
    resetAllData();
    
    if (BottomLineConstants.enableLogging) {
      log.d('🛑 BottomLine Aggregator disposed');
    }
  }
}