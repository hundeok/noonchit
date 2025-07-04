// lib/domain/repositories/surge_repository.dart
import '../entities/surge.dart';

/// 급등/급락 데이터의 시간대별 변동률 추적 및 리셋을 관리하는 Repository
abstract class SurgeRepository {
  /// 시간대별 변동률 스트림 제공 (Surge 엔티티 리스트)
  /// [timeFrame]: 시간대 (예: "1m", "5m", "15m")
  /// [markets]: 모니터링할 마켓 코드 리스트
  /// Returns: Surge 엔티티 리스트 (변동률 절댓값 순 정렬)
  Stream<List<Surge>> watchSurgeByTimeFrame(String timeFrame, List<String> markets);
  
  /// 특정 시간대 수동 리셋
  /// [timeFrame]: 리셋할 시간대
  void resetTimeFrame(String timeFrame);
  
  /// 모든 시간대 수동 리셋
  void resetAllTimeFrames();
  
  /// 다음 리셋 예정 시간 조회
  /// [timeFrame]: 시간대
  /// Returns: 다음 리셋 시간 (null이면 리셋 정보 없음)
  DateTime? getNextResetTime(String timeFrame);
  
  /// 활성화된 시간대 목록 조회
  /// Returns: 사용 가능한 시간대 리스트 (예: ["1m", "5m", "15m"])
  List<String> getActiveTimeFrames();
  
  /// 특정 시간대가 활성화되어 있는지 확인
  /// [timeFrame]: 확인할 시간대
  /// Returns: 활성화 여부
  bool isTimeFrameActive(String timeFrame);
  
  /// 리소스 해제
  Future<void> dispose();
}