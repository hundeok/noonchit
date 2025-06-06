// test/data/datasources/settings_local_ds_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:noonchit/data/datasources/settings_local_ds.dart';
import 'package:noonchit/domain/entities/app_settings.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late SettingsLocalDataSource dataSource;
  late MockSharedPreferences mockPrefs;

  setUpAll(() async {
    dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
    ''');
  });

  setUp(() {
    mockPrefs = MockSharedPreferences();
    dataSource = SettingsLocalDataSource(mockPrefs);
  });

  group('SettingsLocalDataSource', () {
    group('ThemeMode', () {
      test('getThemeMode should return ThemeMode.dark for dark value', () {
        when(() => mockPrefs.getString('themeMode')).thenReturn('dark');
        expect(dataSource.getThemeMode(), ThemeMode.dark);
        verify(() => mockPrefs.getString('themeMode')).called(1);
      });

      test('getThemeMode should return ThemeMode.light for light value', () {
        when(() => mockPrefs.getString('themeMode')).thenReturn('light');
        expect(dataSource.getThemeMode(), ThemeMode.light);
        verify(() => mockPrefs.getString('themeMode')).called(1);
      });

      test('getThemeMode should return ThemeMode.system if not set', () {
        when(() => mockPrefs.getString('themeMode')).thenReturn(null);
        expect(dataSource.getThemeMode(), ThemeMode.system);
        verify(() => mockPrefs.getString('themeMode')).called(1);
      });

      test('getThemeMode should return ThemeMode.system for unknown value', () {
        when(() => mockPrefs.getString('themeMode')).thenReturn('unknown');
        expect(dataSource.getThemeMode(), ThemeMode.system);
        verify(() => mockPrefs.getString('themeMode')).called(1);
      });

      test('saveThemeMode should save light theme to preferences', () async {
        when(() => mockPrefs.setString('themeMode', 'light')).thenAnswer((_) async => true);
        await dataSource.saveThemeMode(ThemeMode.light);
        verify(() => mockPrefs.setString('themeMode', 'light')).called(1);
      });

      test('saveThemeMode should save dark theme to preferences', () async {
        when(() => mockPrefs.setString('themeMode', 'dark')).thenAnswer((_) async => true);
        await dataSource.saveThemeMode(ThemeMode.dark);
        verify(() => mockPrefs.setString('themeMode', 'dark')).called(1);
      });

      test('saveThemeMode should save system theme to preferences', () async {
        when(() => mockPrefs.setString('themeMode', 'system')).thenAnswer((_) async => true);
        await dataSource.saveThemeMode(ThemeMode.system);
        verify(() => mockPrefs.setString('themeMode', 'system')).called(1);
      });
    });

    group('KeepScreenOn', () {
      test('getKeepScreenOn should return true when set to true', () {
        when(() => mockPrefs.getBool('keepScreenOn')).thenReturn(true);
        expect(dataSource.getKeepScreenOn(), true);
        verify(() => mockPrefs.getBool('keepScreenOn')).called(1);
      });

      test('getKeepScreenOn should return false when set to false', () {
        when(() => mockPrefs.getBool('keepScreenOn')).thenReturn(false);
        expect(dataSource.getKeepScreenOn(), false);
        verify(() => mockPrefs.getBool('keepScreenOn')).called(1);
      });

      test('getKeepScreenOn should return false if not set', () {
        when(() => mockPrefs.getBool('keepScreenOn')).thenReturn(null);
        expect(dataSource.getKeepScreenOn(), false);
        verify(() => mockPrefs.getBool('keepScreenOn')).called(1);
      });

      test('saveKeepScreenOn should save true to preferences', () async {
        when(() => mockPrefs.setBool('keepScreenOn', true)).thenAnswer((_) async => true);
        await dataSource.saveKeepScreenOn(true);
        verify(() => mockPrefs.setBool('keepScreenOn', true)).called(1);
      });

      test('saveKeepScreenOn should save false to preferences', () async {
        when(() => mockPrefs.setBool('keepScreenOn', false)).thenAnswer((_) async => true);
        await dataSource.saveKeepScreenOn(false);
        verify(() => mockPrefs.setBool('keepScreenOn', false)).called(1);
      });
    });

    group('SliderPosition', () {
      test('getSliderPosition should return SliderPosition.bottom for bottom value', () {
        when(() => mockPrefs.getString('sliderPosition')).thenReturn('bottom');
        expect(dataSource.getSliderPosition(), SliderPosition.bottom);
        verify(() => mockPrefs.getString('sliderPosition')).called(1);
      });

      test('getSliderPosition should return SliderPosition.top for top value', () {
        when(() => mockPrefs.getString('sliderPosition')).thenReturn('top');
        expect(dataSource.getSliderPosition(), SliderPosition.top);
        verify(() => mockPrefs.getString('sliderPosition')).called(1);
      });

      test('getSliderPosition should return SliderPosition.top if not set', () {
        when(() => mockPrefs.getString('sliderPosition')).thenReturn(null);
        expect(dataSource.getSliderPosition(), SliderPosition.top);
        verify(() => mockPrefs.getString('sliderPosition')).called(1);
      });

      test('getSliderPosition should return SliderPosition.top for unknown value', () {
        when(() => mockPrefs.getString('sliderPosition')).thenReturn('unknown');
        expect(dataSource.getSliderPosition(), SliderPosition.top);
        verify(() => mockPrefs.getString('sliderPosition')).called(1);
      });

      test('saveSliderPosition should save bottom position to preferences', () async {
        when(() => mockPrefs.setString('sliderPosition', 'bottom')).thenAnswer((_) async => true);
        await dataSource.saveSliderPosition(SliderPosition.bottom);
        verify(() => mockPrefs.setString('sliderPosition', 'bottom')).called(1);
      });

      test('saveSliderPosition should save top position to preferences', () async {
        when(() => mockPrefs.setString('sliderPosition', 'top')).thenAnswer((_) async => true);
        await dataSource.saveSliderPosition(SliderPosition.top);
        verify(() => mockPrefs.setString('sliderPosition', 'top')).called(1);
      });
    });

    group('Error Handling', () {
      test('should handle SharedPreferences exceptions gracefully', () {
        when(() => mockPrefs.getString('themeMode')).thenThrow(Exception('Storage error'));
        
        expect(() => dataSource.getThemeMode(), throwsException);
      });
    });
  });
}