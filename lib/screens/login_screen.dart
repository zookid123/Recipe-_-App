import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'terms_agreement_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _googleLoading = false;
  bool _kakaoLoading = false;
  bool _emailLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        Navigator.of(context).pop();
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

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('이메일과 비밀번호를 모두 입력하세요');
      return;
    }

    setState(() => _emailLoading = true);
    try {
      final user = await AuthService.instance.signInWithEmail(email, password);
      if (!mounted) return;
      if (user != null) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      _showError('로그인 실패: 이메일 또는 비밀번호를 확인하세요');
    } finally {
      if (mounted) setState(() => _emailLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _googleLoading || _kakaoLoading || _emailLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        title: const Text('로그인'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // 로고 + 앱 이름
              const Icon(Icons.kitchen, size: 64, color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                '냉장고 구조대',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 32),

              // 이메일 입력 필드
              _CustomTextField(
                controller: _emailController,
                hintText: '이메일',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 16),
              
              // 비밀번호 입력 필드
              _CustomTextField(
                controller: _passwordController,
                hintText: '비밀번호',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 24),

              // 로그인 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isBusy ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _emailLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '로그인',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('계정이 없으신가요?', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: isBusy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TermsAgreementScreen()),
                            );
                          },
                    child: const Text('회원가입', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('비밀번호가 기억이 안 나신다면', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: isBusy
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                            );
                          },
                    child: const Text('비밀번호 찾기', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('또는', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),

              // Google 로그인 버튼
              _SocialLoginButton(
                onPressed: isBusy ? null : _handleGoogle,
                isLoading: _googleLoading,
                backgroundColor: Colors.white,
                textColor: Colors.black87,
                borderColor: const Color(0xFFE0E0E0),
                icon: SizedBox(
                  width: 24,
                  height: 24,
                  child: Image.asset(
                    'assets/images/google.png',
                    cacheWidth: 100,
                    cacheHeight: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                label: 'Google로 시작하기',
              ),

              const SizedBox(height: 12),

              // 카카오 로그인 버튼
              _SocialLoginButton(
                onPressed: isBusy ? null : _handleKakao,
                isLoading: _kakaoLoading,
                backgroundColor: const Color(0xFFFEE500),
                textColor: const Color(0xFF3C1E1E),
                borderColor: const Color(0xFFFEE500),
                icon: SizedBox(
                  width: 24,
                  height: 24,
                  child: Image.asset(
                    'assets/images/kakao.png',
                    cacheWidth: 100,
                    cacheHeight: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                label: '카카오로 시작하기',
              ),

              const SizedBox(height: 40),

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

class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;

  const _CustomTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.orange.withOpacity(0.7)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
