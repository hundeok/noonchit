import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🎯 HapticFeedback import 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart'; // 🔧 수정: app_providers로 통합
import '../../core/network/websocket/base_ws_client.dart';
import 'websocket_modal.dart'; // 🆕 WebSocket 모달 import

class WsStatusIndicator extends ConsumerWidget {
  final double size;
  final bool showTooltip;
  final EdgeInsets? padding;

  const WsStatusIndicator({
    Key? key,
    this.size = 16,
    this.showTooltip = false, // 🔧 기본값을 false로 변경 (롱프레스 모달과 충돌 방지)
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(wsStatusProvider);
    
    Widget indicator = _buildStatusIcon(context, ref, status);
    
    if (padding != null) {
      indicator = Padding(padding: padding!, child: indicator);
    }
    
    return indicator;
  }

  Widget _buildStatusIcon(BuildContext context, WidgetRef ref, WsStatus status) {
    Widget statusIcon = _getStatusIcon(status);
    
    // 롱프레스 제스처 추가
    return GestureDetector(
      onLongPressStart: (details) => _showWebSocketModal(context, ref, details.globalPosition),
      onLongPressEnd: (_) => _hideWebSocketModal(),
      onLongPressCancel: () => _hideWebSocketModal(),
      child: statusIcon,
    );
  }

  /// WebSocket 상세 모달 표시
  void _showWebSocketModal(BuildContext context, WidgetRef ref, Offset globalPosition) {
    // 🎯 햅틱 피드백 추가 (톡~ 소리 복구!)
    HapticFeedback.mediumImpact();
    
    // 기존 툴팁 숨기기
    Tooltip.dismissAllToolTips();
    
    // 화면 크기 가져오기
    final screenSize = MediaQuery.of(context).size;
    final modalWidth = size * 4.2 * 2.5; // 🔧 위치 계산용 크기도 원래대로
    
    // 화면 경계 고려한 위치 계산
    double adjustedX = globalPosition.dx - (modalWidth / 2); // 중앙 정렬
    double adjustedY = globalPosition.dy - (size * 3); // 위쪽으로
    
    // 좌측 경계 체크
    if (adjustedX < 16) {
      adjustedX = 16; // 최소 여백
    }
    
    // 우측 경계 체크
    if (adjustedX + modalWidth > screenSize.width - 16) {
      adjustedX = screenSize.width - modalWidth - 16; // 우측 여백 확보
    }
    
    // 상단 경계 체크
    if (adjustedY < 50) {
      adjustedY = globalPosition.dy + size + 8; // 아래쪽으로 이동
    }
    
    final adjustedPosition = Offset(adjustedX, adjustedY);
    
    WebSocketStatsOverlay.show(
      context: context,
      ref: ref,
      position: adjustedPosition,
      statusIconSize: size,
    );
  }

  /// WebSocket 모달 숨기기
  void _hideWebSocketModal() {
    WebSocketStatsOverlay.hide();
  }

  Widget _getStatusIcon(WsStatus status) {
    switch (status) {
      case WsStatus.connected:
        return _AnimatedStatusIcon(
          icon: Icons.circle,
          color: Colors.green,
          tooltip: showTooltip ? '실시간 연결됨 (롱프레스: 상세정보)' : null,
          animationType: AnimationType.pulse,
          size: size,
        );
        
      case WsStatus.connecting:
        return _AnimatedStatusIcon(
          icon: Icons.refresh,
          color: Colors.blue,
          tooltip: showTooltip ? '연결 중... (롱프레스: 상세정보)' : null,
          animationType: AnimationType.rotate,
          size: size,
        );
        
      case WsStatus.reconnecting:
        return _AnimatedStatusIcon(
          icon: Icons.refresh,
          color: Colors.orange,
          tooltip: showTooltip ? '재연결 중... (롱프레스: 상세정보)' : null,
          animationType: AnimationType.rotate,
          size: size,
        );
        
      case WsStatus.disconnected:
        return _AnimatedStatusIcon(
          icon: Icons.circle,
          color: Colors.grey,
          tooltip: showTooltip ? '연결 끊김 (롱프레스: 상세정보)' : null,
          animationType: AnimationType.none,
          size: size,
        );
        
      case WsStatus.pongTimeout:
        return _AnimatedStatusIcon(
          icon: Icons.circle,
          color: Colors.red,
          tooltip: showTooltip ? 'ping 타임아웃 (롱프레스: 상세정보)' : null,
          animationType: AnimationType.blink,
          size: size,
        );
        
      case WsStatus.failed:
      case WsStatus.error:
        return _AnimatedStatusIcon(
          icon: Icons.error_outline,
          color: Colors.red,
          tooltip: showTooltip ? (status == WsStatus.failed ? '연결 실패 (롱프레스: 상세정보)' : '에러 발생 (롱프레스: 상세정보)') : null,
          animationType: AnimationType.blink,
          size: size,
        );
        
      case WsStatus.maxRetryExceeded:
        return _AnimatedStatusIcon(
          icon: Icons.warning,
          color: Colors.deepOrange,
          tooltip: showTooltip ? '최대 재시도 초과 (롱프레스: 상세정보)' : null,
          animationType: AnimationType.blink,
          size: size,
        );
    }
  }
}

enum AnimationType { none, pulse, rotate, blink }

class _AnimatedStatusIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String? tooltip;
  final AnimationType animationType;
  final double size;

  const _AnimatedStatusIcon({
    required this.icon,
    required this.color,
    required this.animationType,
    required this.size,
    this.tooltip,
  });

  @override
  State<_AnimatedStatusIcon> createState() => _AnimatedStatusIconState();
}

class _AnimatedStatusIconState extends State<_AnimatedStatusIcon>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    switch (widget.animationType) {
      case AnimationType.pulse:
        _controller = AnimationController(
          duration: const Duration(seconds: 2),
          vsync: this,
        );
        _animation = Tween<double>(begin: 0.7, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        );
        _controller.repeat(reverse: true);
        break;
        
      case AnimationType.rotate:
        _controller = AnimationController(
          duration: const Duration(seconds: 1),
          vsync: this,
        );
        _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
        _controller.repeat();
        break;
        
      case AnimationType.blink:
        _controller = AnimationController(
          duration: const Duration(milliseconds: 800),
          vsync: this,
        );
        _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        );
        _controller.repeat(reverse: true);
        break;
        
      case AnimationType.none:
        _controller = AnimationController(vsync: this);
        _animation = const AlwaysStoppedAnimation(1.0);
        break;
    }
  }

  @override
  void didUpdateWidget(_AnimatedStatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationType != widget.animationType) {
      _controller.dispose();
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        Widget icon = Icon(
          widget.icon,
          color: widget.color,
          size: widget.size,
        );

        switch (widget.animationType) {
          case AnimationType.pulse:
          case AnimationType.blink:
            return Transform.scale(
              scale: _animation.value,
              child: Opacity(
                opacity: _animation.value,
                child: icon,
              ),
            );
            
          case AnimationType.rotate:
            return Transform.rotate(
              angle: _animation.value * 2 * 3.14159,
              child: icon,
            );
            
          case AnimationType.none:
            return icon;
        }
      },
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: iconWidget,
      );
    }
    
    return iconWidget;
  }
}