import 'package:flutter/foundation.dart';

/// 섹터 분류 관리 전용 Provider (공유 위젯 레이어)
/// 상세(28개) vs 기본(18개) 분류 토글 및 매핑 데이터 제공
class SectorClassificationProvider extends ChangeNotifier {
 // 현재 선택된 분류 타입 (true: 상세, false: 기본)
 bool _isDetailedClassification = true;
 
 // 🚀 캐시 시스템 추가
 Map<String, List<String>>? _cachedCurrentSectors;
 Map<String, List<String>>? _cachedCoinToSectorsMap;
 
 bool get isDetailedClassification => _isDetailedClassification;
 
 /// 분류 타입 토글
 void toggleClassificationType() {
   // 🚀 캐시 무효화
   _cachedCurrentSectors = null;
   _cachedCoinToSectorsMap = null;
   
   _isDetailedClassification = !_isDetailedClassification;
   notifyListeners();
 }
 
 /// 상세 분류 섹터별 코인 매핑 (28개 섹터)
 static const Map<String, List<String>> _detailedSectors = {
   // ==================== 기본 그룹 ====================
   '비트코인 그룹': ['BTC', 'BCH', 'BSV', 'XEC'],
   '이더리움 그룹': ['ETH', 'ETC'],
   '스테이킹': ['ETH', 'SOL', 'ADA', 'POL', 'ATOM'],

   // ==================== 블록체인 아키텍처 ====================
   '모놀리식 블록체인': [
     'SOL', 'ADA', 'TRX', 'SUI', 'AVAX', 'NEAR', 'CRO', 'APT', 'ETC', 'VET',
     'ATOM', 'ALGO', 'INJ', 'A', 'SEI', 'IOTA', 'XTZ', 'FLOW', 'KAVA', 'EGLD',
     'NEO', 'MINA', 'BERA', 'ZIL', 'QTUM', 'ASTR', 'GAS', 'VTHO', 'VANA', 'ELF',
     'WAVES', 'ICX', 'ONT', 'HIVE', 'SXP', 'POWR', 'ARDR', 'XEM', 'IOST', 'ONG',
     'GLMR', 'ARK', 'AERGO', 'QKC', 'META', 'TT', 'FCT2'
   ],
   '모듈러 블록체인': [
     'ETH', 'DOT', 'MNT', 'POL', 'ARB', 'STX', 'SONIC', 'MOVE', 'CKB', 'CELO',
     'LSK', 'BLAST', 'TAIKO', 'MTL', 'TOKAMAK'
   ],

   // ==================== 스테이블코인 생태계 ====================
   '스테이블 코인': ['USDT', 'USDC'],

   // ==================== DeFi 생태계 ====================
   'DEX/애그리게이터': [
     'UNI', 'JUP', 'DEEP', '1INCH', 'ZRX', 'ORCA', 'COW', 'ORBS', 'AUCTION', 'KNC'
   ],
   '랜딩': ['AAVE', 'COMP', 'STRIKE'],
   '유동화 스테이킹/리스테이킹': ['PENDLE', 'JTO', 'LAYER'],
   'RWA': ['ONDO', 'CTC'],

   // ==================== 인프라 & 기술 ====================
   '지급결제 인프라': ['BTC', 'XRP', 'BCH', 'XLM', 'BSV', 'XEC', 'PUNDIX', 'GRS'],
   '상호운용성/브릿지': ['ZRO', 'W', 'T', 'ZETA', 'STG'],
   '엔터프라이즈 블록체인': ['HBAR', 'POLYX', 'STRAX'],
   '오라클': ['LINK', 'PYTH'],
   '데이터 인프라': ['GRT', 'KAITO', 'ANKR', 'ARKM', 'MVL', 'CARV'],
   '스토리지': ['FIL', 'THETA', 'BTT', 'WAL', 'AKT', 'LPT', 'GLM', 'TFUEL', 'SC', 'STORJ'],
   'AI': ['VIRTUAL', 'RENDER', 'ATH'],

   // ==================== 엔터테인먼트 & 게임 ====================
   '메타버스': ['SAND', 'MANA', 'MOCA', 'MOC'],
   'NFT/게임': [
     'IMX', 'AXS', 'BEAM', 'BLUR', 'ENJ', 'GMT', 'ANIME', 'ME', 'BORA',
     'BIGTIME', 'WAXP', 'AGLD', 'GAME2', 'AQT'
   ],

   // ==================== 미디어 & 콘텐츠 ====================
   '미디어/스트리밍': ['MBL'],
   '광고': ['BAT', 'MLK', 'STMX'],
   '교육/기타 콘텐츠': ['IQ', 'AHT'],

   // ==================== 소셜 & 커뮤니티 ====================
   '소셜/DAO': ['G', 'UXLINK', 'STEEM', 'CBK'],
   '팬토큰': ['CHZ'],
   '밈': ['DOGE', 'SHIB', 'PEPE', 'TRUMP', 'BONK', 'MEW', 'PENGU', 'MOODENG'],

   // ==================== 특수 용도 ====================
   'DID': ['ENS', 'ID', 'CVC'],
   '의료': ['MED'],
   '월렛/메세징': ['SAFE', 'MASK', 'WCT', 'SNT'],
 };

 /// 기본 분류 (18개 섹터) - 🆕 신규상장 섹터 5개 추가
 static const Map<String, List<String>> _basicSectors = {
   '메이저 코인': [
     'BTC', 'ETH', 'XRP', 'ADA', 'SOL', 'DOT', 'AVAX', 'MATIC', 'POL', 'NEAR',
     'ATOM', 'LINK', 'UNI', 'ALGO', 'VET', 'SAND', 'MANA', 'AXS', 'THETA',
     'FIL', 'AAVE', 'DOGE', 'SHIB', 'PEPE'
   ],
   '비트코인 계열': [
     'BTC', 'BCH', 'BSV', 'BTT', '1000SATS', 'ORDI'
   ],
   '이더리움 생태계': [
     'ETH', 'ETC', 'ENS', 'LPT', 'COMP', 'MKR', 'YFI', 'SUSHI', 'BAL',
     '1INCH', 'LRC', 'ZRX', 'BAT', 'ENJ', 'CRV', 'SNX', 'MASK', 'BLUR', 'GRT'
   ],
   '레이어1 블록체인': [
     'EGLD', 'INJ', 'APT', 'SUI', 'ARB', 'OP', 'STX', 'TIA', 'SEI', 'PYTH',
     'JTO', 'JUP', 'TNSR', 'W', 'ENA', 'OMNI', 'REZ', 'BB', 'NOT', 'IO',
     'ZK', 'LISTA', 'ZRO', 'G', 'BANANA', 'RENDER', 'TON', 'NEO', 'GAS',
     'ONT', 'ONG', 'QTUM', 'WAVES', 'LSK', 'STRAX', 'ARK', 'STORJ', 'SC',
     'ARDR', 'KMD', 'ZEC', 'DASH', 'XMR', 'ICX', 'ZIL', 'IOTA', 'XTZ',
     'CELO', 'FLOW', 'MINA', 'HBAR', 'CKB', 'BEAM', 'ZETA', 'TAIKO', 'AERGO'
   ],
   
   // 🆕 시총별 분류 (환율 1,400원 적용 기준)
   '고 시총': [
     'BTC', 'ETH', 'XRP', 'SOL', 'DOGE', 'AVAX', 'TRUMP'
   ],
   '중 시총': [
     'SUI', 'APT', 'NEAR', 'UNI', 'LINK', 'AAVE', 'INJ', 'STX', 'AXS', 'FIL',
     'ATOM', 'DOT', 'PENDLE', 'RENDER', 'GAS', 'ORCA', 'BERA', 'ZRO', 'TIA',
     'MASK', 'VIRTUAL', 'KAITO', 'QTUM', 'JTO', 'OM', 'ONDO', 'ME', 'LAYER',
     'AGLD', 'THETA', 'MTL', 'MNT', 'ADA', 'TAIKO',      'VAULTA', 'DRIFT', 'CTC',
     'XTZ', 'IMX', 'ARKM', 'SAFE', 'JUP', 'WAL', 'LSK', 'KAVA', 'COW',
     'UXLINK', 'ARK', 'FLOW', 'CARV', 'ARB', 'CELO', 'PUNDIX', 'KNC',
     'MANA', 'TRX', 'SAND', 'STORJ', 'XLM', 'HUNT', 'SONIC', 'GLM', 'ZRX',
     'HIVE', 'ZETA', 'MINA', 'POL', '1INCH', 'ALGO', 'SEI', 'STG', 'IOTA',
     'ID', 'SXP', 'HBAR', 'POWR', 'DEEP', 'MOVE', 'POLYX', 'STEEM', 'ONT',
     'BAT', 'CVC', 'AERGO', 'ICX', 'PYTH', 'CRO', 'GRT', 'BLUR', 'ARDR',
     'BORA', 'W', 'MOCA', 'BIGTIME', 'GMT', 'STRAX', 'CHZ', 'SNT', 'TFUEL',
     'JST', 'VET', 'ANIME', 'WAXP', 'ORBS', 'ANKR', 'T', 'G', 'ZIL', 'PENGU',
     'XEM', 'BEAM', 'CKB', 'IQ', 'AHT', 'IOST'
   ],
   '저 시총': [
     'GAME2', 'MVL', 'SC', 'MEW', 'BLAST', 'STMX', 'TT', 'MBL', 'VTHO', 'XEC',
     'BONK', 'SHIB', 'PEPE', 'BTT', 'CBK', 'MLK', 'POKT', 'SIGN', 'MOC',
     'SOPH', 'AWE', 'ATH', 'BOUNTY', 'HP', 'FCT2', 'ASTR', 'META', 'DKA',
     'QKC', 'MED'
   ],
   
   // 🆕 마이너 알트코인 (기존 알트코인 복원)
   '마이너 알트코인': [
     'LTC', 'A', 'TRX', 'XLM', 'STEEM', 'IOST', 'MTL', 'GRS', 'POWR',
     'XEM', 'XEC', 'VTHO', 'TFUEL', 'HIVE', 'CVC', 'SNT', 'SXP', 'T', 'PUNDIX'
   ],
   
   'DeFi 토큰': [
     'CAKE', 'RUNE', 'ALPHA', 'DODO', 'RAY', 'SRM', 'KNC', 'ANKR', 'CELR',
     'KAVA', 'HARD', 'SWP', 'JST', 'SUN', 'CRO', 'CHZ', 'GLM', 'AUCTION',
     'PENDLE', 'STG', 'COW', 'OM', 'ONDO', 'SAFE'
   ],
   '스테이블코인': [
     'USDT', 'USDC', 'BUSD', 'DAI', 'TUSD', 'USDD'
   ],
   '게임/NFT/메타버스': [
     'GALA', 'APE', 'GMT', 'GST', 'LOOKS', 'PLA', 'WAXP', 'TLM', 'SLP',
     'IMX', 'BIGTIME', 'GAME2', 'AGLD', 'YGG', 'ME', 'VIRTUAL', 'MOCA',
     'PENGU', 'MEW', 'ANIME', 'FLOKI', 'BONK', 'WIF', 'BOME'
   ],
   '한국 프로젝트': [
     'KLAY', 'BORA', 'META', 'WEMIX', 'MBL', 'HUNT', 'TEMCO', 'SOLVE',
     'PROM', 'ORBS', 'MIX', 'CENNZ', 'STPT', 'MDT', 'LAMB', 'COTI',
     'WTC', 'NPXS', 'APIS', 'DAC', 'ELF', 'KARMA', 'MEET', 'QKC',
     'SSX', 'UPP', 'TOKAMAK', 'MLK', 'DKA', 'CBK', 'MOC', 'HP',
     'BOUNTY', 'MED', 'MVL', 'ASTR', 'TT', 'MNT', 'FCT2', 'IQ',
     'AHT', 'AWE', 'ATH', 'SOPH', 'SIGN'
   ],
   '솔라나 생태계': [
     'SOL', 'ORCA', 'DRIFT', 'SONIC', 'LAYER', 'DEEP', 'MOVE'
   ],
   'AI/기술 토큰': [
     'ARKM', 'KAITO', 'NXPC', 'WCT', 'AKT', 'AQT', 'CARV', 'UXLINK',
     'WAL', 'CTC', 'POLYX', 'ID', 'VANA', 'STRIKE', 'BERA', 'TRUMP',
     'POKT', 'STMX', 'BLAST'
   ],

   // 🆕 신규상장 섹터
   '2023년 신규상장': [
     'SHIB', 'MASK', 'EGLD', 'SUI', 'GRT', 'BLUR', 'IMX', 'SEI', 'MINA', 'CTC', 'ASTR'
   ],
   '2024년 상반기 신규상장': [
     'ID', 'PYTH', 'MNT', 'BIGTIME', 'AKT', 'ZETA', 'STG', 'BEAM', 'TAIKO', 'ONDO', 'ZRO', 'BLAST'
   ],
   '2024년 하반기 신규상장': [
     'JUP', 'ENS', 'GAL', 'PENDLE', 'ATH', 'UXLINK', 'CKB', 'W', 'CARV', 'INJ', 'MEW', 'UNI', 
     'SAFE', 'DRIFT', 'AGLD', 'PEPE', 'BONK', 'RENDER', 'MOVE', 'ME', 'MOCA', 'VANA'
   ],
   '2025년 상반기 신규상장': [
     'SONIC', 'VTHO', 'ANIME', 'VIRTUAL', 'BERA', 'LAYER', 'TRUMP', 'JTO', 'COW', 'KAITO', 
     'ARKM', 'ORCA', 'WAL', 'COMP', 'FIL', 'WCT', 'DEEP', 'SIGN', 'TIA', 'PENGU', 
     'NXPC', 'OM', 'SOPH', 'LPT', 'POKT', 'RVN', 'AXL', 'ALT', 'RAY', 'NEWT', 'SAHARA'
   ],
   '2025년 하반기 신규상장': [
     'MOODENG', 'HYPER', 'BABY', 'ENA' 
   ],
 };

 /// 🚀 캐시된 현재 활성화된 섹터 매핑 반환
 Map<String, List<String>> get currentSectors {
   _cachedCurrentSectors ??= _isDetailedClassification ? _detailedSectors : _basicSectors;
   return _cachedCurrentSectors!;
 }

 /// 🚀 캐시된 코인→섹터 역색인 맵 반환 (O(1) 조회용)
 Map<String, List<String>> get coinToSectorsMap {
   if (_cachedCoinToSectorsMap == null) {
     _cachedCoinToSectorsMap = <String, List<String>>{};
     currentSectors.forEach((sector, coins) {
       for (final coin in coins) {
         _cachedCoinToSectorsMap!.putIfAbsent(coin, () => []).add(sector);
       }
     });
     
     if (kDebugMode) {
       debugPrint('🚀 SectorClassification: coinToSectorsMap built with ${_cachedCoinToSectorsMap!.length} coins');
     }
   }
   return _cachedCoinToSectorsMap!;
 }

 /// 상세 분류 섹터 매핑 반환
 Map<String, List<String>> get detailedSectors => _detailedSectors;

 /// 기본 분류 섹터 매핑 반환
 Map<String, List<String>> get basicSectors => _basicSectors;

 /// 섹터 목록 반환
 List<String> get sectorNames => currentSectors.keys.toList();

 /// 특정 섹터의 코인들 반환
 List<String> getCoinsInSector(String sectorName) {
   return currentSectors[sectorName] ?? [];
 }

 /// 🚀 최적화된 특정 코인이 속한 섹터들 반환 (O(1) 조회)
 List<String> getSectorsForCoin(String ticker) {
   return coinToSectorsMap[ticker.toUpperCase()] ?? [];
 }

 /// 현재 분류 타입 문자열 반환
 String get currentClassificationName {
   return _isDetailedClassification ? '상세' : '기본';
 }

 /// 섹터별 통계 정보
 Map<String, int> get sectorSizes {
   return currentSectors.map((sector, coins) => 
       MapEntry(sector, coins.length));
 }

 /// 전체 고유 코인 개수
 int get totalUniqueCoins {
   return currentSectors.values
       .expand((coins) => coins)
       .toSet()
       .length;
 }

 /// 중복도가 높은 코인들 (여러 섹터에 속한 코인들)
 Map<String, int> getCoinDuplicationCount() {
   Map<String, int> duplications = {};
   
   currentSectors.forEach((sector, coins) {
     for (String coin in coins) {
       duplications[coin] = (duplications[coin] ?? 0) + 1;
     }
   });
   
   return Map.fromEntries(
     duplications.entries.toList()
       ..sort((a, b) => b.value.compareTo(a.value))
   );
 }

 /// 🔧 디버깅용: 캐시 상태 정보
 Map<String, dynamic> get cacheStatus {
   return {
     'isDetailed': _isDetailedClassification,
     'currentSectorsCached': _cachedCurrentSectors != null,
     'coinToSectorsMapCached': _cachedCoinToSectorsMap != null,
     'totalSectors': currentSectors.length,
     'totalCoins': coinToSectorsMap.length,
     'averageCoinsPerSector': currentSectors.values.map((e) => e.length).reduce((a, b) => a + b) / currentSectors.length,
   };
 }
}