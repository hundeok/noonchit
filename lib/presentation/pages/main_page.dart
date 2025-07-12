// lib/presentation/pages/main_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../core/di/app_providers.dart';
import '../../shared/widgets/common_app_bar.dart';
import 'trade_page.dart';
import 'volume_page.dart';
import 'sector_page.dart';
import 'surge_page.dart';
import 'signal_page.dart'; // 🔥 시그널 페이지 추가
// 🔥 Controller Provider들 import 추가
import '../controllers/volume_controller.dart';
import '../controllers/surge_controller.dart';
import '../controllers/trade_controller.dart';
import '../controllers/sector_controller.dart';
import '../controllers/signal_controller.dart'; // 🔥 시그널 컨트롤러 추가

/// 🎯 메인 페이지 - PageView로 5개 화면 관리
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
  
  // 🔥 5개 페이지 정보 (시그널 메뉴 추가)
  final List<PageInfo> _pages = [
    PageInfo(
      index: 0,
      title: '급등락',
      icon: Icons.trending_up,
      builder: (scrollController) => SurgePage(scrollController: scrollController),
    ),
    PageInfo(
      index: 1,
      title: '체결',
      icon: Icons.monetization_on,
      builder: (scrollController) => TradePage(scrollController: scrollController),
    ),
    PageInfo(
      index: 2,
      title: '볼륨',
      icon: Icons.bar_chart,
      builder: (scrollController) => VolumePage(scrollController: scrollController),
    ),
    PageInfo(
      index: 3,
      title: '섹터',
      icon: Icons.pie_chart,
      builder: (scrollController) => SectorPage(scrollController: scrollController),
    ),
    PageInfo(
      index: 4,
      title: '시그널',
      icon: Icons.flash_on,
      builder: (scrollController) => SignalPage(scrollController: scrollController),
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
    
    // ✅ 각 페이지별 ScrollController 초기화 (5개로 확장)
    for (int i = 0; i < _pages.length; i++) {
      _pageScrollControllers[i] = ScrollController();
    }
    
    // 초기 페이지 인덱스 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedTabProvider.notifier).state = 1; // 체결 페이지
      
      // 🔥 모든 Controller를 미리 초기화해서 데이터 스트림 시작
      _initializeAllControllers();
    });
  }

  /// 🔥 모든 Controller 미리 초기화 - 앱 시작과 동시에 모든 메뉴 실행
  void _initializeAllControllers() {
    try {
      // 1. VolumeController 초기화 (볼륨 메뉴)
      ref.read(volumeControllerProvider);
      debugPrint('🔥 VolumeController 초기화 완료');
      
      // 2. SurgeController 초기화 (급등락 메뉴)  
      ref.read(surgeControllerProvider);
      debugPrint('🔥 SurgeController 초기화 완료');
      
      // 3. TradeController 초기화 (체결 메뉴 - 이미 실행중이지만 명시적으로)
      ref.read(tradeControllerProvider);
      debugPrint('🔥 TradeController 초기화 완료');
      
      // 4. SectorController 초기화 (섹터 메뉴)
      ref.read(sectorControllerProvider);
      debugPrint('🔥 SectorController 초기화 완료');
      
      // 🔥 5. SignalController 초기화 (시그널 메뉴)
      ref.read(signalControllerProvider);
      debugPrint('🔥 SignalController 초기화 완료');
      
      debugPrint('✅ 모든 Controller 초기화 완료 - 5개 메뉴 모두 실행 시작!');
      
    } catch (e) {
      debugPrint('❌ Controller 초기화 오류: $e');
    }
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
    return Scaffold(
      appBar: CommonAppBar(
        title: '', // 빈 제목 (슬라이드 인디케이터가 들어갈 자리)
        pages: _pages,
        pageController: _pageController,
        animationController: _animationController,
      ),
      body: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: _pages.length, // 🔥 5개로 자동 확장
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

  /// 🔥 페이지 변경 처리 - 햅틱 설정 체크 추가
  void _onPageChanged(int index) {
    // 🔥 설정 체크 후 햅틱 (다른 위젯들과 동일한 패턴)
    if (ref.read(appSettingsProvider).isHapticEnabled) {
      HapticFeedback.lightImpact();
    }

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
}

/// 📄 페이지 정보 클래스
class PageInfo {
  final int index;
  final String title;
  final IconData icon;
  final Widget Function(ScrollController scrollController) builder;

  const PageInfo({
    required this.index,
    required this.title,
    required this.icon,
    required this.builder,
  });
}