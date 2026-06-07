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
  Map<String, String?>? _hint;

  @override
  void initState() {
    super.initState();
    _loadHint();
  }

  Future<void> _loadHint() async {
    final hint = await AuthService.instance.getLastLoginHint();
    if (mounted && hint['provider'] != null) {
      setState(() => _hint = hint);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isLoading => _googleLoading || _kakaoLoading || _emailLoading;

  Future<void> _handleQuickLogin() async {
    final provider = _hint?['provider'];
    if (provider == 'google') {
      setState(() => _googleLoading = true);
      bool done = false;
      try {
        final user = await AuthService.instance.signInWithGoogleQuick();
        if (!mounted) return;
        if (user != null) {
          done = true;
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (!mounted) return;
        _showError('로그인 실패: $e');
        done = true;
      }
      if (mounted) setState(() => _googleLoading = false);
      // 캐시된 세션 없으면 일반 Google 로그인으로 자동 폴백
      if (!done && mounted) await _handleGoogle();
    } else if (provider == 'kakao') {
      await _handleKakao();
    }
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
    final isBusy = _isLoading;

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

              // 최근 로그인 힌트 카드
              if (_hint != null) ...[
                _RecentLoginCard(
                  hint: _hint!,
                  isLoading: isBusy,
                  onTap: _handleQuickLogin,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('또는', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 20),
              ],

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
                icon: Image.network(
                  'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                  width: 22,
                  height: 22,
                  errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 22, color: Colors.blue),
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
                  width: 26,
                  height: 26,
                  child: Image.asset(
                    'assets/images/kakao_logo.png',
                    cacheWidth: 120, 
                    cacheHeight: 120,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
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

class _RecentLoginCard extends StatelessWidget {
  final Map<String, String?> hint;
  final bool isLoading;
  final VoidCallback onTap;

  const _RecentLoginCard({
    required this.hint,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = hint['provider'] ?? '';
    final nickname = hint['nickname'] ?? '';
    final email = hint['email'] ?? '';
    final profileImg = hint['profileImg'] ?? '';
    final showBadge = provider == 'google' || provider == 'kakao';
    final providerLabel = provider == 'google' ? 'Google' : '카카오';
    final providerColor = provider == 'google' ? Colors.blue : Colors.yellow.shade700;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            boxShadow: const [
              BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                backgroundImage: profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                child: profileImg.isEmpty
                    ? const Icon(Icons.person, color: Colors.orange, size: 26)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('최근 로그인', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        if (showBadge) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: providerColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              providerLabel,
                              style: TextStyle(
                                fontSize: 9,
                                color: providerColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nickname,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }
}
