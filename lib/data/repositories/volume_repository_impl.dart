// lib/data/repositories/volume_repository_impl.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/volume.dart';
import '../../domain/repositories/volume_repository.dart';
import '../../domain/repositories/trade_repository.dart';

/// VolumeRepository - TradeRepository 구독하는 데이터 계층
class VolumeRepositoryImpl implements VolumeRepository {
  final TradeRepository _tradeRepository;

  bool _disposed = false;

  VolumeRepositoryImpl(this._tradeRepository);

  @override
  Stream<List<Volume>> watchVolumeByTimeFrame(String timeFrame, List<String> markets) {
    if (_disposed) {
      return const Stream.empty();
    }

    debugPrint('VolumeRepository: watchVolumeByTimeFrame() - $timeFrame, ${markets.length} markets');
    
    return _tradeRepository.watchTrades(markets)
        .map((trade) => <Volume>[])
        .asBroadcastStream();
  }

  @override
  void resetTimeFrame(String timeFrame) {
  }

  @override
  void resetAllTimeFrames() {
  }

  @override
  DateTime? getNextResetTime(String timeFrame) {
    return null;
  }

  @override
  List<String> getActiveTimeFrames() {
    return [];
  }

  @override
  bool isTimeFrameActive(String timeFrame) {
    return true;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    
    debugPrint('VolumeRepository: dispose() called');
    _disposed = true;
    
    debugPrint('VolumeRepository: dispose completed');
  }
}