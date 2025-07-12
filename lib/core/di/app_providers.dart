// lib/core/di/app_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bridge/signal_bus.dart';

/// ▶ App lifecycle
export '../utils/app_life_cycle_manager.dart'
    show appLifecycleManagerProvider;

/// ▶ Settings DI + state
export 'settings_provider.dart'
    show
        sharedPreferencesProvider,
        settingsLocalDSProvider,
        settingsRepositoryProvider,
        settingsUsecaseProvider,
        appSettingsProvider;

/// ▶ Domain entities
export '../../domain/entities/app_settings.dart'
    show
        DisplayMode,
        SliderPosition;

/// ▶ WebSocket DI & stats
export 'websocket_provider.dart'
    show
        wsStatusProvider,
        wsClientProvider,
        wsStatsProvider,
        WebSocketStats;

/// ▶ Trade DI & streams
export 'trade_provider.dart';

/// ▶ 🔥 공통 TimeFrame + Trade 타입 시스템
export '../common/time_frame_manager.dart'
    show
        globalTimeFrameManagerProvider,
        timeFrameResetStreamProvider,
        volumeSelectedTimeFrameProvider,
        surgeSelectedTimeFrameProvider,
        commonProcessingConfigProvider;

export '../common/time_frame_types.dart'
    show
        TimeFrame,
        TimeFrameResetEvent,
        ProcessingConfig,
        TradeFilter,
        TradeMode,
        TradeConfig,
        MarketInfo;

/// ▶ Volume DI & streams (공통 시스템 연동)
export 'volume_provider.dart'
    show
        volumeRepositoryProvider,
        volumeUsecaseProvider,
        volumeTimeFrameControllersProvider,
        volumeStreamBinderProvider,
        volumeDataProvider,
        currentVolumeListProvider;

/// ▶ Surge DI & streams (공통 시스템 연동)
export 'surge_provider.dart'
    show
        surgeTimeFrameControllersProvider,
        surgeStreamBinderProvider,
        surgeDataProvider,
        currentSurgeListProvider;

/// ▶ Sector DI & streams (기존 구조 유지)
export 'sector_provider.dart'
    show
        sectorClassificationProvider,
        selectedSectorTimeFrameProvider,
        sectorVolumeDataProvider,
        currentSectorVolumeListProvider;

/// ▶ Signal DI & streams (V4.1 Online)
export 'signal_provider.dart'
    show
        // 🔥 V4.1 의존성 주입
        advancedMetricsProvider,
        patternConfigProvider,
        signalRepoProvider,
        signalUsecaseProvider,
        // 🎯 상태 관리
        signalPatternIndexProvider,
        signalPatternTypeProvider,
        signalPatternEnabledProvider,
        // 🔥 스트림 (온라인 지표 연동)
        signalListProvider,
        allSignalsProvider,
        // 🆕 V4.1 모니터링
        onlineMetricsHealthProvider,
        systemPerformanceProvider;

/// ▶ Market Mood DI & streams
export 'market_mood_provider.dart'
    show
        coinGeckoApiClientProvider,
        marketMoodRemoteDSProvider,
        marketMoodLocalDSProvider,
        marketMoodRepositoryProvider,
        marketMoodUsecaseProvider,
        exchangeRateProvider,
        marketMoodProvider,
        marketMoodComputedDataProvider, // UI에서 로딩/에러 상태 처리를 위해 export
        volumeComparisonProvider,
        currentMarketMoodProvider,
        marketMoodSummaryProvider,
        marketMoodSystemProvider,
        marketMoodControllerProvider,
        MarketMoodComputedData;

/// ▶ Market Mood Domain Entities
export '../../domain/entities/market_mood.dart'
    show
        MarketMood,
        VolumeData,
        MarketMoodData,
        ComparisonResult,
        ComparisonData,
        MarketMoodSystemState,
        VolumeConstants;

/// ▶ Sector 분류 관리 (shared layer)
export '../../shared/widgets/sector_classification.dart'
    show SectorClassificationProvider;

/// ▶ 전역 SnackBar key
final scaffoldMessengerKeyProvider =
    Provider<GlobalKey<ScaffoldMessengerState>>((ref) {
  return GlobalKey<ScaffoldMessengerState>();
});

/// ▶ BottomTab 인덱스
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// ▶ SignalBus 싱글턴
final signalBusProvider = Provider<SignalBus>((ref) {
  final bus = SignalBus();
  ref.onDispose(() => bus.dispose());
  return bus;
});