import 'package:test/test.dart';
import 'package:logger/logger.dart';
import 'package:noonchit/core/config/app_config.dart';

void main() {
  setUp(() {
    // Logger.level 초기화
    Logger.level = AppConfig.isDebugMode ? Level.debug : Level.warning;
  });

  test('Logger.level matches AppConfig.isDebugMode', () {
    const expected = AppConfig.isDebugMode ? Level.debug : Level.warning;
    // ignore: avoid_print
    print('AppConfig.isDebugMode: ${AppConfig.isDebugMode}, Logger.level: ${Logger.level}'); // 디버깅
    expect(Logger.level, equals(expected));
  });
}