import 'dart:async';
import 'package:test/test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/core/bridge/signal_bus.dart';
import 'package:noonchit/core/event/app_event.dart';

void main() {
  setUpAll(() async {
    // 테스트용 환경변수 설정
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  group('SignalBus', () {
    final bus = SignalBus();

    tearDown(() {
      // 모든 스트림 리스너 제거
    });

    test('fireTrade emits on events and eventsOfType', () async {
      final all = <Map<String, dynamic>>[];
      final typed = <Map<String, dynamic>>[];
      final subAll = bus.events.listen(all.add);
      final subType = bus.eventsOfType(SignalEventType.trade).listen(typed.add);

      bus.fireTrade({'foo': 'bar'}, platform: ExchangePlatform.binance);

      // 이벤트 전파 대기
      await Future.delayed(Duration.zero);

      expect(all, hasLength(1));
      expect(typed, hasLength(1));
      expect(all.first['foo'], 'bar');
      expect(all.first['platform'], 'binance');

      await subAll.cancel();
      await subType.cancel();
    });

    test('fireTradeEvent preserves id and ts from AppEvent', () async {
      final nowPayload = {'x': 1};
      final event = AppEvent.now(nowPayload);
      final received = <Map<String, dynamic>>[];
      final sub = bus.eventsOfType(SignalEventType.trade).listen(received.add);

      bus.fireTradeEvent(event, platform: ExchangePlatform.upbit);
      await Future.delayed(Duration.zero);

      expect(received, hasLength(1));
      final json = received.first;
      expect(json['id'], event.id);
      expect(json['ts'], event.ts);
      expect(json['payload'], event.payload);

      await sub.cancel();
    });

    test('eventsOfPlatform filters by platform', () async {
      final got = <Map<String, dynamic>>[];
      final sub = bus
          .eventsOfPlatform(SignalEventType.notification, ExchangePlatform.bybit)
          .listen(got.add);

      bus.fireNotification({'a': 1}, platform: ExchangePlatform.upbit);
      bus.fireNotification({'b': 2}, platform: ExchangePlatform.bybit);
      await Future.delayed(Duration.zero);

      expect(got, hasLength(1));
      expect(got.first['b'], 2);

      await sub.cancel();
    });
  });
}