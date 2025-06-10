// lib/domain/repositories/market_mood_repository.dart
// 🎯 Domain Layer: Repository 인터페이스 (클린 아키텍처 준수)

import '../entities/market_mood.dart';

/// 📊 마켓무드 저장소 인터페이스
/// Data Layer에서 구현해야 할 계약을 정의 (Domain → Data 의존성 제거)
abstract class MarketMoodRepository {
  // ═══════════════════════════════════════════════════════════
  // 📡 원격 데이터 (CoinGecko API)
  // ═══════════════════════════════════════════════════════════
  
  /// 글로벌 마켓 데이터 스트림 (30분 주기)
  Stream<MarketMoodData> getMarketDataStream();
  
  /// 현재 마켓 데이터 한 번 조회
  Future<MarketMoodData?> getCurrentMarketData();
  
  /// 현재 USD/KRW 환율 조회 (캐시 포함)
  Future<double> getExchangeRate();
  
  /// 환율 수동 새로고침
  Future<void> refreshExchangeRate();
  
  // ═══════════════════════════════════════════════════════════
  // 💾 로컬 데이터 (Hive 볼륨 버퍼)
  // ═══════════════════════════════════════════════════════════
  
  /// 볼륨 데이터 추가 (30분마다)
  Future<void> addVolumeData(VolumeData volume);
  
  /// N분 전 볼륨 데이터 조회
  Future<VolumeData?> getVolumeNMinutesAgo(int minutes);
  
  /// 특정 기간의 평균 볼륨 계산
  Future<double?> getAverageVolume(int days);
  
  /// 수집된 데이터 개수 확인
  Future<int> getCollectedDataCount();
  
  /// 앱 시작 시간 조회
  DateTime getAppStartTime();
  
  // ═══════════════════════════════════════════════════════════
  // 🧹 관리 기능
  // ═══════════════════════════════════════════════════════════
  
  /// 백그라운드 복귀 시 누락된 슬롯 보정
  Future<void> syncMissingData();
  
  /// 오래된 데이터 정리
  Future<void> clearOldData();
  
  /// 시스템 헬스체크
  Future<Map<String, dynamic>> getSystemHealth();
  
  /// 현재 상태 로깅
  Future<void> logCurrentStatus();
  
  // ═══════════════════════════════════════════════════════════
  // 🛠️ 개발/테스트용 기능
  // ═══════════════════════════════════════════════════════════
  
  /// 테스트 데이터 주입
  Future<void> injectTestVolumeData(List<VolumeData> testData);
}