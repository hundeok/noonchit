import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/market_mood_provider.dart';

/// Market Mood 상세 정보 팝업 오버레이
class MarketMoodStatsOverlay {
  static OverlayEntry? _overlayEntry;

  /// 롱프레스 시 팝업 표시
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required Offset position,
    required double statusIconSize,
    required MarketMoodData data,
  }) {
    hide(); // 기존 팝업 제거

    _overlayEntry = OverlayEntry(
      builder: (context) => _MarketMoodStatsPopup(
        position: position,
        statusIconSize: statusIconSize,
        ref: ref,
        data: data,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// 팝업 숨기기
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _MarketMoodStatsPopup extends StatefulWidget {
  final Offset position;
  final double statusIconSize;
  final WidgetRef ref;
  final MarketMoodData data;

  const _MarketMoodStatsPopup({
    required this.position,
    required this.statusIconSize,
    required this.ref,
    required this.data,
  });

  @override
  State<_MarketMoodStatsPopup> createState() => _MarketMoodStatsPopupState();
}

class _MarketMoodStatsPopupState extends State<_MarketMoodStatsPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5),
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => MarketMoodStatsOverlay.hide(),
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 투명 배경 (탭하면 닫힘)
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            // 실제 팝업
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Positioned(
                  left: widget.position.dx,
                  top: widget.position.dy,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    alignment: Alignment.center,
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: _buildPopupContent(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupContent() {
    // 화면 크기 가져오기 (새로운 2섹션 시스템 대응)
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = screenSize.width * 0.95; // 95%로 확장

    return IntrinsicWidth(
      child: Container(
        constraints: BoxConstraints(
          minWidth: widget.statusIconSize * 4.2,
          maxWidth: maxWidth,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
            width: 0.8,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 메인 헤더
              _buildHeader(),
              const SizedBox(height: 8),
              // 핵심 지표
              _buildCoreMetrics(),
              const SizedBox(height: 8),
              // 🚀 Section 1: 타임프레임별 가속도 분석 (새로운 시스템)
              _buildSection1TimeframeComparison(),
              const SizedBox(height: 8),
              // 📅 Section 2: 데일리 거래 현황
              _buildSection2DailyStatus(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final data = widget.data;
    final currentMood = widget.ref.watch(currentMarketMoodProvider);
    final updateTime = _formatUpdateTime(data.updatedAt);

    // 분위기 이모지 매핑
    String moodEmoji = switch (currentMood) {
      MarketMood.bull => '🚀',
      MarketMood.weakBull => '🔥',
      MarketMood.sideways => '⚖️',
      MarketMood.bear => '💧',
      MarketMood.deepBear => '🧊',
    };

    String moodName = switch (currentMood) {
      MarketMood.bull => '불장',
      MarketMood.weakBull => '약불장',
      MarketMood.sideways => '중간장',
      MarketMood.bear => '물장',
      MarketMood.deepBear => '얼음장',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 메인 타이틀 (30분 기준 가속도 분석)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              moodEmoji,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$moodName - 30분 가속도 분석',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // 15분 업데이트 주기 안내
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sync,
              size: 9,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 3),
            Text(
              '15분마다 업데이트 • ',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            Icon(
              Icons.access_time,
              size: 9,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                '$updateTime 갱신',
                style: TextStyle(
                  fontSize: 8,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCoreMetrics() {
    final data = widget.data;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('핵심 지표', Icons.analytics),
        const SizedBox(height: 4),
        _buildStatRow(
          icon: Icons.monetization_on,
          label: '24시간 거래대금',
          value: MarketMoodCalculator.formatVolume(data.totalVolumeUsd),
          isHighlight: true,
        ),
        _buildStatRow(
          icon: Icons.pie_chart,
          label: '총 시가총액',
          value: _formatMarketCap(data.totalMarketCapUsd),
        ),
        _buildStatRow(
          icon: Icons.trending_up,
          label: '시총 24시간 변화',
          value: '${data.marketCapChange24h >= 0 ? '+' : ''}${data.marketCapChange24h.toStringAsFixed(2)}%',
          isHighlight: data.marketCapChange24h > 0,
          isWarning: data.marketCapChange24h < -2,
        ),
        _buildStatRow(
          icon: Icons.flash_on,
          label: 'BTC 도미넌스',
          value: '${data.btcDominance.toStringAsFixed(1)}%',
        ),
      ],
    );
  }

  /// 🚀 Section 1: 타임프레임별 가속도 분석 (완전 새로운 시스템)
  Widget _buildSection1TimeframeComparison() {
    return Consumer(
      builder: (context, ref, child) {
        final comparisonData = ref.watch(timeframeComparisonProvider);
        final slotManager = ref.read(ultimateSlotCacheManagerProvider);
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('타임프레임별 가속도 분석', Icons.speed),
            const SizedBox(height: 4),
            
            // 인트라데이 (6개) - 새로운 UI 시스템
            _buildSubSectionTitle('인트라데이 (완성된 슬롯 기반)'),
            _buildNewComparisonRow('30min', comparisonData.thirtyMin, slotManager, Icons.schedule),
            _buildNewComparisonRow('1hour', comparisonData.oneHour, slotManager, Icons.access_time),
            _buildNewComparisonRow('2hour', comparisonData.twoHour, slotManager, Icons.timer),
            _buildNewComparisonRow('4hour', comparisonData.fourHour, slotManager, Icons.timer_3),
            _buildNewComparisonRow('8hour', comparisonData.eightHour, slotManager, Icons.timer_outlined),
            _buildNewComparisonRow('12hour', comparisonData.twelveHour, slotManager, Icons.access_time_filled),
            
            const SizedBox(height: 4),
            
            // 장기 (3개)
            _buildSubSectionTitle('장기 (일별 완성 데이터 기반)'),
            _buildNewComparisonRow('1day', comparisonData.oneDay, slotManager, Icons.calendar_today),
            _buildNewComparisonRow('3day', comparisonData.threeDay, slotManager, Icons.view_day),
            _buildNewComparisonRow('1week', comparisonData.oneWeek, slotManager, Icons.date_range),
          ],
        );
      },
    );
  }

  /// 🎮 새로운 비교 행 위젯 (좌측: 상태 / 우측: 결과)
  Widget _buildNewComparisonRow(String timeframe, ComparisonResult result, UltimateSlotCacheManager slotManager, IconData icon) {
    final gaugeState = slotManager.getGaugeState(timeframe);
    final latestResult = slotManager.getLatestResult(timeframe);
    
    // 좌측 텍스트 생성
    final leftText = MarketMoodCalculator.getLeftText(timeframe, result, gaugeState);
    
    // 우측 텍스트 생성
    final rightText = MarketMoodCalculator.getRightText(latestResult);
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: gaugeState.isCompleted || gaugeState.isInGracePeriod
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          // 상단: 좌측 상태 + 우측 결과
          Row(
            children: [
              // 좌측: 현재 상태
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        leftText,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // 우측: 최신 결과
              SizedBox(
                width: 80,
                child: Text(
                  rightText,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: _getResultColor(latestResult),
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // 하단: 게이지 바 (정밀도 + 색상 변화)
          LinearProgressIndicator(
            value: gaugeState.progress / 100.0,
            backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(gaugeState.gaugeColor),
            minHeight: 3,
          ),
        ],
      ),
    );
  }

  /// 결과값에 따른 색상 결정
  Color _getResultColor(double? changePercent) {
    if (changePercent == null) {
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    }
    
    if (changePercent > 5) return Colors.green;
    if (changePercent < -5) return Colors.red;
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
  }

  /// 📅 Section 2: 데일리 거래 현황
  Widget _buildSection2DailyStatus() {
    return Consumer(
      builder: (context, ref, child) {
        final dailyStatus = ref.watch(dailyStatusProvider);
        final now = DateTime.now();
        final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('데일리 거래 현황 ($currentTime 기준)', Icons.today),
            const SizedBox(height: 4),
            
            // 시간대별 강도
            if (dailyStatus.hourlyIntensityChange != null)
              _buildStatRow(
                icon: Icons.speed,
                label: '시간대별 강도 (어제 동시간 대비)',
                value: '${dailyStatus.hourlyIntensityChange! >= 0 ? '+' : ''}${dailyStatus.hourlyIntensityChange!.toStringAsFixed(1)}% ${dailyStatus.hourlyIntensityChange! > 5 ? '활발 ↗️' : dailyStatus.hourlyIntensityChange! < -5 ? '둔화 ↘️' : '보통 ➡️'}',
                isHighlight: dailyStatus.hourlyIntensityChange! > 5,
                isWarning: dailyStatus.hourlyIntensityChange! < -5,
              )
            else
              _buildStatRow(
                icon: Icons.speed,
                label: '시간대별 강도',
                value: '15분 후 업데이트...',
              ),
            
            // 누적률
            if (dailyStatus.accumulationRate != null)
              _buildAccumulationDisplay(dailyStatus.accumulationRate!)
            else
              _buildStatRow(
                icon: Icons.trending_up,
                label: '어제 대비 누적률',
                value: '15분 후 업데이트...',
              ),
            
            // 예상 최종량
            if (dailyStatus.estimatedFinal != null && dailyStatus.yesterdayFinal != null)
              _buildStatRow(
                icon: Icons.psychology,
                label: '예상 최종량 (현재 페이스)',
                value: '${MarketMoodCalculator.formatVolume(dailyStatus.estimatedFinal!)} (${((dailyStatus.estimatedFinal! - dailyStatus.yesterdayFinal!) / dailyStatus.yesterdayFinal! * 100).toStringAsFixed(1)}% 예상)',
                isHighlight: dailyStatus.estimatedFinal! > dailyStatus.yesterdayFinal!,
                isWarning: dailyStatus.estimatedFinal! < dailyStatus.yesterdayFinal! * 0.9,
              ),
          ],
        );
      },
    );
  }

  /// 누적률 특별 표시 (100% 초과 가능)
  Widget _buildAccumulationDisplay(double rate) {
    final isOver100 = rate >= 100;
    final displayRate = rate.toStringAsFixed(1);
    
    String statusText;
    if (rate >= 120) {
      statusText = '🚀 어제 총량 대폭 초과!';
    } else if (rate >= 110) {
      statusText = '🎉 어제 총량 크게 초과!';
    } else if (rate >= 100) {
      statusText = '✅ 어제 총량 달성!';
    } else if (rate >= 95) {
      statusText = '🔥 어제 수준 근접!';
    } else if (rate >= 80) {
      statusText = '📈 어제의 대부분 달성';
    } else {
      statusText = '진행 중';
    }
    
    return _buildStatRow(
      icon: isOver100 ? Icons.celebration : Icons.trending_up,
      label: '어제 대비 누적률',
      value: '$displayRate% ($statusText)',
      isHighlight: isOver100,
      isWarning: rate < 80,
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 11,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    bool isError = false,
    bool isHighlight = false,
    bool isWarning = false,
  }) {
    Color getColor() {
      if (isError) return Theme.of(context).colorScheme.error;
      if (isHighlight) return Colors.green;
      if (isWarning) return Colors.red;
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlight
            ? Colors.green.withValues(alpha: 0.08)
            : isWarning
            ? Colors.red.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: getColor(),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: getColor(),
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatUpdateTime(DateTime dateTime) {
    // 15분 업데이트 주기에 맞춘 시간 표시
    final koreanTime = dateTime.toUtc().add(const Duration(hours: 9));
    
    return '${koreanTime.year}.${koreanTime.month.toString().padLeft(2, '0')}.${koreanTime.day.toString().padLeft(2, '0')} '
        '${koreanTime.hour.toString().padLeft(2, '0')}:${koreanTime.minute.toString().padLeft(2, '0')}';
  }

  /// 시가총액 포맷팅
  String _formatMarketCap(double marketCapUsd, [double usdToKrw = 1400]) {
    final marketCapKrw = marketCapUsd * usdToKrw;
    if (marketCapKrw >= 1e12) {
      final trillions = (marketCapKrw / 1e12).toStringAsFixed(0);
      return '${_addCommas(trillions)}조원';
    }
    if (marketCapKrw >= 1e8) {
      final hundreds = (marketCapKrw / 1e8).toStringAsFixed(0);
      return '${_addCommas(hundreds)}억원';
    }
    return '${(marketCapKrw / 1e8).toStringAsFixed(1)}억원';
  }

  /// 숫자 콤마 추가
  String _addCommas(String numberStr) {
    final parts = numberStr.split('.');
    final integerPart = parts[0];
    final reversedInteger = integerPart.split('').reversed.join('');
    final withCommas = reversedInteger
        .replaceAllMapped(RegExp(r'.{3}'), (match) => '${match.group(0)},')
        .split('')
        .reversed
        .join('');
    final result = withCommas.startsWith(',') ? withCommas.substring(1) : withCommas;
    return parts.length > 1 ? '$result.${parts[1]}' : result;
  }
}