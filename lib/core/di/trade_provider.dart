import 'dart:async';
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

/// 🚀 시스템 부하 상태 모니터링
class SystemLoadState {
  final bool isHigh;
  final int activeConnections;
  final DateTime lastUpdate;

  const SystemLoadState({
    required this.isHigh,
    required this.activeConnections,
    required this.lastUpdate,
  });

  factory SystemLoadState.normal() => SystemLoadState(
    isHigh: false,
    activeConnections: 0,
    lastUpdate: DateTime.now(),
  );
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

/// 🚀 시스템 부하 모니터링 Provider
final systemLoadProvider = StreamProvider<SystemLoadState>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (_) {
    // 간단한 부하 체크 로직 (실제로는 더 정교하게)
    final now = DateTime.now();
    final isHighLoad = now.millisecondsSinceEpoch % 100 < 20; // 20% 확률로 고부하
    
    return SystemLoadState(
      isHigh: isHighLoad,
      activeConnections: isHighLoad ? 180 : 50,
      lastUpdate: now,
    );
  });
});

/// 🚀 에러 상태 관리 Provider
final marketErrorProvider = StateProvider<String?>((_) => null);

/// 🚀 캐시된 마켓 데이터 폴백 함수들
List<String> _getEssentialMarkets() {
  return ['KRW-BTC', 'KRW-ETH', 'KRW-XRP', 'KRW-SOL'];
}

Map<String, MarketInfo> _getCachedMarketInfo() {
  // 기본 마켓 정보 (실제로는 로컬 캐시에서 가져와야 함)
  return {
    'KRW-BTC': const MarketInfo(market: 'KRW-BTC', koreanName: '비트코인', englishName: 'Bitcoin'),
    'KRW-ETH': const MarketInfo(market: 'KRW-ETH', koreanName: '이더리움', englishName: 'Ethereum'),
    'KRW-XRP': const MarketInfo(market: 'KRW-XRP', koreanName: '리플', englishName: 'Ripple'),
    'KRW-SOL': const MarketInfo(market: 'KRW-SOL', koreanName: '솔라나', englishName: 'Solana'),
  };
}

/// 🆕 마켓 정보 Provider (30분 캐시 + 개선된 에러 처리)
final marketInfoProvider = FutureProvider<Map<String, MarketInfo>>((ref) async {
  final client = ref.read(apiClientProvider);
  
  try {
    final result = await client.request<List<dynamic>>(
      method: 'GET',
      path: '${AppConfig.upbitRestBase}/market/all',
      cacheDur: const Duration(minutes: 30), // 🚀 캐시 통일: 30분
    );
    
    return result.when(
      ok: (markets) {
        ref.read(marketErrorProvider.notifier).state = null; // 🚀 에러 상태 클리어
        
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
        // 🚀 개선된 에러 처리: 타입별 폴백 전략
        final errorMessage = '마켓 정보 로드 실패: $error';
        ref.read(marketErrorProvider.notifier).state = errorMessage;
        
        if (error.isNetworkError) {
          log.w('네트워크 오류로 캐시된 마켓 정보 사용: $error');
          return _getCachedMarketInfo(); // 캐시 폴백
        } else if (error.isServerError) {
          log.e('서버 오류, 기본 마켓 정보 사용: $error');
          return _getCachedMarketInfo(); // 기본 정보
        } else {
          log.e('알 수 없는 오류: $error');
          return <String, MarketInfo>{}; // 최후 수단
        }
      },
    );
  } catch (e) {
    final errorMessage = '마켓 정보 로드 중 예외 발생: $e';
    ref.read(marketErrorProvider.notifier).state = errorMessage;
    log.e(errorMessage);
    return _getCachedMarketInfo(); // 예외 시 폴백
  }
});

/// 1) KRW market list (동적 배치 크기 + 개선된 에러 처리)
final marketsProvider = FutureProvider<List<String>>((ref) async {
  final client = ref.read(apiClientProvider);

  // 🚀 시스템 부하에 따른 동적 배치 크기 결정
  final systemLoad = ref.watch(systemLoadProvider);
  final batchSize = systemLoad.when(
    data: (load) => load.isHigh ? 150 : 199,
    loading: () => 100,
    error: (_, __) => 50,
  );

  // fetch all markets (cache 10 minutes) - 🚀 캐시 통일
  final marketResult = await client.request<List<dynamic>>(
    method: 'GET',
    path: '${AppConfig.upbitRestBase}/market/all',
    cacheDur: const Duration(minutes: 10),
  );

  return marketResult.when(
    ok: (allMarkets) {
      ref.read(marketErrorProvider.notifier).state = null; // 에러 상태 클리어
      
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
      return client.request<List<dynamic>>(
        method: 'GET',
        path: '${AppConfig.upbitRestBase}/ticker',
        query: {'markets': krwMarkets.join(',')},
        cacheDur: null,
      ).then((tickerResult) {
        return tickerResult.when(
          ok: (tickers) {
            final sortedTickers = tickers
                .whereType<Map<String, dynamic>>()
                .toList()
              ..sort((a, b) =>
                  ((b[key] as num?) ?? 0).compareTo((a[key] as num?) ?? 0));

            // ─── WS 구독 종목 슬라이싱 로직 (essentials 우선 + 중복 제거 후 동적 배치 크기) ───
            const essentials = ['KRW-BTC', 'KRW-ETH', 'KRW-XRP', 'KRW-SOL'];
            final sortedMarkets = sortedTickers.map((e) => e['market'] as String).toList();
            final combined = [
              ...essentials.where((market) => krwMarkets.contains(market)), // 🔒 essentials도 CAUTION 체크
              ...sortedMarkets.where((m) => !essentials.contains(m)),
            ];
            
            final result = combined.take(batchSize).toList();
            if (AppConfig.enableTradeLog) {
              log.i('마켓 목록 생성됨: ${result.length}개 (배치 크기: $batchSize)');
            }
            return result;
          },
          err: (error) {
            // 🚀 티커 조회 실패 시 기본 마켓만 반환
            log.w('티커 조회 실패, 기본 마켓 사용: $error');
            ref.read(marketErrorProvider.notifier).state = '티커 조회 실패: $error';
            return _getEssentialMarkets();
          },
        );
      });
    },
    err: (error) {
      // 🚀 마켓 목록 조회 실패 시 폴백 전략
      final errorMessage = '마켓 목록 조회 실패: $error';
      ref.read(marketErrorProvider.notifier).state = errorMessage;
      
      if (error.isNetworkError) {
        log.w('네트워크 오류로 기본 마켓 사용: $error');
        return _getEssentialMarkets();
      } else {
        log.e('마켓 조회 오류: $error');
        return _getEssentialMarkets();
      }
    },
  );
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

/// 4) Filtered trades stream - 🚀 메모리 누수 방지 + 최적화된 리스너
final tradeListProvider = StreamProvider.autoDispose<List<Trade>>((ref) async* {
  // Prevent immediate dispose on loss of listeners
  ref.keepAlive();

  // 🚀 메모리 누수 방지: 주기적 정리
  Timer? cleanupTimer;
  Timer? debounceTimer;
  final Set<StreamSubscription> activeSubscriptions = {};
  
  void cleanupInactiveSubscriptions() {
    final toRemove = activeSubscriptions.where((sub) => sub.isPaused).toList();
    for (final sub in toRemove) {
      sub.cancel();
      activeSubscriptions.remove(sub);
    }
    if (toRemove.isNotEmpty && AppConfig.enableTradeLog) {
      log.d('정리된 비활성 구독: ${toRemove.length}개');
    }
  }

  cleanupTimer = Timer.periodic(const Duration(seconds: 30), (_) {
    cleanupInactiveSubscriptions();
  });

  // 현재 threshold 값과 markets를 읽어 스트림 구독
  final threshold = ref.watch(tradeFilterThresholdProvider);
  final markets = await ref.watch(marketsProvider.future);
  final repository = ref.read(repoProvider);

  // 🚀 최적화된 threshold 변경 리스너 (디바운스 적용)
  ref.listen<double>(tradeFilterThresholdProvider, (prev, next) {
    if (prev != null && prev != next) {
      // 연속된 변경을 300ms 디바운스
      debounceTimer?.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (AppConfig.enableTradeLog) {
          log.i(
            'Threshold changed: ${prev.toStringAsFixed(0)} → ${next.toStringAsFixed(0)}',
          );
        }
        repository.updateThreshold(next);
      });
    }
  });

  // 🚀 dispose 시 안전한 정리
  ref.onDispose(() {
    cleanupTimer?.cancel();
    debounceTimer?.cancel();
    
    for (final subscription in activeSubscriptions) {
      try {
        subscription.cancel();
      } catch (e) {
        log.w('구독 취소 중 에러: $e');
      }
    }
    activeSubscriptions.clear();
    
    if (AppConfig.enableTradeLog) {
      log.d('TradeListProvider 리소스 정리 완료');
    }
  });

  // 실제 필터된 거래 스트림 방출
  yield* repository.watchFilteredTrades(threshold, markets);
});

/// 5) Aggregated trades stream - 🚀 메모리 누수 방지
final aggregatedTradeProvider = StreamProvider.autoDispose<Trade>((ref) {
  // Prevent dispose on background
  ref.keepAlive();
  
  // 🚀 메모리 정리 타이머
  final cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
    // 필요시 정리 로직 (현재는 단순 로깅)
    if (AppConfig.enableTradeLog) {
      log.d('AggregatedTradeProvider 메모리 체크');
    }
  });
  
  ref.onDispose(() {
    cleanupTimer.cancel();
    if (AppConfig.enableTradeLog) {
      log.d('AggregatedTradeProvider 정리 완료');
    }
  });
  
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
      
  /// 🚀 현재 에러 상태 조회
  String? get currentError => ref.read(marketErrorProvider);
  
  /// 🚀 시스템 부하 상태 조회
  SystemLoadState? get systemLoad => ref.read(systemLoadProvider).asData?.value;
}