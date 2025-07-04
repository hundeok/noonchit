// lib/presentation/pages/market_mood_page.dart
// 📱 Presentation Layer: Market Mood 페이지 (모달 형태, 클린 아키텍처)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../controllers/market_mood_controller.dart';

/// 📱 마켓무드 상세 페이지 (모달 형태)
class MarketMoodPage extends ConsumerStatefulWidget {
  final double statusIconSize;
  final MarketMoodData data;

  const MarketMoodPage({
    super.key,
    required this.statusIconSize,
    required this.data,
  });

  @override
  ConsumerState<MarketMoodPage> createState() => _MarketMoodPageState();
}

class _MarketMoodPageState extends ConsumerState<MarketMoodPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animationController.forward();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5),
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          alignment: Alignment.center,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: _buildPageContent(),
          ),
        );
      },
    );
  }

  Widget _buildPageContent() {
    // 화면 크기 계산
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = screenSize.width * 0.9;

    return IntrinsicWidth(
      child: Container(
        constraints: BoxConstraints(
          minWidth: widget.statusIconSize * 4.2,
          maxWidth: maxWidth,
        ),
        decoration: _buildContainerDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildCoreMetrics(),
              const SizedBox(height: 8),
              _buildIntradayAnalysis(),
              const SizedBox(height: 8),
              _buildLongTermAnalysis(),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildContainerDecoration() {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          // [수정] withOpacity -> withValues
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: 2,
        ),
        BoxShadow(
          // [수정] withOpacity -> withValues
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
      border: Border.all(
        // [수정] withOpacity -> withValues
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        width: 0.8,
      ),
    );
  }

  Widget _buildHeader() {
    final controller = ref.read(marketMoodPageControllerProvider.notifier);
    final updateTime = controller.formatUpdateTime(widget.data.updatedAt);

    return Consumer(
      builder: (context, ref, child) {
        final computedAsync = ref.watch(marketMoodComputedDataProvider);

        return computedAsync.when(
          data: (computedData) {
            final currentMood = ref.watch(currentMarketMoodProvider);
            final moodEmoji = controller.getMoodEmoji(currentMood);
            final moodName = controller.getMoodName(currentMood);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                        '$moodName - ᖾ ᖽ',
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 9,
                      // [수정] withOpacity -> withValues
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '실시간 기준 • ',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        // [수정] withOpacity -> withValues
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                    Icon(
                      Icons.access_time,
                      size: 9,
                      // [수정] withOpacity -> withValues
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '$updateTime 업데이트',
                        style: TextStyle(
                          fontSize: 8,
                          // [수정] withOpacity -> withValues
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
          loading: () => _buildLoadingHeader(),
          error: (_, __) => _buildErrorHeader(),
        );
      },
    );
  }

  Widget _buildLoadingHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)
            ),
            SizedBox(width: 8),
            Text(
              '로딩중...',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 12,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 4),
            Text(
              '데이터 로드 오류',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCoreMetrics() {
    return Consumer(
      builder: (context, ref, child) {
        final exchangeAsync = ref.watch(exchangeRateProvider);

        return exchangeAsync.when(
          data: (exchangeRate) => _buildCoreMetricsContent(exchangeRate),
          loading: () => _buildLoadingMetrics(),
          error: (_, __) => _buildCoreMetricsContent(1400.0),
        );
      },
    );
  }

  Widget _buildCoreMetricsContent(double exchangeRate) {
    final controller = ref.read(marketMoodPageControllerProvider.notifier);

    return FutureBuilder<List<String>>(
      future: Future.wait([
        controller.formatVolume(widget.data.totalVolumeUsd),
        controller.formatMarketCap(widget.data.totalMarketCapUsd),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingMetrics();
        }
        if (snapshot.hasData) {
          final values = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('핵심 지표', Icons.analytics),
              const SizedBox(height: 4),
              _buildStatRow(
                icon: Icons.monetization_on,
                label: '24시간 거래대금',
                value: values[0],
                isHighlight: true,
              ),
              _buildStatRow(
                icon: Icons.pie_chart,
                label: '총 시가총액',
                value: values[1],
              ),
              _buildStatRow(
                icon: Icons.trending_up,
                label: '시총 24시간 변화',
                value: '${widget.data.marketCapChange24h >= 0 ? '+' : ''}${widget.data.marketCapChange24h.toStringAsFixed(2)}%',
                isHighlight: widget.data.marketCapChange24h > 0,
                isWarning: widget.data.marketCapChange24h < -2,
              ),
              _buildStatRow(
                icon: Icons.flash_on,
                label: 'BTC 도미넌스',
                value: '${widget.data.btcDominance.toStringAsFixed(1)}%',
              ),
            ],
          );
        }
        return _buildLoadingMetrics();
      },
    );
  }

  Widget _buildLoadingMetrics() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('핵심 지표', Icons.analytics),
        const SizedBox(height: 4),
        const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ],
    );
  }

  Widget _buildIntradayAnalysis() {
    return Consumer(
      builder: (context, ref, child) {
        final computedAsync = ref.watch(marketMoodComputedDataProvider);

        return computedAsync.when(
          data: (computedData) {
            final comparisonData = ref.watch(volumeComparisonProvider);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('인트라데이 비교 분석', Icons.schedule),
                const SizedBox(height: 4),
                _buildComparisonRow('30분 대비', comparisonData.thirtyMin, Icons.hourglass_empty),
                _buildComparisonRow('1시간 대비', comparisonData.oneHour, Icons.hourglass_full),
                _buildComparisonRow('2시간 대비', comparisonData.twoHour, Icons.access_time),
                _buildComparisonRow('4시간 대비', comparisonData.fourHour, Icons.timer),
                _buildComparisonRow('8시간 대비', comparisonData.eightHour, Icons.timer_outlined),
                _buildComparisonRow('12시간 대비', comparisonData.twelveHour, Icons.update),
              ],
            );
          },
          loading: () => _buildLoadingSection('인트라데이 비교 분석', Icons.schedule),
          error: (_, __) => _buildErrorSection('인트라데이 비교 분석', Icons.schedule),
        );
      },
    );
  }

  Widget _buildLongTermAnalysis() {
    return Consumer(
      builder: (context, ref, child) {
        final computedAsync = ref.watch(marketMoodComputedDataProvider);

        return computedAsync.when(
          data: (computedData) {
            final comparisonData = ref.watch(volumeComparisonProvider);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('장기 비교 분석', Icons.calendar_month),
                const SizedBox(height: 4),
                _buildComparisonRow('24시간 대비', comparisonData.twentyFourHour, Icons.calendar_today),
                _buildComparisonRow('3일 평균 대비', comparisonData.threeDayAverage, Icons.view_day),
                _buildComparisonRow('일주일 평균 대비', comparisonData.weeklyAverage, Icons.date_range),
              ],
            );
          },
          loading: () => _buildLoadingSection('장기 비교 분석', Icons.calendar_month),
          error: (_, __) => _buildErrorSection('장기 비교 분석', Icons.calendar_month),
        );
      },
    );
  }

  Widget _buildLoadingSection(String title, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, icon),
        const SizedBox(height: 4),
        const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ],
    );
  }

  Widget _buildErrorSection(String title, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, icon),
        const SizedBox(height: 4),
        Text(
          '데이터 로드 오류',
          style: TextStyle(
            fontSize: 9,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(String label, ComparisonResult result, IconData icon) {
    final controller = ref.read(marketMoodPageControllerProvider.notifier);

    if (result.isReady && result.changePercent != null) {
      return _buildStatRow(
        icon: icon,
        label: label,
        value: controller.formatComparisonValue(result),
        isHighlight: controller.isHighlight(result),
        isWarning: controller.isWarning(result),
      );
    } else {
      return _buildProgressRow(icon, label, result);
    }
  }

  Widget _buildProgressRow(IconData icon, String label, ComparisonResult result) {
    final controller = ref.read(marketMoodPageControllerProvider.notifier);
    final progressPercent = controller.getProgressPercent(result);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            // [수정] withOpacity -> withValues
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label: $progressPercent% (${result.status})',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    // [수정] withOpacity -> withValues
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: result.progressPercent.clamp(0.0, 1.0),
                  // [수정] withOpacity -> withValues
                  backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(
                    result.progressPercent >= 1.0
                      ? Colors.green
                      // [수정] withOpacity -> withValues
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                  ),
                  minHeight: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 11,
          // [수정] withOpacity -> withValues
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            // [수정] withOpacity -> withValues
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            letterSpacing: 0.3,
          ),
        ),
      ],
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
      // [수정] withOpacity -> withValues
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlight
            // [수정] withOpacity -> withValues
            ? Colors.green.withValues(alpha: 0.08)
            : isWarning
            // [수정] withOpacity -> withValues
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
              // [수정] withOpacity -> withValues
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
}