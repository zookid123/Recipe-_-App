import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'screens/home_screen.dart';
import 'screens/recipe_list_screen.dart';
import 'screens/community_screen.dart';
import 'screens/my_page_screen.dart';
import 'services/auth_service.dart';
import 'services/comment_watcher.dart';
import 'firebase_config.dart';

// 마우스 드래그로도 가로 스크롤 가능하게 전역 설정
class _AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 카카오 SDK 초기화
  KakaoSdk.init(
    nativeAppKey: "3bcdaee38c1d9cf859d5ff6d45c9ef54",
    javaScriptAppKey: "534df5ad8dfcab4206e7b8e101264f13",
  );

  await Firebase.initializeApp(
    options: kIsWeb ? FirebaseConfig.web : FirebaseConfig.android,
  );

  // 저장된 로그인 세션 복원
  await AuthService.instance.init();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: _AppScrollBehavior(),
      home: const MainShell(),
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    RecipeListScreen(),
    CommunityScreen(),
    MyPageScreen(),
  ];

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_onAuthChanged);
    _onAuthChanged(); // 앱 시작 시 현재 로그인 상태로 초기화
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    CommentWatcher.instance.stop();
    super.dispose();
  }

  void _onAuthChanged() {
    if (AuthService.instance.isLoggedIn) {
      CommentWatcher.instance.start();
    } else {
      CommentWatcher.instance.stop();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              activeIcon: Icon(Icons.menu_book),
              label: '레시피',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.forum_outlined),
              activeIcon: Icon(Icons.forum),
              label: '커뮤니티',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '마이',
            ),
          ],
        ),
      ),
    );
  }
}
