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
  Map<String, String?>? _hint; // 최근 로그인 힌트

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

  bool get _isLoading => _googleLoading || _kakaoLoading;

  // 힌트 카드 탭 — 계정 선택창 없이 빠른 재로그인
  Future<void> _handleQuickLogin() async {
    final provider = _hint?['provider'];
    if (provider == 'google') {
      setState(() => _googleLoading = true);
      try {
        final user = await AuthService.instance.signInWithGoogleQuick();
        if (!mounted) return;
        if (user != null) Navigator.of(context).pop();
      } catch (e) {
        if (!mounted) return;
        _showError('로그인 실패: $e');
      } finally {
        if (mounted) setState(() => _googleLoading = false);
      }
    } else if (provider == 'kakao') {
      await _handleKakao();
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (!mounted) return;
      if (user != null) Navigator.of(context).pop();
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
      if (user != null) Navigator.of(context).pop();
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

              // ── 최근 로그인 힌트 카드 ─────────────────────
              if (_hint != null) ...[
                _RecentLoginCard(
                  hint: _hint!,
                  isLoading: _isLoading,
                  onTap: _handleQuickLogin,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('또는',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Google 로그인 버튼
              _SocialLoginButton(
                onPressed: _isLoading ? null : _handleGoogle,
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
                onPressed: _isLoading ? null : _handleKakao,
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

// ── 최근 로그인 힌트 카드 ─────────────────────────────────
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
    final providerLabel = provider == 'google' ? 'Google' : '카카오';
    final providerColor =
        provider == 'google' ? Colors.blue : Colors.yellow.shade700;

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
              BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 8,
                  offset: Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              // 프로필 아바타
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                backgroundImage:
                    profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                child: profileImg.isEmpty
                    ? const Icon(Icons.person, color: Colors.orange, size: 26)
                    : null,
              ),
              const SizedBox(width: 14),
              // 계정 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('최근 로그인',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: providerColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            providerLabel,
                            style: TextStyle(
                                fontSize: 9,
                                color: providerColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nickname,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.orange),
                    )
                  : const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.orange),
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
