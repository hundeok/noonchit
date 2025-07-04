// lib/shared/widgets/sector_names.dart
// 🆕 실제 섹터 분류에 맞춘 네이밍 매핑

import '../../domain/entities/app_settings.dart';

class SectorNames {
  // 🎯 상세 분류 (28개 섹터) 네이밍 매핑
  static const Map<String, Map<String, String>> detailedSectorNaming = {
    // ==================== 기본 그룹 ====================
    '비트코인 그룹': {
      'ticker': 'BTC-GRP',
      'korean': '비트코인 그룹',
      'english': 'Bitcoin Group',
    },
    '이더리움 그룹': {
      'ticker': 'ETH-GRP',
      'korean': '이더리움 그룹',
      'english': 'Ethereum Group',
    },
    '스테이킹': {
      'ticker': 'STAKE',
      'korean': '스테이킹',
      'english': 'Staking',
    },

    // ==================== 블록체인 아키텍처 ====================
    '모놀리식 블록체인': {
      'ticker': 'MONO',
      'korean': '모놀리식 블록체인',
      'english': 'Monolithic Blockchain',
    },
    '모듈러 블록체인': {
      'ticker': 'MODU',
      'korean': '모듈러 블록체인',
      'english': 'Modular Blockchain',
    },

    // ==================== 스테이블코인 생태계 ====================
    '스테이블 코인': {
      'ticker': 'STABLE',
      'korean': '스테이블 코인',
      'english': 'Stablecoin',
    },

    // ==================== DeFi 생태계 ====================
    'DEX/애그리게이터': {
      'ticker': 'DEX',
      'korean': 'DEX/애그리게이터',
      'english': 'DEX/Aggregator',
    },
    '랜딩': {
      'ticker': 'LEND',
      'korean': '랜딩',
      'english': 'Lending',
    },
    '유동화 스테이킹/리스테이킹': {
      'ticker': 'LSTAKE',
      'korean': '유동화 스테이킹/리스테이킹',
      'english': 'Liquid Staking/Restaking',
    },
    'RWA': {
      'ticker': 'RWA',
      'korean': 'RWA',
      'english': 'Real World Assets',
    },

    // ==================== 인프라 & 기술 ====================
    '지급결제 인프라': {
      'ticker': 'PAY',
      'korean': '지급결제 인프라',
      'english': 'Payment Infrastructure',
    },
    '상호운용성/브릿지': {
      'ticker': 'BRIDGE',
      'korean': '상호운용성/브릿지',
      'english': 'Interoperability/Bridge',
    },
    '엔터프라이즈 블록체인': {
      'ticker': 'ENTER',
      'korean': '엔터프라이즈 블록체인',
      'english': 'Enterprise Blockchain',
    },
    '오라클': {
      'ticker': 'ORACLE',
      'korean': '오라클',
      'english': 'Oracle',
    },
    '데이터 인프라': {
      'ticker': 'DATA',
      'korean': '데이터 인프라',
      'english': 'Data Infrastructure',
    },
    '스토리지': {
      'ticker': 'STORAGE',
      'korean': '스토리지',
      'english': 'Storage',
    },
    'AI': {
      'ticker': 'AI',
      'korean': 'AI',
      'english': 'Artificial Intelligence',
    },

    // ==================== 엔터테인먼트 & 게임 ====================
    '메타버스': {
      'ticker': 'META',
      'korean': '메타버스',
      'english': 'Metaverse',
    },
    'NFT/게임': {
      'ticker': 'NFT-GAME',
      'korean': 'NFT/게임',
      'english': 'NFT/Gaming',
    },

    // ==================== 미디어 & 콘텐츠 ====================
    '미디어/스트리밍': {
      'ticker': 'MEDIA',
      'korean': '미디어/스트리밍',
      'english': 'Media/Streaming',
    },
    '광고': {
      'ticker': 'AD',
      'korean': '광고',
      'english': 'Advertising',
    },
    '교육/기타 콘텐츠': {
      'ticker': 'EDU',
      'korean': '교육/기타 콘텐츠',
      'english': 'Education/Content',
    },

    // ==================== 소셜 & 커뮤니티 ====================
    '소셜/DAO': {
      'ticker': 'SOCIAL',
      'korean': '소셜/DAO',
      'english': 'Social/DAO',
    },
    '팬토큰': {
      'ticker': 'FAN',
      'korean': '팬토큰',
      'english': 'Fan Token',
    },
    '밈': {
      'ticker': 'MEME',
      'korean': '밈',
      'english': 'Meme',
    },

    // ==================== 특수 용도 ====================
    'DID': {
      'ticker': 'DID',
      'korean': 'DID',
      'english': 'Decentralized Identity',
    },
    '의료': {
      'ticker': 'MED',
      'korean': '의료',
      'english': 'Medical',
    },
    '월렛/메세징': {
      'ticker': 'WALLET',
      'korean': '월렛/메세징',
      'english': 'Wallet/Messaging',
    },
  };

  // 🎯 기본 분류 (18개 섹터) 네이밍 매핑 - 🆕 신규상장 4개 섹터 추가
  static const Map<String, Map<String, String>> basicSectorNaming = {
    '메이저 코인': {
      'ticker': 'MAJOR',
      'korean': '메이저 코인',
      'english': 'Major Coins',
    },
    '비트코인 계열': {
      'ticker': 'BTC-FAM',
      'korean': '비트코인 계열',
      'english': 'Bitcoin Family',
    },
    '이더리움 생태계': {
      'ticker': 'ETH-ECO',
      'korean': '이더리움 생태계',
      'english': 'Ethereum Ecosystem',
    },
    '레이어1 블록체인': {
      'ticker': 'L1',
      'korean': '레이어1 블록체인',
      'english': 'Layer 1 Blockchain',
    },
    '고 시총': {
      'ticker': 'LARGE-CAP',
      'korean': '고 시총',
      'english': 'Large Market Cap',
    },
    '중 시총': {
      'ticker': 'MID-CAP',
      'korean': '중 시총',
      'english': 'Mid Market Cap',
    },
    '저 시총': {
      'ticker': 'SMALL-CAP',
      'korean': '저 시총',
      'english': 'Small Market Cap',
    },
    '마이너 알트코인': {
      'ticker': 'MINOR-ALT',
      'korean': '마이너 알트코인',
      'english': 'Minor Altcoins',
    },
    'DeFi 토큰': {
      'ticker': 'DEFI',
      'korean': 'DeFi 토큰',
      'english': 'DeFi Tokens',
    },
    '스테이블코인': {
      'ticker': 'STABLE',
      'korean': '스테이블코인',
      'english': 'Stablecoins',
    },
    '게임/NFT/메타버스': {
      'ticker': 'GAMING',
      'korean': '게임/NFT/메타버스',
      'english': 'Gaming/NFT/Metaverse',
    },
    '한국 프로젝트': {
      'ticker': 'KOREA',
      'korean': '한국 프로젝트',
      'english': 'Korean Projects',
    },
    '솔라나 생태계': {
      'ticker': 'SOL-ECO',
      'korean': '솔라나 생태계',
      'english': 'Solana Ecosystem',
    },
    'AI/기술 토큰': {
      'ticker': 'AI-TECH',
      'korean': 'AI/기술 토큰',
      'english': 'AI/Tech Tokens',
    },

    // 🆕 신규상장 섹터 4개 추가
    '2023년 신규상장': {
      'ticker': 'NEW-23',
      'korean': '2023년 신규상장',
      'english': '2023 New Listings',
    },
    '2024년 상반기 신규상장': {
      'ticker': 'NEW-24H1',
      'korean': '2024년 상반기 신규상장',
      'english': '2024 H1 New Listings',
    },
    '2024년 하반기 신규상장': {
      'ticker': 'NEW-24H2',
      'korean': '2024년 하반기 신규상장',
      'english': '2024 H2 New Listings',
    },
    '2025년 상반기 신규상장': {
      'ticker': 'NEW-25H1',
      'korean': '2025년 상반기 신규상장',
      'english': '2025 H1 New Listings',
    },
  };

  /// 🎯 섹터명을 DisplayMode에 따라 변환 (기본/상세 분류 자동 감지)
  static String getDisplayName(String sectorKey, DisplayMode displayMode, {bool isDetailed = false}) {
    // 정규화 (입력된 섹터명 그대로 매핑에서 찾기)
    final normalizedKey = sectorKey.trim();
    
    // 상세/기본 분류에 따라 적절한 매핑 선택
    final sectorData = isDetailed 
        ? detailedSectorNaming[normalizedKey] 
        : basicSectorNaming[normalizedKey];
    
    // 매핑이 없으면 다른 분류에서 찾기 시도
    final fallbackData = isDetailed 
        ? basicSectorNaming[normalizedKey]
        : detailedSectorNaming[normalizedKey];
    
    final finalData = sectorData ?? fallbackData;
    
    if (finalData == null) {
      // 매핑이 없으면 원본 반환 (fallback)
      return sectorKey;
    }

    switch (displayMode) {
      case DisplayMode.ticker:
        return finalData['ticker'] ?? sectorKey;
      case DisplayMode.korean:
        return finalData['korean'] ?? sectorKey;
      case DisplayMode.english:
        return finalData['english'] ?? sectorKey;
    }
  }

  /// 🔧 모든 섹터 키 목록 반환 (디버깅용)
  static List<String> getAllSectorKeys({bool isDetailed = false}) {
    return isDetailed 
        ? detailedSectorNaming.keys.toList()
        : basicSectorNaming.keys.toList();
  }

  /// 🔧 특정 섹터가 매핑에 있는지 확인
  static bool hasSector(String sectorKey, {bool isDetailed = false}) {
    final normalizedKey = sectorKey.trim();
    
    return isDetailed 
        ? detailedSectorNaming.containsKey(normalizedKey)
        : basicSectorNaming.containsKey(normalizedKey);
  }

  /// 🔧 디버깅용 - 매핑되지 않은 섹터 찾기
  static List<String> findUnmappedSectors(List<String> actualSectorKeys, {bool isDetailed = false}) {
    final unmapped = <String>[];
    
    for (final sectorKey in actualSectorKeys) {
      if (!hasSector(sectorKey, isDetailed: isDetailed)) {
        unmapped.add(sectorKey);
      }
    }
    
    return unmapped;
  }

  /// 🔧 전체 매핑 정보 반환 (디버깅용)
  static Map<String, Map<String, String>> getAllMappings({bool isDetailed = false}) {
    return isDetailed ? detailedSectorNaming : basicSectorNaming;
  }
}

// 🆕 SectorTile에서 사용할 헬퍼 확장
extension SectorDisplayExtension on String {
  /// 섹터명을 DisplayMode에 따라 표시
  String toDisplayName(DisplayMode displayMode, {bool isDetailed = false}) {
    return SectorNames.getDisplayName(this, displayMode, isDetailed: isDetailed);
  }
}