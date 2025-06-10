// lib/core/di/market_mood_provider.dart
// 🚀 Performance Optimized Provider - 메모이제이션, 배치처리, 선택적 무효화, 주기적 갱신 적용

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart'; // 🚀 debounceTime, distinctUntilChanged
import 'dart:async';

import '../network/api_client_coingecko.dart';
import '../utils/logger.dart';
import 'trade_provider.dart' show hiveServiceProvider;
import '../../data/datasources/market_mood_remote_ds.dart';
import '../../data/datasources/market_mood_local_ds.dart';
import '../../data/repositories/market_mood_repository_impl.dart';
import '../../domain/entities/market_mood.dart';
import '../../domain/usecases/market_mood_usecase.dart';

/// 🌐 CoinGecko API 클라이언트 Provider
final coinGeckoApiClientProvider = Provider<CoinGeckoApiClient>((ref) {
  return CoinGeckoApiClient();
});

/// 🔥 Remote DataSource Provider
final marketMoodRemoteDSProvider = Provider<MarketMoodRemoteDataSource>((ref) {
  final client = ref.read(coinGeckoApiClientProvider);
  return MarketMoodRemoteDataSource(client);
});

/// 🔥 Local DataSource Provider
final marketMoodLocalDSProvider = Provider<MarketMoodLocalDataSource>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  return MarketMoodLocalDataSource(hive);
});

/// 🔥 Repository Provider
final marketMoodRepositoryProvider = Provider<MarketMoodRepositoryImpl>((ref) {
  final remoteDS = ref.read(marketMoodRemoteDSProvider);
  final localDS = ref.read(marketMoodLocalDSProvider);
  return MarketMoodRepositoryImpl(remoteDS, localDS);
});

/// 🔥 UseCase Provider
final marketMoodUsecaseProvider = Provider<MarketMoodUsecase>((ref) {
  final repository = ref.read(marketMoodRepositoryProvider);
  return MarketMoodUsecase(repository);
});

/// 🚀 메모이제이션된 환율 Provider - 캐시 유지 (TTL 필요 시 autoDispose로 변경)
final exchangeRateProvider = FutureProvider.autoDispose<double>((ref) async {
  final usecase = ref.read(marketMoodUsecaseProvider);
  try {
    final rate = await usecase.getExchangeRate();
    log.d('환율 조회 성공: $rate (캐시됨)');
    return rate;
  } catch (e, st) {
    log.w('환율 조회 실패, 기본값 1400 사용: $e', e, st);
    return 1400.0;
  }
});

/// 🚀 최적화된 마켓 데이터 스트림 - distinct + debounceTime 적용
final marketMoodProvider = StreamProvider<MarketMoodData>((ref) {
  final repository = ref.read(marketMoodRepositoryProvider);

  ref.onDispose(repository.dispose);

  return repository
      .getMarketDataStream()
      .distinct((prev, next) => prev.totalVolumeUsd == next.totalVolumeUsd)
      .debounceTime(const Duration(milliseconds: 100));
});

/// 🚀 통합 계산 Provider - 주기적 갱신 및 포그라운드 복귀 시 자동 invalidate 적용
final marketMoodComputedDataProvider = FutureProvider.autoDispose<MarketMoodComputedData>((ref) async {
  // 1) autoDispose 비활성화 링크 (keepAlive)
  final link = ref.keepAlive();

  // 2) 15분마다 재계산
  final timer = Timer.periodic(const Duration(minutes: 15), (_) {
    ref.invalidateSelf();
  });

  // 3) 앱 복귀 시 재계산
  ref.onResume(() {
    ref.invalidateSelf();
  });

  // 4) 종료 시 정리
  ref.onDispose(() {
    timer.cancel();
    link.close();
  });

  // 기존 로직
  final moodAsync = ref.watch(marketMoodProvider);
  final exchangeAsync = ref.watch(exchangeRateProvider);
  final usecase = ref.read(marketMoodUsecaseProvider);

  return moodAsync.when(
    data: (marketData) async {
      final exchangeRate = exchangeAsync.asData?.value ?? 1400.0;
      try {
        final results = await Future.wait(
          [
            usecase.calculateCurrentMood(marketData.totalVolumeUsd),
            usecase.calculateVolumeComparison(marketData.totalVolumeUsd),
          ],
          eagerError: false,
        );
        final currentMood = results[0] as MarketMood;
        final volumeComparison = results[1] as ComparisonData;
        final moodSummary = usecase.generateMoodSummary(currentMood);

        return MarketMoodComputedData(
          marketData: marketData,
          currentMood: currentMood,
          volumeComparison: volumeComparison,
          moodSummary: moodSummary,
          exchangeRate: exchangeRate,
          computedAt: DateTime.now(),
        );
      } catch (e, st) {
        // [수정됨] 이름 있는 파라미터(named parameter) 대신 위치 기반 파라미터(positional parameter) 사용
        log.e('배치 계산 오류: $e', e, st);
        return MarketMoodComputedData.error();
      }
    },
    loading: () async => MarketMoodComputedData.loading(),
    error: (error, stack) async {
      // [수정됨] 이름 있는 파라미터(named parameter) 대신 위치 기반 파라미터(positional parameter) 사용
      log.e('마켓무드 계산 오류: $error', error, stack);
      return MarketMoodComputedData.error();
    },
  );
});

/// 🎯 개별 데이터 접근 Provider들 - 메모이제이션된 결과에서 추출
final currentMarketMoodProvider = Provider<MarketMood>((ref) {
  final computedAsync = ref.watch(marketMoodComputedDataProvider);
  return computedAsync.when(
    data: (computed) => computed.currentMood,
    loading: () => MarketMood.sideways,
    error: (_, __) => MarketMood.sideways,
  );
});

final volumeComparisonProvider = Provider<ComparisonData>((ref) {
  final computedAsync = ref.watch(marketMoodComputedDataProvider);
  return computedAsync.when(
    data: (computed) => computed.volumeComparison,
    loading: () => ComparisonData.loading(),
    error: (_, __) => ComparisonData.error(),
  );
});

final marketMoodSummaryProvider = Provider<String>((ref) {
  final computedAsync = ref.watch(marketMoodComputedDataProvider);
  return computedAsync.when(
    data: (computed) => computed.moodSummary,
    loading: () => '로딩중...',
    error: (_, __) => '오류 발생',
  );
});

/// 🌐 최적화된 시스템 상태 Provider
final marketMoodSystemProvider = Provider<MarketMoodSystemState>((ref) {
  final computedAsync = ref.watch(marketMoodComputedDataProvider);
  final usecase = ref.read(marketMoodUsecaseProvider);

  return computedAsync.when(
    data: (computed) => usecase.createSystemState(
      marketData: computed.marketData,
      comparisonData: computed.volumeComparison,
      currentMood: computed.currentMood,
      exchangeRate: computed.exchangeRate,
      isLoading: false,
      hasError: false,
    ),
    loading: () => usecase.createSystemState(
      marketData: null,
      comparisonData: ComparisonData.loading(),
      currentMood: MarketMood.sideways,
      exchangeRate: 1400.0,
      isLoading: true,
      hasError: false,
    ),
    error: (_, __) => usecase.createSystemState(
      marketData: null,
      comparisonData: ComparisonData.error(),
      currentMood: MarketMood.sideways,
      exchangeRate: 1400.0,
      isLoading: false,
      hasError: true,
    ),
  );
});

/// 🎮 최적화된 마켓 무드 컨트롤러
final marketMoodControllerProvider = Provider((ref) => OptimizedMarketMoodController(ref));

class OptimizedMarketMoodController {
  final Ref ref;
  DateTime? _lastRefresh;
  static const _refreshCooldown = Duration(seconds: 30);

  OptimizedMarketMoodController(this.ref);

  /// 🚀 스마트 새로고침 - 쿨다운 적용
  void refresh() {
    final now = DateTime.now();
    if (_lastRefresh != null && now.difference(_lastRefresh!) < _refreshCooldown) {
      // [수정됨] + 연산자 대신 인접 문자열 연결 사용
      log.d('새로고침 쿨다운 중... '
          '${_refreshCooldown.inSeconds - now.difference(_lastRefresh!).inSeconds}초 후 가능');
      return;
    }

    _lastRefresh = now;
    ref.invalidate(marketMoodProvider);
    ref.invalidate(exchangeRateProvider);
    log.d('마켓무드 데이터 새로고침 완료');
  }

  /// 🚀 캐시된 현재 무드 조회
  MarketMood getCurrentMood() => ref.read(currentMarketMoodProvider);

  /// 🚀 캐시된 비교 데이터 조회
  ComparisonData getComparisonData() => ref.read(volumeComparisonProvider);

  /// 🚀 환율만 선택적 새로고침
  Future<void> refreshExchangeRate() async {
    final usecase = ref.read(marketMoodUsecaseProvider);
    await usecase.refreshExchangeRate();
    ref.invalidate(exchangeRateProvider);
    log.d('환율 새로고침 완료');
  }

  /// 🚀 시스템 헬스 체크 (캐시 활용)
  Future<Map<String, dynamic>> getSystemHealth() async {
    final usecase = ref.read(marketMoodUsecaseProvider);
    final state = ref.read(marketMoodSystemProvider);
    return {
      ...await usecase.getSystemHealth(),
      'cached_state': {
        'is_loading': state.isLoading,
        'has_error': state.hasError,
        'last_update': state.marketData?.updatedAt.toIso8601String(),
      }
    };
  }

  /// 🚀 성능 통계 로깅
  Future<void> logSystemStatus() async {
    final usecase = ref.read(marketMoodUsecaseProvider);
    final computedAsync = ref.read(marketMoodComputedDataProvider);
    await usecase.logSystemStatus();
    computedAsync.whenData((computed) {
      log.i('성능 통계 - 계산 시간: ${DateTime.now().difference(computed.computedAt).inMilliseconds}ms');
    });
  }

  /// 🚀 메모리 정리 (필요 시 호출)
  void clearCache() {
    ref.invalidate(marketMoodComputedDataProvider);
    ref.invalidate(exchangeRateProvider);
    ref.invalidate(marketMoodProvider);
    log.d('캐시 정리 완료');
  }
}

/// 🚀 통합 계산 결과 데이터 클래스
class MarketMoodComputedData {
  final MarketMoodData? marketData;
  final MarketMood currentMood;
  final ComparisonData volumeComparison;
  final String moodSummary;
  final double exchangeRate;
  final DateTime computedAt;

  const MarketMoodComputedData({
    this.marketData,
    required this.currentMood,
    required this.volumeComparison,
    required this.moodSummary,
    required this.exchangeRate,
    required this.computedAt,
  });

  factory MarketMoodComputedData.loading() => MarketMoodComputedData(
        currentMood: MarketMood.sideways,
        volumeComparison: ComparisonData.loading(),
        moodSummary: '로딩중...',
        exchangeRate: 1400.0,
        computedAt: DateTime.now(),
      );

  factory MarketMoodComputedData.error() => MarketMoodComputedData(
        currentMood: MarketMood.sideways,
        volumeComparison: ComparisonData.error(),
        moodSummary: '오류 발생',
        exchangeRate: 1400.0,
        computedAt: DateTime.now(),
      );

  /// 🚀 데이터 신선도 체크 (15분 이상 오래되면 갱신 필요)
  bool get isStale => DateTime.now().difference(computedAt) > const Duration(minutes: 15);

  /// 🚀 성능 메트릭
  Duration get age => DateTime.now().difference(computedAt);
}