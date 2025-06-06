import 'package:test/test.dart';
import 'package:noonchit/core/utils/date_time.dart';

void main() {
  group('DateTimeX', () {
    test('hhmmss formats correctly', () {
      final dt = DateTime(2024, 5, 17, 22, 5, 1);
      expect(dt.hhmmss(), '22:05:01');
    });

    test('fromEpochMs converts UTC ms to local DateTime', () {
      final msUtc = DateTime.utc(2020, 1, 1, 0, 0, 0).millisecondsSinceEpoch;
      final dtLocal = DateTimeX.fromEpochMs(msUtc);
      final expected = DateTime.fromMillisecondsSinceEpoch(msUtc, isUtc: true).toLocal();
      expect(dtLocal, expected);
    });

    test('parseIso8601 parses Zulu ISO string to local DateTime', () {
      const iso = '2024-05-17T22:05:01Z';
      final parsed = DateTimeX.parseIso8601(iso);
      final expected = DateTime.parse(iso).toLocal();
      expect(parsed, expected);
    });
  });
}