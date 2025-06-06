// lib/domain/usecases/volume_usecase.dart

import 'dart:async';
import '../../core/error/app_exception.dart';
import '../../core/extensions/result.dart';
import '../entities/volume.dart';
import '../repositories/volume_repository.dart';

/// Volume 관련 비즈니스 로직을 제공하는 UseCase
class VolumeUsecase {
  final VolumeRepository _repository;

  VolumeUsecase(this._repository);

  /// 시간대별 볼륨 랭킹 스트림 반환 (에러 처리 포함)
  Stream<Result<List<Volume>, AppException>> getVolumeRanking(
    String timeFrame,
    List<String> markets,
  ) {
    return _repository
        .watchVolumeByTimeFrame(timeFrame, markets)
        .transform(_wrapWithErrorHandling<List<Volume>>('Volume ranking failed'));
  }

  /// 특정 시간대 수동 리셋
  Result<void, AppException> resetTimeFrame(String timeFrame) {
    try {
      _repository.resetTimeFrame(timeFrame);
      return const Ok(null);
    } catch (e) {
      return Err(AppException('Reset timeframe failed: $e'));
    }
  }

  /// 모든 시간대 수동 리셋
  Result<void, AppException> resetAllTimeFrames() {
    try {
      _repository.resetAllTimeFrames();
      return const Ok(null);
    } catch (e) {
      return Err(AppException('Reset all timeframes failed: $e'));
    }
  }

  /// 다음 리셋 시간 조회
  Result<DateTime?, AppException> getNextResetTime(String timeFrame) {
    try {
      final resetTime = _repository.getNextResetTime(timeFrame);
      return Ok(resetTime);
    } catch (e) {
      return Err(AppException('Get reset time failed: $e'));
    }
  }

  /// 활성 시간대 목록 조회
  Result<List<String>, AppException> getActiveTimeFrames() {
    try {
      final timeFrames = _repository.getActiveTimeFrames();
      return Ok(timeFrames);
    } catch (e) {
      return Err(AppException('Get active timeframes failed: $e'));
    }
  }

  /// 시간대 유효성 검증
  Result<bool, AppException> validateTimeFrame(String timeFrame) {
    try {
      final isActive = _repository.isTimeFrameActive(timeFrame);
      return Ok(isActive);
    } catch (e) {
      return Err(AppException('Validate timeframe failed: $e'));
    }
  }

  /// 볼륨 데이터 유효성 검증 (비즈니스 로직)
  Result<List<Volume>, AppException> validateVolumeData(List<Volume> volumes) {
    try {
      // 비즈니스 규칙: 볼륨이 있는 것만, 중복 제거, 정렬 확인
      final validVolumes = volumes
          .where((v) => v.hasVolume && v.market.isNotEmpty)
          .toSet() // 중복 제거
          .toList();

      // 정렬 확인 (볼륨 내림차순)
      final isSorted = _isVolumeSorted(validVolumes);
      if (!isSorted) {
        validVolumes.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
      }

      return Ok(validVolumes);
    } catch (e) {
      return Err(AppException('Volume data validation failed: $e'));
    }
  }

  /// 시간대별 볼륨 비교 (비즈니스 로직)
  Result<Map<String, double>, AppException> compareVolumeAcrossTimeFrames(
    String market,
    List<String> timeFrames,
  ) {
    try {
      // 여러 시간대의 특정 코인 볼륨 비교
      // 실제 구현은 Repository에서 여러 스트림을 조합해야 함
      final comparison = <String, double>{};
      
      // TODO: 실제 구현 시 여러 timeFrame의 데이터를 조합
      // 현재는 단순 예시
      for (final tf in timeFrames) {
        comparison[tf] = 0.0; // 실제 데이터 조회 필요
      }
      
      return Ok(comparison);
    } catch (e) {
      return Err(AppException('Volume comparison failed: $e'));
    }
  }

  /// 헬퍼: 볼륨 정렬 확인
  bool _isVolumeSorted(List<Volume> volumes) {
    if (volumes.length <= 1) return true;
    
    for (int i = 0; i < volumes.length - 1; i++) {
      if (volumes[i].totalVolume < volumes[i + 1].totalVolume) {
        return false;
      }
    }
    return true;
  }

  /// 헬퍼: 에러 처리 변환기
  StreamTransformer<T, Result<T, AppException>> _wrapWithErrorHandling<T>(String errorMsg) {
    return StreamTransformer.fromHandlers(
      handleData: (data, sink) => sink.add(Ok(data)),
      handleError: (error, stack, sink) =>
          sink.add(Err(AppException('$errorMsg: $error'))),
    );
  }
}