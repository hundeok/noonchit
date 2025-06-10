// lib/data/datasources/market_mood_remote_ds.dart
// 🌐 Data Layer: 원격 데이터 소스 (안정성이 검증된 Timer 방식으로 복원)

import 'dart:async';
import '../../core/network/api_client_coingecko.dart';
import '../../core/utils/logger.dart';
import '../../data/models/market_mood_dto.dart';

/// 🌐 마켓무드 원격 데이터 소스
class MarketMoodRemoteDataSource {
  final CoinGeckoApiClient _apiClient;
  Timer? _globalDataTimer;
  StreamController<CoinGeckoGlobalDataDto>? _globalDataController;

  MarketMoodRemoteDataSource(this._apiClient);

  Stream<CoinGeckoGlobalDataDto> getGlobalMarketDataStream() {
    // 이미 스트림이 활성화된 경우 재사용
    if (_globalDataController != null && !_globalDataController!.isClosed) {
      return _globalDataController!.stream;
    }
    
    _globalDataController = StreamController<CoinGeckoGlobalDataDto>.broadcast();
    
    Future<void> fetch() async {
      try {
        final responseDto = await _apiClient.getGlobalMarketData();
        final dataDto = responseDto.data;

        if (_globalDataController != null && !_globalDataController!.isClosed) {
          _globalDataController!.add(dataDto);
          log.d('📊 글로벌 마켓 데이터 수신 성공 (Timer): ${dataDto.totalVolumeUsd.toStringAsFixed(0)}B USD');
        }
      } catch (e, st) {
        if (_globalDataController != null && !_globalDataController!.isClosed) {
          _globalDataController!.addError(e, st);
          log.e('❌ 글로벌 마켓 데이터 조회 실패 (Timer): $e');
        }
      }
    }

    // 첫 호출
    fetch();

    // 30분마다 호출
    _globalDataTimer = Timer.periodic(const Duration(minutes: 30), (_) => fetch());

    _globalDataController!.onCancel = () {
      _globalDataTimer?.cancel();
      _globalDataTimer = null;
      log.d('🔄 글로벌 마켓 데이터 스트림 리스너 없음. 타이머 중지.');
    };

    return _globalDataController!.stream;
  }

  Future<CoinGeckoGlobalDataDto> getGlobalMarketData() async {
    final responseDto = await _apiClient.getGlobalMarketData();
    return responseDto.data;
  }

  Future<double> getUsdToKrwRate() async {
    return _apiClient.getUsdToKrwRate();
  }

  Future<bool> checkApiHealth() async {
    try {
      await getGlobalMarketData();
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _globalDataTimer?.cancel();
    _globalDataTimer = null;
    _globalDataController?.close();
    _globalDataController = null;
    log.d('🧹 MarketMoodRemoteDataSource 정리 완료');
  }
}