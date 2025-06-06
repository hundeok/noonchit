// lib/core/di/volume_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';
import 'app_providers.dart' show signalBusProvider;
import 'websocket_provider.dart' show wsClientProvider;
import 'trade_provider.dart' show marketsProvider; // 🎯 마켓 리스트 재사용
import '../../data/datasources/trade_remote_ds.dart';
import '../../data/repositories/volume_repository_impl.dart';
import '../../domain/repositories/volume_repository.dart';
import '../../domain/usecases/volume_usecase.dart'; // 🆕 UseCase import
import '../../domain/entities/volume.dart'; // 🆕 Volume 엔티티 import 추가!


// ═══════════════════════════════════════════════════════════════════════════════
// 🆕 VOLUME 전용 Provider들 (브로드캐스트 스트림 기반)
// ═══════════════════════════════════════════════════════════════════════════════

/// 🎯 볼륨 전용 RemoteDataSource (TradeRemoteDataSource와 동일한 인스턴스)
final volumeRemoteDSProvider = Provider<TradeRemoteDataSource>((ref) {
  return TradeRemoteDataSource(
    ref.read(wsClientProvider),
    ref.read(signalBusProvider),
    useTestData: AppConfig.useTestDataInDev,
  );
});

/// 🆕 VolumeRepository
final volumeRepositoryProvider = Provider<VolumeRepository>((ref) {
  return VolumeRepositoryImpl(
    ref.read(volumeRemoteDSProvider),
  );
});

/// 🆕 VolumeUsecase
final volumeUsecaseProvider = Provider<VolumeUsecase>((ref) {
  return VolumeUsecase(
    ref.read(volumeRepositoryProvider),
  );
});

/// 🆕 볼륨 시간대 상태 (기본값: 1분)
final volumeTimeFrameIndexProvider = StateProvider<int>((_) => 0); // 1분이 기본 (0:1m, 1:5m, 2:15m)

final volumeTimeFrameProvider = StateProvider<String>((ref) {
  final index = ref.watch(volumeTimeFrameIndexProvider);
  final timeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
  if (index >= 0 && index < timeFrames.length) {
    return timeFrames[index];
  }
  return '1m'; // fallback (기본값 1분)
});

/// 🆕 볼륨 데이터 스트림 (실시간 즉시 업데이트)
final volumeDataProvider = StreamProvider.autoDispose<List<Volume>>((ref) async* {
  // Prevent immediate dispose on loss of listeners
  ref.keepAlive();

  try {
    // 현재 시간대와 markets를 읽어서 스트림 구독
    final timeFrame = ref.watch(volumeTimeFrameProvider);
    final markets = await ref.watch(marketsProvider.future);
    final usecase = ref.read(volumeUsecaseProvider); // 🆕 UseCase 사용

    if (AppConfig.enableTradeLog) {
      log.i('Volume stream started: $timeFrame, ${markets.length} markets');
    }

    // 🚀 실시간 볼륨 데이터 스트림 방출 (UseCase를 통해)
    yield* usecase.getVolumeRanking(timeFrame, markets).map((result) {
      return result.when(
        ok: (volumes) => volumes,
        err: (error) {
          log.e('Volume UseCase error: ${error.message}');
          return <Volume>[]; // 에러 시 빈 리스트
        },
      );
    });
    
  } catch (e, stackTrace) {
    log.e('Volume stream error: $e', e, stackTrace);
    
    // 에러 시 빈 리스트 방출
    yield <Volume>[];
  }
});

/// 🆕 볼륨 시간대 컨트롤러
final volumeTimeFrameController = Provider((ref) => VolumeTimeFrameController(ref));

class VolumeTimeFrameController {
  final Ref ref;
  VolumeTimeFrameController(this.ref);

  void updateTimeFrame(String timeFrame, int index) {
    final timeFrames = AppConfig.timeFrames.map((tf) => '${tf}m').toList();
    if (index < 0 || index >= timeFrames.length) {
      if (AppConfig.enableTradeLog) log.w('Invalid timeFrame index: $index');
      return;
    }
    
    ref.read(volumeTimeFrameProvider.notifier).state = timeFrame;
    ref.read(volumeTimeFrameIndexProvider.notifier).state = index;
    
    if (AppConfig.enableTradeLog) {
      log.i('Volume TimeFrame updated: $timeFrame (index: $index)');
    }
  }

  /// 수동 리셋 메서드들 (UseCase를 통해)
  void resetCurrentTimeFrame() {
    final usecase = ref.read(volumeUsecaseProvider);
    final timeFrame = ref.read(volumeTimeFrameProvider);
    
    final result = usecase.resetTimeFrame(timeFrame);
    result.when(
      ok: (_) {
        if (AppConfig.enableTradeLog) {
          log.i('Volume reset: $timeFrame');
        }
      },
      err: (error) {
        log.e('Volume reset failed: ${error.message}');
      },
    );
  }

  void resetAllTimeFrames() {
    final usecase = ref.read(volumeUsecaseProvider);
    
    final result = usecase.resetAllTimeFrames();
    result.when(
      ok: (_) {
        if (AppConfig.enableTradeLog) {
          log.i('Volume reset: all timeframes');
        }
      },
      err: (error) {
        log.e('Volume reset all failed: ${error.message}');
      },
    );
  }

  /// 다음 리셋 시간 조회 (UseCase를 통해)
  DateTime? getNextResetTime() {
    final usecase = ref.read(volumeUsecaseProvider);
    final timeFrame = ref.read(volumeTimeFrameProvider);
    
    final result = usecase.getNextResetTime(timeFrame);
    return result.when(
      ok: (resetTime) => resetTime,
      err: (error) {
        log.e('Get reset time failed: ${error.message}');
        return null;
      },
    );
  }

  /// Getters
  String get currentTimeFrame => ref.read(volumeTimeFrameProvider);
  int get currentIndex => ref.read(volumeTimeFrameIndexProvider);
  List<String> get availableTimeFrames => AppConfig.timeFrames.map((tf) => '${tf}m').toList();
  
  /// 시간대 한국어 이름
  String getTimeFrameName(String timeFrame) {
    final minutes = int.tryParse(timeFrame.replaceAll('m', ''));
    return AppConfig.timeFrameNames[minutes] ?? timeFrame;
  }
}