// lib/data/datasources/trade_remote_ds.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/bridge/signal_bus.dart';
import '../../../core/event/app_event.dart';
import '../../../core/network/websocket/trade_ws_client.dart';
import '../models/trade_dto.dart';
import '../../domain/entities/trade.dart';

/// Fetches a live trade stream; on error falls back to synthetic data.
/// 🆕 브로드캐스트 지원으로 여러 Repository가 동일한 스트림 구독 가능
class TradeRemoteDataSource {
  final TradeWsClient _ws;
  final SignalBus _signalBus;
  final bool _useTestData;

  // 🆕 브로드캐스트 시스템
  StreamController<Trade>? _masterController;
  StreamSubscription<List<Map<String, dynamic>>>? _wsSub;
  bool _disposed = false;
  List<String>? _currentMarkets; // 현재 구독 중인 마켓들
  int _subscriberCount = 0; // 구독자 수 추적

  TradeRemoteDataSource(
    this._ws,
    this._signalBus, {
    bool useTestData = false,
  }) : _useTestData = useTestData;

  /// 🆕 브로드캐스트 스트림 제공 - 여러 Repository가 구독 가능
  Stream<Trade> watch(List<String> markets) {
    if (_useTestData) return _testStream();

    // dispose 후 재사용 가능하도록 초기화
    if (_disposed) {
      debugPrint('TradeRemoteDataSource: resetting after dispose');
      _disposed = false;
    }

    // 🆕 동일한 마켓이면 기존 스트림 재사용
    if (_masterController != null && 
        _currentMarkets != null && 
        _marketsEqual(_currentMarkets!, markets)) {
      debugPrint('TradeRemoteDataSource: reusing existing broadcast stream for ${markets.length} markets');
      return _masterController!.stream;
    }

    // 🆕 새로운 마켓이면 기존 스트림 정리하고 새로 생성
    _cleanupMasterStream();
    _initializeMasterStream(markets);

    return _masterController!.stream;
  }

  /// 🆕 마스터 브로드캐스트 스트림 초기화
  void _initializeMasterStream(List<String> markets) {
    debugPrint('TradeRemoteDataSource: initializing master broadcast stream for ${markets.length} markets');
    
    _currentMarkets = List<String>.from(markets);
    
    _masterController = StreamController<Trade>.broadcast(
      onListen: () {
        _subscriberCount++;
        debugPrint('TradeRemoteDataSource: subscriber added (total: $_subscriberCount)');
        
        // 첫 번째 구독자일 때만 WebSocket 시작
        if (_subscriberCount == 1 && !_disposed) {
          _startWebSocket(markets);
        }
      },
      onCancel: () {
        _subscriberCount--;
        debugPrint('TradeRemoteDataSource: subscriber removed (remaining: $_subscriberCount)');
        
        // 모든 구독자가 떠나면 WebSocket 정리 (즉시는 아니고 잠시 대기)
        if (_subscriberCount <= 0) {
          Timer(const Duration(seconds: 5), () {
            if (_subscriberCount <= 0 && !_disposed) {
              debugPrint('TradeRemoteDataSource: no subscribers, cleaning up WebSocket');
              _cleanupWebSocket();
            }
          });
        }
      },
    );
  }

  /// 🆕 WebSocket 연결 시작
  Future<void> _startWebSocket(List<String> markets) async {
    if (_disposed) return;

    try {
      debugPrint('TradeRemoteDataSource: starting WebSocket for ${markets.length} markets');
      
      await _ws.connect(markets);
      _wsSub = _ws.stream.listen(
        (rawBatch) {
          // controller가 닫혔거나 disposed면 처리 안함
          if (_disposed || _masterController == null || _masterController!.isClosed) {
            debugPrint('TradeRemoteDataSource: skipping data - disposed or closed');
            return;
          }

          for (final item in rawBatch) {
            final dto = TradeDto.tryParse(item);
            if (dto == null) continue;
            final entity = dto.toEntity();
            
            // 🆕 마스터 컨트롤러에 브로드캐스트
            if (!_disposed && _masterController != null && !_masterController!.isClosed) {
              _masterController!.add(entity);
            }

            // dispatch as AppEvent with metadata
            final event = AppEvent.now(dto.toMap());
            _signalBus.fireTradeEvent(event);
          }
        },
        onError: (error, stackTrace) {
          debugPrint('WebSocket error: $error');
          if (!_disposed && _masterController != null && !_masterController!.isClosed) {
            _masterController!.addStream(_testStream());
          }
        },
        onDone: () {
          debugPrint('WebSocket done');
          if (!_disposed && _masterController != null && !_masterController!.isClosed) {
            _masterController!.addStream(_testStream());
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('WS connection failed: $e');
      if (!_disposed && _masterController != null && !_masterController!.isClosed) {
        _masterController!.addStream(_testStream());
      }
    }
  }

  /// 🆕 WebSocket만 정리 (컨트롤러는 유지)
  void _cleanupWebSocket() {
    debugPrint('TradeRemoteDataSource: cleaning up WebSocket');
    _wsSub?.cancel();
    _wsSub = null;
  }

  /// 🆕 마스터 스트림 완전 정리
  void _cleanupMasterStream() {
    debugPrint('TradeRemoteDataSource: cleaning up master stream');
    
    _cleanupWebSocket();
    
    if (_masterController != null && !_masterController!.isClosed) {
      _masterController!.close();
    }
    _masterController = null;
    _currentMarkets = null;
    _subscriberCount = 0;
  }

  /// 🆕 마켓 리스트 비교 헬퍼
  bool _marketsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = Set<String>.from(a);
    final setB = Set<String>.from(b);
    return setA.containsAll(setB) && setB.containsAll(setA);
  }

  /// Synthetic fallback stream for dev/test.
  Stream<Trade> _testStream() async* {
    final rnd = Random();
    const symbols = [
      'KRW-BTC', 'KRW-ETH', 'KRW-XRP',
      'KRW-DOGE', 'KRW-SOL', 'KRW-ADA',
      'KRW-LINK', 'KRW-DOT', 'KRW-AVAX',
      'KRW-MATIC',
    ];

    while (!_disposed) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_disposed) break;
      
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final dto = TradeDto(
        market: symbols[rnd.nextInt(symbols.length)],
        price: (rnd.nextDouble() * 1000).roundToDouble(),
        volume: rnd.nextDouble(),
        side: rnd.nextBool() ? 'BID' : 'ASK',
        changePrice: 0.0,
        changeState: 'EVEN',
        timestampMs: nowMs,
        sequentialId: 'test-$nowMs-${rnd.nextInt(1000)}',
      );
      yield dto.toEntity();
      _signalBus.fireTradeEvent(AppEvent.now(dto.toMap()));
    }
  }

  /// Clean up resources when no longer needed.
  Future<void> dispose() async {
    if (_disposed) return;
    
    _disposed = true;
    
    debugPrint('TradeRemoteDataSource: disposing...');
    
    // 모든 리소스 정리
    _cleanupMasterStream();
    
    debugPrint('TradeRemoteDataSource: disposed');
    
    // do not dispose shared ws client here
  }
}