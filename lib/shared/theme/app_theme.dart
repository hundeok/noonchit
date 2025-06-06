import 'package:flutter/material.dart';
import '../../core/bridge/signal_bus.dart'; // ExchangePlatform 임포트

/// 앱의 테마 설정을 관리하는 클래스
class AppTheme {
  AppTheme._(); // private 생성자
  
  // 공통 컬러 팔레트
  static const Color neutralWhite = Colors.white;
  static const Color neutralBlack = Colors.black;
  static const Color neutralGrey = Colors.grey;
  static const Color accentOrange = Colors.orange;
  
  // 플랫폼별 포인트 컬러
  static Color getPrimaryColor(ExchangePlatform platform) {
    switch (platform) {
      case ExchangePlatform.upbit:
        return accentOrange;
      case ExchangePlatform.binance:
        return const Color(0xFFF0B90B); // 바이낸스 노랑
      case ExchangePlatform.bybit:
        return const Color(0xFF00C087); // 바이빗 초록
      case ExchangePlatform.bithumb:
        return const Color(0xFF1A3C34); // 빗썸 초록
    }
  }

  static Color getSecondaryColor(ExchangePlatform platform) {
    switch (platform) {
      case ExchangePlatform.upbit:
        return Colors.orangeAccent;
      case ExchangePlatform.binance:
        return const Color(0xFFF3BA2F); // 바이낸스 밝은 노랑
      case ExchangePlatform.bybit:
        return const Color(0xFF00D4B1); // 바이빗 밝은 초록
      case ExchangePlatform.bithumb:
        return const Color(0xFF2A5D52); // 빗썸 밝은 초록
    }
  }
  
  // 기본 테마 설정 (시스템 모드 또는 기본값용)
  static ThemeData light({ExchangePlatform platform = ExchangePlatform.upbit}) {
    final primaryColor = getPrimaryColor(platform);
    final secondaryColor = getSecondaryColor(platform);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: neutralGrey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: neutralWhite,
          backgroundColor: primaryColor,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
  
  // 다크 테마
  static ThemeData dark({ExchangePlatform platform = ExchangePlatform.upbit}) {
    final primaryColor = getPrimaryColor(platform);
    final secondaryColor = getSecondaryColor(platform);
    
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: secondaryColor,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: neutralGrey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: neutralBlack,
          backgroundColor: primaryColor,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
  
  // 시스템 테마 (시스템 설정에 따라 라이트/다크 결정)
  static ThemeData system(BuildContext context, {ExchangePlatform platform = ExchangePlatform.upbit}) {
    final brightness = MediaQuery.of(context).platformBrightness;
    return brightness == Brightness.light
        ? light(platform: platform)
        : dark(platform: platform);
  }
}