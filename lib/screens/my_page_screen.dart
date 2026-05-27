import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
              _MenuItem(Icons.notifications_outlined, '알림 설정', '', _showNotificationSettings),
              _MenuItem(Icons.lock_outline, '개인정보 처리방침', '', _showPrivacyPolicy),
              _MenuItem(Icons.info_outline, '앱 정보', '', _showAppInfo),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    bool recipeAlert = prefs.getBool('notify_recipe') ?? true;
    bool communityAlert = prefs.getBool('notify_community') ?? true;
    bool fridgeAlert = prefs.getBool('notify_fridge') ?? true;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('알림 설정', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('새 레시피 알림', style: TextStyle(fontSize: 14)),
                value: recipeAlert,
                activeThumbColor: Colors.orange,
                onChanged: (v) => setS(() => recipeAlert = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('커뮤니티 댓글 알림', style: TextStyle(fontSize: 14)),
                value: communityAlert,
                activeThumbColor: Colors.orange,
                onChanged: (v) => setS(() => communityAlert = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('유통기한 임박 알림', style: TextStyle(fontSize: 14)),
                value: fridgeAlert,
                activeThumbColor: Colors.orange,
                onChanged: (v) => setS(() => fridgeAlert = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await prefs.setBool('notify_recipe', recipeAlert);
                await prefs.setBool('notify_community', communityAlert);
                await prefs.setBool('notify_fridge', fridgeAlert);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('알림 설정이 저장되었습니다.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              child: const Text('저장', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('개인정보 처리방침', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('수집하는 개인정보 항목',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 6),
              Text(
                '• 소셜 로그인(Google, 카카오) 시 이메일, 닉네임, 프로필 사진\n'
                '• 서비스 이용 기록(레시피 조회수, 댓글, 즐겨찾기)',
                style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
              ),
              SizedBox(height: 14),
              Text('수집 및 이용 목적',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 6),
              Text(
                '• 서비스 제공 및 회원 관리\n'
                '• 개인화 추천 및 커뮤니티 기능 제공',
                style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
              ),
              SizedBox(height: 14),
              Text('보유 및 이용 기간',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 6),
              Text(
                '• 회원 탈퇴 시 즉시 삭제\n'
                '• 단, 관련 법령에 따라 일정 기간 보관될 수 있음',
                style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
              ),
              SizedBox(height: 14),
              Text('제3자 제공',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 6),
              Text(
                '• 원칙적으로 외부에 제공하지 않음\n'
                '• Firebase(Google)를 통해 데이터 저장 및 인증 처리',
                style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인', style: TextStyle(color: Colors.orange)),
          ),
        ],
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
