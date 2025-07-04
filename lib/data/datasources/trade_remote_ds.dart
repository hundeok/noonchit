// lib/data/datasources/trade_remote_ds.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/bridge/signal_bus.dart';
import '../../../core/event/app_event.dart';
import '../../../core/network/websocket/trade_ws_client.dart';
import '../models/trade_dto.dart';
import '../../domain/entities/trade.dart';

/// 🔄 리팩토링: 단순하고 깔끔한 Trade 데이터 소스
/// - BaseWsClient를 믿고 맡김
/// - 가짜 데이터 fallback 제거  
/// - 복잡한 구독자 관리 로직 제거
/// - 순수하게 "데이터 변환 + 브로드캐스팅"만 담당
class TradeRemoteDataSource {
  final TradeWsClient _ws;
  final SignalBus _signalBus;
  final bool _useTestData;

  // 🎯 핵심: 단순한 스트림 관리
  Stream<Trade>? _currentStream;
  List<String> _currentMarkets = [];
  bool _disposed = false;

  TradeRemoteDataSource(
    this._ws,
    this._signalBus, {
    bool useTestData = false,
  }) : _useTestData = useTestData;

  /// 🎯 핵심 메소드: 마켓이 바뀔 때만 새 스트림 생성
  Stream<Trade> watch(List<String> markets) {
    if (_disposed) {
      throw StateError('TradeRemoteDataSource has been disposed');
    }

    if (_useTestData) {
      return _testStream();
    }

    // 마켓이 바뀌면 새 스트림 생성
    if (!_marketsEqual(_currentMarkets, markets)) {
      debugPrint('TradeRemoteDataSource: Creating new stream for ${markets.length} markets');
      _currentMarkets = List.from(markets);
      _currentStream = _createTradeStream(markets);
    }

    return _currentStream!;
  }

  /// 🔥 고급: 순수성과 부수효과 분리
  Stream<Trade> _createTradeStream(List<String> markets) {
    // WebSocket 연결 시작 (비동기)
    _ws.connect(markets);
    
    // BaseWsClient의 스트림 사용
    return _ws.stream
        .expand((batch) => batch)              // List<Map> → Map
        .map(_parseToTradeDto)                 // Map → TradeDto? (순수 함수)
        .where((dto) => dto != null)           // null 필터링
        .cast<TradeDto>()                      // TradeDto? → TradeDto
        .transform(_sideEffectTransformer())   // 부수 효과 처리 (이벤트 발송)
        .map((dto) => dto.toEntity())          // TradeDto → Trade (순수 함수)
        .asBroadcastStream();                  // 여러 Repository 구독 가능
  }

  /// 🎯 순수 함수: 파싱만 담당 (부수 효과 없음)
  TradeDto? _parseToTradeDto(Map<String, dynamic> json) {
    try {
      return TradeDto.tryParse(json);
    } catch (e) {
      debugPrint('TradeRemoteDataSource: Parse error - $e');
      return null;
    }
  }

  /// 🎯 부수 효과 전용 Transformer: 데이터는 그대로 통과시키되 이벤트 발송
  StreamTransformer<TradeDto, TradeDto> _sideEffectTransformer() {
    return StreamTransformer.fromHandlers(
      handleData: (TradeDto dto, EventSink<TradeDto> sink) {
        // 🎯 부수 효과: SignalBus 이벤트 발송
        _signalBus.fireTradeEvent(AppEvent.now(dto.toMap()));
        
        // 데이터는 그대로 다음 단계로 전달
        sink.add(dto);
      },
      handleError: (error, stackTrace, EventSink<TradeDto> sink) {
        debugPrint('TradeRemoteDataSource: Stream error - $error');
        // 에러도 그대로 전파
        sink.addError(error, stackTrace);
      },
    );
  }

  /// 🎯 마켓 리스트 비교 (순서 무관)
  bool _marketsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = Set<String>.from(a);
    final setB = Set<String>.from(b);
    return setA.containsAll(setB) && setB.containsAll(setA);
  }

  /// 🧪 테스트 전용 스트림 (개발/디버그용)
  Stream<Trade> _testStream() async* {
    final rnd = Random();
    const symbols = [
      'KRW-BTC', 'KRW-ETH', 'KRW-XRP',
      'KRW-DOGE', 'KRW-SOL', 'KRW-ADA',
    ];

    while (!_disposed) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_disposed) break;

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final dto = TradeDto(
        market: symbols[rnd.nextInt(symbols.length)],
        price: (rnd.nextDouble() * 1000000 + 10000).roundToDouble(),
        volume: rnd.nextDouble() * 10,
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

  /// 🧹 리소스 정리
  Future<void> dispose() async {
    if (_disposed) return;
    
    _disposed = true;
    _currentStream = null;
    _currentMarkets.clear();
    
    debugPrint('TradeRemoteDataSource: disposed');
    // BaseWsClient는 TradeWsClient에서 관리하므로 여기서 dispose 안함
  }
}