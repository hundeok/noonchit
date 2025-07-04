import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart'; // 🔥 추가: share() 메서드용

import '../config/app_config.dart';
import '../services/hive_service.dart';
import '../network/api_client.dart';
import '../utils/logger.dart';
import 'app_providers.dart' show signalBusProvider;
import 'websocket_provider.dart' show wsClientProvider;
import '../../data/datasources/trade_cache_ds.dart';
import '../../data/datasources/trade_remote_ds.dart';
import '../../data/repositories/trade_repository_impl.dart';
import '../../domain/entities/trade.dart';
import '../../domain/usecases/trade_usecase.dart';
import '../../data/processors/trade_aggregator.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 핵심 타입 정의
// ══════════════════════════════════════════════════════════════════════════════

/// 거래 필터 Enum
enum TradeFilter {
  min20M(20000000, '2천만원'),
  min50M(50000000, '5천만원'),
  min100M(100000000, '1억원'),
  min200M(200000000, '2억원'),
  min300M(300000000, '3억원'),
  min400M(400000000, '4억원'),
  min500M(500000000, '5억원'),
  min1B(1000000000, '10억원');
  
  const TradeFilter(this.value, this.displayName);
  final double value;
  final String displayName;
  
  static TradeFilter fromValue(double value) {
    return values.firstWhere(
      (filter) => filter.value == value,
      orElse: () => TradeFilter.min20M,
    );
  }
  
  static List<TradeFilter> get available => values;
  static List<double> get availableValues => values.map((f) => f.value).toList();
}

/// 거래 모드 Enum
enum TradeMode {
  accumulated('누적'),
  range('구간');
  
  const TradeMode(this.displayName);
  final String displayName;
  
  bool get isRange => this == TradeMode.range;
  bool get isAccumulated => this == TradeMode.accumulated;
}

/// 거래 설정
class TradeConfig {
  static const int maxTradesPerFilter = 200;
  static const int maxCacheSize = 250;
  static const Duration batchInterval = Duration(milliseconds: 100);
  
  static List<TradeFilter> get supportedFilters => TradeFilter.available;
  static List<double> get supportedValues => TradeFilter.availableValues;
}

/// 마켓 정보 클래스
class MarketInfo {
  final String market;
  final String koreanName;
  final String englishName;

  const MarketInfo({
    required this.market,
    required this.koreanName,
    required this.englishName,
  });

  factory MarketInfo.fromJson(Map<String, dynamic> json) {
    return MarketInfo(
      market: json['market'] ?? '',
      koreanName: json['korean_name'] ?? '',
      englishName: json['english_name'] ?? '',
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🔧 Extension
// ══════════════════════════════════════════════════════════════════════════════

extension TradeFilterList on List<TradeFilter> {
  List<double> get values => map((f) => f.value).toList();
  List<String> get displayNames => map((f) => f.displayName).toList();
  
  TradeFilter? findByValue(double value) {
    try {
      return firstWhere((f) => f.value == value);
    } catch (e) {
      return null;
    }
  }
}

extension SafeTradeMap on Map<double, List<Trade>> {
  void addTradeToFilter(double filterValue, Trade trade) {
    final list = this[filterValue] ?? <Trade>[];
    list.add(trade);
    
    if (list.length > TradeConfig.maxTradesPerFilter) {
      list.removeAt(0);
    }
    
    this[filterValue] = list;
  }
  
  List<Trade> getTradesForFilter(double filterValue) {
    return this[filterValue] ?? <Trade>[];
  }
  
  void clearAllFilters() {
    forEach((key, value) => value.clear());
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🏗️ Infrastructure Layer
// ══════════════════════════════════════════════════════════════════════════════

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(
      apiKey: AppConfig.apiKey,
      apiSecret: AppConfig.apiSecret,
    ));

final hiveServiceProvider = Provider<HiveService>((ref) {
  throw UnimplementedError('HiveService must be provided via main.dart override');
});

final cacheDSProvider = Provider<TradeCacheDataSource>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  return TradeCacheDataSource(hive.tradeBox);
});

final remoteDSProvider = Provider((ref) => TradeRemoteDataSource(
      ref.read(wsClientProvider),
      ref.read(signalBusProvider),
      useTestData: AppConfig.useTestDataInDev,
    ));

final repoProvider = Provider((ref) => TradeRepositoryImpl(
      ref.read(remoteDSProvider),
      ref.read(cacheDSProvider),
    ));

final usecaseProvider = Provider((ref) => TradeUsecase(ref.read(repoProvider)));

// ══════════════════════════════════════════════════════════════════════════════
// 📊 Market Data Layer
// ══════════════════════════════════════════════════════════════════════════════

final marketInfoProvider = FutureProvider<Map<String, MarketInfo>>((ref) async {
  final client = ref.read(apiClientProvider);
  
  try {
    final result = await client.request<List<dynamic>>(
      method: 'GET',
      path: '${AppConfig.upbitRestBase}/market/all',
      cacheDur: const Duration(hours: 1),
    );
    
    return result.when(
      ok: (markets) {
        final Map<String, MarketInfo> marketMap = {};
        int filteredCount = 0;
        
        for (final market in markets) {
          if (market is Map<String, dynamic>) {
            final warning = market['market_warning'] as String?;
            if (warning == 'CAUTION') {
              filteredCount++;
              continue;
            }
            
            final info = MarketInfo.fromJson(market);
            marketMap[info.market] = info;
          }
        }
        
        // Markets loaded: ${marketMap.length} (filtered: $filteredCount)
        return marketMap;
      },
      err: (error) {
        log.e('Market info failed: $error');
        return <String, MarketInfo>{};
      },
    );
  } catch (e, stackTrace) {
    log.e('Market info error: $e', e, stackTrace);
    return <String, MarketInfo>{};
  }
});

final marketsProvider = FutureProvider<List<String>>((ref) async {
  final client = ref.read(apiClientProvider);
  final marketInfoMap = await ref.watch(marketInfoProvider.future);
  
  final krwMarkets = marketInfoMap.keys
      .where((market) => market.startsWith('KRW-'))
      .toList();

  final now = DateTime.now();
  final isEarly = now.hour >= 9 && now.hour < 10;
  final key = isEarly ? 'acc_trade_price_24h' : 'acc_trade_price';

  final tickerResult = await client.request<List<dynamic>>(
    method: 'GET',
    path: '${AppConfig.upbitRestBase}/ticker',
    query: {'markets': krwMarkets.join(',')},
    cacheDur: null,
  );
  
  final tickers = tickerResult
      .when(ok: (v) => v, err: (_) => <dynamic>[])  
      .whereType<Map<String, dynamic>>()
      .toList()
    ..sort((a, b) =>
        ((b[key] as num?) ?? 0).compareTo((a[key] as num?) ?? 0));

  const essentials = ['KRW-BTC', 'KRW-ETH', 'KRW-XRP', 'KRW-SOL'];
  final sortedMarkets = tickers.map((e) => e['market'] as String).toList();
  final combined = [
    ...essentials.where((market) => krwMarkets.contains(market)),
    ...sortedMarkets.where((m) => !essentials.contains(m)),
  ];
  
  return combined.take(199).toList();
});

// ══════════════════════════════════════════════════════════════════════════════
// ⚙️ Settings Layer
// ══════════════════════════════════════════════════════════════════════════════

final tradeFilterIndexProvider = StateProvider<int>((_) => 0);

final tradeFilterThresholdProvider = StateProvider<TradeFilter>((ref) =>
    TradeFilter.available.firstWhere(
      (f) => f.value >= 20000000,
      orElse: () => TradeFilter.min20M,
    ));

final tradeModeProvider = StateProvider<TradeMode>((ref) => TradeMode.accumulated);

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 State Management Layer
// ══════════════════════════════════════════════════════════════════════════════

final tradeFilterCacheProvider = StateNotifierProvider<TradeFilterNotifier, Map<TradeFilter, List<Trade>>>((ref) {
  return TradeFilterNotifier();
});

class TradeFilterNotifier extends StateNotifier<Map<TradeFilter, List<Trade>>> {
  TradeFilterNotifier() : super({}) {
    final initialState = <TradeFilter, List<Trade>>{};
    for (final filter in TradeConfig.supportedFilters) {
      initialState[filter] = <Trade>[];
    }
    state = initialState;
  }

  void addTrade(Trade trade) {
    final total = trade.total;
    final newState = Map<TradeFilter, List<Trade>>.from(state);

    for (final filter in TradeConfig.supportedFilters) {
      if (total >= filter.value) {
        final list = List<Trade>.from(newState[filter] ?? <Trade>[]);
        list.add(trade);

        if (list.length > TradeConfig.maxTradesPerFilter) {
          list.removeAt(0);
        }

        newState[filter] = list;
      } else {
        break;
      }
    }

    state = newState;
  }

  void clearAll() {
    final newState = <TradeFilter, List<Trade>>{};
    for (final filter in TradeConfig.supportedFilters) {
      newState[filter] = <Trade>[];
    }
    state = newState;
  }
}

final tradeSeenIdsProvider = StateNotifierProvider<TradeSeenIdsNotifier, Set<String>>((ref) {
  return TradeSeenIdsNotifier();
});

class TradeSeenIdsNotifier extends StateNotifier<Set<String>> {
  final LinkedHashSet<String> _orderedIds = LinkedHashSet<String>();

  TradeSeenIdsNotifier() : super(<String>{});

  bool addId(String id) {
    if (_orderedIds.contains(id)) return false;

    _orderedIds.add(id);

    if (_orderedIds.length > TradeConfig.maxCacheSize) {
      final removeCount = (_orderedIds.length / 4).ceil();
      final oldestIds = _orderedIds.take(removeCount).toList();
      
      for (final oldId in oldestIds) {
        _orderedIds.remove(oldId);
      }
    }

    state = Set<String>.from(_orderedIds);
    return true;
  }

  void clear() {
    _orderedIds.clear();
    state = <String>{};
  }
}

final tradeAggregatorProvider = Provider<TradeAggregator>((ref) {
  return TradeAggregator();
});

// ══════════════════════════════════════════════════════════════════════════════
// 🔄 Processing Layer
// ══════════════════════════════════════════════════════════════════════════════

final tradeProcessingTimerProvider = StreamProvider((ref) {
  return Stream.periodic(AppConfig.globalResetInterval, (i) => i);
});

final rawTradeProcessingProvider = StreamProvider<Trade>((ref) async* {
  final markets = await ref.read(marketsProvider.future);
  final repo = ref.read(repoProvider);
  final aggregator = ref.read(tradeAggregatorProvider);
  final seenIdsNotifier = ref.read(tradeSeenIdsProvider.notifier);
  final filterCacheNotifier = ref.read(tradeFilterCacheProvider.notifier);

  if (AppConfig.isDebugMode) {
    // log.d('Trade processing started (${markets.length} markets)');
  }

  ref.listen(tradeProcessingTimerProvider, (previous, next) {
    next.whenData((value) {
      aggregator.flushTrades(onTradeProcessed: (processedTrade) {
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
        filterCacheNotifier.addTrade(trade);
      });
    });
  });

  yield* repo.watchTrades(markets).where((trade) {
    final key = '${trade.market}/${trade.sequentialId}';
    if (!seenIdsNotifier.addId(key)) return false;

    aggregator.processTrade(
      {
        'market': trade.market,
        'price': trade.price,
        'volume': trade.volume,
        'timestamp': trade.timestampMs,
        'isBuy': trade.isBuy,
        'sequential_id': trade.sequentialId,
      },
      onTradeProcessed: (processedTrade) {
        final aggregatedTrade = Trade(
          market: processedTrade['market'] as String,
          price: processedTrade['price'] as double,
          volume: processedTrade['volume'] as double,
          side: (processedTrade['isBuy'] as bool) ? 'BID' : 'ASK',
          changePrice: 0.0,
          changeState: 'EVEN',
          timestampMs: processedTrade['timestamp'] as int,
          sequentialId: processedTrade['sequential_id'] as String,
        );
        filterCacheNotifier.addTrade(aggregatedTrade);
      },
    );

    return true;
  }).share(); // 🔥 추가: 브로드캐스트 스트림으로 변환
});

// ══════════════════════════════════════════════════════════════════════════════
// 🔵 AsyncNotifier 기반 Public API Layer
// ══════════════════════════════════════════════════════════════════════════════

class TradeListNotifier extends AsyncNotifier<List<Trade>> {
  @override
  FutureOr<List<Trade>> build() async {
    final initialTrades = _calculateTrades();
    _setupStateListeners();
    return initialTrades;
  }

  void _setupStateListeners() {
    ref.listen(rawTradeProcessingProvider, (previous, next) {
      next.when(
        data: (trade) => {},
        loading: () => {},
        error: (error, stack) => log.e('Trade processing error: $error'),
      );
    });

    ref.listen(tradeFilterCacheProvider, (previous, next) {
      _updateTrades();
    });

    ref.listen<TradeFilter>(tradeFilterThresholdProvider, (prev, next) {
      if (prev != null && prev != next) {
        // Filter changed: ${prev.displayName} → ${next.displayName}
        _updateTrades();
      }
    });

    ref.listen<TradeMode>(tradeModeProvider, (prev, next) {
      if (prev != null && prev != next) {
        // Mode changed: ${prev.displayName} → ${next.displayName}
        _updateTrades();
      }
    });
  }

  void _updateTrades() {
    final newTrades = _calculateTrades();
    // Trades updated: ${newTrades.length}
    state = AsyncValue.data(newTrades);
  }

  List<Trade> _calculateTrades() {
    final filterThreshold = ref.read(tradeFilterThresholdProvider);
    final tradeMode = ref.read(tradeModeProvider);
    final usecase = ref.read(usecaseProvider);
    final filterCache = ref.read(tradeFilterCacheProvider);
    
    final legacyFilterCache = <double, List<Trade>>{};
    filterCache.forEach((filter, trades) {
      legacyFilterCache[filter.value] = trades;
    });
    
    return usecase.calculateFilteredTrades(
      legacyFilterCache,
      filterThreshold.value,
      tradeMode.isRange,
    );
  }
}

final tradeListProvider = AsyncNotifierProvider<TradeListNotifier, List<Trade>>(() {
  return TradeListNotifier();
});

final aggregatedTradeProvider = StreamProvider<Trade>((ref) {
  ref.keepAlive();
  return ref.watch(rawTradeProcessingProvider.stream);
});

// ══════════════════════════════════════════════════════════════════════════════
// 🎛️ Controller Helper
// ══════════════════════════════════════════════════════════════════════════════

final tradeThresholdController = Provider((ref) => TradeThresholdController(ref));

class TradeThresholdController {
  final Ref ref;
  TradeThresholdController(this.ref);

  void updateThreshold(TradeFilter filter, int index) {
    final options = TradeConfig.supportedFilters;
    if (index < 0 || index >= options.length) {
      // Invalid threshold index: $index
      return;
    }
    
    ref.read(tradeFilterThresholdProvider.notifier).state = filter;
    ref.read(tradeFilterIndexProvider.notifier).state = index;
  }

  void updateMode(TradeMode mode) {
    ref.read(tradeModeProvider.notifier).state = mode;
  }

  void updateThresholdByValue(double thresholdValue, int index) {
    final filter = TradeFilter.fromValue(thresholdValue);
    updateThreshold(filter, index);
  }

  void updateModeByBool(bool isRange) {
    final mode = isRange ? TradeMode.range : TradeMode.accumulated;
    updateMode(mode);
  }

  TradeFilter get currentFilter => ref.read(tradeFilterThresholdProvider);
  TradeMode get currentMode => ref.read(tradeModeProvider);
  int get currentIndex => ref.read(tradeFilterIndexProvider);
  List<TradeFilter> get availableFilters => TradeConfig.supportedFilters;
  
  double get currentThreshold => currentFilter.value;
  bool get isRangeMode => currentMode.isRange;
  List<double> get availableThresholds => TradeConfig.supportedValues;
}