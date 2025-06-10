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

/// ▶ Trade 화면 로직
export '../../presentation/controllers/trade_controller.dart'
    show tradeControllerProvider;

/// ▶ Volume DI & streams
export 'volume_provider.dart'
    show
        volumeRemoteDSProvider,
        volumeRepositoryProvider,
        volumeUsecaseProvider,
        volumeTimeFrameIndexProvider,
        volumeTimeFrameProvider,
        volumeDataProvider,
        volumeTimeFrameController;

/// ▶ Volume 화면 로직
export '../../presentation/controllers/volume_controller.dart'
    show volumeControllerProvider;

/// ▶ Sector DI & streams
export 'sector_provider.dart'
    show
        sectorClassificationProvider,
        sectorTimeFrameIndexProvider,
        sectorTimeFrameProvider,
        sectorVolumeDataProvider,
        sectorTimeFrameController;

/// ▶ Sector 화면 로직
export '../../presentation/controllers/sector_controller.dart'
    show sectorControllerProvider;

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