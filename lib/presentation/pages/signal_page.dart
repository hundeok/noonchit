// lib/presentation/pages/signal_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_config.dart';
import '../../core/di/settings_provider.dart';
import '../../core/di/signal_provider.dart';
import '../../core/di/trade_provider.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/signal.dart';
import '../controllers/signal_controller.dart';
import '../widgets/signal_tile.dart';

/// 🚀 Signal Page V4.1 - 온라인 지표 연동
class SignalPage extends ConsumerWidget {
  final ScrollController scrollController;

  const SignalPage({
    super.key,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // V4.1 Controller 기반 시스템
    final controller = ref.watch(signalControllerProvider.notifier);
    final state = ref.watch(signalControllerProvider);

    // 시그널 스트림 (V4.1 온라인 지표 연동)
    final signalsAsync = ref.watch(signalListProvider);

    // markets 정보
    final marketsAsync = ref.watch(marketsProvider);

    // 슬라이더 위치 설정
    final sliderPosition = ref.watch(appSettingsProvider).sliderPosition;

    // 🆕 V4.1 시스템 모니터링
    ref.listen(signalSystemMonitorProvider, (prev, next) {
      if (next.hasError && AppConfig.enableTradeLog) {
        debugPrint('⚠️ Signal system monitoring error: ${next.error}');
      }
    });

    // 에러 메시지 자동 클리어
    ref.listen(signalControllerProvider.select((s) => s.errorMessage), (prev, next) {
      if (next != null) {
        Future.delayed(const Duration(seconds: 5), () {
          controller.clearError();
        });
      }
    });

    // 🆕 V4.1 슬라이더 위젯 (온라인 지표 상태 포함)
    final sliderWidget = _buildEnhancedSliderWidget(
      controller,
      state,
      marketsAsync,
      ref,
      context,
    );

    // 🆕 V4.1 시그널 리스트 (정렬 및 필터링 포함)
    final signalListWidget = _buildEnhancedSignalList(
      signalsAsync,
      controller,
      scrollController,
      state,
      context,
      ref,
    );

    return PrimaryScrollController(
      controller: scrollController,
      child: Column(
        children: [
          // 슬라이더 위치에 따른 조건부 배치
          if (sliderPosition == SliderPosition.top) sliderWidget,

          // 🆕 V4.1 에러 메시지 표시
          if (state.errorMessage != null) _buildErrorBanner(state.errorMessage!, controller),

          // 시그널 리스트 (항상 중간)
          Expanded(child: signalListWidget),

          // 슬라이더가 하단일 때
          if (sliderPosition == SliderPosition.bottom) sliderWidget,
        ],
      ),
    );
  }

  /// 🆕 V4.1 에러 배너
  Widget _buildErrorBanner(String errorMessage, SignalController controller) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: controller.clearError,
            child: const Icon(Icons.close, color: Colors.red, size: 16),
          ),
        ],
      ),
    );
  }

  /// 🚀 V4.1 강화된 슬라이더 위젯 (온라인 지표 상태 포함)
  Widget _buildEnhancedSliderWidget(
    SignalController controller,
    SignalState state,
    AsyncValue<List<String>> marketsAsync,
    WidgetRef ref,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🎯 첫 번째 줄: 아이콘 + 제목 + 설명 + 상태 표시
          Row(
            children: [
              // 패턴 아이콘 + 제목
              Icon(
                _getPatternIcon(state.currentPattern),
                size: 18,
                color: _getPatternColor(state.currentPattern),
              ),
              const SizedBox(width: 8),
              
              // 제목 + 설명
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.currentPattern.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      state.currentPattern.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 🆕 V4.1 시스템 상태 표시
              _buildSystemStatusChip(state),
              const SizedBox(width: 8),

              // 활성화/비활성화 토글
              _buildPatternToggle(state, controller, ref),
            ],
          ),

          const SizedBox(height: 8),

          // 🎯 두 번째 줄: 임계값 + 신뢰도 정보
          Row(
            children: [
              Text(
                '임계값: ${controller.getThresholdDisplayText()}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Spacer(),
              // 🆕 V4.1 신뢰도 정보
              Text(
                controller.getConfidenceStatusText(),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 🎯 세 번째 줄: 패턴 슬라이더
          Row(
            children: [
              // 슬라이더
              Expanded(
                child: Slider(
                  value: state.selectedIndex.toDouble(),
                  min: 0,
                  max: (PatternType.values.length - 1).toDouble(),
                  divisions: PatternType.values.length - 1,
                  label: state.currentPattern.displayName,
                  activeColor: _getPatternColor(state.currentPattern),
                  onChanged: (v) {
                    if (ref.read(appSettingsProvider).isHapticEnabled) {
                      HapticFeedback.lightImpact();
                    }
                    final index = v.round();
                    marketsAsync.whenData((markets) {
                      controller.setPatternIndex(index, markets);
                    });
                  },
                ),
              ),

              // 🆕 V4.1 정렬 버튼
              _buildSortButton(state, controller),
            ],
          ),

          // 🆕 V4.1 온라인 지표 상태 바
          _buildOnlineMetricsStatusBar(state),
        ],
      ),
    );
  }

  /// 🆕 V4.1 시스템 상태 칩
  Widget _buildSystemStatusChip(SignalState state) {
    final isHealthy = state.isSystemHealthy;
    final color = isHealthy ? Colors.green : Colors.orange;
    final icon = isHealthy ? Icons.check_circle : Icons.warning;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            isHealthy ? 'OK' : 'WARN',
            style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// 🆕 V4.1 패턴 토글 버튼
  Widget _buildPatternToggle(SignalState state, SignalController controller, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        if (ref.read(appSettingsProvider).isHapticEnabled) {
          HapticFeedback.lightImpact();
        }
        controller.togglePatternEnabled();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange,
            width: 1.5,
          ),
          color: state.isPatternEnabled ? Colors.orange : Colors.transparent,
        ),
        child: Text(
          state.isPatternEnabled ? '활성' : '비활성',
          style: TextStyle(
            color: state.isPatternEnabled ? Colors.white : Colors.orange,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 🆕 V4.1 정렬 버튼
  Widget _buildSortButton(SignalState state, SignalController controller) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.sort,
        size: 18,
        color: Colors.grey[600],
      ),
      onSelected: (value) {
        controller.setSortField(value);
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'time', child: Text('시간 ${_getSortIcon(state, 'time')}')),
        PopupMenuItem(value: 'confidence', child: Text('신뢰도 ${_getSortIcon(state, 'confidence')}')),
        PopupMenuItem(value: 'change', child: Text('변화율 ${_getSortIcon(state, 'change')}')),
        PopupMenuItem(value: 'amount', child: Text('거래액 ${_getSortIcon(state, 'amount')}')),
        PopupMenuItem(value: 'market', child: Text('마켓 ${_getSortIcon(state, 'market')}')),
      ],
    );
  }

  /// 🆕 정렬 아이콘 헬퍼
  String _getSortIcon(SignalState state, String field) {
    if (state.sortField != field) return '';
    return state.sortAscending ? '↑' : '↓';
  }

  /// 🆕 V4.1 온라인 지표 상태 바
  Widget _buildOnlineMetricsStatusBar(SignalState state) {
    if (!state.hasOnlineMetrics) {
      return Container(
        height: 2,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1),
          color: Colors.grey[300],
        ),
      );
    }

    final health = state.onlineMetricsHealth!;
    final totalMarkets = health['totalMarkets'] ?? 0;
    final healthyMarkets = health['healthyMarkets'] ?? 0;
    final staleMarkets = health['staleMarkets'] ?? 0;
    
    final healthRatio = totalMarkets > 0 ? healthyMarkets / totalMarkets : 0.0;
    final color = staleMarkets > 0 ? Colors.orange : Colors.green;

    return Container(
      height: 2,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        color: Colors.grey[300],
      ),
      child: FractionallySizedBox(
        widthFactor: healthRatio,
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            color: color,
          ),
        ),
      ),
    );
  }

  /// 🚀 V4.1 강화된 시그널 리스트 (정렬 및 온라인 지표 표시)
  Widget _buildEnhancedSignalList(
    AsyncValue<List<Signal>> signalsAsync,
    SignalController controller,
    ScrollController scrollController,
    SignalState state,
    BuildContext context,
    WidgetRef ref,
  ) {
    return signalsAsync.when(
      data: (list) {
        final viewList = controller.apply(list);

        if (viewList.isEmpty) {
          return _buildEmptyState(state, context, controller);
        }

        return _buildSignalListView(viewList, scrollController, state, ref);
      },
      loading: () => _buildLoadingState(context),
      error: (e, _) => _buildErrorState(e, context, ref),
    );
  }

  /// 🆕 V4.1 빈 상태 (온라인 지표 정보 포함)
  Widget _buildEmptyState(SignalState state, BuildContext context, SignalController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.radar,
            size: 64,
            color: Theme.of(context).hintColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            state.isPatternEnabled
                ? '${state.currentPattern.displayName} 패턴이 감지되지 않았습니다.'
                : '패턴 감지가 비활성화되어 있습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).hintColor, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '임계값: ${controller.getThresholdDisplayText()}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).hintColor.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          // 🆕 V4.1 온라인 지표 상태
          if (state.hasOnlineMetrics) ...[
            const SizedBox(height: 8),
            Text(
              controller.getSystemStatusText(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).hintColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
          // 🆕 V4.1 빠른 액션 버튼들
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 온라인 지표 리셋 버튼
              ElevatedButton.icon(
                onPressed: () => controller.resetOnlineMetrics(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('지표 리셋'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              // 프리셋 적용 버튼
              ElevatedButton.icon(
                onPressed: () => _showPresetDialog(context, controller),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('프리셋'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🆕 V4.1 로딩 상태 (개선된 디자인)
  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            '온라인 지표 연동 중...',
            style: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// 🆕 V4.1 에러 상태 (개선된 에러 처리)
  Widget _buildErrorState(Object error, BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '시그널 로드 중 오류가 발생했습니다.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(signalListProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // 🆕 V4.1 고급 진단 버튼
              ElevatedButton.icon(
                onPressed: () => _showDiagnosticsDialog(context, ref),
                icon: const Icon(Icons.info),
                label: const Text('진단'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🆕 V4.1 시그널 리스트 뷰 (온라인 지표 표시 포함)
  Widget _buildSignalListView(
    List<Signal> viewList,
    ScrollController scrollController,
    SignalState state,
    WidgetRef ref,
  ) {
    return RawScrollbar(
      controller: scrollController,
      thumbVisibility: false,
      trackVisibility: false,
      thickness: 6.4,
      radius: const Radius.circular(3.2),
      thumbColor: Colors.orange.withValues(alpha: 0.5),
      interactive: true,
      minThumbLength: 40,
      child: ListView.builder(
        controller: scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.only(left: 16, right: 20, top: 16, bottom: 16),
        itemCount: viewList.length,
        itemBuilder: (context, index) {
          final signal = viewList[index];
          
          return Column(
            children: [
              // 🆕 V4.1 Signal Tile 사용 (탭 기능 추가)
              GestureDetector(
                onTap: () => _showSignalDetails(context, signal, ref),
                child: SignalTile(
                  signal: signal,
                  showOnlineMetrics: true,
                ),
              ),
              
              // 구분선 (마지막 아이템 제외)
              if (index < viewList.length - 1)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey[300],
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================================================
  // 🆕 V4.1 대화상자들
  // ==========================================================================

  /// 🆕 프리셋 선택 대화상자
  void _showPresetDialog(BuildContext context, SignalController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('패턴 프리셋 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.security, color: Colors.blue),
              title: const Text('Conservative'),
              subtitle: const Text('False Positive 최소화'),
              onTap: () {
                controller.applyPreset('conservative');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.balance, color: Colors.green),
              title: const Text('Balanced'),
              subtitle: const Text('균형잡힌 기본 설정'),
              onTap: () {
                controller.applyPreset('balanced');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.speed, color: Colors.red),
              title: const Text('Aggressive'),
              subtitle: const Text('감지율 최대화'),
              onTap: () {
                controller.applyPreset('aggressive');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 🆕 진단 정보 대화상자
  void _showDiagnosticsDialog(BuildContext context, WidgetRef ref) {
    final controller = ref.read(signalControllerProvider.notifier);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('시스템 진단'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: controller.getSystemHealthReport(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('진단 중...'),
                ],
              );
            }
            
            if (snapshot.hasError) {
              return Text('진단 실패: ${snapshot.error}');
            }
            
            final report = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('버전: ${report['version']}'),
                  Text('상태: ${report['status']}'),
                  Text('업타임: ${report['uptime']}분'),
                  Text('처리된 거래: ${report['totalProcessedTrades']}건'),
                  Text('활성 패턴: ${report['activePatterns']}개'),
                  Text('추적 마켓: ${report['trackedMarkets']}개'),
                  const SizedBox(height: 16),
                  const Text('온라인 지표 상태:', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (report['onlineMetricsHealth'] != null) ...[
                    Text('총 마켓: ${report['onlineMetricsHealth']['totalMarkets']}'),
                    Text('정상: ${report['onlineMetricsHealth']['healthyMarkets']}'),
                    Text('만료: ${report['onlineMetricsHealth']['staleMarkets']}'),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// 🆕 시그널 상세 정보 대화상자
  void _showSignalDetails(BuildContext context, Signal signal, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${signal.patternType.displayName} - ${signal.ticker}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 기본 정보
              _buildDetailRow('마켓', signal.market),
              _buildDetailRow('현재가', '${signal.currentPrice.toStringAsFixed(0)}원'),
              _buildDetailRow('변화율', '${signal.changePercent.toStringAsFixed(2)}%'),
              _buildDetailRow('거래액', '${(signal.tradeAmount / 1000000).toStringAsFixed(1)}M'),
              _buildDetailRow('감지시간', signal.detectedAt.toString().substring(0, 19)),
              
              if (signal.confidence != null)
                _buildDetailRow('신뢰도', '${(signal.confidence! * 100).toStringAsFixed(1)}%'),
              
              // 온라인 지표 정보
              if (signal.hasOnlineMetrics) ...[
                const SizedBox(height: 16),
                const Text('온라인 지표', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                if (signal.onlineIndicators?.rsi != null)
                  _buildDetailRow('RSI', '${signal.onlineIndicators!.rsi!.toStringAsFixed(1)} (${signal.onlineIndicators!.rsiState})'),
                
                if (signal.onlineIndicators?.macd != null)
                  _buildDetailRow('MACD', '${signal.onlineIndicators!.macd!.toStringAsFixed(2)} (${signal.onlineIndicators!.macdState})'),
              ],
              
              // 다이버전스 정보
              if (signal.divergence != null) ...[
                const SizedBox(height: 16),
                const Text('다이버전스', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildDetailRow('타입', signal.divergence!.type),
                _buildDetailRow('강도', signal.divergence!.confidenceLevel),
                _buildDetailRow('소스', signal.divergence!.source),
              ],
              
              // 고급 지표들
              const SizedBox(height: 16),
              const Text('고급 지표', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              if (signal.zScore != null)
                _buildDetailRow('Z-Score', signal.zScore!.toStringAsFixed(2)),
              
              if (signal.liquidityVortex != null)
                _buildDetailRow('Liquidity Vortex', signal.liquidityVortex!.toStringAsFixed(3)),
              
              if (signal.flashPulse != null)
                _buildDetailRow('Flash Pulse', signal.flashPulse!.toStringAsFixed(2)),
              
              // 버전 정보
              if (signal.version != null) ...[
                const SizedBox(height: 16),
                _buildDetailRow('버전', signal.version!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// 상세 정보 행
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 헬퍼 함수들
  // ==========================================================================

  /// 패턴별 아이콘 반환
  IconData _getPatternIcon(PatternType pattern) {
    switch (pattern) {
      case PatternType.surge:
        return Icons.trending_up;
      case PatternType.flashFire:
        return Icons.flash_on;
      case PatternType.stackUp:
        return Icons.stacked_line_chart;
      case PatternType.stealthIn:
        return Icons.visibility_off;
      case PatternType.blackHole:
        return Icons.radio_button_unchecked;
      case PatternType.reboundShot:
        return Icons.trending_up;
    }
  }

  /// 패턴별 색상 반환
  Color _getPatternColor(PatternType pattern) {
    switch (pattern) {
      case PatternType.surge:
        return Colors.red;
      case PatternType.flashFire:
        return Colors.orange;
      case PatternType.stackUp:
        return Colors.amber;
      case PatternType.stealthIn:
        return Colors.green;
      case PatternType.blackHole:
        return Colors.purple;
      case PatternType.reboundShot:
        return Colors.blue;
    }
  }
}