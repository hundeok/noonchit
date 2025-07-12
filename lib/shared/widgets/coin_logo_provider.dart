// lib/shared/widgets/coin_logo_provider.dart
// 🚀 캐시 시스템이 적용된 코인 로고 프로바이더

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 🎨 업비트 KRW 마켓 → CoinPaprika ID 매핑 테이블
/// 실제 업비트 KRW 마켓의 모든 코인들 완전 매칭 (2024년 기준 ~250개)
class CoinLogoProvider {
  
  /// 🆕 메모리 캐시 (위젯 레벨 캐싱)
  static final Map<String, Widget> _widgetCache = {};
  
  /// 🆕 캐시 설정
  static const int _maxCacheObjects = 500; // 최대 500개 이미지 캐시
  
  /// 코인 로고 URL 가져오기 (64x64 썸네일)
  static String? getCoinLogoUrl(String ticker) {
    final paprikaId = _getCoinPaprikaId(ticker);
    if (paprikaId == null) return null;
    
    return 'https://coinpaprika.com/coin/$paprikaId/logo.png';
  }

  /// 코인 로고 URL 가져오기 (200x200 작은 이미지)
  static String? getCoinLogoUrlSmall(String ticker) {
    // CoinPaprika는 동일한 URL 사용 (자동 리사이즈)
    return getCoinLogoUrl(ticker);
  }

  /// 🚀 캐시된 코인 로고 위젯 생성 (메인 함수)
  static Widget buildCoinLogo({
    required String ticker,
    double radius = 16,
    Color? fallbackColor,
    Color? fallbackTextColor,
  }) {
    final cacheKey = '${ticker.toUpperCase()}_${radius}_${fallbackColor.hashCode}_${fallbackTextColor.hashCode}';
    
    // 🎯 메모리 캐시에서 먼저 확인
    if (_widgetCache.containsKey(cacheKey)) {
      return _widgetCache[cacheKey]!;
    }
    
    final logoUrl = getCoinLogoUrl(ticker);
    
    Widget logoWidget;
    
    if (logoUrl != null) {
      logoWidget = _buildCachedNetworkImage(
        ticker: ticker,
        logoUrl: logoUrl,
        radius: radius,
        fallbackColor: fallbackColor,
        fallbackTextColor: fallbackTextColor,
      );
    } else {
      logoWidget = _buildFallbackAvatar(ticker, radius, fallbackColor, fallbackTextColor);
    }
    
    // 🎯 메모리 캐시에 저장 (용량 제한)
    if (_widgetCache.length < _maxCacheObjects) {
      _widgetCache[cacheKey] = logoWidget;
    }
    
    return logoWidget;
  }

  /// 🚀 cached_network_image를 사용한 네트워크 이미지 로딩
  static Widget _buildCachedNetworkImage({
    required String ticker,
    required String logoUrl,
    required double radius,
    Color? fallbackColor,
    Color? fallbackTextColor,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: logoUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          
          // 🎯 캐시 설정 (기본 캐시 매니저 사용)
          // cacheManager: DefaultCacheManager(), // 필요시 커스텀 매니저 설정
          
          // 🎯 로딩 중 위젯
          placeholder: (context, url) => Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
            ),
            child: Center(
              child: SizedBox(
                width: radius * 0.6,
                height: radius * 0.6,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ),
          
          // 🎯 에러 시 fallback
          errorWidget: (context, url, error) {
            return _buildFallbackAvatar(ticker, radius, fallbackColor, fallbackTextColor);
          },
          
          // 🎯 이미지 로드 완료
          imageBuilder: (context, imageProvider) {
            return Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 🧹 캐시 정리 함수들
  static void clearMemoryCache() {
    _widgetCache.clear();
  }
  
  static void clearSpecificCache(String ticker) {
    _widgetCache.removeWhere((key, value) => key.startsWith(ticker.toUpperCase()));
  }
  
  static Future<void> clearNetworkCache() async {
    // cached_network_image의 캐시 정리
    // await DefaultCacheManager().emptyCache();
  }
  
  static int getMemoryCacheSize() {
    return _widgetCache.length;
  }

  /// CoinPaprika ID 매핑 (업비트 KRW 마켓 전체 커버 - 665줄 버전 기반)
  static String? _getCoinPaprikaId(String ticker) {
    const paprikaMappings = {
      // === 메이저 코인들 ===
      'BTC': 'btc-bitcoin',
      'ETH': 'eth-ethereum',
      'XRP': 'xrp-xrp',
      'ADA': 'ada-cardano',
      'SOL': 'sol-solana',
      'DOT': 'dot-polkadot',
      'AVAX': 'avax-avalanche',
      'MATIC': 'matic-polygon',
      'POL': 'pol-polygon-ecosystem-token',
      'NEAR': 'near-near-protocol',
      'ATOM': 'atom-cosmos',
      'LINK': 'link-chainlink',
      'UNI': 'uni-uniswap',
      'ALGO': 'algo-algorand',
      'VET': 'vet-vechain',
      'SAND': 'sand-the-sandbox',
      'MANA': 'mana-decentraland',
      'AXS': 'axs-axie-infinity',
      'THETA': 'theta-theta-token',
      'FIL': 'fil-filecoin',
      'AAVE': 'aave-new',
      'DOGE': 'doge-dogecoin',
      'SHIB': 'shib-shiba-inu',
      'PEPE': 'pepe-pepe',
      
      // === 비트코인 계열 ===
      'BCH': 'bch-bitcoin-cash',
      'BSV': 'bsv-bitcoin-sv',
      'BTT': 'btt-bittorrent',
      '1000SATS': 'sats-1000sats',
      'ORDI': 'ordi-ordinals',
      
      // === 이더리움 생태계 ===
      'ETC': 'etc-ethereum-classic',
      'ENS': 'ens-ethereum-name-service',
      'LPT': 'lpt-livepeer',
      'COMP': 'comp-compound',
      'MKR': 'mkr-maker',
      'YFI': 'yfi-yearn-finance',
      'SUSHI': 'sushi-sushiswap',
      'BAL': 'bal-balancer',
      '1INCH': '1inch-1inch',
      'LRC': 'lrc-loopring',
      'ZRX': 'zrx-0x',
      'BAT': 'bat-basic-attention-token',
      'ENJ': 'enj-enjincoin',
      'CRV': 'crv-curve-dao-token',
      'SNX': 'snx-synthetix-network-token',
      'MASK': 'mask-mask-network',
      'BLUR': 'blur-blur',
      'GRT': 'grt-the-graph',
      
      // === 레이어1 블록체인들 ===
      'EGLD': 'egld-elrond',
      'INJ': 'inj-injective-protocol',
      'APT': 'apt-aptos',
      'SUI': 'sui-sui',
      'ARB': 'arb-arbitrum',
      'OP': 'op-optimism',
      'STX': 'stx-stacks',
      'TIA': 'tia-celestia',
      'SEI': 'sei-sei',
      'PYTH': 'pyth-pyth-network',
      'JTO': 'jto-jito',
      'JUP': 'jup-jupiter',
      'TNSR': 'tnsr-tensor',
      'W': 'w-wormhole',
      'ENA': 'ena-ethena',
      'OMNI': 'omni-omni-network',
      'REZ': 'rez-renzo',
      'BB': 'bb-bouncbit',
      'NOT': 'not-notcoin',
      'IO': 'io-io-net',
      'ZK': 'zk-zksync',
      'LISTA': 'lista-lista-dao',
      'ZRO': 'zro-layerzero',
      'G': 'g-gravity',
      'BANANA': 'banana-banana-gun',
      'RENDER': 'rndr-render-token',
      'TON': 'ton-the-open-network',
      'NEO': 'neo-neo',
      'GAS': 'gas-gas',
      'ONT': 'ont-ontology',
      'ONG': 'ong-ong',
      'QTUM': 'qtum-qtum',
      'WAVES': 'waves-waves',
      'LSK': 'lsk-lisk',
      'STRAX': 'strax-stratis',
      'ARK': 'ark-ark',
      'STORJ': 'storj-storj',
      'SC': 'sc-siacoin',
      'ARDR': 'ardr-ardor',
      'KMD': 'kmd-komodo',
      'ZEC': 'zec-zcash',
      'DASH': 'dash-dash',
      'XMR': 'xmr-monero',
      'ICX': 'icx-icon',
      'ZIL': 'zil-zilliqa',
      'IOTA': 'miota-iota',
      'XTZ': 'xtz-tezos',
      'CELO': 'celo-celo',
      'FLOW': 'flow-flow',
      'MINA': 'mina-mina-protocol',
      'HBAR': 'hbar-hedera-hashgraph',
      'CKB': 'ckb-nervos-network',
      'BEAM': 'beam-beam',
      'ZETA': 'zeta-zetachain',
      'TAIKO': 'taiko-taiko',
      'AERGO': 'aergo-aergo',
      
      // === 알트코인들 ===
      'LTC': 'ltc-litecoin',
      'A': 'a-vaulta', // VAULTA (볼타)
      'TRX': 'trx-tron',
      'XLM': 'xlm-stellar',
      'STEEM': 'steem-steem',
      'IOST': 'iost-iost',
      'MTL': 'mtl-metal',
      'GRS': 'grs-groestlcoin',
      'POWR': 'powr-power-ledger',
      'XEM': 'xem-nem',
      'XEC': 'xec-ecash',
      'VTHO': 'vtho-vethor-token',
      'TFUEL': 'tfuel-theta-fuel',
      'HIVE': 'hive-hive',
      'CVC': 'cvc-civic',
      'SNT': 'snt-status',
      'SXP': 'sxp-swipe',
      'T': 't-threshold-network',
      'PUNDIX': 'pundix-pundi-x',
      
      // === DeFi 토큰들 ===
      'CAKE': 'cake-pancakeswap',
      'RUNE': 'rune-thorchain',
      'ALPHA': 'alpha-alpha-finance-lab',
      'DODO': 'dodo-dodo',
      'RAY': 'ray-raydium',
      'SRM': 'srm-serum',
      'KNC': 'knc-kyber-network',
      'ANKR': 'ankr-ankr-network',
      'CELR': 'celr-celer-network',
      'KAVA': 'kava-kava',
      'HARD': 'hard-kava-lend',
      'SWP': 'swp-kava-swap',
      'JST': 'jst-just',
      'SUN': 'sun-sun',
      'CRO': 'cro-cronos',
      'CHZ': 'chz-chiliz',
      'GLM': 'glm-golem',
      'AUCTION': 'auction-bounce',
      'PENDLE': 'pendle-pendle',
      'STG': 'stg-stargate-finance',
      'COW': 'cow-cow-protocol',
      'OM': 'om-mantra-dao',
      'ONDO': 'ondo-ondo',
      'SAFE': 'safe-safe',
      
      // === 스테이블코인 ===
      'USDT': 'usdt-tether',
      'USDC': 'usdc-usd-coin',
      'BUSD': 'busd-binance-usd',
      'DAI': 'dai-dai',
      'TUSD': 'tusd-trueusd',
      'USDD': 'usdd-usdd',
      
      // === 게임/NFT/메타버스 ===
      'GALA': 'gala-gala',
      'APE': 'ape-apecoin',
      'GMT': 'gmt-stepn',
      'GST': 'gst-green-satoshi-token',
      'LOOKS': 'looks-looksrare',
      'PDA': 'pda-playdapp',
      'WAXP': 'wax-wax',
      'TLM': 'tlm-alien-worlds',
      'SLP': 'slp-smooth-love-potion',
      'IMX': 'imx-immutable-x',
      'BIGTIME': 'bigtime-big-time',
      'GAME2': 'game-gamebuild',
      'AGLD': 'agld-adventure-gold',
      'YGG': 'ygg-yield-guild-games',
      'ME': 'me-magic-eden',
      'VIRTUAL': 'virtual-virtual-protocol',
      'MOCA': 'moca-moca',
      'PENGU': 'pengu-pudgy-penguins',
      'MEW': 'mew-cat-in-a-dogs-world',
      'ANIME': 'anime-animecoin',
      'FLOKI': 'floki-floki',
      'BONK': 'bonk-bonk',
      'WIF': 'wif-dogwifcoin',
      'BOME': 'bome-book-of-meme',
      
      // === 한국 프로젝트들 ===
      'KLAY': 'klay-klaytn',
      'BORA': 'bora-bora',
      'META': 'meta-metadium',
      'WEMIX': 'wemix-wemix-token',
      'MBL': 'mbl-moviebloc',
      'HUNT': 'hunt-hunt',
      'TEMCO': 'temco-temco',
      'SOLVE': 'solve-solve-care',
      'PROM': 'prom-prometeus',
      'ORBS': 'orbs-orbs',
      'MIX': 'mix-mixmarvel',
      'CENNZ': 'cennz-centrality',
      'STPT': 'stpt-standard-tokenization-protocol',
      'MDT': 'mdt-measurable-data-token',
      'LAMB': 'lamb-lambda',
      'COTI': 'coti-coti',
      'WTC': 'wtc-waltonchain',
      'NPXS': 'npxs-pundi-x',
      'APIS': 'apis-apis',
      'DAC': 'dac-davinci-coin',
      'ELF': 'elf-aelf',
      'KARMA': 'karma-karma-dao',
      'MEET': 'meet-coinmeet',
      'QKC': 'qkc-quarkchain',
      'SSX': 'ssx-somesing',
      'UPP': 'upp-sentinel-protocol',
      'TOKAMAK': 'ton-tokamak-network',
      'MLK': 'mlk-milk-alliance',
      'DKA': 'dka-dkargo',
      'CBK': 'cbk-cobak-token',
      'MOC': 'moc-mossland',
      'HP': 'hp-hippo-protocol',
      'BOUNTY': 'bnty-bounty0x',
      'MED': 'med-medibloc-qrc20',
      'MVL': 'mvl-mass-vehicle-ledger',
      'ASTR': 'astr-astar',
      'TT': 'tt-thunder-token',
      'MNT': 'mnt-mantle',
      'FCT2': 'fct-firmachain',
      'IQ': 'iq-everipedia',
      'AHT': 'aht-ahatoken',
      'AWE': 'awe-awe-network',
      'ATH': 'ath14-aethir',
      'SOPH': 'soph-sophon',
      'SIGN': 'sign-sign',
      
      // === 솔라나 생태계 ===
      'ORCA': 'orca-orca',
      'DRIFT': 'drift-drift-protocol',
      'SONIC': 's-sonic',
      'LAYER': 'layer-solayer',
      'DEEP': 'deep-deepbook-protocol',
      'MOVE': 'move-movement',
      
      // === AI/기술 토큰들 ===
      'ARKM': 'arkm-arkham',
      'KAITO': 'kaito-kaito',
      'NXPC': 'nxpc-nexpace',
      'WCT': 'wct-walletconnect-token',
      'AKT': 'akt-akash-network',
      'AQT': 'aqt-alpha-quark-token',
      'CARV': 'carv-carv',
      'UXLINK': 'uxlink-uxlink',
      'WAL': 'wal-walrus',
      'CTC': 'ctc-creditcoin',
      'POLYX': 'polyx-polymesh',
      'ID': 'id-space-id',
      'VANA': 'vana-vana',
      'STRIKE': 'strike-strike',
      'BERA': 'bera-berachain',
      'TRUMP': 'trump-maga',
      'POKT': 'pokt-pocket-network',
      'STMX': 'stmx-stormx',
      'BLAST': 'blast-blast',
      
      // === 신규 상장 코인들 ===
      'RVN': 'rvn-ravencoin',
      'AXL': 'axl-axelar',
      'ALT': 'alt-altlayer',
      'NEWT': 'newt-newton-protocol',
      'SAHARA': 'sahara-sahara-ai',
      'MOODENG': 'moodeng-moo-deng-moodengsbs',
      'HYPER': 'hyper-hyperlane',
      'BABY': 'baby-babylon',
      'RESOLV': 'resolv-resolv',
    };
    
    return paprikaMappings[ticker.toUpperCase()];
  }

  /// Fallback 아바타 생성 (첫 글자 또는 기본 아이콘)
  static Widget _buildFallbackAvatar(
    String ticker, 
    double radius, 
    Color? fallbackColor, 
    Color? fallbackTextColor,
  ) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: fallbackColor ?? Colors.grey.shade300,
      child: Text(
        ticker.isNotEmpty ? ticker[0].toUpperCase() : '?',
        style: TextStyle(
          color: fallbackTextColor ?? Colors.grey.shade700,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.6,
        ),
      ),
    );
  }

  /// 특정 티커가 지원되는지 확인
  static bool isSupported(String ticker) => _getCoinPaprikaId(ticker.toUpperCase()) != null;
}