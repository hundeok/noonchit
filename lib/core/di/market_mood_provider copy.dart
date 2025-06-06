import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client_coingecko.dart';
import '../utils/logger.dart';

/// 🔥 시장 분위기 enum
enum MarketMood {
  bull, // 🚀 불장 - rocket_launch (화염 톤)
  weakBull, // 🔥 약불장 - local_fire_department (화염 톤)
  sideways, // ⚖️ 중간장 - balance (중성 톤)
  bear, // 💧 물장 - water_drop (쿨 톤)
  deepBear, // 🧊 얼음장 - ac_unit (아이시 톤)
}

/// 📊 마켓 무드 데이터 모델
class MarketMoodData {
  final double totalMarketCapUsd;
  final double totalVolumeUsd;
  final double btcDominance;
  final double marketCapChange24h;
  final DateTime updatedAt;

  const MarketMoodData({
    required this.totalMarketCapUsd,
    required this.totalVolumeUsd,
    required this.btcDominance,
    required this.marketCapChange24h,
    required this.updatedAt,
  });

  factory MarketMoodData.fromCoinGecko(CoinGeckoGlobalData data) {
    return MarketMoodData(
      totalMarketCapUsd: data.totalMarketCapUsd,
      totalVolumeUsd: data.totalVolumeUsd,
      btcDominance: data.btcDominance,
      marketCapChange24h: data.marketCapChangePercentage24hUsd,
      updatedAt: DateTime.now(),
    );
  }
}

/// 📈 인트라데이 볼륨 데이터 (30분 단위)
class TimestampedVolume {
  final DateTime timestamp;
  final double volumeUsd;

  const TimestampedVolume({
    required this.timestamp,
    required this.volumeUsd,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'volumeUsd': volumeUsd,
      };

  factory TimestampedVolume.fromJson(Map<String, dynamic> json) {
    return TimestampedVolume(
      timestamp: DateTime.parse(json['timestamp']),
      volumeUsd: (json['volumeUsd'] as num).toDouble(),
    );
  }
}

/// 🔄 통합 순환 버퍼 관리자 (일주일 = 336개 슬롯)
class UnifiedVolumeManager {
  static final _instance = UnifiedVolumeManager._internal();
  static UnifiedVolumeManager get instance => _instance;
  UnifiedVolumeManager._internal();

  final List<TimestampedVolume?> _buffer = List.filled(336, null); // 7일 × 48개
  int _currentIndex = 0;
  late DateTime _appStartTime;
  bool _initialized = false;

  void initialize() {
    if (!_initialized) {
      _appStartTime = DateTime.now();
      _initialized = true;
      log.d('UnifiedVolumeManager 초기화: $_appStartTime');
    }
  }

  DateTime get appStartTime => _appStartTime;

  /// 새 데이터 추가 (30분마다 호출)
  void addVolumeData(double volumeUsd) {
    final now = DateTime.now();
    _buffer[_currentIndex] = TimestampedVolume(
      timestamp: now,
      volumeUsd: volumeUsd,
    );
    _currentIndex = (_currentIndex + 1) % 336;
    log.d('볼륨 데이터 추가: ${volumeUsd}B at $now');
  }

  /// N분 전 데이터 가져오기
  TimestampedVolume? getVolumeNMinutesAgo(int minutes) {
    final slotsBack = (minutes / 30).round();
    if (slotsBack <= 0 || slotsBack >= 336) return null;

    final targetIndex = (_currentIndex - slotsBack + 336) % 336;
    final data = _buffer[targetIndex];
    
    if (data == null) return null;
    
    // 시간 검증: 실제로 N분 전 데이터인지 확인
    final expectedTime = DateTime.now().subtract(Duration(minutes: minutes));
    final timeDiff = (data.timestamp.difference(expectedTime)).abs().inMinutes;
    
    if (timeDiff > 45) return null; // 45분 이상 차이나면 무효
    
    return data;
  }

  /// 특정 기간의 평균 계산
  double? getAverageVolume(int days) {
    final slots = days * 48; // 하루 48개 슬롯
    if (slots > 336) return null;

    final volumes = <double>[];
    for (int i = 1; i <= slots; i++) {
      final index = (_currentIndex - i + 336) % 336;
      final data = _buffer[index];
      if (data != null) {
        volumes.add(data.volumeUsd);
      }
    }

    if (volumes.isEmpty) return null;
    return volumes.reduce((a, b) => a + b) / volumes.length;
  }

  /// 수집된 데이터 개수 확인
  int getCollectedDataCount() {
    return _buffer.where((data) => data != null).length;
  }

  /// 자정 초기화 (매일 자정에 호출)
  void resetAtMidnight() {
    log.d('자정 초기화 실행');
    // 순환 버퍼는 자동으로 오래된 데이터를 덮어쓰므로 별도 초기화 불필요
  }
}

/// 📊 비교 결과 데이터
class ComparisonResult {
  final bool isReady;
  final double? changePercent;
  final double progressPercent;
  final String status;

  const ComparisonResult({
    required this.isReady,
    this.changePercent,
    required this.progressPercent,
    required this.status,
  });

  factory ComparisonResult.collecting(double progress) {
    return ComparisonResult(
      isReady: false,
      progressPercent: progress,
      status: '수집중',
    );
  }

  factory ComparisonResult.ready(double changePercent) {
    return ComparisonResult(
      isReady: true,
      changePercent: changePercent,
      progressPercent: 1.0,
      status: 'ready',
    );
  }
}

/// 📈 전체 비교 데이터
class ComparisonData {
  final ComparisonResult thirtyMin;
  final ComparisonResult oneHour;
  final ComparisonResult twoHour;
  final ComparisonResult fourHour;
  final ComparisonResult eightHour;
  final ComparisonResult twelveHour;
  final ComparisonResult twentyFourHour;
  final ComparisonResult threeDayAverage;
  final ComparisonResult weeklyAverage;

  const ComparisonData({
    required this.thirtyMin,
    required this.oneHour,
    required this.twoHour,
    required this.fourHour,
    required this.eightHour,
    required this.twelveHour,
    required this.twentyFourHour,
    required this.threeDayAverage,
    required this.weeklyAverage,
  });

  factory ComparisonData.loading() {
    const loading = ComparisonResult(
      isReady: false,
      progressPercent: 0.0,
      status: '로딩중',
    );
    return const ComparisonData(
      thirtyMin: loading,
      oneHour: loading,
      twoHour: loading,
      fourHour: loading,
      eightHour: loading,
      twelveHour: loading,
      twentyFourHour: loading,
      threeDayAverage: loading,
      weeklyAverage: loading,
    );
  }

  factory ComparisonData.error() {
    const error = ComparisonResult(
      isReady: false,
      progressPercent: 0.0,
      status: '오류',
    );
    return const ComparisonData(
      thirtyMin: error,
      oneHour: error,
      twoHour: error,
      fourHour: error,
      eightHour: error,
      twelveHour: error,
      twentyFourHour: error,
      threeDayAverage: error,
      weeklyAverage: error,
    );
  }
}

/// 🧮 볼륨 비교 계산기
class VolumeComparator {
  final UnifiedVolumeManager _manager;
  
  VolumeComparator(this._manager);

  /// 변화율 계산
  double _calculateChangePercent(double current, double previous) {
    if (previous <= 0) return 0.0;
    return ((current - previous) / previous) * 100;
  }

  /// 게이지 진행률 계산 (첫 주기는 2배 시간, 이후는 타임프레임대로)
  double _calculateProgress(int targetMinutes, DateTime appStartTime) {
    final elapsed = DateTime.now().difference(appStartTime).inMinutes;
    
    // 첫 주기인지 확인 (2배 시간 필요)
    final firstCycleMinutes = targetMinutes * 2;
    
    if (elapsed < firstCycleMinutes) {
      // 첫 주기: 2배 시간 기준으로 연속적으로 증가
      return min(elapsed / firstCycleMinutes, 1.0);
    } else {
      // 이후 주기: 타임프레임 기준으로 순환하지만 실시간으로 증가
      final cycleElapsed = (elapsed - firstCycleMinutes) % targetMinutes;
      return cycleElapsed / targetMinutes;
    }
  }

  /// 장기 비교용 실시간 진행률 계산
  double _calculateLongTermProgress(int targetMinutes, DateTime appStartTime) {
    final elapsed = DateTime.now().difference(appStartTime).inMinutes;
    return min(elapsed / targetMinutes, 1.0);
  }

  /// 30분 대비 계산
  ComparisonResult compare30Minutes(double currentVolume) {
    final elapsed = DateTime.now().difference(_manager.appStartTime).inMinutes;
    
    if (elapsed < 60) {
      // 첫 60분: 수집 중 - 실시간 진행률
      final progress = _calculateProgress(30, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    // 60분 후: 30분 전 데이터와 비교
    final thirtyMinAgo = _manager.getVolumeNMinutesAgo(30);
    if (thirtyMinAgo == null) {
      final progress = _calculateProgress(30, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    final changePercent = _calculateChangePercent(currentVolume, thirtyMinAgo.volumeUsd);
    return ComparisonResult.ready(changePercent);
  }

  /// 1시간 대비 계산
  ComparisonResult compare1Hour(double currentVolume) {
    final elapsed = DateTime.now().difference(_manager.appStartTime).inMinutes;
    
    if (elapsed < 120) {
      // 첫 120분: 수집 중 - 실시간 진행률
      final progress = _calculateProgress(60, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    // 120분 후: 1시간 전 데이터와 비교
    final oneHourAgo = _manager.getVolumeNMinutesAgo(60);
    if (oneHourAgo == null) {
      final progress = _calculateProgress(60, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    final changePercent = _calculateChangePercent(currentVolume, oneHourAgo.volumeUsd);
    return ComparisonResult.ready(changePercent);
  }

  /// 2시간 대비 계산
  ComparisonResult compare2Hours(double currentVolume) {
    final elapsed = DateTime.now().difference(_manager.appStartTime).inMinutes;
    
    if (elapsed < 240) {
      // 첫 240분: 수집 중 - 실시간 진행률
      final progress = _calculateProgress(120, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    // 240분 후: 2시간 전 데이터와 비교
    final twoHoursAgo = _manager.getVolumeNMinutesAgo(120);
    if (twoHoursAgo == null) {
      final progress = _calculateProgress(120, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    final changePercent = _calculateChangePercent(currentVolume, twoHoursAgo.volumeUsd);
    return ComparisonResult.ready(changePercent);
  }

  /// 4시간 대비 계산
  ComparisonResult compare4Hours(double currentVolume) {
    final elapsed = DateTime.now().difference(_manager.appStartTime).inMinutes;
    
    if (elapsed < 480) {
      // 첫 480분: 수집 중 - 실시간 진행률
      final progress = _calculateProgress(240, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    // 480분 후: 4시간 전 데이터와 비교
    final fourHoursAgo = _manager.getVolumeNMinutesAgo(240);
    if (fourHoursAgo == null) {
      final progress = _calculateProgress(240, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    final changePercent = _calculateChangePercent(currentVolume, fourHoursAgo.volumeUsd);
    return ComparisonResult.ready(changePercent);
  }

  /// 8시간 대비 계산
  ComparisonResult compare8Hours(double currentVolume) {
    final elapsed = DateTime.now().difference(_manager.appStartTime).inMinutes;
    
    if (elapsed < 960) {
      // 첫 960분: 수집 중 - 실시간 진행률
      final progress = _calculateProgress(480, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    // 960분 후: 8시간 전 데이터와 비교
    final eightHoursAgo = _manager.getVolumeNMinutesAgo(480);
    if (eightHoursAgo == null) {
      final progress = _calculateProgress(480, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    final changePercent = _calculateChangePercent(currentVolume, eightHoursAgo.volumeUsd);
    return ComparisonResult.ready(changePercent);
  }

  /// 12시간 대비 계산
  ComparisonResult compare12Hours(double currentVolume) {
    final elapsed = DateTime.now().difference(_manager.appStartTime).inMinutes;
    
    if (elapsed < 1440) {
      // 첫 1440분(24시간): 수집 중 - 실시간 진행률
      final progress = _calculateProgress(720, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    // 1440분 후: 12시간 전 데이터와 비교
    final twelveHoursAgo = _manager.getVolumeNMinutesAgo(720);
    if (twelveHoursAgo == null) {
      final progress = _calculateProgress(720, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    final changePercent = _calculateChangePercent(currentVolume, twelveHoursAgo.volumeUsd);
    return ComparisonResult.ready(changePercent);
  }

  /// 24시간 대비 계산
  ComparisonResult compare24Hours(double currentVolume) {
    final elapsed = DateTime.now().difference(_manager.appStartTime).inMinutes;
    
    if (elapsed < 1440) {
      // 첫 24시간: 수집 중 - 실시간 연속 진행률
      final progress = _calculateLongTermProgress(1440, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    // 24시간 후: 24시간 전 데이터와 비교
    final twentyFourHoursAgo = _manager.getVolumeNMinutesAgo(1440);
    if (twentyFourHoursAgo == null) {
      return ComparisonResult.collecting(0.8);
    }
    
    final changePercent = _calculateChangePercent(currentVolume, twentyFourHoursAgo.volumeUsd);
    return ComparisonResult.ready(changePercent);
  }

  /// 3일 평균 대비 계산
  ComparisonResult compare3DayAverage(double currentVolume) {
    final elapsed = DateTime.now().difference(_manager.appStartTime).inMinutes;
    
    if (elapsed < 4320) { // 3일 = 4320분
      // 3일간 수집 중 - 실시간 연속 진행률
      final progress = _calculateLongTermProgress(4320, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    final threeDayAverage = _manager.getAverageVolume(3);
    if (threeDayAverage == null) {
      return ComparisonResult.collecting(0.8);
    }
    
    final changePercent = _calculateChangePercent(currentVolume, threeDayAverage);
    return ComparisonResult.ready(changePercent);
  }

  /// 일주일 평균 대비 계산
  ComparisonResult compareWeeklyAverage(double currentVolume) {
    final elapsed = DateTime.now().difference(_manager.appStartTime).inMinutes;
    
    if (elapsed < 10080) { // 7일 = 10080분
      // 일주일간 수집 중 - 실시간 연속 진행률
      final progress = _calculateLongTermProgress(10080, _manager.appStartTime);
      return ComparisonResult.collecting(progress);
    }
    
    final weeklyAverage = _manager.getAverageVolume(7);
    if (weeklyAverage == null) {
      return ComparisonResult.collecting(0.8);
    }
    
    final changePercent = _calculateChangePercent(currentVolume, weeklyAverage);
    return ComparisonResult.ready(changePercent);
  }

  /// 전체 비교 데이터 계산
  ComparisonData calculateAll(double currentVolume) {
    return ComparisonData(
      thirtyMin: compare30Minutes(currentVolume),
      oneHour: compare1Hour(currentVolume),
      twoHour: compare2Hours(currentVolume),
      fourHour: compare4Hours(currentVolume),
      eightHour: compare8Hours(currentVolume),
      twelveHour: compare12Hours(currentVolume),
      twentyFourHour: compare24Hours(currentVolume),
      threeDayAverage: compare3DayAverage(currentVolume),
      weeklyAverage: compareWeeklyAverage(currentVolume),
    );
  }
}

/// 💰 마켓 무드 계산기
class MarketMoodCalculator {
  static String _addCommas(String numberStr) {
    final parts = numberStr.split('.');
    final integerPart = parts[0];
    final reversedInteger = integerPart.split('').reversed.join('');
    final withCommas = reversedInteger
        .replaceAllMapped(RegExp(r'.{3}'), (match) => '${match.group(0)},')
        .split('')
        .reversed
        .join('');
    final result = withCommas.startsWith(',') ? withCommas.substring(1) : withCommas;
    return parts.length > 1 ? '$result.${parts[1]}' : result;
  }

  static String formatVolume(double volumeUsd, [double usdToKrw = 1400]) {
    final volumeKrw = volumeUsd * usdToKrw;
    if (volumeKrw >= 1e12) {
      final trillions = (volumeKrw / 1e12).toStringAsFixed(0);
      return '${_addCommas(trillions)}조원';
    }
    if (volumeKrw >= 1e8) {
      final hundreds = (volumeKrw / 1e8).toStringAsFixed(0);
      return '${_addCommas(hundreds)}억원';
    }
    return '${(volumeKrw / 1e8).toStringAsFixed(1)}억원';
  }

  static String formatMarketCap(double marketCapUsd, [double usdToKrw = 1400]) {
    final marketCapKrw = marketCapUsd * usdToKrw;
    if (marketCapKrw >= 1e12) {
      final trillions = (marketCapKrw / 1e12).toStringAsFixed(0);
      return '${_addCommas(trillions)}조원';
    }
    if (marketCapKrw >= 1e8) {
      final hundreds = (marketCapKrw / 1e8).toStringAsFixed(0);
      return '${_addCommas(hundreds)}억원';
    }
    return '${(marketCapKrw / 1e8).toStringAsFixed(1)}억원';
  }

  static String formatVolumeWithRate(double volumeUsd, double usdToKrw) {
    return formatVolume(volumeUsd, usdToKrw);
  }

  static String formatMarketCapWithRate(double marketCapUsd, double usdToKrw) {
    return formatMarketCap(marketCapUsd, usdToKrw);
  }

  /// 30분 전 대비 분위기 계산 (실시간 기준)
  static MarketMood calculateMoodByComparison(double current, double previous) {
    if (previous == 0) return MarketMood.sideways;
    
    final changePercent = ((current - previous) / previous) * 100;
    
    if (changePercent >= 15) return MarketMood.bull;
    if (changePercent >= 5) return MarketMood.weakBull;
    if (changePercent >= -5) return MarketMood.sideways;
    if (changePercent >= -15) return MarketMood.bear;
    return MarketMood.deepBear;
  }

  /// 절대값 기준 분위기 계산 (fallback)
  static MarketMood calculateMoodByAbsolute(double volumeUsd) {
    if (volumeUsd >= 150e9) return MarketMood.bull;
    if (volumeUsd >= 100e9) return MarketMood.weakBull;
    if (volumeUsd >= 70e9) return MarketMood.sideways;
    if (volumeUsd >= 50e9) return MarketMood.bear;
    return MarketMood.deepBear;
  }

  /// 최종 분위기 계산 (30분 전 데이터 우선, 없으면 절대값)
  static MarketMood calculateMood(double currentVolume, UnifiedVolumeManager manager) {
    final thirtyMinAgo = manager.getVolumeNMinutesAgo(30);
    
    if (thirtyMinAgo != null) {
      return calculateMoodByComparison(currentVolume, thirtyMinAgo.volumeUsd);
    } else {
      return calculateMoodByAbsolute(currentVolume);
    }
  }
}

/// 🌐 환율 Provider (12시간 캐시)
final exchangeRateProvider = FutureProvider.autoDispose<double>((ref) async {
  final client = ref.read(coinGeckoApiClientProvider);
  
  try {
    final rate = await client.getUsdToKrwRate();
    log.d('환율 조회 성공: $rate원');
    return rate;
  } catch (e) {
    log.w('환율 조회 실패, 기본값 사용: $e');
    return 1400.0; // 기본값
  }
});

/// 🔄 통합 볼륨 관리자 Provider
final unifiedVolumeManagerProvider = Provider<UnifiedVolumeManager>((ref) {
  final manager = UnifiedVolumeManager.instance;
  manager.initialize();
  return manager;
});

/// 📊 볼륨 비교 계산기 Provider
final volumeComparatorProvider = Provider<VolumeComparator>((ref) {
  final manager = ref.read(unifiedVolumeManagerProvider);
  return VolumeComparator(manager);
});

/// 📈 볼륨 비교 데이터 Provider
final volumeComparisonProvider = Provider<ComparisonData>((ref) {
  final marketMoodAsync = ref.watch(marketMoodProvider);
  final comparator = ref.read(volumeComparatorProvider);
  
  return marketMoodAsync.when(
    data: (data) => comparator.calculateAll(data.totalVolumeUsd),
    loading: () => ComparisonData.loading(),
    error: (_, __) => ComparisonData.error(),
  );
});

/// 🌐 CoinGecko API 클라이언트 Provider
final coinGeckoApiClientProvider = Provider<CoinGeckoApiClient>((ref) {
  return CoinGeckoApiClient();
});

/// 🌐 글로벌 마켓 데이터 Provider
final marketGlobalDataProvider = StreamProvider<CoinGeckoGlobalData>((ref) {
  final client = ref.read(coinGeckoApiClientProvider);
  final controller = StreamController<CoinGeckoGlobalData>();
  
  Timer? timer;
  
  Future<void> fetchData() async {
    try {
      final response = await client.getGlobalMarketData();
      // response는 CoinGeckoGlobalResponse 타입
      final data = response.data; // data는 CoinGeckoGlobalData 타입
      
      if (!controller.isClosed) {
        controller.add(data);
      }
    } catch (e) {
      log.e('글로벌 마켓 데이터 조회 실패: $e');
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  // 최초 실행
  fetchData();
  
  // 30분마다 반복
  timer = Timer.periodic(const Duration(minutes: 30), (t) => fetchData());
  
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  
  return controller.stream;
});

/// 🎯 마켓 무드 데이터 Provider (볼륨 데이터 수집 포함)
final marketMoodProvider = StreamProvider<MarketMoodData>((ref) {
  final controller = StreamController<MarketMoodData>();
  final volumeManager = ref.read(unifiedVolumeManagerProvider);
  
  // 글로벌 데이터 스트림 구독
  ref.listen(marketGlobalDataProvider, (previous, next) {
    next.when(
      data: (globalData) {
        // 볼륨 데이터를 통합 관리자에 추가
        volumeManager.addVolumeData(globalData.totalVolumeUsd);
        
        // 마켓 무드 데이터 생성
        final moodData = MarketMoodData.fromCoinGecko(globalData);
        
        if (!controller.isClosed) {
          controller.add(moodData);
        }
      },
      loading: () {
        // 로딩 중일 때는 아무것도 하지 않음
      },
      error: (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
    );
  });
  
  ref.onDispose(() {
    controller.close();
  });
  
  return controller.stream;
});

/// 🎯 현재 마켓 무드 Provider (30분 기준 실시간 계산)
final currentMarketMoodProvider = Provider<MarketMood>((ref) {
  final marketMoodAsync = ref.watch(marketMoodProvider);
  final volumeManager = ref.read(unifiedVolumeManagerProvider);
  
  return marketMoodAsync.when(
    data: (data) => MarketMoodCalculator.calculateMood(
      data.totalVolumeUsd, 
      volumeManager,
    ),
    loading: () => MarketMood.sideways,
    error: (_, __) => MarketMood.sideways,
  );
});

/// 📊 마켓 무드 상태 Provider
final marketMoodStateProvider = Provider<AsyncValue<MarketMoodData>>((ref) {
  return ref.watch(marketMoodProvider);
});

/// 🎮 마켓 무드 컨트롤러
final marketMoodController = Provider<MarketMoodController>((ref) {
  return MarketMoodController();
});

class MarketMoodController {
  /// 수동 새로고침
  void refresh(WidgetRef ref) {
    ref.invalidate(marketGlobalDataProvider);
    ref.invalidate(exchangeRateProvider);
  }
  
  /// 무드 정보 가져오기
  MarketMood getCurrentMood(WidgetRef ref) {
    return ref.read(currentMarketMoodProvider);
  }
  
  /// 비교 데이터 가져오기
  ComparisonData getComparisonData(WidgetRef ref) {
    return ref.read(volumeComparisonProvider);
  }
}

/// 📊 전체 시스템 상태 Provider
final marketMoodSystemProvider = Provider<Map<String, dynamic>>((ref) {
  final marketMoodAsync = ref.watch(marketMoodProvider);
  final comparisonData = ref.watch(volumeComparisonProvider);
  final currentMood = ref.watch(currentMarketMoodProvider);
  final exchangeRateAsync = ref.watch(exchangeRateProvider);
  
  return {
    'marketData': marketMoodAsync.valueOrNull,
    'comparison': comparisonData,
    'currentMood': currentMood,
    'exchangeRate': exchangeRateAsync.valueOrNull ?? 1400.0,
    'isLoading': marketMoodAsync.isLoading || exchangeRateAsync.isLoading,
    'hasError': marketMoodAsync.hasError || exchangeRateAsync.hasError,
  };
});

/// 📊 마켓 무드 상태 요약 Provider
final marketMoodSummaryProvider = Provider<String>((ref) {
  final systemState = ref.watch(marketMoodSystemProvider);
  final mood = systemState['currentMood'] as MarketMood;
  
  String moodEmoji = switch (mood) {
    MarketMood.bull => '🚀',
    MarketMood.weakBull => '🔥',
    MarketMood.sideways => '⚖️',
    MarketMood.bear => '💧',
    MarketMood.deepBear => '🧊',
  };
  
  String moodText = switch (mood) {
    MarketMood.bull => '불장',
    MarketMood.weakBull => '약불장',
    MarketMood.sideways => '중간장',
    MarketMood.bear => '물장',
    MarketMood.deepBear => '얼음장',
  };
  
  return '$moodEmoji $moodText';
});

/// 🔄 전체 시스템 초기화 Provider
final marketMoodSystemInitProvider = FutureProvider<bool>((ref) async {
  try {
    // 통합 볼륨 매니저 초기화
    final volumeManager = ref.read(unifiedVolumeManagerProvider);
    volumeManager.initialize();
    
    log.d('마켓 무드 시스템 초기화 완료');
    return true;
  } catch (e) {
    log.e('마켓 무드 시스템 초기화 실패: $e');
    return false;
  }
});

/// 🎯 메인 시스템 Provider (앱에서 이것만 watch하면 됨)
final mainMarketMoodProvider = Provider<Map<String, dynamic>>((ref) {
  // 시스템 초기화 확인
  final initAsync = ref.watch(marketMoodSystemInitProvider);
  
  if (initAsync.isLoading) {
    return {'status': 'initializing', 'data': null};
  }
  
  if (initAsync.hasError) {
    return {'status': 'error', 'data': initAsync.error};
  }
  
  // 시스템 상태 반환
  final systemState = ref.watch(marketMoodSystemProvider);
  return {'status': 'ready', 'data': systemState};
});