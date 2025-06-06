// lib/domain/usecases/settings_usecase.dart
import 'package:flutter/material.dart';
import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

/// 앱 설정 관련 비즈니스 로직
class SettingsUsecase {
  final SettingsRepository _repo;

  SettingsUsecase(this._repo);

  Future<AppSettings> getSettings() {
    return _repo.getSettings();
  }

  Future<void> updateThemeMode(ThemeMode mode) {
    return _repo.updateThemeMode(mode);
  }

  Future<void> updateKeepScreenOn(bool on) {
    return _repo.updateKeepScreenOn(on);
  }

  Future<void> updateSliderPosition(SliderPosition pos) {
    return _repo.updateSliderPosition(pos);
  }

  /// 🆕 코인명 표시 방식 업데이트
  Future<void> updateDisplayMode(DisplayMode mode) {
    return _repo.updateDisplayMode(mode);
  }

  /// 💰 금액 표시 방식 업데이트
  Future<void> updateAmountDisplayMode(AmountDisplayMode mode) {
    return _repo.updateAmountDisplayMode(mode);
  }
}