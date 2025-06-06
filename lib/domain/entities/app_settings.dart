import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

/// 슬라이더 위치를 표현하는 enum
enum SliderPosition { top, bottom }

/// 🆕 코인명 표시 방식을 표현하는 enum
enum DisplayMode {
  ticker, // BTC, ETH, XRP
  korean, // 비트코인, 이더리움, 리플
  english, // Bitcoin, Ethereum, Ripple
}

/// 💰 금액 표시 방식을 표현하는 enum
enum AmountDisplayMode {
  number, // 1,234만 (숫자)
  icon,   // 💵 (아이콘)
}

class AppSettings extends Equatable {
  final ThemeMode themeMode;
  final bool keepScreenOn;
  final SliderPosition sliderPosition;
  final DisplayMode displayMode; // 🆕 코인명 표시 방식 추가
  final AmountDisplayMode amountDisplayMode; // 💰 금액 표시 방식 추가

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.keepScreenOn = false,
    this.sliderPosition = SliderPosition.top,
    this.displayMode = DisplayMode.ticker, // 🆕 기본값: 티커
    this.amountDisplayMode = AmountDisplayMode.number, // 💰 기본값: 숫자
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? keepScreenOn,
    SliderPosition? sliderPosition,
    DisplayMode? displayMode, // 🆕 파라미터 추가
    AmountDisplayMode? amountDisplayMode, // 💰 파라미터 추가
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        sliderPosition: sliderPosition ?? this.sliderPosition,
        displayMode: displayMode ?? this.displayMode, // 🆕 복사 로직 추가
        amountDisplayMode: amountDisplayMode ?? this.amountDisplayMode, // 💰 복사 로직 추가
      );

  @override
  List<Object?> get props => [
        themeMode,
        keepScreenOn,
        sliderPosition,
        displayMode, // 🆕 equality 비교에 추가
        amountDisplayMode, // 💰 equality 비교에 추가
      ];
}