// lib/core/event/app_event.dart

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

typedef Json = Map<String, dynamic>;

/// 애플리케이션 전역 이벤트의 베이스 클래스
/// - id     : UUID v4
/// - ts     : UTC 밀리초 타임스탬프
/// - payload: 자유 형태 JSON
class AppEvent extends Equatable {
  /// 고유 ID (UUID v4)
  final String id;

  /// UTC 밀리초 타임스탬프
  final int ts;

  /// 페이로드 데이터 (불변)
  final Json payload;

  const AppEvent({
    required this.id,
    required this.ts,
    required this.payload,
  });

  /// 현재 시각을 기준으로 id·ts를 자동 생성합니다.
  factory AppEvent.now(Json payload) {
    final nowUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    return AppEvent(
      id: const Uuid().v4(),
      ts: nowUtcMs,
      payload: Map<String, dynamic>.of(payload), // 방어적 복사
    );
  }

  /// UTC ms → 로컬 DateTime
  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toLocal();

  /// JSON 직렬화 (payload도 복사하여 노출)
  Json toJson() => {
        'id': id,
        'ts': ts,
        'payload': Map<String, dynamic>.of(payload),
      };

  /// JSON 역직렬화
  factory AppEvent.fromJson(Json json) {
    return AppEvent(
      id: json['id'] as String,
      ts: json['ts'] as int,
      payload: Map<String, dynamic>.of(json['payload'] as Json),
    );
  }

  /// 복사본 생성 (immutable 유지)
  AppEvent copyWith({
    String? id,
    int? ts,
    Json? payload,
  }) =>
      AppEvent(
        id: id ?? this.id,
        ts: ts ?? this.ts,
        payload: payload != null ? Map<String, dynamic>.of(payload) : this.payload,
      );

  @override
  List<Object?> get props => [id, ts, payload];
}
