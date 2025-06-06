// test/domain/entities/app_settings_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/domain/entities/app_settings.dart';

void main() {
  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  group('AppSettings', () {
    group('constructor and defaults', () {
      test('should have correct default values', () {
        const settings = AppSettings();

        expect(settings.themeMode, ThemeMode.system);
        expect(settings.keepScreenOn, false);
        expect(settings.sliderPosition, SliderPosition.top);
      });

      test('should accept custom values', () {
        const settings = AppSettings(
          themeMode: ThemeMode.dark,
          keepScreenOn: true,
          sliderPosition: SliderPosition.bottom,
        );

        expect(settings.themeMode, ThemeMode.dark);
        expect(settings.keepScreenOn, true);
        expect(settings.sliderPosition, SliderPosition.bottom);
      });

      test('should support partial initialization', () {
        const settings1 = AppSettings(themeMode: ThemeMode.light);
        const settings2 = AppSettings(keepScreenOn: true);
        const settings3 = AppSettings(sliderPosition: SliderPosition.bottom);

        expect(settings1.themeMode, ThemeMode.light);
        expect(settings1.keepScreenOn, false);
        expect(settings1.sliderPosition, SliderPosition.top);

        expect(settings2.themeMode, ThemeMode.system);
        expect(settings2.keepScreenOn, true);
        expect(settings2.sliderPosition, SliderPosition.top);

        expect(settings3.themeMode, ThemeMode.system);
        expect(settings3.keepScreenOn, false);
        expect(settings3.sliderPosition, SliderPosition.bottom);
      });
    });

    group('copyWith', () {
      const originalSettings = AppSettings(
        themeMode: ThemeMode.dark,
        keepScreenOn: true,
        sliderPosition: SliderPosition.bottom,
      );

      test('should return copy with updated themeMode', () {
        final updated = originalSettings.copyWith(themeMode: ThemeMode.light);

        expect(updated.themeMode, ThemeMode.light);
        expect(updated.keepScreenOn, true); // 변경되지 않음
        expect(updated.sliderPosition, SliderPosition.bottom); // 변경되지 않음
      });

      test('should return copy with updated keepScreenOn', () {
        final updated = originalSettings.copyWith(keepScreenOn: false);

        expect(updated.themeMode, ThemeMode.dark); // 변경되지 않음
        expect(updated.keepScreenOn, false);
        expect(updated.sliderPosition, SliderPosition.bottom); // 변경되지 않음
      });

      test('should return copy with updated sliderPosition', () {
        final updated = originalSettings.copyWith(sliderPosition: SliderPosition.top);

        expect(updated.themeMode, ThemeMode.dark); // 변경되지 않음
        expect(updated.keepScreenOn, true); // 변경되지 않음
        expect(updated.sliderPosition, SliderPosition.top);
      });

      test('should return copy with multiple updated values', () {
        final updated = originalSettings.copyWith(
          themeMode: ThemeMode.system,
          keepScreenOn: false,
        );

        expect(updated.themeMode, ThemeMode.system);
        expect(updated.keepScreenOn, false);
        expect(updated.sliderPosition, SliderPosition.bottom); // 변경되지 않음
      });

      test('should return copy with all updated values', () {
        final updated = originalSettings.copyWith(
          themeMode: ThemeMode.light,
          keepScreenOn: false,
          sliderPosition: SliderPosition.top,
        );

        expect(updated.themeMode, ThemeMode.light);
        expect(updated.keepScreenOn, false);
        expect(updated.sliderPosition, SliderPosition.top);
      });

      test('should return identical copy when no parameters provided', () {
        final updated = originalSettings.copyWith();

        expect(updated.themeMode, originalSettings.themeMode);
        expect(updated.keepScreenOn, originalSettings.keepScreenOn);
        expect(updated.sliderPosition, originalSettings.sliderPosition);
        expect(updated, equals(originalSettings));
      });

      test('should not modify original instance', () {
        const original = AppSettings(
          themeMode: ThemeMode.dark,
          keepScreenOn: true,
          sliderPosition: SliderPosition.bottom,
        );

        final updated = original.copyWith(
          themeMode: ThemeMode.light,
          keepScreenOn: false,
          sliderPosition: SliderPosition.top,
        );

        // 원본은 변경되지 않아야 함
        expect(original.themeMode, ThemeMode.dark);
        expect(original.keepScreenOn, true);
        expect(original.sliderPosition, SliderPosition.bottom);

        // 새 인스턴스는 업데이트된 값을 가져야 함
        expect(updated.themeMode, ThemeMode.light);
        expect(updated.keepScreenOn, false);
        expect(updated.sliderPosition, SliderPosition.top);
      });
    });

    group('Equatable', () {
      test('should be equal when all properties are same', () {
        const settings1 = AppSettings(
          themeMode: ThemeMode.dark,
          keepScreenOn: true,
          sliderPosition: SliderPosition.bottom,
        );
        const settings2 = AppSettings(
          themeMode: ThemeMode.dark,
          keepScreenOn: true,
          sliderPosition: SliderPosition.bottom,
        );

        expect(settings1, equals(settings2));
        expect(settings1.hashCode, equals(settings2.hashCode));
      });

      test('should not be equal when themeMode differs', () {
        const settings1 = AppSettings(themeMode: ThemeMode.dark);
        const settings2 = AppSettings(themeMode: ThemeMode.light);

        expect(settings1, isNot(equals(settings2)));
      });

      test('should not be equal when keepScreenOn differs', () {
        const settings1 = AppSettings(keepScreenOn: true);
        const settings2 = AppSettings(keepScreenOn: false);

        expect(settings1, isNot(equals(settings2)));
      });

      test('should not be equal when sliderPosition differs', () {
        const settings1 = AppSettings(sliderPosition: SliderPosition.top);
        const settings2 = AppSettings(sliderPosition: SliderPosition.bottom);

        expect(settings1, isNot(equals(settings2)));
      });

      test('should have correct props', () {
        const settings = AppSettings(
          themeMode: ThemeMode.dark,
          keepScreenOn: true,
          sliderPosition: SliderPosition.bottom,
        );

        expect(settings.props, [
          ThemeMode.dark,
          true,
          SliderPosition.bottom,
        ]);
      });

      test('should work correctly with default values', () {
        const settings1 = AppSettings();
        const settings2 = AppSettings();

        expect(settings1, equals(settings2));
        expect(settings1.props, [
          ThemeMode.system,
          false,
          SliderPosition.top,
        ]);
      });
    });

    group('SliderPosition enum', () {
      test('should have correct values', () {
        expect(SliderPosition.values, [SliderPosition.top, SliderPosition.bottom]);
      });

      test('should be usable in switch statements', () {
        String getPositionName(SliderPosition position) {
          switch (position) {
            case SliderPosition.top:
              return 'top';
            case SliderPosition.bottom:
              return 'bottom';
          }
        }

        expect(getPositionName(SliderPosition.top), 'top');
        expect(getPositionName(SliderPosition.bottom), 'bottom');
      });
    });

    group('edge cases', () {
      test('should handle all ThemeMode values', () {
        const systemSettings = AppSettings(themeMode: ThemeMode.system);
        const lightSettings = AppSettings(themeMode: ThemeMode.light);
        const darkSettings = AppSettings(themeMode: ThemeMode.dark);

        expect(systemSettings.themeMode, ThemeMode.system);
        expect(lightSettings.themeMode, ThemeMode.light);
        expect(darkSettings.themeMode, ThemeMode.dark);
      });

      test('should handle copyWith with same values', () {
        const original = AppSettings(
          themeMode: ThemeMode.dark,
          keepScreenOn: true,
          sliderPosition: SliderPosition.bottom,
        );

        final updated = original.copyWith(
          themeMode: ThemeMode.dark, // 같은 값
          keepScreenOn: true, // 같은 값
          sliderPosition: SliderPosition.bottom, // 같은 값
        );

        expect(updated, equals(original));
        expect(updated.themeMode, ThemeMode.dark);
        expect(updated.keepScreenOn, true);
        expect(updated.sliderPosition, SliderPosition.bottom);
      });
    });
  });
}