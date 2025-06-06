// lib/presentation/pages/main_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // 🎯 HapticFeedback용
import '../../core/di/app_providers.dart';
import '../../shared/widgets/common_app_bar.dart';
import 'trade_page.dart';
import 'volume_page.dart'; // 🆕 VolumePage import 추가
import 'sector_page.dart'; // 🆕 SectorPage import 추가

/// 🎯 메인 페이지 - PageView로 4개 화면 관리
class MainPage extends ConsumerStatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  
  // ✅ TradePage의 ScrollController를 위한 각 페이지별 관리
  final Map<int, ScrollController> _pageScrollControllers = {};
  
  // 4개 페이지 정보
  final List<PageInfo> _pages = [
    PageInfo(
      index: 0,
      title: '급등락',
      icon: Icons.trending_up, // ✅ 그대로 유지
      builder: (scrollController) => _buildPlaceholderPage('급등락', Icons.trending_up, '급등락 모니터링 페이지'),
    ),
    PageInfo(
      index: 1,
      title: '체결',
      icon: Icons.monetization_on, // ✅ 변경: show_chart → monetization_on 💰
      builder: (scrollController) => TradePage(scrollController: scrollController), // ✅ ScrollController 전달
    ),
    PageInfo(
      index: 2,
      title: '볼륨',
      icon: Icons.bar_chart, // ✅ 그대로 유지
      builder: (scrollController) => VolumePage(scrollController: scrollController), // 🆕 VolumePage 연결!
    ),
    PageInfo(
      index: 3,
      title: '섹터',
      icon: Icons.pie_chart, // ✅ 변경: business → pie_chart 🥧
      builder: (scrollController) => SectorPage(scrollController: scrollController), // 🆕 SectorPage 연결!
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    // PageController 초기화 (체결 페이지를 기본으로)
    _pageController = PageController(initialPage: 1);
    
    // 애니메이션 컨트롤러 초기화 
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // ✅ 각 페이지별 ScrollController 초기화
    for (int i = 0; i < _pages.length; i++) {
      _pageScrollControllers[i] = ScrollController();
    }
    
    // 초기 페이지 인덱스 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedTabProvider.notifier).state = 1; // 체결 페이지
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    // ✅ 모든 ScrollController 해제
    for (final controller in _pageScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ GestureDetector 제거 - 순수하게 PrimaryScrollController가 상태바 터치 처리
    return Scaffold(
      appBar: CommonAppBar(
        title: '', // 빈 제목 (슬라이드 인디케이터가 들어갈 자리)
        pages: _pages,
        pageController: _pageController,
        animationController: _animationController,
      ),
      body: SafeArea( // ✅ SafeArea 추가
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: _pages.length,
          // ✅ iOS 스타일 physics + 스크롤 충돌 방지
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          // ✅ 스크롤 방향 명시 (수평 스와이프)
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            // ✅ 각 페이지에 해당하는 ScrollController 전달
            final scrollController = _pageScrollControllers[index]!;
            return _pages[index].builder(scrollController);
          },
        ),
      ),
    );
  }

  /// 페이지 변경 처리
  void _onPageChanged(int index) {
    HapticFeedback.lightImpact(); // 🎯 스와이프 햅틱 추가!

    // Provider 상태 업데이트
    ref.read(selectedTabProvider.notifier).state = index;
    
    // 애니메이션 트리거
    _animationController.forward().then((_) {
      _animationController.reset();
    });
    
    debugPrint('📱 페이지 변경: ${_pages[index].title} (index: $index)');
  }

  /// 🎯 외부에서 페이지 이동 (슬라이드 인디케이터 클릭 시)
  void goToPage(int index) {
    if (index >= 0 && index < _pages.length) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 플레이스홀더 페이지 생성
  static Widget _buildPlaceholderPage(String title, IconData icon, String description) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.orange.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Text(
              '🚧 개발 예정',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 📄 페이지 정보 클래스
class PageInfo {
  final int index;
  final String title;
  final IconData icon;
  final Widget Function(ScrollController scrollController) builder; // ✅ ScrollController 파라미터 추가

  const PageInfo({
    required this.index,
    required this.title,
    required this.icon,
    required this.builder,
  });
}