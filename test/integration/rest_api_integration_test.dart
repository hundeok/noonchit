import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive/hive.dart';
import 'package:noonchit/core/config/app_config.dart';
import 'package:noonchit/core/network/api_client.dart';
import 'package:noonchit/data/models/trade_dto.dart';
import 'dart:io';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient client;

  setUpAll(() async {
    // 1) .env 파일 로드
    try {
      await dotenv.load();
      debugPrint(".env 파일이 성공적으로 로드되었습니다.");
    } catch (e, stackTrace) {
      debugPrint("⚠️ .env 파일을 로드할 수 없습니다: $e");
      debugPrint("StackTrace: $stackTrace");
      // 테스트용 환경 변수 설정 (fallback)
      dotenv.testLoad(fileInput: '''
LOG_LEVEL=debug
DEBUG_MODE=true
UPBIT_API_KEY=64uuQWXi3NwIQMrXnBBEN64aQN6qB6V5N4xLJ1op
UPBIT_API_SECRET=qFaUEfwfxquB4hiXpK1mcKMQRxmqLJGwi3RcDiVW
UPBIT_REST_URL=https://api.upbit.com/v1
UPBIT_WS_URL=wss://api.upbit.com/websocket/v1
      ''');
    }

    // 2) Hive 초기화 (테스트 전용 디렉토리)
    try {
      // path_provider 대신 고정 경로 사용
      const testHivePath = './test_hive';
      await Directory(testHivePath).create(recursive: true);
      Hive.init(testHivePath);
      if (!Hive.isAdapterRegistered(TradeDtoAdapter().typeId)) {
        Hive.registerAdapter(TradeDtoAdapter());
      }
      if (!Hive.isBoxOpen('trades')) {
        await Hive.openBox<TradeDto>('trades');
      }
      debugPrint('[Test] Hive 초기화 완료: $testHivePath');
    } catch (e, stackTrace) {
      debugPrint('[Test] ⚠️ Hive 초기화 실패: $e');
      debugPrint('[Test] StackTrace: $stackTrace');
      rethrow;
    }

    // 3) AppConfig 초기화
    try {
      await AppConfig.init();
      debugPrint('[Test] AppConfig 초기화 완료');
    } catch (e, stackTrace) {
      debugPrint('[Test] ⚠️ AppConfig 초기화 실패: $e');
      debugPrint('[Test] StackTrace: $stackTrace');
      rethrow;
    }

    // 4) API 클라이언트 초기화
    final apiKey = AppConfig.apiKey.isNotEmpty
        ? AppConfig.apiKey
        : '64uuQWXi3NwIQMrXnBBEN64aQN6qB6V5N4xLJ1op';
    final apiSecret = AppConfig.apiSecret.isNotEmpty
        ? AppConfig.apiSecret
        : 'qFaUEfwfxquB4hiXpK1mcKMQRxmqLJGwi3RcDiVW';

    client = ApiClient(
      apiKey: apiKey,
      apiSecret: apiSecret,
    );
    debugPrint('🔑 API 키가 설정되었습니다.');
  });

  tearDownAll(() async {
    // Hive 리소스 정리
    try {
      if (Hive.isBoxOpen('trades')) {
        await Hive.box<TradeDto>('trades').close();
      }
      await Hive.close();
      debugPrint('[Test] Hive 리소스 정리 완료');
    } catch (e, stackTrace) {
      debugPrint('[Test] ⚠️ Hive 리소스 정리 실패: $e');
      debugPrint('[Test] StackTrace: $stackTrace');
    }

    // 테스트 디렉토리 정리
    try {
      final testHiveDir = Directory('./test_hive');
      if (await testHiveDir.exists()) {
        await testHiveDir.delete(recursive: true);
        debugPrint('[Test] 테스트 Hive 디렉토리 정리 완료');
      }
    } catch (e, stackTrace) {
      debugPrint('[Test] ⚠️ 테스트 디렉토리 정리 실패: $e');
      debugPrint('[Test] StackTrace: $stackTrace');
    }
  });

  test('GET /market/all returns a non-empty list', () async {
    // AppConfig에서 기본 URL 가져오기
    final baseUrl = AppConfig.upbitRestBase;
    try {
      final res = await client
          .request<List<dynamic>>(
            method: 'GET',
            path: '$baseUrl/market/all',
          )
          .timeout(const Duration(seconds: 10)); // 타임아웃을 Future.timeout으로 처리

      expect(res.isOk, isTrue, reason: 'API 호출이 성공해야 합니다.');
      final markets = res.valueOrNull;
      expect(markets, isNotNull, reason: '마켓 데이터가 null이 아니어야 합니다.');
      expect(markets, isA<List>(), reason: '응답이 리스트 형식이어야 합니다.');
      expect(markets!.isNotEmpty, isTrue, reason: '마켓 리스트가 비어 있지 않아야 합니다.');

      // 결과 샘플 검증
      if (markets.isNotEmpty) {
        addTearDown(() {
          debugPrint('마켓 데이터 ${markets.length}개 성공적으로 로드');
        });
        expect(
          markets.first,
          containsPair('market', startsWith('KRW-')),
          reason: '첫 번째 마켓 이름은 KRW-로 시작해야 합니다.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[Test] ⚠️ API 호출 실패: $e');
      debugPrint('[Test] StackTrace: $stackTrace');
      fail('API 호출 중 에러 발생: $e');
    }
  });
}