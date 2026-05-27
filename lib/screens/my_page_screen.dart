import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'recent_recipes_screen.dart';
import 'bookmarks_screen.dart';
import 'my_activity_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';
import 'open_source_license_screen.dart';
import 'achievements_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService.instance.signOut();
    }
  }

  void _goToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isLoggedIn = user != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('마이페이지'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AchievementsScreen()),
              ),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 프로필 헤더
            Container(
              width: double.infinity,
              color: Colors.orange,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                children: [
                  // 프로필 이미지
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    backgroundImage: isLoggedIn && user.profileImageUrl != null
                        ? NetworkImage(user.profileImageUrl!)
                        : null,
                    child: (!isLoggedIn || user.profileImageUrl == null)
                        ? const Icon(Icons.person, size: 48, color: Colors.orange)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  // 칭호
                  if (isLoggedIn && user.selectedTitle != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            user.selectedTitle!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  // 닉네임
                  Text(
                    isLoggedIn ? user.nickname : '게스트',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 이메일 or 안내 문구
                  Text(
                    isLoggedIn
                        ? (user.email ?? _providerLabel(user.provider))
                        : '로그인하면 더 많은 기능을 사용할 수 있어요',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  // 로그인 / 로그아웃 / 프로필 편집 버튼
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoggedIn) ...[
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.edit, size: 15),
                          label: const Text('프로필 편집'),
                        ),
                        const SizedBox(width: 10),
                      ],
                      OutlinedButton(
                        onPressed: isLoggedIn ? _handleLogout : _goToLogin,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(isLoggedIn ? '로그아웃' : '로그인 / 회원가입'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 내 활동
            _menuSection('내 활동', [
              _MenuItem(Icons.bookmark_border, '즐겨찾기', '', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BookmarksScreen()));
              }),
              _MenuItem(Icons.history, '최근 본 레시피', '', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RecentRecipesScreen()));
              }),
              _MenuItem(
                Icons.receipt_long_outlined,
                '내 활동 내역',
                '',
                isLoggedIn
                    ? () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MyActivityScreen()))
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('로그인 후 이용할 수 있어요.')),
                        ),
              ),
            ]),

            const SizedBox(height: 12),

            // 설정
            _menuSection('설정', [
              _MenuItem(Icons.notifications_outlined, '알림 설정', '준비 중', null),
              _MenuItem(Icons.lock_outline, '개인정보 처리방침', '', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
              }),
              _MenuItem(Icons.info_outline, '앱 정보', '', _showAppInfo),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _showAppInfo() async {
    String version = '1.0.0';
    String buildNumber = '1';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      buildNumber = info.buildNumber;
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AppInfoScreen(version: version, buildNumber: buildNumber),
      ),
    );
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'google':
        return 'Google 계정';
      case 'kakao':
        return '카카오 계정';
      default:
        return '';
    }
  }

  Widget _menuSection(String title, List<_MenuItem> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...items.map(
            (item) => ListTile(
              leading: Icon(item.icon, color: Colors.orange, size: 22),
              title: Text(item.label, style: const TextStyle(fontSize: 15)),
              trailing: Text(
                item.trailing,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: item.onTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String trailing;
  final VoidCallback? onTap;
  const _MenuItem(this.icon, this.label, this.trailing, this.onTap);
}

// ─── 앱 정보 화면 ────────────────────────────────────────────

class _AppInfoScreen extends StatelessWidget {
  final String version;
  final String buildNumber;

  const _AppInfoScreen({required this.version, required this.buildNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('앱 정보'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 상단 히어로 영역
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Color(0xFFFF8C00)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 36),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🥦', style: TextStyle(fontSize: 48)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '냉장고 구조대',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'v$version',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '오늘도 맛있는 하루 되세요! 🍽️',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 주요 기능
            _InfoSection(
              title: '주요 기능',
              children: [
                _FeatureRow(Icons.search_rounded, '스마트 레시피 검색', '요리명, 재료로 원하는 레시피를 빠르게 검색'),
                _FeatureRow(Icons.kitchen_outlined, '냉장고 파먹기', '보유 재료를 입력하면 만들 수 있는 요리 추천'),
                _FeatureRow(Icons.bookmark_border_rounded, '즐겨찾기', '마음에 드는 레시피를 저장해 언제든 확인'),
                _FeatureRow(Icons.people_outline_rounded, '커뮤니티', '요리 사진과 후기를 이웃과 함께 공유'),
                _FeatureRow(Icons.trending_up_rounded, '인기 레시피', '오늘의 조회수 기반 실시간 인기 순위 제공'),
              ],
            ),

            const SizedBox(height: 12),

            // 버전 정보
            _InfoSection(
              title: '버전 정보',
              children: [
                _InfoRow('앱 버전', version),
                _InfoRow('빌드 번호', buildNumber),
                _InfoRow('최소 지원', 'Android 6.0 / iOS 13 / Web'),
                _InfoRow('최종 업데이트', '2026.05.20'),
              ],
            ),

            const SizedBox(height: 12),

            // 고객지원
            _InfoSection(
              title: '고객지원 및 법적 고지',
              children: [
                _InfoRow('문의 이메일', 'support@refrigerator-rescue.kr'),
                _InfoRow(
                  '개인정보 처리방침',
                  '보기',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
                  ),
                ),
                _InfoRow(
                  '이용약관',
                  '보기',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TermsScreen()),
                  ),
                ),
                _InfoRow(
                  '오픈소스 라이선스',
                  '보기',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OpenSourceLicenseScreen()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 푸터
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  const Text(
                    '© 2026 냉장고 구조대 팀',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Made with ❤️ in Korea',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...children,
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureRow(this.icon, this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow(this.label, this.value, {this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF444444))),
          Row(
            children: [
              Text(value,
                  style: TextStyle(
                    fontSize: 14,
                    color: onTap != null ? Colors.orange : Colors.grey,
                  )),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, size: 16, color: Colors.orange),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: row,
      );
    }
    return row;
  }
}
