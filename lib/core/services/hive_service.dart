// lib/core/services/hive_service.dart

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/logger.dart';
import '../../data/models/trade_dto.dart';
import '../../data/models/market_mood_dto.dart'; // 🔥 MarketMood DTO 추가

/// 🎯 Hive 전역 관리 서비스 (싱글톤)
/// - 앱 시작 시 한 번만 초기화
/// - 모든 TypeAdapter 등록 및 Box 관리
/// - 백그라운드에서도 Box 유지 (닫지 않음)
/// - AppConfig에 의존하지 않는 완전 독립 서비스
class HiveService {
  // 싱글톤 패턴
  HiveService._();
  static final HiveService _instance = HiveService._();
  factory HiveService() => _instance;

  // 🏷️ Box 이름 상수 (HiveService 자체 관리)
  static const String _tradeBoxName = 'trades';
  static const String _marketMoodVolumeBoxName = 'market_mood_volume'; // 🔥 추가
  static const String _marketMoodCacheBoxName = 'market_mood_cache';   // 🔥 추가

  // Box 인스턴스 캐싱
  late final Box<TradeDto> _tradeBox;
  late final Box<TimestampedVolume> _marketMoodVolumeBox; // 🔥 추가
  late final Box _marketMoodCacheBox; // 🔥 추가 (dynamic)
  
  // 초기화 상태 관리
  bool _initialized = false;
  Future<void>? _initFuture;

  /// 🎯 Trade Box getter (이미 열려있다는 전제)
  Box<TradeDto> get tradeBox {
    if (!_initialized) {
      throw StateError(
        'HiveService has not been initialized. Call HiveService.init() before using tradeBox.'
      );
    }
    return _tradeBox;
  }

  /// 🔥 MarketMood Volume Box getter (이미 열려있다는 전제)
  Box<TimestampedVolume> get marketMoodVolumeBox {
    if (!_initialized) {
      throw StateError(
        'HiveService has not been initialized. Call HiveService.init() before using marketMoodVolumeBox.'
      );
    }
    return _marketMoodVolumeBox;
  }

  /// 🔥 MarketMood Cache Box getter (이미 열려있다는 전제)
  Box get marketMoodCacheBox {
    if (!_initialized) {
      throw StateError(
        'HiveService has not been initialized. Call HiveService.init() before using marketMoodCacheBox.'
      );
    }
    return _marketMoodCacheBox;
  }

  /// 🚀 Hive 초기화 (앱 시작 시 단 한 번만 호출)
  Future<void> init() async {
    if (_initialized) {
      log.i('[HiveService] already initialized, skipping');
      return;
    }

    // 동시 호출 방어 - race condition 완전 차단
    if (_initFuture != null) {
      log.d('[HiveService] init already in progress, waiting...');
      return _initFuture;
    }

    _initFuture = _doInit();
    await _initFuture;
  }

  /// 🔧 실제 초기화 로직
  Future<void> _doInit() async {
    try {
      // 1. Hive 플랫폼 초기화
      await Hive.initFlutter();
      log.i('[HiveService] Hive.initFlutter() completed');

      // 2. TypeAdapter 등록 (중복 방지)
      _registerAdapters();

      // 3. 모든 Box 열기 및 캐싱
      _tradeBox = await Hive.openBox<TradeDto>(_tradeBoxName);
      log.i('[HiveService] "$_tradeBoxName" box opened and cached');

      _marketMoodVolumeBox = await Hive.openBox<TimestampedVolume>(_marketMoodVolumeBoxName); // 🔥 추가
      log.i('[HiveService] "$_marketMoodVolumeBoxName" box opened and cached');

      _marketMoodCacheBox = await Hive.openBox(_marketMoodCacheBoxName); // 🔥 추가
      log.i('[HiveService] "$_marketMoodCacheBoxName" box opened and cached');

      _initialized = true;
      log.i('[HiveService] ✅ initialized successfully');
      
    } catch (e, st) {
      log.e('[HiveService] ❌ init failed', e, st);
      _initialized = false;
      rethrow; // 초기화 실패 시 상위에서 처리할 수 있도록
    } finally {
      // 초기화 완료 후 Future 해제 (재시도 가능하도록)
      _initFuture = null;
    }
  }

  /// 📋 모든 TypeAdapter 등록 (중복 방지)
  void _registerAdapters() {
    // Trade Adapter
    final tradeAdapter = TradeDtoAdapter();
    if (!Hive.isAdapterRegistered(tradeAdapter.typeId)) {
      Hive.registerAdapter(tradeAdapter);
      log.i('[HiveService] TradeDtoAdapter registered (typeId: ${tradeAdapter.typeId})');
    } else {
      log.d('[HiveService] TradeDtoAdapter already registered');
    }
    
    // 🔥 TimestampedVolume Adapter 추가
    final volumeAdapter = TimestampedVolumeAdapter();
    if (!Hive.isAdapterRegistered(volumeAdapter.typeId)) {
      Hive.registerAdapter(volumeAdapter);
      log.i('[HiveService] TimestampedVolumeAdapter registered (typeId: ${volumeAdapter.typeId})');
    } else {
      log.d('[HiveService] TimestampedVolumeAdapter already registered');
    }
    
    // 📝 향후 다른 어댑터 추가 시 여기에 추가
  }

  /// 🧹 리소스 정리 (디버그 모드에서만 실행)
  /// 일반적으로 모바일 앱에서는 OS가 자동 정리하므로 호출 불필요
  Future<void> dispose() async {
    if (!kDebugMode) {
      log.d('[HiveService] dispose skipped in production mode');
      return;
    }
    
    if (!_initialized) {
      log.d('[HiveService] not initialized, skip dispose');
      return;
    }

    try {
      if (_tradeBox.isOpen) {
        await _tradeBox.close();
        log.i('[HiveService] "$_tradeBoxName" box closed');
      }

      // 🔥 MarketMood Box들 정리 추가
      if (_marketMoodVolumeBox.isOpen) {
        await _marketMoodVolumeBox.close();
        log.i('[HiveService] "$_marketMoodVolumeBoxName" box closed');
      }

      if (_marketMoodCacheBox.isOpen) {
        await _marketMoodCacheBox.close();
        log.i('[HiveService] "$_marketMoodCacheBoxName" box closed');
      }

      await Hive.close();
      log.i('[HiveService] 🧹 all Hive resources disposed');
      
    } catch (e, st) {
      log.e('[HiveService] dispose failed', e, st);
    } finally {
      _initialized = false;
    }
  }

  /// 🔍 디버깅용: 현재 상태 정보
  Map<String, Object> get debugInfo => {
    'initialized': _initialized,
    'tradeBox': {
      'name': _tradeBoxName,
      'open': _initialized ? _tradeBox.isOpen : false,
      'length': _initialized ? _tradeBox.length : 0,
    },
    'marketMoodVolumeBox': { // 🔥 추가
      'name': _marketMoodVolumeBoxName,
      'open': _initialized ? _marketMoodVolumeBox.isOpen : false,
      'length': _initialized ? _marketMoodVolumeBox.length : 0,
    },
    'marketMoodCacheBox': { // 🔥 추가
      'name': _marketMoodCacheBoxName,
      'open': _initialized ? _marketMoodCacheBox.isOpen : false,
      'length': _initialized ? _marketMoodCacheBox.length : 0,
    },
    'initInProgress': _initFuture != null,
  };

  /// 🔍 디버깅용: 상태 로깅
  void logStatus() {
    log.d('[HiveService] Status: $debugInfo');
  }

  /// 🔍 디버깅용: Box 상세 정보 (개발 시 유용)
  void logBoxDetails() {
    if (!_initialized) {
      log.w('[HiveService] Cannot log box details - not initialized');
      return;
    }
    
    log.d('[HiveService] Box Details:');
    log.d('  Trade Box:');
    log.d('    - Name: $_tradeBoxName');
    log.d('    - Length: ${_tradeBox.length}');
    log.d('    - Keys sample: ${_tradeBox.keys.take(5).toList()}');
    log.d('    - Is open: ${_tradeBox.isOpen}');
    
    // 🔥 MarketMood Box 정보 추가
    log.d('  MarketMood Volume Box:');
    log.d('    - Name: $_marketMoodVolumeBoxName');
    log.d('    - Length: ${_marketMoodVolumeBox.length}');
    log.d('    - Keys sample: ${_marketMoodVolumeBox.keys.take(5).toList()}');
    log.d('    - Is open: ${_marketMoodVolumeBox.isOpen}');
    
    log.d('  MarketMood Cache Box:');
    log.d('    - Name: $_marketMoodCacheBoxName');
    log.d('    - Length: ${_marketMoodCacheBox.length}');
    log.d('    - Keys sample: ${_marketMoodCacheBox.keys.take(5).toList()}');
    log.d('    - Is open: ${_marketMoodCacheBox.isOpen}');
  }
}