import 'package:meta/meta.dart';
import '../error/app_exception.dart';

/// Either 스타일의 결과 타입.
///
/// - `Ok<T, E>`: 성공 시 데이터를 담습니다.
/// - `Err<T, E>`: 실패 시 예외를 담습니다.
@immutable
sealed class Result<T, E extends AppException> {
  const Result();

  /// 성공/실패에 따라 분기 처리합니다.
  R when<R>({
    required R Function(T value) ok,
    required R Function(E error) err,
  }) {
    if (this is Ok<T, E>) {
      return ok((this as Ok<T, E>).value);
    } else {
      return err((this as Err<T, E>).error);
    }
  }

  /// 성공 여부
  bool get isOk => this is Ok<T, E>;

  /// 실패 여부
  bool get isErr => this is Err<T, E>;

  /// 성공 값 (없으면 null)
  T? get valueOrNull => isOk ? (this as Ok<T, E>).value : null;

  /// 실패 예외 (없으면 null)
  E? get errorOrNull => isErr ? (this as Err<T, E>).error : null;

  /// 성공 값을 매핑합니다.
  Result<U, E> map<U>(U Function(T value) f) {
    if (this is Ok<T, E>) {
      return Ok<U, E>(f((this as Ok<T, E>).value));
    } else {
      return Err<U, E>((this as Err<T, E>).error);
    }
  }

  /// 실패 예외를 다른 타입으로 매핑합니다.
  /// 성공 시에도 새로운 에러 타입 F 를 사용하도록 합니다.
  Result<T, F> mapErr<F extends AppException>(F Function(E error) f) {
    if (this is Err<T, E>) {
      final err = (this as Err<T, E>).error;
      return Err<T, F>(f(err));
    }
    return Ok<T, F>((this as Ok<T, E>).value);
  }

  /// 성공 시 비동기 후속 작업을 수행합니다.
  Future<Result<U, E>> thenAsync<U>(Future<U> Function(T value) f) async {
    if (this is Ok<T, E>) {
      final T value = (this as Ok<T, E>).value;
      try {
        final u = await f(value);
        return Ok<U, E>(u);
      } on AppException catch (e) {
        final E errVal = e is E ? e : AppException(e.message) as E;
        return Err<U, E>(errVal);
      } catch (e) {
        final E errVal = AppException(e.toString()) as E;
        return Err<U, E>(errVal);
      }
    } else {
      return Err<U, E>((this as Err<T, E>).error);
    }
  }

  @override
  String toString() {
    if (this is Ok<T, E>) {
      return 'Ok(${(this as Ok<T, E>).value})';
    } else {
      return 'Err(${(this as Err<T, E>).error})';
    }
  }
}

/// 성공 결과를 담습니다.
class Ok<T, E extends AppException> extends Result<T, E> {
  final T value;
  const Ok(this.value);
}

/// 실패 결과를 담습니다.
class Err<T, E extends AppException> extends Result<T, E> {
  final E error;
  const Err(this.error);
}
