// 🚀 캐시 시스템이 적용된 섹터 로고 프로바이더

import 'package:flutter/material.dart';

/// 🎨 섹터 로고 관리 전용 Provider
/// 캐시 시스템 + WebP 지원
class SectorLogoProvider {
  
  /// 🆕 메모리 캐시 (위젯 레벨 캐싱)
  static final Map<String, Widget> _widgetCache = {};
  
  /// 🆕 캐시 설정
  static const int _maxCacheObjects = 50; // 최대 50개 아이콘 캐시
  
  /// 🚀 캐시된 섹터 로고 위젯 생성 (메인 함수)
  static Widget buildSectorIcon({
    required int sectorNumber,
    double size = 40.0,
  }) {
    final cacheKey = 'sector_${sectorNumber}_${size.toInt()}';
    
    // 🎯 메모리 캐시에서 먼저 확인
    if (_widgetCache.containsKey(cacheKey)) {
      return _widgetCache[cacheKey]!;
    }
    
    // 새로운 위젯 생성
    final logoWidget = _buildSectorIconWidget(
      sectorNumber: sectorNumber,
      size: size,
    );
    
    // 🎯 메모리 캐시에 저장 (용량 제한)
    if (_widgetCache.length < _maxCacheObjects) {
      _widgetCache[cacheKey] = logoWidget;
    }
    
    return logoWidget;
  }

  /// 🎯 실제 섹터 아이콘 위젯 생성
  static Widget _buildSectorIconWidget({
    required int sectorNumber,
    required double size,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/icons/sector/sector$sectorNumber.webp',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
            ),
            child: Center(
              child: Text(
                '📊',
                style: TextStyle(fontSize: size * 0.5),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 🧹 캐시 정리 함수들
  static void clearCache() {
    _widgetCache.clear();
  }
  
  static void clearSpecificCache(int sectorNumber) {
    _widgetCache.removeWhere((key, value) => key.startsWith('sector_$sectorNumber'));
  }
  
  static int getCacheSize() {
    return _widgetCache.length;
  }

  /// 🎯 섹터 번호 유효성 검사 (✅ 수정된 부분)
  static bool isValidSectorNumber(int sectorNumber) {
    // 46을 47로 변경하여 새로운 섹터 번호를 유효한 범위에 포함시킵니다.
    return sectorNumber >= 1 && sectorNumber <= 47;
  }

  /// 🔧 디버깅용: 캐시 상태 정보
  static Map<String, dynamic> getCacheStatus() {
    return {
      'totalCached': _widgetCache.length,
      'maxCapacity': _maxCacheObjects,
      'cacheKeys': _widgetCache.keys.toList(),
      'memoryUsage': '${(_widgetCache.length / _maxCacheObjects * 100).toStringAsFixed(1)}%',
    };
  }
}