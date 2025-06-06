// lib/core/di/notification_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../utils/logger.dart';
import 'app_providers.dart'; // scaffoldMessengerKeyProvider

/// 🔔 알림 타입 enum
enum NotificationType {
  trade,       // 체결 알림
  priceAlert,  // 가격 알림  
  volume,      // 거래량 알림
  surge,       // 급등락 알림
  system,      // 시스템 알림
}

/// 🔔 알림 상태 enum  
enum NotificationStatus {
  unread,      // 읽지 않음
  read,        // 읽음
  archived,    // 보관됨
}

/// 🔔 알림 데이터 모델 (임시)
class NotificationData {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationStatus status;
  final DateTime createdAt;
  final Map<String, dynamic>? extra;

  const NotificationData({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.status = NotificationStatus.unread,
    required this.createdAt,
    this.extra,
  });

  NotificationData copyWith({
    NotificationStatus? status,
    Map<String, dynamic>? extra,
  }) {
    return NotificationData(
      id: id,
      title: title,
      message: message,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      extra: extra ?? this.extra,
    );
  }
}

/// 🔔 알림 목록 Provider
final notificationListProvider = StateProvider<List<NotificationData>>((ref) => []);

/// 🔔 읽지 않은 알림 개수
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationListProvider);
  return notifications.where((n) => n.status == NotificationStatus.unread).length;
});

/// 🔔 알림 필터 Provider
final notificationFilterProvider = StateProvider<NotificationType?>((ref) => null);

/// 🔔 필터된 알림 목록
final filteredNotificationProvider = Provider<List<NotificationData>>((ref) {
  final notifications = ref.watch(notificationListProvider);
  final filter = ref.watch(notificationFilterProvider);
  
  if (filter == null) return notifications;
  return notifications.where((n) => n.type == filter).toList();
});

/// 🔔 알림 관리 서비스
final notificationServiceProvider = Provider((ref) => NotificationService(ref));

/// 알림 서비스 클래스
class NotificationService {
  final Ref ref;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  
  NotificationService(this.ref);

  /// 🆕 Firebase 리스너 설정 (AppRouter에서 이동됨)
  void setupFirebaseListeners(GlobalKey<NavigatorState> navigatorKey) {
    final messenger = ref.read(scaffoldMessengerKeyProvider).currentState;
    
    // 앱이 실행 중일 때 알림 수신
    _onMessageSub = FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n != null) {
        // 알림 Provider에 저장
        addNotification(
          title: n.title ?? '알림',
          message: n.body ?? '',
          type: _getNotificationType(msg.data),
          extra: msg.data,
        );
        
        // SnackBar로도 표시
        if (messenger != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('${n.title}: ${n.body}')));
        }
      }
    });
    
    // 앱이 종료된 상태에서 알림 클릭해서 앱 시작
    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) {
        final n = msg.notification;
        if (n != null) {
          addNotification(
            title: n.title ?? '알림',
            message: n.body ?? '',
            type: _getNotificationType(msg.data),
            extra: msg.data,
          );
        }
        
        // TODO: 나중에 특정 알림 모달 자동 열기 기능 추가 가능
        // NotificationModal.show(navigatorKey.currentContext!);
      }
    });
    
    // 앱이 백그라운드에 있을 때 알림 클릭
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final n = msg.notification;
      if (n != null) {
        addNotification(
          title: n.title ?? '알림',
          message: n.body ?? '',
          type: _getNotificationType(msg.data),
          extra: msg.data,
        );
        
        // TODO: 나중에 특정 알림 모달 자동 열기 기능 추가 가능
        // NotificationModal.show(navigatorKey.currentContext!);
      }
    });
    
    log.i('🔔 Firebase 알림 리스너 설정 완료');
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
  
  /// Firebase 리스너 정리
  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedSub?.cancel();
    log.i('🧹 Firebase 알림 리스너 정리됨');
  }
  
  /// 알림 추가
  void addNotification({
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
    
    log.i('🔔 알림 추가: $title');
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
}