// lib/presentation/pages/splash_page.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'main_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  VideoPlayerController? _controller;
  bool _isVideoInitialized = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    
    // 안전망: 5초 후 강제 이동 (비디오 문제 시)
    Future.delayed(const Duration(seconds: 5), () {
      if (!_hasNavigated && mounted) {
        _navigateToMain();
      }
    });
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/noonchit_intro_84frames.mp4');
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        
        // 비디오 설정
        _controller!.setVolume(0.0); // 음소거
        _controller!.setLooping(false);
        
        // 재생 완료 리스너
        _controller!.addListener(_videoListener);
        
        // 재생 시작
        _controller!.play();
      }
    } catch (e) {
      // 비디오 로드 실패 시 즉시 메인으로 이동
      debugPrint('Video initialization failed: $e');
      if (mounted) {
        _navigateToMain();
      }
    }
  }

  void _videoListener() {
    if (_controller != null && _controller!.value.position >= _controller!.value.duration) {
      // 비디오 재생 완료
      _navigateToMain();
    }
  }

  void _navigateToMain() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainPage(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // 어두운 배경
      body: Center(
        child: _isVideoInitialized && _controller != null
            ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              )
            : _buildLoadingFallback(),
      ),
    );
  }

  Widget _buildLoadingFallback() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 로딩 중이거나 비디오 실패 시 대체 UI
        Icon(
          Icons.currency_bitcoin,
          size: 64,
          color: Colors.orange.withValues(alpha: 0.8),
        ),
        const SizedBox(height: 16),
        Text(
          'NOONCHIT',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.9),
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.orange.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}