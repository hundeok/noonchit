import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../config/app_config.dart';
import '../services/hive_service.dart';
import '../network/api_client.dart';
import '../utils/logger.dart';
import '../common/time_frame_types.dart'; // 🔥 공통 타입 시스템 사용
import 'app_providers.dart' show signalBusProvider;
import 'websocket_provider.dart' show wsClientProvider;
import '../../data/datasources/trade_cache_ds.dart';
import '../../data/datasources/trade_remote_ds.dart';
import '../../data/repositories/trade_repository_impl.dart';
import '../../domain/entities/trade.dart';
import '../../domain/usecases/trade_usecase.dart';
import '../../data/processors/trade_aggregator.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 🔥 타입 정의 제거 - 공통 time_frame_types.dart 사용
// ══════════════════════════════════════════════════════════════════════════════

// TradeFilter enum → time_frame_types.dart로 이관 ✅
// TradeMode enum → time_frame_types.dart로 이관 ✅  
// TradeConfig class → time_frame_types.dart로 이관 ✅
// MarketInfo class → time_frame_types.dart로 이관 ✅

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
        
        for (final market in markets) {
          if (market is Map<String, dynamic>) {
            final warning = market['market_warning'] as String?;
            if (warning == 'CAUTION') {
              continue;
            }
            
            final info = MarketInfo.fromJson(market);
            marketMap[info.market] = info;
          }
        }
        
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

final tradeFilterThresholdProvider = StateProvider<TradeFilter>((ref) => TradeFilter.min20M);

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
// 🔄 Master Stream Layer (Single WS Connection for All Modules)
// ══════════════════════════════════════════════════════════════════════════════

/// 🎯 Master Trade Stream - 모든 모듈이 공유하는 단일 데이터 소스
final masterTradeStreamProvider = FutureProvider.autoDispose<Stream<Trade>>((ref) async {
  final markets = await ref.watch(marketsProvider.future); // watch로 새 코인 자동 감지
  final repo = ref.read(repoProvider);
  
  // 연결 유지 (백그라운드에서도 WS 끊어지지 않음)
  ref.keepAlive();
  
  if (AppConfig.isDebugMode) {
    // log.d('Master trade stream started (${markets.length} markets)');
  }
  
  // 단일 WS 연결 + 브로드캐스트로 모든 모듈에서 재사용
  return repo.watchTrades(markets)
    .distinct((prev, next) => 
      prev.sequentialId == next.sequentialId && 
      prev.market == next.market)
    .shareReplay(maxSize: 1); // 재연결 방지
});

// ══════════════════════════════════════════════════════════════════════════════
// 🔄 Processing Layer (Master Stream 기반)
// ══════════════════════════════════════════════════════════════════════════════

final tradeProcessingTimerProvider = StreamProvider((ref) {
  return Stream.periodic(AppConfig.globalResetInterval, (i) => i);
});

final rawTradeProcessingProvider = StreamProvider<Trade>((ref) async* {
  final masterStream = await ref.read(masterTradeStreamProvider.future);
  final aggregator = ref.read(tradeAggregatorProvider);
  final seenIdsNotifier = ref.read(tradeSeenIdsProvider.notifier);
  final filterCacheNotifier = ref.read(tradeFilterCacheProvider.notifier);

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

  yield* masterStream.where((trade) {
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
  });
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
        _updateTrades();
      }
    });

    ref.listen<TradeMode>(tradeModeProvider, (prev, next) {
      if (prev != null && prev != next) {
        _updateTrades();
      }
    });
  }

  void _updateTrades() {
    final newTrades = _calculateTrades();
    state = AsyncValue.data(newTrades);
  }

  List<Trade> _calculateTrades() {
    final filterThreshold = ref.read(tradeFilterThresholdProvider);
    final tradeMode = ref.read(tradeModeProvider);
    final usecase = ref.read(usecaseProvider);
    final filterCache = ref.read(tradeFilterCacheProvider);
    
    return usecase.calculateFilteredTrades(
      filterCache,
      filterThreshold,
      tradeMode.isRange,
    );
  }
}

final tradeListProvider = AsyncNotifierProvider<TradeListNotifier, List<Trade>>(() {
  return TradeListNotifier();
});

// ⭐ 불필요한 aggregatedTradeProvider 제거!
// 기존: final aggregatedTradeProvider = StreamProvider<Trade>((ref) { ... });
// 변경: rawTradeProcessingProvider를 직접 사용하세요!

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
      return;
    }
    
    ref.read(tradeFilterThresholdProvider.notifier).state = filter;
    ref.read(tradeFilterIndexProvider.notifier).state = index;
  }

  void updateMode(TradeMode mode) {
    ref.read(tradeModeProvider.notifier).state = mode;
  }

  TradeFilter get currentFilter => ref.read(tradeFilterThresholdProvider);
  TradeMode get currentMode => ref.read(tradeModeProvider);
  int get currentIndex => ref.read(tradeFilterIndexProvider);
  List<TradeFilter> get availableFilters => TradeConfig.supportedFilters;
  
  bool get isRangeMode => currentMode.isRange;
}