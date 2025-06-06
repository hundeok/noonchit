// lib/shared/widgets/notification_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/utils/logger.dart';
import '../../core/di/app_providers.dart';
import '../../core/di/notification_provider.dart'; // 🆕 Provider 분리

/// 🔔 Firebase + 비즈니스 로직을 담당하는 알림 서비스
class NotificationService {
  final Ref ref;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  
  NotificationService(this.ref);

  /// Firebase 리스너 설정
  void setupFirebaseListeners(GlobalKey<NavigatorState> navigatorKey) {
    final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
    
    // 앱이 실행 중일 때 알림 수신
    _onMessageSub = FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) {
        // 🎯 Provider를 통해 알림 추가
        _addNotificationToProvider(
          title: n.title ?? '알림',
          message: n.body ?? '',
          type: _getNotificationType(msg.data),
          extra: msg.data,
        );
        
        // SnackBar로도 표시
        _showNotificationSnackBar(messenger, n, msg.data);
      }
    });
    
    // 앱이 종료된 상태에서 알림 클릭해서 앱 시작
    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) {
        final n = msg.notification;
        if (n != null) {
          _addNotificationToProvider(
            title: n.title ?? '알림',
            message: n.body ?? '',
            type: _getNotificationType(msg.data),
            extra: msg.data,
          );
        }
      }
    });
    
    // 앱이 백그라운드에 있을 때 알림 클릭
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final n = msg.notification;
      if (n != null) {
        _addNotificationToProvider(
          title: n.title ?? '알림',
          message: n.body ?? '',
          type: _getNotificationType(msg.data),
          extra: msg.data,
        );
      }
    });
    
    log.i('🔔 Firebase 알림 리스너 설정 완료');
  }

  /// Provider를 통한 알림 추가 (내부 메서드)
  void _addNotificationToProvider({
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? extra,
  }) {
    final notification = NotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: type,
      createdAt: DateTime.now(),
      extra: extra,
    );
    
    final currentList = ref.read(notificationListProvider);
    ref.read(notificationListProvider.notifier).state = [
      notification,
      ...currentList,
    ];
    
    log.i('🔔 알림 추가: $title (${type.name})');
  }

  /// SnackBar 표시
  void _showNotificationSnackBar(
    ScaffoldMessengerState? messenger,
    RemoteNotification notification,
    Map<String, dynamic>? data,
  ) {
    if (messenger == null) return;
    
    final type = _getNotificationType(data);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(
          children: [
            Icon(_getIconForType(type), color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('${notification.title}: ${notification.body}')),
          ],
        ),
        backgroundColor: _getColorForType(type),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '보기',
          textColor: Colors.white,
          onPressed: () {
            // TODO: 알림 모달 열기
            log.i('📱 알림 상세보기 요청');
          },
        ),
      ));
  }

  /// Firebase 메시지 데이터로부터 알림 타입 추론
  NotificationType _getNotificationType(Map<String, dynamic>? data) {
    if (data == null) return NotificationType.system;
    
    final type = data['type']?.toString().toLowerCase();
    switch (type) {
      case 'trade':
      case 'execution':
        return NotificationType.trade;
      case 'price':
      case 'price_alert':
        return NotificationType.priceAlert;
      case 'volume':
        return NotificationType.volume;
      case 'surge':
      case 'pump':
      case 'dump':
        return NotificationType.surge;
      default:
        return NotificationType.system;
    }
  }

  /// 🆕 타입별 아이콘 반환 (NotificationService 내부 메서드)
  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.trade:
        return Icons.show_chart;
      case NotificationType.priceAlert:
        return Icons.attach_money;
      case NotificationType.volume:
        return Icons.bar_chart;
      case NotificationType.surge:
        return Icons.trending_up;
      case NotificationType.system:
        return Icons.settings;
    }
  }

  /// 🆕 타입별 색상 반환 (NotificationService 내부 메서드)  
  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.trade:
        return Colors.blue;
      case NotificationType.priceAlert:
        return Colors.green;
      case NotificationType.volume:
        return Colors.purple;
      case NotificationType.surge:
        return Colors.red;
      case NotificationType.system:
        return Colors.grey;
    }
  }

  /// 🎯 외부에서 호출 가능한 알림 추가 (공개 메서드)
  void addNotification({
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? extra,
  }) {
    _addNotificationToProvider(
      title: title,
      message: message,
      type: type,
      extra: extra,
    );
  }
  
  /// 알림 읽음 처리
  void markAsRead(String notificationId) {
    final currentList = ref.read(notificationListProvider);
    final updatedList = currentList.map((notification) {
      if (notification.id == notificationId) {
        return notification.copyWith(status: NotificationStatus.read);
      }
      return notification;
    }).toList();
    
    ref.read(notificationListProvider.notifier).state = updatedList;
    log.i('👁️ 알림 읽음: $notificationId');
  }
  
  /// 알림 제거
  void removeNotification(String notificationId) {
    final currentList = ref.read(notificationListProvider);
    final updatedList = currentList.where((n) => n.id != notificationId).toList();
    ref.read(notificationListProvider.notifier).state = updatedList;
    log.i('🗑️ 알림 제거: $notificationId');
  }
  
  /// 모든 알림 읽음 처리
  void markAllAsRead() {
    final currentList = ref.read(notificationListProvider);
    final updatedList = currentList.map((notification) => 
      notification.copyWith(status: NotificationStatus.read)
    ).toList();
    
    ref.read(notificationListProvider.notifier).state = updatedList;
    log.i('👁️ 모든 알림 읽음 처리');
  }
  
  /// 모든 알림 제거
  void clearAllNotifications() {
    ref.read(notificationListProvider.notifier).state = [];
    log.i('🧹 모든 알림 제거');
  }
  
  /// 필터 설정
  void setFilter(NotificationType? type) {
    ref.read(notificationFilterProvider.notifier).state = type;
    log.i('🔍 알림 필터: ${type?.name ?? "전체"}');
  }
  
  /// 읽지 않은 알림 개수
  int getUnreadCount() {
    return ref.read(unreadNotificationCountProvider);
  }

  /// Firebase 리스너 정리
  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    log.i('🧹 Firebase 알림 리스너 정리됨');
  }
}

/// 🔔 알림 서비스 Provider
final notificationServiceProvider = Provider((ref) => NotificationService(ref));