// lib/shared/widgets/slide_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🎯 HapticFeedback용 추가
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/app_providers.dart';
import '../../presentation/pages/main_page.dart';

/// 🎨 슬라이드 인디케이터 - iOS 스타일의 페이지 인디케이터 (롤링 윈도우)
class SlideIndicator extends ConsumerStatefulWidget {
 final List<PageInfo> pages;
 final PageController pageController;
 final AnimationController animationController;

 const SlideIndicator({
   Key? key,
   required this.pages,
   required this.pageController,
   required this.animationController,
 }) : super(key: key);

 @override
 ConsumerState<SlideIndicator> createState() => _SlideIndicatorState();
}

class _SlideIndicatorState extends ConsumerState<SlideIndicator>
   with TickerProviderStateMixin {
 
 late List<AnimationController> _iconControllers;
 late List<Animation<double>> _scaleAnimations;
 late List<Animation<Color?>> _colorAnimations;
 late ScrollController _scrollController; // 🔥 롤링 윈도우용 스크롤 컨트롤러

 @override
 void initState() {
   super.initState();
   _scrollController = ScrollController(); // 🔥 스크롤 컨트롤러 초기화
   _setupAnimations();
 }

 /// 애니메이션 설정
 void _setupAnimations() {
   _iconControllers = List.generate(
     widget.pages.length,
     (index) => AnimationController(
       duration: const Duration(milliseconds: 250),
       vsync: this,
     ),
   );

   _scaleAnimations = _iconControllers.map((controller) {
     return Tween<double>(
       begin: 0.8, // 작은 크기
       end: 1.2,   // 큰 크기
     ).animate(CurvedAnimation(
       parent: controller,
       curve: Curves.easeOutBack, // 통통 튀는 애니메이션
     ));
   }).toList();

   _colorAnimations = _iconControllers.map((controller) {
     return ColorTween(
       begin: Colors.grey.shade400,     // 비활성 색상
       end: Colors.orange,              // 활성 색상
     ).animate(CurvedAnimation(
       parent: controller,
       curve: Curves.easeInOut,
     ));
   }).toList();

   // 초기 선택된 페이지 애니메이션 시작 (체결 페이지 = index 1)
   WidgetsBinding.instance.addPostFrameCallback((_) {
     _iconControllers[1].forward();
   });
 }

 @override
 void dispose() {
   _scrollController.dispose(); // 🔥 스크롤 컨트롤러 해제
   for (final controller in _iconControllers) {
     controller.dispose();
   }
   super.dispose();
 }

 @override
 Widget build(BuildContext context) {
   final currentIndex = ref.watch(selectedTabProvider);
   
   // 페이지 변경 시 애니메이션 업데이트
   _updateAnimations(currentIndex);
   
   // 🔥 롤링 윈도우 스크롤 업데이트
   _scrollToWindow(currentIndex);

   return SizedBox(
     height: 40,
     child: SingleChildScrollView( // 🔥 Row → SingleChildScrollView로 변경
       controller: _scrollController,
       scrollDirection: Axis.horizontal,
       physics: const NeverScrollableScrollPhysics(), // 사용자 스크롤 금지
       child: Row(
         mainAxisSize: MainAxisSize.min,
         children: widget.pages.asMap().entries.map((entry) {
           final index = entry.key;
           final page = entry.value;
           
           return _buildAnimatedIcon(index, page, currentIndex);
         }).toList(),
       ),
     ),
   );
 }

 /// 🔥 현재 인덱스를 기준으로 4개씩 윈도우 슬라이딩
 void _scrollToWindow(int currentIndex) {
   const windowSize = 4;
   final total = widget.pages.length;
   
   // 5개 미만이면 롤링 불필요
   if (total <= windowSize) return;
   
   // 윈도우 시작 인덱스 계산 (단방향)
   int startIndex;
   if (currentIndex <= 2) {
     // 0,1,2,3 페이지일 때는 [0,1,2,3] 윈도우
     startIndex = 0;
   } else {
     // 4 페이지일 때는 [1,2,3,4] 윈도우
     startIndex = 1;
   }
   
   // 아이콘 하나의 너비 계산 (margin + padding + 아이콘 영역)
   // margin: 1.8*2, padding: 8*2, width: 32 = 51.6
   const itemWidth = 32.0 + 16.0 + 3.6;
   final targetOffset = startIndex * itemWidth;
   
   // 부드럽게 스크롤 이동
   if (_scrollController.hasClients) {
     _scrollController.animateTo(
       targetOffset,
       duration: const Duration(milliseconds: 300),
       curve: Curves.easeInOut,
     );
   }
 }

 /// 애니메이션 업데이트
 void _updateAnimations(int currentIndex) {
   for (int i = 0; i < _iconControllers.length; i++) {
     if (i == currentIndex) {
       _iconControllers[i].forward();
     } else {
       _iconControllers[i].reverse();
     }
   }
 }

 /// 애니메이션 아이콘 생성
 Widget _buildAnimatedIcon(int index, PageInfo page, int currentIndex) {
   final isSelected = index == currentIndex;
   
   return AnimatedBuilder(
     animation: Listenable.merge([
       _scaleAnimations[index],
       _colorAnimations[index],
     ]),
     builder: (context, child) {
       return GestureDetector(
         onTap: () => _onIconTap(index),
         child: Container(
           margin: const EdgeInsets.symmetric(horizontal: 1.8),
           padding: const EdgeInsets.all(8),
           child: Transform.scale(
             scale: _scaleAnimations[index].value,
             child: Container(
               width: 32,
               height: 32,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: isSelected 
                   ? Colors.orange.withValues(alpha: 0.1)
                   : Colors.transparent,
                 border: isSelected 
                   ? Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1)
                   : null,
               ),
               child: Icon(
                 page.icon,
                 size: isSelected ? 20 : 16,
                 color: _colorAnimations[index].value,
               ),
             ),
           ),
         ),
       );
     },
   );
 }

 /// 아이콘 클릭 처리
 void _onIconTap(int index) {
   // 햅틱 피드백 먼저 실행
   if (ref.read(appSettingsProvider).isHapticEnabled) {
     HapticFeedback.lightImpact(); // 🎯 햅틱 활성화!
   }
   
   // Provider 상태 업데이트
   ref.read(selectedTabProvider.notifier).state = index;
   
   // 페이지 이동
   widget.pageController.animateToPage(
     index,
     duration: const Duration(milliseconds: 300),
     curve: Curves.easeInOut,
   );
   
   debugPrint('🎯 슬라이드 인디케이터 클릭: ${widget.pages[index].title}');
 }
}

/// 🎨 간단 버전 슬라이드 인디케이터 (애니메이션 없음, 롤링 윈도우)
class SimpleSlideIndicator extends ConsumerStatefulWidget {
 final List<PageInfo> pages;
 final PageController pageController;

 const SimpleSlideIndicator({
   Key? key,
   required this.pages,
   required this.pageController,
 }) : super(key: key);

 @override
 ConsumerState<SimpleSlideIndicator> createState() => _SimpleSlideIndicatorState();
}

class _SimpleSlideIndicatorState extends ConsumerState<SimpleSlideIndicator> {
 late ScrollController _scrollController;

 @override
 void initState() {
   super.initState();
   _scrollController = ScrollController();
 }

 @override
 void dispose() {
   _scrollController.dispose();
   super.dispose();
 }

 @override
 Widget build(BuildContext context) {
   final currentIndex = ref.watch(selectedTabProvider);
   
   // 🔥 롤링 윈도우 스크롤 업데이트
   _scrollToWindow(currentIndex);

   return SizedBox(
     height: 40,
     child: SingleChildScrollView( // 🔥 Row → SingleChildScrollView로 변경
       controller: _scrollController,
       scrollDirection: Axis.horizontal,
       physics: const NeverScrollableScrollPhysics(), // 사용자 스크롤 금지
       child: Row(
         mainAxisSize: MainAxisSize.min,
         children: widget.pages.asMap().entries.map((entry) {
           final index = entry.key;
           final page = entry.value;
           final isSelected = index == currentIndex;
           
           return GestureDetector(
             onTap: () {
               if (ref.read(appSettingsProvider).isHapticEnabled) {
                 HapticFeedback.lightImpact(); // 🎯 간단 버전에도 햅틱 추가!
               }
               
               ref.read(selectedTabProvider.notifier).state = index;
               widget.pageController.animateToPage(
                 index,
                 duration: const Duration(milliseconds: 300),
                 curve: Curves.easeInOut,
               );
             },
             child: Container(
               margin: const EdgeInsets.symmetric(horizontal: 4),
               padding: const EdgeInsets.all(8),
               child: Container(
                 width: 32,
                 height: 32,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   color: isSelected 
                     ? Colors.orange.withValues(alpha: 0.1)
                     : Colors.transparent,
                   border: isSelected 
                     ? Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1)
                     : null,
                 ),
                 child: Icon(
                   page.icon,
                   size: isSelected ? 20 : 16,
                   color: isSelected ? Colors.orange : Colors.grey.shade400,
                 ),
               ),
             ),
           );
         }).toList(),
       ),
     ),
   );
 }

 /// 🔥 현재 인덱스를 기준으로 4개씩 윈도우 슬라이딩 (SimpleSlideIndicator용)
 void _scrollToWindow(int currentIndex) {
   const windowSize = 4;
   final total = widget.pages.length;
   
   // 5개 미만이면 롤링 불필요
   if (total <= windowSize) return;
   
   // 윈도우 시작 인덱스 계산 (단방향)
   int startIndex;
   if (currentIndex <= 2) {
     // 0,1,2,3 페이지일 때는 [0,1,2,3] 윈도우
     startIndex = 0;
   } else {
     // 4 페이지일 때는 [1,2,3,4] 윈도우
     startIndex = 1;
   }
   
   // 아이콘 하나의 너비 계산 (margin + padding + 아이콘 영역)
   // margin: 4*2, padding: 8*2, width: 32 = 56
   const itemWidth = 32.0 + 16.0 + 8.0;
   final targetOffset = startIndex * itemWidth;
   
   // 부드럽게 스크롤 이동
   if (_scrollController.hasClients) {
     _scrollController.animateTo(
       targetOffset,
       duration: const Duration(milliseconds: 300),
       curve: Curves.easeInOut,
     );
   }
 }
}