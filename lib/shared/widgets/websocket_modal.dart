// lib/shared/widgets/websocket_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';

/// WebSocket 상세 정보 팝업 오버레이
class WebSocketStatsOverlay {
  static OverlayEntry? _overlayEntry;

  /// 롱프레스 시 팝업 표시 (Market Mood 방식)
  static void show({
    required BuildContext context,
    required WidgetRef ref,
    required Offset position,
    required double statusIconSize,
  }) {
    hide(); // 기존 팝업 제거

    // Market Mood와 동일한 방식으로 위치 미리 계산
    final adjustedPosition = _calculateModalPosition(context, position, statusIconSize);

    _overlayEntry = OverlayEntry(
      builder: (context) => _WebSocketStatsPopup(
        position: adjustedPosition,
        statusIconSize: statusIconSize,
        ref: ref,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// WebSocket 전용 위치 계산 (항상 아래쪽에만 표시)
  static Offset _calculateModalPosition(BuildContext context, Offset globalPosition, double size) {
    final screenSize = MediaQuery.of(context).size;
    final modalWidth = size * 4.2 * 2.5;
    final modalHeight = 200.0;
    
    // 아이콘 중앙 기준으로 모달 중앙 정렬 + 우측으로 이동
    double adjustedX = globalPosition.dx - (modalWidth / 2) + 150; // 🔧 우측으로 50px 이동
    double adjustedY = globalPosition.dy + size + 2; // 🔧 항상 아래쪽에만
    
    // 좌측 경계 체크
    if (adjustedX < 16) {
      adjustedX = 16;
    }
    
    // 우측 경계 체크
    if (adjustedX + modalWidth > screenSize.width - 0) {
      adjustedX = screenSize.width - modalWidth - 0;
    }
    
    // 하단 경계 체크 (화면 아래로 벗어나면 위쪽으로만)
    if (adjustedY + modalHeight > screenSize.height - 50) {
      adjustedY = globalPosition.dy - modalHeight - 8;
    }
    
    return Offset(adjustedX, adjustedY);
  }

  /// 팝업 숨기기
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _WebSocketStatsPopup extends StatefulWidget {
  final Offset position;
  final double statusIconSize;
  final WidgetRef ref;

  const _WebSocketStatsPopup({
    required this.position,
    required this.statusIconSize,
    required this.ref,
  });

  @override
  State<_WebSocketStatsPopup> createState() => _WebSocketStatsPopupState();
}

class _WebSocketStatsPopupState extends State<_WebSocketStatsPopup>
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
      onTap: () => WebSocketStatsOverlay.hide(),
      behavior: HitTestBehavior.translucent,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 투명 배경 (탭하면 닫힘)
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            // 실제 팝업 (Market Mood 방식: 이미 계산된 위치 사용)
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
    // Market Mood와 동일한 크기 계산
    final baseSize = widget.statusIconSize * 4.2;
    
    return IntrinsicWidth(
      child: Container(
        constraints: BoxConstraints(
          minWidth: baseSize,
          maxWidth: baseSize * 2.5,
          minHeight: baseSize,
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
              _buildStatsContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsContent() {
    final stats = widget.ref.read(wsStatsProvider);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ⏰ 시간 정보
        _buildSectionTitle('시간 정보', Icons.access_time),
        const SizedBox(height: 4),
        
        _buildStatRow(
          icon: Icons.link,
          label: '현재 연결',
          value: stats.connectTime != null && stats.uptime != null
              ? _formatDuration(stats.uptime!)
              : '미연결',
          isHighlight: stats.connectTime != null,
        ),
        
        if (stats.lastStateChangeTime != null)
          _buildStatRow(
            icon: Icons.schedule,
            label: '마지막 변경',
            value: _formatTimeAgo(stats.lastStateChangeTime!),
          ),
        
        const SizedBox(height: 8),
        
        // 🔄 연결 통계
        _buildSectionTitle('연결 통계', Icons.analytics),
        const SizedBox(height: 4),
        
        _buildStatRow(
          icon: Icons.refresh,
          label: '재연결',
          value: '${stats.reconnectCount}회',
          isWarning: stats.reconnectCount > 5,
        ),
        
        _buildStatRow(
          icon: Icons.play_arrow,
          label: '총 세션',
          value: '${stats.totalSessions}회',
        ),
        
        if (stats.connectionAttempts > 0)
          _buildStatRow(
            icon: Icons.trending_up,
            label: '성공률',
            value: '${stats.connectionSuccessRate.toStringAsFixed(1)}%',
            isHighlight: stats.connectionSuccessRate > 90,
            isWarning: stats.connectionSuccessRate < 70,
          ),
        
        const SizedBox(height: 8),
        
        // 📱 앱 생명주기
        _buildSectionTitle('앱 생명주기', Icons.timeline),
        const SizedBox(height: 4),
        
        _buildStatRow(
          icon: Icons.hourglass_full,
          label: '누적 시간',
          value: _formatDuration(stats.cumulativeConnectTime),
        ),
        
        if (stats.totalSessions > 0)
          _buildStatRow(
            icon: Icons.timer_outlined,
            label: '평균 세션',
            value: _formatDuration(stats.averageSessionDuration),
          ),
      ],
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
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              letterSpacing: 0.3,
            ),
            overflow: TextOverflow.ellipsis,
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
      if (isHighlight) return Theme.of(context).colorScheme.primary;
      if (isWarning) return Theme.of(context).colorScheme.tertiary;
      return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlight 
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : isWarning
            ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.08)
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) return '없음';
    
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    
    if (duration.inHours > 0) {
      final hours = twoDigits(duration.inHours);
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return '$hours:$minutes:$seconds';
    } else if (duration.inMinutes > 0) {
      final minutes = duration.inMinutes;
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return '$minutes분 $seconds초';
    } else {
      return '${duration.inSeconds}초';
    }
  }
}