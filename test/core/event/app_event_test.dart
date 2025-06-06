// test/core/event/app_event_test.dart

import 'package:test/test.dart';
import 'package:noonchit/core/event/app_event.dart';

void main() {
  group('AppEvent', () {
    test('now() generates unique id and current ts', () {
      final e1 = AppEvent.now(const {'a': 1});
      final e2 = AppEvent.now(const {'b': 2});
      expect(e1.id, isNotEmpty);
      expect(e1.ts, isPositive);
      expect(e1.id, isNot(e2.id));
    });

    test('toJson and fromJson are inverse', () {
      final e = AppEvent.now(const {'x': 42});
      final json = e.toJson();
      final e2 = AppEvent.fromJson(json);
      expect(e2.id, e.id);
      expect(e2.ts, e.ts);
      expect(e2.payload, e.payload);
    });

    test('copyWith overrides fields', () {
      final orig = AppEvent.now(const {'v': 3});
      final copy = orig.copyWith(
        id: 'newid',
        ts: 123456,
        payload: const {'v': 4},
      );
      expect(copy.id, 'newid');
      expect(copy.ts, 123456);
      expect(copy.payload, const {'v': 4});

      // 원본 불변
      expect(orig.id, isNot('newid'));
    });

    test('equality and hashCode via Equatable', () {
      final e = AppEvent.now(const {'k': 'v'});
      final same = AppEvent(id: e.id, ts: e.ts, payload: e.payload);
      expect(e, equals(same));
      expect(e.hashCode, same.hashCode);
    });
  });
}
