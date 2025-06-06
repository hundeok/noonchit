// test/core/extensions/result_test.dart

import 'package:test/test.dart';
import 'package:noonchit/core/extensions/result.dart';
import 'package:noonchit/core/error/app_exception.dart';

class MyException extends AppException {
  const MyException(String message) : super(message);
}

void main() {
  group('Result', () {
    test('Ok and Err construction and when()', () {
      const ok = Ok<int, AppException>(123);
      const err = Err<int, AppException>(AppException('bad'));

      expect(
        ok.when(ok: (v) => v * 2, err: (_) => 0),
        equals(246),
      );
      expect(
        err.when(ok: (_) => 1, err: (e) => -1),
        equals(-1),
      );
    });

    test('isOk, isErr, valueOrNull, errorOrNull', () {
      const ok = Ok<String, AppException>('hi');
      const err = Err<String, AppException>(AppException('oops'));

      expect(ok.isOk, isTrue);
      expect(ok.isErr, isFalse);
      expect(ok.valueOrNull, 'hi');
      expect(ok.errorOrNull, isNull);

      expect(err.isOk, isFalse);
      expect(err.isErr, isTrue);
      expect(err.valueOrNull, isNull);
      expect(err.errorOrNull, isA<AppException>());
    });

    test('map and mapErr', () {
      const ok = Ok<int, AppException>(2);
      final mappedOk = ok.map((v) => 'val$v');
      expect(mappedOk, isA<Ok<String, AppException>>());

      const err = Err<int, AppException>(AppException('x'));
      final mapErr = err.mapErr((e) => MyException(e.message));
      expect(mapErr, isA<Err<int, MyException>>());
    });

    test('thenAsync succeeds and fails properly', () async {
      const ok = Ok<int, AppException>(5);
      final nextOk = await ok.thenAsync((v) async => v * 3);
      expect(nextOk, isA<Ok<int, AppException>>());
      expect((nextOk as Ok<int, AppException>).value, equals(15));

      const err = Err<int, AppException>(AppException('fail'));
      final nextErr = await err.thenAsync((_) async => 1);
      expect(nextErr, isA<Err<int, AppException>>());
    });

    test('toString output', () {
      expect(const Ok<int, AppException>(10).toString(), 'Ok(10)');
      expect(
        const Err<int, AppException>(AppException('e')).toString(),
        'Err(AppException(message: e))',
      );
    });
  });
}
