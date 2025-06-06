import 'package:logger/logger.dart';
import '../config/app_config.dart';

/// 글로벌 Logger 인스턴스
/// - 개발 모드: AppConfig.logLevel에 따라 동적 조절
/// - 프로덕션모드: warning 이상 자동
final Logger log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,      // 스택 트레이스 라인 수
    errorMethodCount: 5, // 오류 시 표시할 스택 트레이스 라인 수
    lineLength: 120,     // 로그 한 줄 최대 길이
    colors: true,        // 컬러 출력 (터미널)
    printTime: true,     // 타임스탬프 포함
  ),
  level: AppConfig.logLevel, // 🔥 환경변수로 동적 조절 가능
);