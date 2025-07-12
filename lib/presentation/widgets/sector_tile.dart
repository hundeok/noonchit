import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../../domain/entities/app_settings.dart';
import '../../shared/widgets/sector_names.dart';
import '../../shared/widgets/sector_logo_provider.dart';
import '../../shared/widgets/amount_display_widget.dart';
import '../../shared/utils/tile_common.dart';
import '../../shared/utils/blink_animation_mixin.dart';
import '../../shared/utils/amount_formatter.dart';
import '../controllers/sector_controller.dart';

class SectorTile extends ConsumerStatefulWidget {
  final String sectorName;
  final double totalVolume;
  final int rank;
  final bool isHot;        // ✅ Controller에서 계산된 값
  final bool shouldBlink;  // ✅ Controller에서 계산된 값

  const SectorTile({
    Key? key,
    required this.sectorName,
    required this.totalVolume,
    required this.rank,
    required this.isHot,
    required this.shouldBlink,
  }) : super(key: key);

  @override
  ConsumerState<SectorTile> createState() => _SectorTileState();
}

class _SectorTileState extends ConsumerState<SectorTile>
    with SingleTickerProviderStateMixin {

  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  bool _isBlinking = false;

  @override
  void initState() {
    super.initState();
    // ✅ 애니메이션 초기화 (Volume과 완전 동일)
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(SectorTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // ✅ shouldBlink props 변화 감지해서 애니메이션 시작 (Volume과 완전 동일)
    if (widget.shouldBlink && !oldWidget.shouldBlink && !_isBlinking) {
      _startBlink();
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  /// ✅ 블링크 시작 (Volume과 완전 동일한 로직)
  void _startBlink() {
    final blinkEnabled = ref.read(appSettingsProvider).blinkEnabled;
    if (!mounted || !blinkEnabled) return;
    
    _isBlinking = true;
    _blinkController.forward().then((_) {
      if (mounted) {
        _blinkController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _isBlinking = false;
            });
            
            // ✅ 애니메이션 완료 후 Controller에 상태 초기화 요청 (Volume과 동일)
            ref.read(sectorControllerProvider.notifier).clearBlinkState(widget.sectorName);
          }
        });
      }
    });
  }

  /// ✅ 섹터 번호 매핑 (섹터만의 고유 로직)
  int _getSectorNumber(String sectorName) {
    const sectorNumberMap = {
      // 상세 분류 (1-28번)
      '비트코인 그룹': 1, '이더리움 그룹': 2, '스테이킹': 3, '모놀리식 블록체인': 4,
      '모듈러 블록체인': 5, '스테이블 코인': 6, 'DEX/애그리게이터': 7, '랜딩': 8,
      '유동화 스테이킹/리스테이킹': 9, 'RWA': 10, '지급결제 인프라': 11, '상호운용성/브릿지': 12,
      '엔터프라이즈 블록체인': 13, '오라클': 14, '데이터 인프라': 15, '스토리지': 16,
      'AI': 17, '메타버스': 18, 'NFT/게임': 19, '미디어/스트리밍': 20,
      '광고': 21, '교육/기타 콘텐츠': 22, '소셜/DAO': 23, '팬토큰': 24,
      '밈': 25, 'DID': 26, '의료': 27, '월렛/메세징': 28,
      // 기본 분류 (29-47번)
      '메이저 코인': 29, '비트코인 계열': 30, '이더리움 생태계': 31, '레이어1 블록체인': 32,
      '고 시총': 33, '중 시총': 34, '저 시총': 35, '마이너 알트코인': 36,
      'DeFi 토큰': 37, '스테이블코인': 38, '게임/NFT/메타버스': 39, '한국 프로젝트': 40,
      '솔라나 생태계': 41, 'AI/기술 토큰': 42, '2023년 신규상장': 43, '2024년 상반기 신규상장': 44,
      '2024년 하반기 신규상장': 45, '2025년 상반기 신규상장': 46,
      '2025년 하반기 신규상장': 47, // ✅ 수정된 부분
    };
    return sectorNumberMap[sectorName] ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    
    // 🚀 Controller에서 직접 상태 조회 (Volume과 동일한 패턴)
    final controller = ref.read(sectorControllerProvider.notifier);
    final displayMode = ref.watch(appSettingsProvider).displayMode;
    
    // ✅ 섹터명 표시 (Controller에서 분류 상태 조회)
    final displaySectorName = SectorNames.getDisplayName(
      widget.sectorName, 
      displayMode, 
      isDetailed: controller.isDetailedClassification, // 🚀 Controller에서 조회!
    );

    // ✅ 표준 카드 위젯 생성 (Volume과 완전 동일한 구조)
    Widget cardWidget = TileCommon.buildStandardCard(
      child: TileCommon.buildFlexRow(
        children: [
          // 🏆 순위 부분 (Volume과 동일)
          FlexChild.fixed(
            TileCommon.buildRankWidget(context, widget.rank),
          ),

          const FlexChild.fixed(SizedBox(width: 12)),

          // 🎨 섹터 아이콘 부분 (섹터만의 고유 요소)
          FlexChild.fixed(
            SectorLogoProvider.buildSectorIcon(
              sectorNumber: _getSectorNumber(widget.sectorName),
              size: 40.0,
            ),
          ),

          const FlexChild.fixed(SizedBox(width: 12)),

          // 📱 섹터명 부분 (Volume과 동일한 구조)
          FlexChild.expanded(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displaySectorName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 🔥 HOT 아이콘 (설정 체크 - 블링크와 동일한 패턴)
                    Consumer(
                      builder: (context, ref, child) {
                        final hotEnabled = ref.watch(appSettingsProvider).hotEnabled;
                        if (hotEnabled && widget.isHot) {
                          return TileCommon.buildHotIcon(true) ?? const SizedBox.shrink();
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  SectorNames.getDisplayName(
                    widget.sectorName, 
                    DisplayMode.ticker, 
                    isDetailed: controller.isDetailedClassification, // 🚀 Controller에서 조회!
                  ),
                  style: TextStyle(
                    color: onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            flex: 25,
          ),

          // 💰 거래량 부분 (Volume과 완전 동일)
          FlexChild.expanded(
            Align(
              alignment: Alignment.centerRight,
              child: Consumer(
                builder: (context, ref, child) {
                  final amountDisplayMode = ref.watch(appSettingsProvider).amountDisplayMode;

                  return amountDisplayMode == AmountDisplayMode.icon
                      ? AmountDisplayWidget(
                          totalAmount: widget.totalVolume,
                          isBuy: true,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        )
                      : Text(
                          AmountFormatter.formatVolume(widget.totalVolume),
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                },
              ),
            ),
            flex: 30,
          ),
        ],
      ),
    );

    // ✅ 블링크 애니메이션 적용 (Volume과 완전 동일)
    final blinkEnabled = ref.watch(appSettingsProvider).blinkEnabled;

    // ✅ 블링크 상태에 따른 애니메이션 적용 (Volume과 완전 동일)
    if (blinkEnabled && (_isBlinking || widget.shouldBlink)) {
      return BlinkAnimationHelper.wrapWithBlinkEffect(
        child: cardWidget,
        shouldBlink: _isBlinking,
        blinkAnimation: _blinkAnimation,
        blinkColor: Colors.amber,
      );
    }

    return cardWidget;
  }
}
