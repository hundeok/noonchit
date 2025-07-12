// core/utils/bottom_line_circular_buffer.dart
// 🔄 메모리 효율적인 순환 버퍼 구현 (바텀라인 전용)

import 'dart:math' as math;
import 'bottom_line_constants.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 🔄 기본 순환 버퍼 (제네릭)
// ══════════════════════════════════════════════════════════════════════════════

/// 메모리 효율적인 순환 버퍼 (FIFO)
/// 최대 크기 고정으로 메모리 사용량 제한
class CircularBuffer<T> {
  final int _maxSize;
  final List<T?> _buffer;
  int _head = 0;  // 다음 추가될 위치
  int _tail = 0;  // 가장 오래된 데이터 위치
  int _count = 0; // 현재 저장된 데이터 개수

  CircularBuffer(this._maxSize) 
    : assert(_maxSize > 0, 'Buffer size must be positive'),
      _buffer = List<T?>.filled(_maxSize, null);

  /// 현재 저장된 데이터 개수
  int get length => _count;

  /// 버퍼 최대 크기
  int get maxSize => _maxSize;

  /// 버퍼가 비어있는지
  bool get isEmpty => _count == 0;

  /// 버퍼가 가득 찼는지
  bool get isFull => _count == _maxSize;

  /// 사용률 (0.0 ~ 1.0)
  double get utilization => _count / _maxSize;

  /// 데이터 추가 (오래된 데이터 자동 제거)
  void add(T item) {
    _buffer[_head] = item;
    _head = (_head + 1) % _maxSize;
    
    if (_count < _maxSize) {
      _count++;
    } else {
      // 버퍼가 가득 찬 경우, tail도 이동
      _tail = (_tail + 1) % _maxSize;
    }
  }

  /// 여러 데이터 한 번에 추가
  void addAll(Iterable<T> items) {
    for (final item in items) {
      add(item);
    }
  }

  /// 가장 최근 데이터 반환 (제거하지 않음)
  T? get last {
    if (isEmpty) return null;
    final lastIndex = (_head - 1 + _maxSize) % _maxSize;
    return _buffer[lastIndex];
  }

  /// 가장 오래된 데이터 반환 (제거하지 않음)
  T? get first {
    if (isEmpty) return null;
    return _buffer[_tail];
  }

  /// 인덱스로 데이터 접근 (0 = 가장 오래된 데이터)
  T? operator [](int index) {
    if (index < 0 || index >= _count) return null;
    final actualIndex = (_tail + index) % _maxSize;
    return _buffer[actualIndex];
  }

  /// 모든 데이터를 리스트로 반환 (오래된 순서)
  List<T> get items {
    if (isEmpty) return <T>[];
    
    final result = <T>[];
    for (int i = 0; i < _count; i++) {
      final item = this[i];
      if (item != null) result.add(item);
    }
    return result;
  }

  /// 최신 N개 데이터 반환
  List<T> getRecent(int count) {
    if (count <= 0 || isEmpty) return <T>[];
    
    final actualCount = math.min(count, _count);
    final result = <T>[];
    
    for (int i = _count - actualCount; i < _count; i++) {
      final item = this[i];
      if (item != null) result.add(item);
    }
    
    return result;
  }

  /// 조건에 맞는 데이터 필터링
  List<T> where(bool Function(T) test) {
    return items.where(test).toList();
  }

  /// 데이터 개수 세기
  int count(bool Function(T) test) {
    return items.where(test).length;
  }

  /// 조건에 맞는 첫 번째 데이터 찾기
  T? firstWhere(bool Function(T) test, {T? orElse}) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return orElse;
  }

  /// 모든 데이터 제거
  void clear() {
    for (int i = 0; i < _maxSize; i++) {
      _buffer[i] = null;
    }
    _head = 0;
    _tail = 0;
    _count = 0;
  }

  /// 오래된 데이터 일부 제거
  void removeOld(int count) {
    if (count <= 0 || isEmpty) return;
    
    final actualCount = math.min(count, _count);
    
    for (int i = 0; i < actualCount; i++) {
      _buffer[_tail] = null;
      _tail = (_tail + 1) % _maxSize;
      _count--;
    }
  }

  /// 메모리 사용량 추정 (바이트)
  int get estimatedMemoryBytes {
    // 대략적인 계산 (객체 오버헤드 포함)
    return _maxSize * 64 + 128; // 64바이트 per slot + 오버헤드
  }

  /// 버퍼 상태 요약
  Map<String, dynamic> get stats {
    return {
      'max_size': _maxSize,
      'current_count': _count,
      'utilization': '${(utilization * 100).toStringAsFixed(1)}%',
      'is_full': isFull,
      'memory_bytes': estimatedMemoryBytes,
      'head_position': _head,
      'tail_position': _tail,
    };
  }

  @override
  String toString() {
    return 'CircularBuffer<$T>($_count/$maxSize, ${(utilization * 100).toStringAsFixed(1)}%)';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 📊 시간 기반 순환 버퍼 (TTL 지원)
// ══════════════════════════════════════════════════════════════════════════════

/// 시간 정보와 함께 저장되는 데이터
class TimestampedData<T> {
  final T data;
  final DateTime timestamp;

  const TimestampedData(this.data, this.timestamp);

  /// 데이터 생성 후 경과 시간
  Duration get age => DateTime.now().difference(timestamp);

  /// 지정된 시간보다 오래되었는지
  bool isOlderThan(Duration duration) => age > duration;

  @override
  String toString() => 'TimestampedData($data, ${timestamp.toIso8601String()})';
}

/// 시간 기반 순환 버퍼 (TTL 자동 제거)
class TimeBasedCircularBuffer<T> extends CircularBuffer<TimestampedData<T>> {
  final Duration _ttl;
  DateTime? _lastCleanup;

  TimeBasedCircularBuffer(int maxSize, this._ttl) : super(maxSize);

  /// TTL (Time To Live)
  Duration get ttl => _ttl;

  /// 데이터 추가 (자동으로 타임스탬프 부여)
  void addData(T data) {
    add(TimestampedData(data, DateTime.now()));
    _autoCleanup();
  }

  /// 유효한 데이터만 반환 (TTL 체크)
  List<T> get validData {
    return items
      .where((item) => !item.isOlderThan(_ttl))
      .map((item) => item.data)
      .toList();
  }

  /// 최신 유효 데이터 N개 반환
  List<T> getRecentValidData(int count) {
    final valid = validData;
    final actualCount = math.min(count, valid.length);
    return valid.reversed.take(actualCount).toList().reversed.toList();
  }

  /// 만료된 데이터 개수
  int get expiredCount {
    return items.where((item) => item.isOlderThan(_ttl)).length;
  }

  /// 자동 정리 (1분마다)
  void _autoCleanup() {
    final now = DateTime.now();
    if (_lastCleanup == null || 
        now.difference(_lastCleanup!).inMinutes >= 1) {
      removeExpired();
      _lastCleanup = now;
    }
  }

  /// 만료된 데이터 제거
  void removeExpired() {
    if (isEmpty) return;

    int expiredCount = 0;
    while (!isEmpty && first!.isOlderThan(_ttl)) {
      removeOld(1);
      expiredCount++;
    }

    if (BottomLineConstants.enableDetailedLogging && expiredCount > 0) {
      // log.d('🗑️ Removed $expiredCount expired items from TimeBasedCircularBuffer');
    }
  }

  /// 통계 정보 (TTL 포함)
  @override
  Map<String, dynamic> get stats {
    final baseStats = super.stats;
    
    baseStats.addAll({
      'ttl_seconds': _ttl.inSeconds,
      'valid_count': validData.length,
      'expired_count': expiredCount,
      'oldest_age_seconds': isEmpty ? 0 : first!.age.inSeconds,
      'newest_age_seconds': isEmpty ? 0 : last!.age.inSeconds,
      'last_cleanup': _lastCleanup?.toIso8601String() ?? 'Never',
    });
    
    return baseStats;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🎯 바텀라인 특화 버퍼들
// ══════════════════════════════════════════════════════════════════════════════

/// 거래 데이터 전용 순환 버퍼
class TradeCircularBuffer extends CircularBuffer<Map<String, dynamic>> {
  TradeCircularBuffer() : super(BottomLineConstants.maxRecentTrades);

  /// 고액거래만 필터링
  List<Map<String, dynamic>> get largeTrades {
    return where((trade) {
      final amount = trade['amount'] as double? ?? 0.0;
      return amount >= BottomLineConstants.largeTradeThreshold;
    });
  }

  /// 특정 마켓의 거래들
  List<Map<String, dynamic>> getTradesForMarket(String market) {
    return where((trade) => trade['market'] == market);
  }

  /// 최근 N분간의 거래들
  List<Map<String, dynamic>> getTradesInLastMinutes(int minutes) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    return where((trade) {
      final timestamp = trade['timestamp'] as int? ?? 0;
      return DateTime.fromMillisecondsSinceEpoch(timestamp).isAfter(cutoff);
    });
  }

  /// 거래량 합계 계산
  double getTotalVolume() {
    return items.fold(0.0, (sum, trade) {
      final volume = trade['volume'] as double? ?? 0.0;
      return sum + volume;
    });
  }

  /// 거래대금 합계 계산
  double getTotalAmount() {
    return items.fold(0.0, (sum, trade) {
      final amount = trade['amount'] as double? ?? 0.0;
      return sum + amount;
    });
  }
}

/// 문자열 데이터 전용 순환 버퍼 (고액거래 ID 등)
class StringCircularBuffer extends CircularBuffer<String> {
  StringCircularBuffer(int maxSize) : super(maxSize);

  /// 중복 제거된 고유 문자열들
  Set<String> get uniqueItems => items.toSet();

  /// 특정 패턴과 매칭되는 문자열들
  List<String> getMatching(RegExp pattern) {
    return where((item) => pattern.hasMatch(item));
  }

  /// 특정 접두사로 시작하는 문자열들
  List<String> getStartingWith(String prefix) {
    return where((item) => item.startsWith(prefix));
  }

  /// 문자열 길이 통계
  Map<String, dynamic> get lengthStats {
    if (isEmpty) {
      return {'min': 0, 'max': 0, 'avg': 0.0};
    }
    
    final lengths = items.map((item) => item.length).toList();
    return {
      'min': lengths.reduce(math.min),
      'max': lengths.reduce(math.max),
      'avg': lengths.reduce((a, b) => a + b) / lengths.length,
    };
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 🏭 팩토리 클래스
// ══════════════════════════════════════════════════════════════════════════════

/// 바텀라인용 버퍼 팩토리
class BottomLineBufferFactory {
  BottomLineBufferFactory._();

  /// 거래 데이터용 버퍼 생성
  static TradeCircularBuffer createTradeBuffer() {
    return TradeCircularBuffer();
  }

  /// 고액거래 ID용 버퍼 생성
  static StringCircularBuffer createLargeTradeBuffer() {
    return StringCircularBuffer(BottomLineConstants.maxRecentLargeTrades);
  }

  /// 시장 이름용 버퍼 생성
  static StringCircularBuffer createMarketBuffer() {
    return StringCircularBuffer(BottomLineConstants.maxTrackedMarkets);
  }

  /// TTL 기반 데이터 버퍼 생성
  static TimeBasedCircularBuffer<T> createTimeBasedBuffer<T>(
    int maxSize, 
    Duration ttl,
  ) {
    return TimeBasedCircularBuffer<T>(maxSize, ttl);
  }

  /// 기본 제네릭 버퍼 생성
  static CircularBuffer<T> createBuffer<T>(int maxSize) {
    return CircularBuffer<T>(maxSize);
  }

  /// 버퍼 성능 테스트 (개발용)
  static Map<String, dynamic> performanceTest() {
    final stopwatch = Stopwatch()..start();
    
    // 1000개 데이터로 성능 테스트
    final buffer = CircularBuffer<int>(1000);
    
    // 추가 성능
    for (int i = 0; i < 2000; i++) {
      buffer.add(i);
    }
    final addTime = stopwatch.elapsedMicroseconds;
    
    // 조회 성능
    stopwatch.reset();
    for (int i = 0; i < 1000; i++) {
      buffer[i % buffer.length];
    }
    final accessTime = stopwatch.elapsedMicroseconds;
    
    // 필터링 성능
    stopwatch.reset();
    buffer.where((item) => item % 2 == 0);
    final filterTime = stopwatch.elapsedMicroseconds;
    
    stopwatch.stop();
    
    return {
      'add_2000_items_us': addTime,
      'access_1000_times_us': accessTime,
      'filter_once_us': filterTime,
      'memory_usage_bytes': buffer.estimatedMemoryBytes,
      'utilization': buffer.utilization,
    };
  }
}