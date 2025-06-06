// lib/core/di/app_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../bridge/signal_bus.dart';

/// ▶ App lifecycle (sliderPositionProvider 제거됨)
export '../utils/app_life_cycle_manager.dart'
    show appLifecycleManagerProvider;

/// ▶ Settings DI + state (settingsProvider → appSettingsProvider)
export 'settings_provider.dart'
    show
        sharedPreferencesProvider,
        settingsLocalDSProvider,
        settingsRepositoryProvider,
        settingsUsecaseProvider,
        appSettingsProvider; // 🔧 이름 변경!

/// ▶ Domain entities (DisplayMode 등 enum export)
export '../../domain/entities/app_settings.dart'
    show
        DisplayMode, // 🆕 DisplayMode enum export
        SliderPosition; // 기존 SliderPosition도 명시적 export

/// ▶ WebSocket DI & stats (🆕 새로 추가)
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

/// ▶ 🆕 Volume DI & streams (독립적)
export 'volume_provider.dart'
    show
        volumeRemoteDSProvider,
        volumeRepositoryProvider,
        volumeUsecaseProvider, // 🆕 UseCase 추가
        volumeTimeFrameIndexProvider,
        volumeTimeFrameProvider,
        volumeDataProvider,
        volumeTimeFrameController;

/// ▶ 🆕 Volume 화면 로직
export '../../presentation/controllers/volume_controller.dart'
    show volumeControllerProvider;

/// ▶ 🆕 Sector DI & streams (독립적)
export 'sector_provider.dart'
    show
        sectorClassificationProvider,
        sectorTimeFrameIndexProvider,
        sectorTimeFrameProvider,
        sectorVolumeDataProvider,
        sectorTimeFrameController;

/// ▶ 🆕 Sector 화면 로직
export '../../presentation/controllers/sector_controller.dart'
    show sectorControllerProvider;

/// ▶ 🆕 Market Mood DI & streams (CoinGecko API 기반)
export 'market_mood_provider.dart'
    show
        coinGeckoApiClientProvider,
        marketMoodProvider,
        currentMarketMoodProvider,
        marketMoodStateProvider,
        MarketMood,
        MarketMoodData,
        MarketMoodCalculator;

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
/// Riverpod이 dispose 시점에 자동으로 SignalBus.dispose() 호출
final signalBusProvider = Provider<SignalBus>((ref) {
  final bus = SignalBus();
  ref.onDispose(() => bus.dispose());
  return bus;
});