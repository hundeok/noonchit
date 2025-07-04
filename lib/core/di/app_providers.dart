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

/// ▶ Volume DI & streams
export 'volume_provider.dart'
show
volumeRepositoryProvider,
volumeUsecaseProvider,
volumeTimeFrameIndexProvider,
volumeTimeFrameProvider,
volumeDataProvider,
volumeTimeFrameController;

/// ▶ Surge DI & streams
export 'surge_provider.dart'
show
surgeRepositoryProvider,
surgeUsecaseProvider,
surgeTimeFrameIndexProvider,
surgeTimeFrameProvider,
surgeDataProvider,
surgeTimeFrameController;

/// ▶ Sector DI & streams
export 'sector_provider.dart'
show
sectorClassificationProvider,
sectorTimeFrameIndexProvider,
sectorTimeFrameProvider,
sectorVolumeDataProvider,
sectorTimeFrameController;

/// ▶ Signal DI & streams (V4.1 Online)
export 'signal_provider.dart'
show
// 🔥 V4.1 의존성 주입
advancedMetricsProvider,
patternConfigProvider,
patternDetectorProvider,
signalRepoProvider,
signalUsecaseProvider,
// 🎯 상태 관리
signalPatternIndexProvider,
signalPatternTypeProvider,
signalThresholdProvider,
signalPatternEnabledProvider,
// 🔥 스트림 (온라인 지표 연동)
signalListProvider,
allSignalsProvider,
// 🆕 V4.1 모니터링
onlineMetricsHealthProvider,
systemPerformanceProvider,
// 🎮 V4.1 컨트롤러
signalPatternController,
SignalPatternControllerV4,
// 🛠️ StateNotifier
PatternConfigNotifier,
// 🔍 디버깅
debugSystemStatusProvider;

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