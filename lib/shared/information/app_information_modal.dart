import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInformationModal {
  /// 앱 정보 모달 표시
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const _AppInformationContent(),
    );
  }
}

class _AppInformationContent extends StatefulWidget {
  const _AppInformationContent();

  @override
  State<_AppInformationContent> createState() => _AppInformationContentState();
}

class _AppInformationContentState extends State<_AppInformationContent> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _packageInfo = packageInfo;
        });
      }
    } catch (e) {
      // 패키지 정보를 불러올 수 없는 경우 기본값 사용
      if (mounted) {
        setState(() {
          _packageInfo = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    // 설정 모달보다 조금 작은 크기로 설정
    final dialogHeight = isLandscape 
        ? (screenHeight * 0.6).clamp(250.0, 300.0)
        : 450.0;
    final dialogWidth = screenWidth * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(context),
            Divider(color: Colors.grey.shade300, height: 1),
            Expanded(child: _buildContent(context)),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  /// 헤더 (제목만, X버튼 제거)
  Widget _buildHeader(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange, size: 24),
          SizedBox(width: 8),
          Text(
            '앱 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 앱 정보 내용
  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          
          // 앱 아이콘 및 이름
          _buildAppIcon(),
          const SizedBox(height: 20),
          
          // 앱 정보 카드들
          _buildInfoCard(
            icon: Icons.smartphone,
            title: '앱 이름',
            value: _packageInfo?.appName ?? 'Crypto Tracker',
          ),
          const SizedBox(height: 12),
          
          _buildInfoCard(
            icon: Icons.numbers,
            title: '버전',
            value: _packageInfo?.version ?? '1.0.0',
          ),
          const SizedBox(height: 12),
          
          _buildInfoCard(
            icon: Icons.code,
            title: '빌드 번호',
            value: _packageInfo?.buildNumber ?? '1',
          ),
          const SizedBox(height: 12),
          
          _buildInfoCard(
            icon: Icons.business,
            title: '패키지명',
            value: _packageInfo?.packageName ?? 'com.example.crypto_tracker',
            isLongText: true,
          ),
          const SizedBox(height: 12),
          
          _buildInfoCard(
            icon: Icons.person,
            title: '개발자',
            value: 'hd cho',
          ),
          const SizedBox(height: 12),
          
          _buildInfoCard(
            icon: Icons.calendar_today,
            title: '빌드 날짜',
            value: _getBuildDate(),
          ),
        ],
      ),
    );
  }

/// 앱 아이콘 위젯 (이미지로 변경)
Widget _buildAppIcon() {
  return Container(
    width: 80,
    height: 80,
    decoration: const BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      boxShadow: [
        BoxShadow(
          color: Colors.orange,
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Center(
        child: Image.asset(
          'assets/app_information_icon.webp',
          width: 64,  // 80의 80% = 64
          height: 64, // 80의 80% = 64
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // 이미지 로드 실패 시 기본 아이콘 표시
            return Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                gradient: LinearGradient(
                  colors: [Colors.grey, Colors.deepOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.trending_up,
                color: Colors.white,
                size: 40,
              ),
            );
          },
        ),
      ),
    ),
  );
}

  /// 빌드 날짜 자동 생성
  String _getBuildDate() {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
  }

  /// 정보 카드 위젯
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    bool isLongText = false,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: isLongText ? () => _copyToClipboard(context, value) : null,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isLongText ? Colors.orange : null,
                        decoration: isLongText ? TextDecoration.underline : null,
                      ),
                      maxLines: isLongText ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (isLongText)
              const Icon(
                Icons.copy,
                color: Colors.grey,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  /// 푸터 (저작권 정보만)
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(
        '© 2025 Noonchit',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  /// 클립보드에 복사
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$text가 클립보드에 복사되었습니다'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}