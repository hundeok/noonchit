// lib/shared/widgets/notification_modal.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationModal {
  /// 알림 모달 표시
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) => const _NotificationModalContent(),
    );
  }
}

class _NotificationModalContent extends ConsumerWidget {
  const _NotificationModalContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          _buildHeader(context, ref),
          
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

  /// 헤더 (제목만, X 버튼 제거)
  Widget _buildHeader(BuildContext context, WidgetRef ref) {
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
          // 제목 (X 버튼 제거)
          const Row(
            children: [
              SizedBox(width: 16),
              Icon(Icons.notifications, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                '알림',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 알림 컨텐츠 (placeholder) - 가로/세로 모드 대응
  Widget _buildContent(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // 가로 모드일 때 더 작은 높이 사용 + Safe Area 고려
    final maxHeight = isLandscape 
        ? (screenHeight * 0.65 - bottomPadding).clamp(200.0, 250.0) // 가로: Safe Area 제외
        : 400.0; // 세로 모드: 기존 400

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 알림 아이콘
            Icon(
              Icons.notifications_outlined,
              size: isLandscape ? 60 : 80, // 가로 모드에서 아이콘 크기 축소
              color: Colors.orange.withValues(alpha: 0.5),
            ),
            SizedBox(height: isLandscape ? 16 : 24), // 가로 모드에서 간격 축소
            
            // 제목
            Text(
              '알림 기능',
              style: TextStyle(
                fontSize: isLandscape ? 20 : 24, // 가로 모드에서 폰트 크기 축소
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            SizedBox(height: isLandscape ? 8 : 12), // 가로 모드에서 간격 축소
            
            // 설명
            Text(
              '실시간 체결 알림과\n가격 변동 알림을 받아보세요',
              style: TextStyle(
                fontSize: isLandscape ? 14 : 16, // 가로 모드에서 폰트 크기 축소
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isLandscape ? 20 : 32), // 가로 모드에서 간격 축소
            
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
            SizedBox(height: isLandscape ? 12 : 16), // 가로 모드에서 간격 축소
            
            // 기능 미리보기
            Text(
              '• 실시간 체결 알림\n• 급등락 알림\n• 거래량 급증 알림\n• 맞춤 가격 알림',
              style: TextStyle(
                fontSize: isLandscape ? 12 : 13, // 가로 모드에서 폰트 크기 축소
                color: Colors.grey.shade500,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}