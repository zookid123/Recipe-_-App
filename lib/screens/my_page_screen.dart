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
import 'achievements_screen.dart';
import 'open_source_license_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';

import 'admin_screen.dart';
import 'chat_list_screen.dart';

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
          // 업적 버튼
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AchievementsScreen()),
            ),
            icon: const Icon(Icons.stars_rounded),
            tooltip: '업적 및 도전과제',
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
                  // 칭호 (있을 경우만 표시)
                  if (isLoggedIn && user.selectedTitle != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      ),
                      child: Text(
                        '⭐ ${user.selectedTitle}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
              _MenuItem(
                Icons.chat_bubble_outline,
                '채팅',
                '',
                isLoggedIn
                    ? () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ChatListScreen()))
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('로그인 후 이용할 수 있어요.')),
                        ),
              ),
            ]),

            const SizedBox(height: 12),

            // 설정
            _menuSection('설정', [
              _MenuItem(Icons.notifications_outlined, '알림 설정', '', _showNotificationSettings),
              _MenuItem(Icons.lock_outline, '개인정보 처리방침', '', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
              }),
              _MenuItem(Icons.info_outline, '앱 정보', '', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const _AppInfoScreen()));
              }),
              if (AuthService.instance.isAdmin)
                _MenuItem(Icons.admin_panel_settings_outlined, '관리자 패널', '시스템 관리', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
                }),
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

/// 앱 정보 화면
class _AppInfoScreen extends StatelessWidget {
  const _AppInfoScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('앱 정보'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 히어로 영역
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Color(0xFFFFAB40)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 20)],
                    ),
                    child: const Text('🥦', style: TextStyle(fontSize: 50)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '냉장고 구조대',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('v 1.0.0 (1)', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '남은 재료로 만드는 맛있는 한 끼',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 기능 소개
            _infoSection('주요 기능', [
              _featureRow(Icons.search, '레시피 검색', '농림축산식품부 공공 데이터를 활용한 600+ 레시피'),
              _featureRow(Icons.kitchen, '냉장고 파먹기', '보유한 재료를 선택하면 만들 수 있는 요리 추천'),
              _featureRow(Icons.bookmark, '즐겨찾기', '마음에 드는 레시피를 보관하고 언제든 확인'),
              _featureRow(Icons.forum, '커뮤니티', '요리 팁을 나누고 나만의 요리를 자랑하는 공간'),
            ]),

            const SizedBox(height: 12),

            // 버전 정보
            _infoSection('상세 정보', [
              _infoRow('앱 버전', '1.0.0'),
              _infoRow('빌드 번호', '1'),
              _infoRow('최소 지원 OS', 'Android 5.0 / iOS 12.0'),
              _infoRow('최종 업데이트', '2026.06.01'),
            ]),

            const SizedBox(height: 12),

            // 고객지원 및 법적고지
            _infoSection('고객지원 및 법적고지', [
              _infoRow('문의 이메일', 'support@recipe_save.com'),
              _infoRow('개인정보 처리방침', '', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()))),
              _infoRow('이용약관', '', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()))),
              _infoRow('오픈소스 라이선스', '', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OpenSourceLicenseScreen()))),
            ]),

            const SizedBox(height: 40),
            const Text('© 2026 냉장고 구조대 팀', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.orange, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {VoidCallback? onTap}) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty) Text(value, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ],
      ),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}
