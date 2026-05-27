import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _googleLoading = false;
  bool _kakaoLoading = false;

  Future<void> _handleGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        Navigator.of(context).pop(); // 로그인 성공 → 마이페이지로 복귀
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Google 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _handleKakao() async {
    setState(() => _kakaoLoading = true);
    try {
      final user = await AuthService.instance.signInWithKakao();
      if (!mounted) return;
      if (user != null) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      _showError('카카오 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _kakaoLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('로그인'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 로고 + 앱 이름
              const Icon(Icons.kitchen, size: 72, color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                '냉장고 구조대',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '소셜 계정으로 간편하게 로그인하세요',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),

              const Spacer(flex: 2),

              // Google 로그인 버튼
              _SocialLoginButton(
                onPressed: _googleLoading || _kakaoLoading ? null : _handleGoogle,
                isLoading: _googleLoading,
                backgroundColor: Colors.white,
                textColor: Colors.black87,
                borderColor: const Color(0xFFE0E0E0),
                icon: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                  width: 22,
                  height: 22,
                  errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 22, color: Colors.blue),
                ),
                label: 'Google로 시작하기',
              ),

              const SizedBox(height: 14),

              // 카카오 로그인 버튼
              _SocialLoginButton(
                onPressed: _googleLoading || _kakaoLoading ? null : _handleKakao,
                isLoading: _kakaoLoading,
                backgroundColor: const Color(0xFFFEE500),
                textColor: const Color(0xFF3C1E1E),
                borderColor: const Color(0xFFFEE500),
                icon: SizedBox(
                  width: 26,
                  height: 26,
                  child: Image.asset(
                    'assets/images/kakao_logo.png',
                    // 캐시 사이즈를 화면 해상도보다 높게 설정하여 강제로 선명하게 로드
                    cacheWidth: 120, 
                    cacheHeight: 120,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    fit: BoxFit.contain,
                  ),
                ),
                label: '카카오로 시작하기',
              ),

              const Spacer(flex: 3),

              const Text(
                '로그인 시 서비스 이용약관 및\n개인정보 처리방침에 동의하게 됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final Widget icon;
  final String label;

  const _SocialLoginButton({
    required this.onPressed,
    required this.isLoading,
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
