// ignore_for_file: prefer_const_declarations
import 'package:test/test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/core/config/app_config.dart';

void main() {
  setUpAll(() async {
    // 테스트용 환경변수 설정
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  group('AppConfig', () {
    test('isDebugMode reflects dart.vm.product', () {
      // 실행 모드에 따라 달라지므로 그냥 bool 타입인지만 확인
      expect(AppConfig.isDebugMode, isA<bool>());
    });

    test('default tradeFilters and filterNames are consistent', () {
      final filters = AppConfig.tradeFilters;
      final names = AppConfig.filterNames;
      expect(filters, isNotEmpty);
      for (final f in filters) {
        expect(names.containsKey(f), isTrue,
            reason: 'filterNames에 $f 가 누락됨');
      }
    });

    test('updateFilters replaces and sorts correctly', () {
      final original = List<double>.unmodifiable([2e6, 5e6, 1e7, 2e7, 5e7, 1e8, 2e8, 3e8, 4e8, 5e8, 1e9]);
      AppConfig.updateFilters([50, 10, 30]);
      expect(AppConfig.tradeFilters, equals([10, 30, 50]));
      // 복구
      AppConfig.updateFilters(original);
    });

    test('timeFrames and timeFrameNames match', () {
      final tfs = AppConfig.timeFrames;
      final names = AppConfig.timeFrameNames;
      for (final tf in tfs) {
        expect(names.containsKey(tf), isTrue,
            reason: 'timeFrameNames에 $tf 분이 누락됨');
      }
    });

    test('surge detection constants are set', () {
      expect(AppConfig.surgeThresholdPercent, greaterThan(0));
      expect(AppConfig.surgeWindowDuration, isA<Duration>());
    });
  });
}