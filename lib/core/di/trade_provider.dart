import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/hive_service.dart';          // 🎯 NEW
import '../network/api_client.dart';
import '../utils/logger.dart';
import 'app_providers.dart' show signalBusProvider;
import 'websocket_provider.dart' show wsClientProvider; // 🆕 WebSocket import
import '../../data/datasources/trade_cache_ds.dart';
import '../../data/datasources/trade_remote_ds.dart';
import '../../data/repositories/trade_repository_impl.dart';
import '../../domain/entities/trade.dart';
import '../../domain/usecases/trade_usecase.dart';

/// 🆕 마켓 정보 클래스
class MarketInfo {
  final String market;      // KRW-BTC
  final String koreanName;  // 비트코인
  final String englishName; // Bitcoin

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

/// 0) REST API client
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(
      apiKey: AppConfig.apiKey,
      apiSecret: AppConfig.apiSecret,
    ));

/// 🎯 HiveService Provider (main.dart에서 override)
final hiveServiceProvider = Provider<HiveService>((ref) {
  throw UnimplementedError('HiveService must be provided via main.dart override');
});

/// 🆕 마켓 정보 Provider (1시간 캐시 + market_warning 필터링)
final marketInfoProvider = FutureProvider<Map<String, MarketInfo>>((ref) async {
  final client = ref.read(apiClientProvider);
  
  try {
    final result = await client.request<List<dynamic>>(
      method: 'GET',
      path: '${AppConfig.upbitRestBase}/market/all',
      cacheDur: const Duration(hours: 1), // 1시간 캐시
    );
    
    return result.when(
      ok: (markets) {
        final Map<String, MarketInfo> marketMap = {};
        int filteredCount = 0;
        
        for (final market in markets) {
          if (market is Map<String, dynamic>) {
            // 🔒 market_warning 필터링 (업비트 백서 준수)
            final warning = market['market_warning'] as String?;
            if (warning == 'CAUTION') {
              filteredCount++;
              if (AppConfig.enableTradeLog) {
                log.d('Filtered CAUTION market: ${market['market']}');
              }
              continue; // CAUTION 종목은 건너뛰기
            }
            
            final info = MarketInfo.fromJson(market);
            marketMap[info.market] = info;
          }
        }
        
        if (AppConfig.enableTradeLog) {
          log.i('마켓 정보 로드됨: ${marketMap.length}개 (CAUTION 필터링: $filteredCount개)');
        }
        return marketMap;
      },
      err: (error) {
        log.w('마켓 정보 로드 실패: $error');
        return <String, MarketInfo>{};
      },
    );
  } catch (e) {
    log.e('마켓 정보 로드 중 오류: $e');
    return <String, MarketInfo>{};
  }
});

/// 1) KRW market list (top 199 by volume + essentials) + market_warning 필터링
final marketsProvider = FutureProvider<List<String>>((ref) async {
  final client = ref.read(apiClientProvider);

  // fetch all markets (cache 5 minutes)
  final marketResult = await client.request<List<dynamic>>(
    method: 'GET',
    path: '${AppConfig.upbitRestBase}/market/all',
    cacheDur: const Duration(minutes: 5),
  );
  final allMarkets =
      marketResult.when(ok: (v) => v, err: (_) => <dynamic>[]);

  // 🔒 filter KRW markets + market_warning 필터링 (업비트 백서 준수)
  final krwMarkets = <String>[];
  int cautionCount = 0;
  
  for (final market in allMarkets.whereType<Map<String, dynamic>>()) {
    final marketCode = market['market'] as String?;
    if (marketCode != null && marketCode.startsWith('KRW-')) {
      // CAUTION 종목은 WebSocket 구독에서 제외
      final warning = market['market_warning'] as String?;
      if (warning == 'CAUTION') {
        cautionCount++;
        continue;
      }
      krwMarkets.add(marketCode);
    }
  }
  
  if (AppConfig.enableTradeLog && cautionCount > 0) {
    log.i('CAUTION 종목 $cautionCount개 제외됨 (WebSocket 구독 안전성)');
  }

  // pick top by 24h volume (or acc_trade_price when outside 9–10am)
  final now = DateTime.now();
  final isEarly = now.hour >= 9 && now.hour < 10;
  final key = isEarly ? 'acc_trade_price_24h' : 'acc_trade_price';

  // real-time ticker lookup (no cache)
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

  // ─── WS 구독 종목 슬라이싱 로직 (essentials 우선 + 중복 제거 후 상위 199개) ───
  const essentials = ['KRW-BTC', 'KRW-ETH', 'KRW-XRP', 'KRW-SOL'];
  final sortedMarkets = tickers.map((e) => e['market'] as String).toList();
  final combined = [
    ...essentials.where((market) => krwMarkets.contains(market)), // 🔒 essentials도 CAUTION 체크
    ...sortedMarkets.where((m) => !essentials.contains(m)),
  ];
  return combined.take(199).toList();
});

final cacheDSProvider = Provider<TradeCacheDataSource>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  return TradeCacheDataSource(hive.tradeBox);
});

final remoteDSProvider = Provider((ref) => TradeRemoteDataSource(
      ref.read(wsClientProvider), // 🔄 websocket_provider에서 import
      ref.read(signalBusProvider),
      useTestData: AppConfig.useTestDataInDev,
    ));

final repoProvider = Provider((ref) => TradeRepositoryImpl(
      ref.read(remoteDSProvider),
      ref.read(cacheDSProvider),
    ));

final usecaseProvider = Provider((ref) => TradeUsecase(ref.read(repoProvider)));

/// 3) Filter state
final tradeFilterIndexProvider = StateProvider<int>((_) => 0);
final tradeFilterThresholdProvider = StateProvider<double>((ref) =>
    AppConfig.tradeFilters.firstWhere(
      (f) => f >= 20000000,
      orElse: () => AppConfig.tradeFilters.last,
    ));

/// 4) Filtered trades stream
final tradeListProvider = StreamProvider.autoDispose<List<Trade>>((ref) async* {
  // Prevent immediate dispose on loss of listeners
  ref.keepAlive();

  // 현재 threshold 값과 markets를 읽어 스트림 구독
  final threshold = ref.watch(tradeFilterThresholdProvider);
  final markets = await ref.watch(marketsProvider.future);
  final repository = ref.read(repoProvider);

  // threshold 변경 시 Repository에도 업데이트
  ref.listen<double>(tradeFilterThresholdProvider, (prev, next) {
    if (prev != null && prev != next) {
      if (AppConfig.enableTradeLog) {
        log.i(
          'Threshold changed: ${prev.toStringAsFixed(0)} → ${next.toStringAsFixed(0)}',
        );
      }
      repository.updateThreshold(next);
    }
  });

  // 실제 필터된 거래 스트림 방출
  yield* repository.watchFilteredTrades(threshold, markets);
});

/// 5) Aggregated trades stream
final aggregatedTradeProvider = StreamProvider.autoDispose<Trade>((ref) {
  // Prevent dispose on background
  ref.keepAlive();
  final repository = ref.read(repoProvider);
  return repository.watchAggregatedTrades();
});

/// 6) Helper to change threshold & index
final tradeThresholdController = Provider((ref) => TradeThresholdController(ref));

class TradeThresholdController {
  final Ref ref;
  TradeThresholdController(this.ref);

  void updateThreshold(double threshold, int index) {
    final options =
        AppConfig.tradeFilters.where((f) => f >= 20000000).toList();
    if (index < 0 || index >= options.length) {
      if (AppConfig.enableTradeLog) log.w('Invalid threshold index: $index');
      return;
    }
    ref.read(tradeFilterThresholdProvider.notifier).state = threshold;
    ref.read(tradeFilterIndexProvider.notifier).state = index;
    AppConfig.updateFilters(options);
    if (AppConfig.enableTradeLog) {
      log.i(
        'Threshold updated: ${threshold.toStringAsFixed(0)} (index: $index)',
      );
    }
  }

  double get currentThreshold => ref.read(tradeFilterThresholdProvider);
  int get currentIndex => ref.read(tradeFilterIndexProvider);
  List<double> get availableThresholds =>
      AppConfig.tradeFilters.where((f) => f >= 20000000).toList();
}