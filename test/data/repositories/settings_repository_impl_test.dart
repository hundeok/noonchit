// test/data/repositories/settings_repository_impl_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/data/datasources/settings_local_ds.dart';
import 'package:noonchit/data/repositories/settings_repository_impl.dart';
import 'package:noonchit/domain/entities/app_settings.dart';

class MockSettingsLocalDataSource extends Mock implements SettingsLocalDataSource {}

void main() {
  late SettingsRepositoryImpl repository;
  late MockSettingsLocalDataSource mockDataSource;

  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
    registerFallbackValue(ThemeMode.system);
    registerFallbackValue(SliderPosition.top);
  });

  setUp(() {
    mockDataSource = MockSettingsLocalDataSource();
    repository = SettingsRepositoryImpl(mockDataSource);
  });

  group('SettingsRepositoryImpl', () {
    group('getSettings', () {
      test('should return AppSettings with all values from data source', () async {
        when(() => mockDataSource.getThemeMode()).thenReturn(ThemeMode.dark);
        when(() => mockDataSource.getKeepScreenOn()).thenReturn(true);
        when(() => mockDataSource.getSliderPosition()).thenReturn(SliderPosition.bottom);

        final result = await repository.getSettings();

        expect(result.themeMode, ThemeMode.dark);
        expect(result.keepScreenOn, true);
        expect(result.sliderPosition, SliderPosition.bottom);
        verify(() => mockDataSource.getThemeMode()).called(1);
        verify(() => mockDataSource.getKeepScreenOn()).called(1);
        verify(() => mockDataSource.getSliderPosition()).called(1);
      });

      test('should return AppSettings with default values when data source returns defaults', () async {
        when(() => mockDataSource.getThemeMode()).thenReturn(ThemeMode.system);
        when(() => mockDataSource.getKeepScreenOn()).thenReturn(false);
        when(() => mockDataSource.getSliderPosition()).thenReturn(SliderPosition.top);

        final result = await repository.getSettings();

        expect(result.themeMode, ThemeMode.system);
        expect(result.keepScreenOn, false);
        expect(result.sliderPosition, SliderPosition.top);
        verify(() => mockDataSource.getThemeMode()).called(1);
        verify(() => mockDataSource.getKeepScreenOn()).called(1);
        verify(() => mockDataSource.getSliderPosition()).called(1);
      });

      test('should return AppSettings with mixed values', () async {
        when(() => mockDataSource.getThemeMode()).thenReturn(ThemeMode.light);
        when(() => mockDataSource.getKeepScreenOn()).thenReturn(true);
        when(() => mockDataSource.getSliderPosition()).thenReturn(SliderPosition.top);

        final result = await repository.getSettings();

        expect(result.themeMode, ThemeMode.light);
        expect(result.keepScreenOn, true);
        expect(result.sliderPosition, SliderPosition.top);
      });
    });

    group('updateThemeMode', () {
      test('should call data source with ThemeMode.light', () async {
        when(() => mockDataSource.saveThemeMode(ThemeMode.light)).thenAnswer((_) async => {});

        await repository.updateThemeMode(ThemeMode.light);

        verify(() => mockDataSource.saveThemeMode(ThemeMode.light)).called(1);
      });

      test('should call data source with ThemeMode.dark', () async {
        when(() => mockDataSource.saveThemeMode(ThemeMode.dark)).thenAnswer((_) async => {});

        await repository.updateThemeMode(ThemeMode.dark);

        verify(() => mockDataSource.saveThemeMode(ThemeMode.dark)).called(1);
      });

      test('should call data source with ThemeMode.system', () async {
        when(() => mockDataSource.saveThemeMode(ThemeMode.system)).thenAnswer((_) async => {});

        await repository.updateThemeMode(ThemeMode.system);

        verify(() => mockDataSource.saveThemeMode(ThemeMode.system)).called(1);
      });
    });

    group('updateKeepScreenOn', () {
      test('should call data source with true', () async {
        when(() => mockDataSource.saveKeepScreenOn(true)).thenAnswer((_) async => {});

        await repository.updateKeepScreenOn(true);

        verify(() => mockDataSource.saveKeepScreenOn(true)).called(1);
      });

      test('should call data source with false', () async {
        when(() => mockDataSource.saveKeepScreenOn(false)).thenAnswer((_) async => {});

        await repository.updateKeepScreenOn(false);

        verify(() => mockDataSource.saveKeepScreenOn(false)).called(1);
      });
    });

    group('updateSliderPosition', () {
      test('should call data source with SliderPosition.bottom', () async {
        when(() => mockDataSource.saveSliderPosition(SliderPosition.bottom)).thenAnswer((_) async => {});

        await repository.updateSliderPosition(SliderPosition.bottom);

        verify(() => mockDataSource.saveSliderPosition(SliderPosition.bottom)).called(1);
      });

      test('should call data source with SliderPosition.top', () async {
        when(() => mockDataSource.saveSliderPosition(SliderPosition.top)).thenAnswer((_) async => {});

        await repository.updateSliderPosition(SliderPosition.top);

        verify(() => mockDataSource.saveSliderPosition(SliderPosition.top)).called(1);
      });
    });

    group('Error Handling', () {
      test('should propagate exceptions from getThemeMode', () async {
        when(() => mockDataSource.getThemeMode()).thenThrow(Exception('Storage error'));
        when(() => mockDataSource.getKeepScreenOn()).thenReturn(false);
        when(() => mockDataSource.getSliderPosition()).thenReturn(SliderPosition.top);

        expect(() async => await repository.getSettings(), throwsException);
      });

      test('should propagate exceptions from getKeepScreenOn', () async {
        when(() => mockDataSource.getThemeMode()).thenReturn(ThemeMode.system);
        when(() => mockDataSource.getKeepScreenOn()).thenThrow(Exception('Storage error'));
        when(() => mockDataSource.getSliderPosition()).thenReturn(SliderPosition.top);

        expect(() async => await repository.getSettings(), throwsException);
      });

      test('should propagate exceptions from getSliderPosition', () async {
        when(() => mockDataSource.getThemeMode()).thenReturn(ThemeMode.system);
        when(() => mockDataSource.getKeepScreenOn()).thenReturn(false);
        when(() => mockDataSource.getSliderPosition()).thenThrow(Exception('Storage error'));

        expect(() async => await repository.getSettings(), throwsException);
      });

      test('should propagate exceptions from saveThemeMode', () async {
        when(() => mockDataSource.saveThemeMode(any())).thenThrow(Exception('Storage error'));

        expect(() async => await repository.updateThemeMode(ThemeMode.light), throwsException);
      });

      test('should propagate exceptions from saveKeepScreenOn', () async {
        when(() => mockDataSource.saveKeepScreenOn(any())).thenThrow(Exception('Storage error'));

        expect(() async => await repository.updateKeepScreenOn(true), throwsException);
      });

      test('should propagate exceptions from saveSliderPosition', () async {
        when(() => mockDataSource.saveSliderPosition(any())).thenThrow(Exception('Storage error'));

        expect(() async => await repository.updateSliderPosition(SliderPosition.bottom), throwsException);
      });
    });
  });
}