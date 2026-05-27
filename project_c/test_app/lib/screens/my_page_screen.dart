import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'recent_recipes_screen.dart';
import 'bookmarks_screen.dart';
import 'my_activity_screen.dart';
import 'fridge_screen.dart';

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

            // 나만의 냉장고
            _menuSection('나만의 냉장고', [
              _MenuItem(Icons.kitchen_outlined, '재료 관리', '유통기한 알림', () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FridgeScreen()));
              }),
            ]),

            const SizedBox(height: 12),

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
              _MenuItem(Icons.lock_outline, '개인정보 처리방침', '준비 중', null),
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
    final ctx = context;
    showDialog(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('앱 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('레시피 앱'),
            const SizedBox(height: 6),
            Text('버전: $version ($buildNumber)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('확인', style: TextStyle(color: Colors.orange)),
          ),
        ],
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
