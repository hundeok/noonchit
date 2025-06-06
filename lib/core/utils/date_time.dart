import 'package:intl/intl.dart';

/// DateTime extension utilities for formatting and comparison.
extension DateTimeX on DateTime {
  /// `2024-05-17 22:05:01` → `22:05:01`
  String hhmmss() => DateFormat('HH:mm:ss').format(this);

  /// `2024-05-17` 형식의 날짜 문자열 반환
  String yyyyMMdd() => DateFormat('yyyy-MM-dd').format(this);

  /// `22:05` 형식의 시간 문자열 반환
  String hhmm() => DateFormat('HH:mm').format(this);

  /// `2024-05-17 22:05` 형식의 날짜+시간 문자열 반환
  String yyyyMMddhhmm() => DateFormat('yyyy-MM-dd HH:mm').format(this);

  /// 현재 시간과의 차이를 사람이 읽기 쉬운 형태로 표시
  /// 예: '방금 전', '3분 전', '2시간 전', '어제', '3일 전', '2주 전', '5개월 전', '1년 전'
  String timeAgo() {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 2) return '어제';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}주 전';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}개월 전';
    return '${(diff.inDays / 365).floor()}년 전';
  }

  /// UTC 밀리초(ms)를 로컬 DateTime으로 변환
  static DateTime fromEpochMs(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();

  /// ISO 8601 문자열을 로컬 DateTime으로 파싱
  static DateTime parseIso8601(String iso) =>
      DateTime.parse(iso).toLocal();

  /// 동일한 날짜인지 확인
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// 오늘인지 확인
  bool get isToday => isSameDay(DateTime.now());

  /// 어제인지 확인
  bool get isYesterday =>
      isSameDay(DateTime.now().subtract(const Duration(days: 1)));
}
