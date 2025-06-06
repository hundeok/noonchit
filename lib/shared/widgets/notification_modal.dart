// lib/shared/widgets/notification_modal.dart
import 'package:flutter/material.dart';

class NotificationModal {
  /// 알림 모달 표시
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => _NotificationModalContent(),
    );
  }
}

class _NotificationModalContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🎨 알림 모달 헤더
          _buildHeader(context),
          
          // 구분선
          Divider(color: Colors.grey.shade300, height: 1),
          
          // 🎯 알림 placeholder 내용
          _buildContent(context),
          
          // 하단 여백
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  /// 헤더 (제목 + 닫기 버튼)
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // 당김 핸들
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // 제목과 닫기 버튼
          Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.notifications, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                '알림',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 알림 컨텐츠 (placeholder)
  Widget _buildContent(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 알림 아이콘
          Icon(
            Icons.notifications_outlined,
            size: 80,
            color: Colors.orange.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          
          // 제목
          const Text(
            '알림 기능',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          
          // 설명
          Text(
            '실시간 체결 알림과\n가격 변동 알림을 받아보세요',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // 준비 중 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.construction,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  '곧 출시 예정!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // 기능 미리보기
          Text(
            '• 실시간 체결 알림\n• 급등락 알림\n• 거래량 급증 알림\n• 맞춤 가격 알림',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}