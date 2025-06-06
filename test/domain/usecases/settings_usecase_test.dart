// test/domain/usecases/settings_usecase_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/domain/entities/app_settings.dart';
import 'package:noonchit/domain/repositories/settings_repository.dart';
import 'package:noonchit/domain/usecases/settings_usecase.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late SettingsUsecase usecase;
  late MockSettingsRepository mockRepo;

  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
    registerFallbackValue(ThemeMode.system);
    registerFallbackValue(SliderPosition.top);
  });

  setUp(() {
    mockRepo = MockSettingsRepository();
    usecase = SettingsUsecase(mockRepo);
  });

  group('SettingsUsecase', () {
    const settings = AppSettings(
      themeMode: ThemeMode.dark,
      keepScreenOn: true,
      sliderPosition: SliderPosition.bottom,
    );

    group('getSettings', () {
      test('should return settings from repository', () async {
        when(() => mockRepo.getSettings()).thenAnswer((_) async => settings);

        final result = await usecase.getSettings();

        expect(result, settings);
        expect(result.themeMode, ThemeMode.dark);
        expect(result.keepScreenOn, true);
        expect(result.sliderPosition, SliderPosition.bottom);
        verify(() => mockRepo.getSettings()).called(1);
      });

      test('should return default settings when repository returns defaults', () async {
        const defaultSettings = AppSettings();
        when(() => mockRepo.getSettings()).thenAnswer((_) async => defaultSettings);

        final result = await usecase.getSettings();

        expect(result, defaultSettings);
        expect(result.themeMode, ThemeMode.system);
        expect(result.keepScreenOn, false);
        expect(result.sliderPosition, SliderPosition.top);
        verify(() => mockRepo.getSettings()).called(1);
      });

      test('should propagate repository errors', () async {
        when(() => mockRepo.getSettings()).thenThrow(Exception('Storage error'));

        expect(() => usecase.getSettings(), throwsException);
        verify(() => mockRepo.getSettings()).called(1);
      });
    });

    group('updateThemeMode', () {
      test('should call repository with light theme', () async {
        when(() => mockRepo.updateThemeMode(ThemeMode.light)).thenAnswer((_) async => {});

        await usecase.updateThemeMode(ThemeMode.light);

        verify(() => mockRepo.updateThemeMode(ThemeMode.light)).called(1);
      });

      test('should call repository with dark theme', () async {
        when(() => mockRepo.updateThemeMode(ThemeMode.dark)).thenAnswer((_) async => {});

        await usecase.updateThemeMode(ThemeMode.dark);

        verify(() => mockRepo.updateThemeMode(ThemeMode.dark)).called(1);
      });

      test('should call repository with system theme', () async {
        when(() => mockRepo.updateThemeMode(ThemeMode.system)).thenAnswer((_) async => {});

        await usecase.updateThemeMode(ThemeMode.system);

        verify(() => mockRepo.updateThemeMode(ThemeMode.system)).called(1);
      });

      test('should propagate repository errors', () async {
        when(() => mockRepo.updateThemeMode(any())).thenThrow(Exception('Update failed'));

        expect(() => usecase.updateThemeMode(ThemeMode.light), throwsException);
        verify(() => mockRepo.updateThemeMode(ThemeMode.light)).called(1);
      });
    });

    group('updateKeepScreenOn', () {
      test('should call repository with true', () async {
        when(() => mockRepo.updateKeepScreenOn(true)).thenAnswer((_) async => {});

        await usecase.updateKeepScreenOn(true);

        verify(() => mockRepo.updateKeepScreenOn(true)).called(1);
      });

      test('should call repository with false', () async {
        when(() => mockRepo.updateKeepScreenOn(false)).thenAnswer((_) async => {});

        await usecase.updateKeepScreenOn(false);

        verify(() => mockRepo.updateKeepScreenOn(false)).called(1);
      });

      test('should propagate repository errors', () async {
        when(() => mockRepo.updateKeepScreenOn(any())).thenThrow(Exception('Update failed'));

        expect(() => usecase.updateKeepScreenOn(true), throwsException);
        verify(() => mockRepo.updateKeepScreenOn(true)).called(1);
      });
    });

    group('updateSliderPosition', () {
      test('should call repository with top position', () async {
        when(() => mockRepo.updateSliderPosition(SliderPosition.top)).thenAnswer((_) async => {});

        await usecase.updateSliderPosition(SliderPosition.top);

        verify(() => mockRepo.updateSliderPosition(SliderPosition.top)).called(1);
      });

      test('should call repository with bottom position', () async {
        when(() => mockRepo.updateSliderPosition(SliderPosition.bottom)).thenAnswer((_) async => {});

        await usecase.updateSliderPosition(SliderPosition.bottom);

        verify(() => mockRepo.updateSliderPosition(SliderPosition.bottom)).called(1);
      });

      test('should propagate repository errors', () async {
        when(() => mockRepo.updateSliderPosition(any())).thenThrow(Exception('Update failed'));

        expect(() => usecase.updateSliderPosition(SliderPosition.top), throwsException);
        verify(() => mockRepo.updateSliderPosition(SliderPosition.top)).called(1);
      });
    });

    group('integration scenarios', () {
      test('should handle multiple sequential operations', () async {
        when(() => mockRepo.getSettings()).thenAnswer((_) async => const AppSettings());
        when(() => mockRepo.updateThemeMode(any())).thenAnswer((_) async => {});
        when(() => mockRepo.updateKeepScreenOn(any())).thenAnswer((_) async => {});
        when(() => mockRepo.updateSliderPosition(any())).thenAnswer((_) async => {});

        // 초기 설정 가져오기
        final initialSettings = await usecase.getSettings();
        expect(initialSettings.themeMode, ThemeMode.system);

        // 여러 설정 순차적으로 업데이트
        await usecase.updateThemeMode(ThemeMode.dark);
        await usecase.updateKeepScreenOn(true);
        await usecase.updateSliderPosition(SliderPosition.bottom);

        // 모든 메서드가 호출되었는지 확인
        verify(() => mockRepo.getSettings()).called(1);
        verify(() => mockRepo.updateThemeMode(ThemeMode.dark)).called(1);
        verify(() => mockRepo.updateKeepScreenOn(true)).called(1);
        verify(() => mockRepo.updateSliderPosition(SliderPosition.bottom)).called(1);
      });

      test('should handle repository method calls independently', () async {
        when(() => mockRepo.updateThemeMode(any())).thenAnswer((_) async => {});
        when(() => mockRepo.updateKeepScreenOn(any())).thenAnswer((_) async => {});
        when(() => mockRepo.updateSliderPosition(any())).thenAnswer((_) async => {});

        // 각 메서드를 독립적으로 호출
        await usecase.updateKeepScreenOn(false);
        await usecase.updateSliderPosition(SliderPosition.top);
        await usecase.updateThemeMode(ThemeMode.light);

        // 다른 메서드는 호출되지 않았는지 확인
        verifyNever(() => mockRepo.getSettings());
        verify(() => mockRepo.updateThemeMode(ThemeMode.light)).called(1);
        verify(() => mockRepo.updateKeepScreenOn(false)).called(1);
        verify(() => mockRepo.updateSliderPosition(SliderPosition.top)).called(1);
      });
    });
  });
}