import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 앱 전체에서 사용하는 통합 사용자 모델
class AppUser {
  final String id;
  final String nickname;
  final String? email;
  final String? profileImageUrl;
  final String provider; // 'google' | 'kakao' | 'email'
  final String? name;       // 이름 추가
  final String? birthdate;  // 생년월일 추가
  final String? contactEmail; // 실제 이메일 주소 추가
  final String? gender;     // 성별 추가
  final String? selectedTitle;

  const AppUser({
    required this.id,
    required this.nickname,
    this.email,
    this.profileImageUrl,
    required this.provider,
    this.name,
    this.birthdate,
    this.contactEmail,
    this.gender,
    this.selectedTitle,
  });

  static const Object _unset = Object();

  AppUser copyWith({
    String? nickname,
    String? profileImageUrl,
    String? name,
    String? birthdate,
    String? contactEmail,
    String? gender,
    Object? selectedTitle = _unset,
  }) {
    return AppUser(
      id: id,
      nickname: nickname ?? this.nickname,
      email: email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      provider: provider,
      name: name ?? this.name,
      birthdate: birthdate ?? this.birthdate,
      contactEmail: contactEmail ?? this.contactEmail,
      gender: gender ?? this.gender,
      selectedTitle: identical(selectedTitle, _unset)
          ? this.selectedTitle
          : selectedTitle as String?,
    );
  }
}

/// Google + 카카오 로그인을 통합 관리하는 서비스
///
/// 사용법:
///   final auth = AuthService.instance;
///   auth.addListener(() { ... });  // 로그인 상태 변화 감지
///   await auth.signInWithGoogle();
///   await auth.signInWithKakao();
///   await auth.signOut();
///   auth.currentUser  // null이면 비로그인
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  AppUser? _currentUser;
  bool _loading = true;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _loading;

  static const _prefKeyKakaoId = 'kakao_user_id';
  static const _prefKeyKakaoNick = 'kakao_user_nickname';
  static const _prefKeyKakaoEmail = 'kakao_user_email';
  static const _prefKeyKakaoImg = 'kakao_user_img';
  static const _prefKeyProvider = 'auth_provider';

  /// 앱 시작 시 호출 — 저장된 세션 복원
  Future<void> _printKeyHash() async {
    try {
      String keyHash = await KakaoSdk.origin;
      debugPrint('\n[Kakao KeyHash]: $keyHash\n');
    } catch (e) {
      debugPrint('[Kakao KeyHash] Error: $e');
    }
  }

  Future<void> init() async {
    await _printKeyHash(); // 키 해시 출력 추가
    // Firebase Auth 상태 확인
    final firebaseUser = fb.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _currentUser = _fromFirebaseUser(firebaseUser);
      // Firestore에서 추가 정보 가져오기
      await _loadAdditionalUserData();
      _loading = false;
      notifyListeners();
      return;
    }

    // 카카오 세션 복원
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString(_prefKeyProvider);
    if (provider == 'kakao') {
      final isValid = await AuthApi.instance.hasToken();
      if (isValid) {
        final id = prefs.getString(_prefKeyKakaoId);
        final nick = prefs.getString(_prefKeyKakaoNick);
        if (id != null && nick != null) {
          _currentUser = AppUser(
            id: id,
            nickname: nick,
            email: prefs.getString(_prefKeyKakaoEmail),
            profileImageUrl: prefs.getString(_prefKeyKakaoImg),
            provider: 'kakao',
          );
        }
      }
    }

    _loading = false;
    notifyListeners();
  }

  // ─── Google 로그인 ───────────────────────────────────────

  Future<AppUser?> signInWithGoogle() async {
    try {
      fb.UserCredential result;

      if (kIsWeb) {
        // 웹: Firebase Auth 팝업 방식 (google_sign_in 패키지 불필요)
        final googleProvider = fb.GoogleAuthProvider();
        result = await fb.FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // 모바일: google_sign_in 패키지 방식
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null;

        final googleAuth = await googleUser.authentication;
        final credential = fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        result = await fb.FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = result.user;
      if (user == null) return null;

      _currentUser = _fromFirebaseUser(user);
      await _saveUserToFirestore(_currentUser!);
      await _loadAdditionalUserData(); // 최신 정보 로드
      notifyListeners();
      return _currentUser;
    } catch (e) {
      debugPrint('[AuthService] Google 로그인 오류: $e');
      rethrow;
    }
  }

  // ─── 카카오 로그인 ──────────────────────────────────────

  Future<AppUser?> signInWithKakao() async {
    try {
      if (kIsWeb) {
        // 웹: 카카오 계정으로 로그인 (현재 도메인을 리다이렉트 URI로 사용)
        await UserApi.instance.loginWithKakaoAccount();
      } else {
        // 모바일: 카카오톡 앱이 설치되어 있으면 앱으로, 없으면 웹으로
        if (await isKakaoTalkInstalled()) {
          await UserApi.instance.loginWithKakaoTalk();
        } else {
          await UserApi.instance.loginWithKakaoAccount();
        }
      }

      final kakaoUser = await UserApi.instance.me();
      final kakaoAccount = kakaoUser.kakaoAccount;
      final profile = kakaoAccount?.profile;

      final id = kakaoUser.id.toString();
      final nickname = profile?.nickname ?? '카카오 사용자';
      final email = kakaoAccount?.email;
      final imgUrl = profile?.profileImageUrl;

      _currentUser = AppUser(
        id: 'kakao_$id',
        nickname: nickname,
        email: email,
        profileImageUrl: imgUrl,
        provider: 'kakao',
      );

      // 로컬에 세션 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyProvider, 'kakao');
      await prefs.setString(_prefKeyKakaoId, 'kakao_$id');
      await prefs.setString(_prefKeyKakaoNick, nickname);
      if (email != null) await prefs.setString(_prefKeyKakaoEmail, email);
      if (imgUrl != null) await prefs.setString(_prefKeyKakaoImg, imgUrl);

      await _saveUserToFirestore(_currentUser!);
      notifyListeners();
      return _currentUser;
    } catch (e) {
      debugPrint('[AuthService] 카카오 로그인 오류: $e');
      rethrow;
    }
  }

  // ─── 이메일/비밀번호 로그인 ──────────────────────────────────

  Future<AppUser?> signInWithEmail(String email, String password) async {
    try {
      final result = await fb.FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = result.user;
      if (user == null) return null;

      _currentUser = _fromFirebaseUser(user);
      await _saveUserToFirestore(_currentUser!);
      await _loadAdditionalUserData(); // 최신 정보 로드
      notifyListeners();
      return _currentUser;
    } catch (e) {
      debugPrint('[AuthService] 로그인 오류: $e');
      rethrow;
    }
  }

  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
    required String name,
    required String birthdate,
    required String gender,
  }) async {
    try {
      final result = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = result.user;
      if (user == null) return null;

      // Firebase 닉네임 설정
      await user.updateDisplayName(nickname);

      _currentUser = AppUser(
        id: user.uid,
        nickname: nickname,
        email: email,
        provider: 'email',
        name: name,
        birthdate: birthdate,
        contactEmail: email, // 이메일 가입이므로 contactEmail도 동일하게 설정
        gender: gender,
      );

      await _saveUserToFirestore(_currentUser!);
      
      // 회원가입 후 바로 로그인 상태가 되는 것을 방지 (로그인 페이지로 이동하기 위함)
      final signedUpUser = _currentUser;
      await signOut();
      
      return signedUpUser;
    } catch (e) {
      debugPrint('[AuthService] 회원가입 오류: $e');
      rethrow;
    }
  }

  // ─── 중복 체크 ──────────────────────────────────────────

  Future<bool> checkEmailExists(String email) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<bool> checkNicknameExists(String nickname) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .get();
    return query.docs.isNotEmpty;
  }

  // ─── 로그아웃 ───────────────────────────────────────────

  Future<void> signOut() async {
    final provider = _currentUser?.provider;

    if (provider == 'google' || provider == 'email') {
      await fb.FirebaseAuth.instance.signOut();
      if (provider == 'google') {
        await GoogleSignIn().signOut();
      }
    } else if (provider == 'kakao') {
      await UserApi.instance.logout();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyProvider);
      await prefs.remove(_prefKeyKakaoId);
      await prefs.remove(_prefKeyKakaoNick);
      await prefs.remove(_prefKeyKakaoEmail);
      await prefs.remove(_prefKeyKakaoImg);
    }

    // 로컬 데이터 초기화
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_recipes');
    await prefs.remove('liked_recipes');
    await prefs.remove('user_likes');

    _currentUser = null;
    notifyListeners();
  }

  // ─── 업적 진행도 조회 ────────────────────────────────────

  Future<UserProgress> fetchUserProgress() async {
    final user = _currentUser;
    if (user == null) return UserProgress.zero;

    try {
      final fs = FirebaseFirestore.instance;
      final uid = user.id;

      final countResults = await Future.wait([
        fs.collection('users').doc(uid).collection('recentRecipes').count().get(),
        fs.collection('users').doc(uid).collection('bookmarks').count().get(),
        fs.collection('users').doc(uid).collection('myComments').count().get(),
        fs.collection('community').where('authorId', isEqualTo: uid).count().get(),
        fs.collection('recipes').where('authorId', isEqualTo: uid).count().get(),
      ]);

      final bookmarkSnap = await fs
          .collection('users')
          .doc(uid)
          .collection('bookmarks')
          .get();
      final nations = bookmarkSnap.docs
          .map((d) => (d.data())['nation'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toSet()
          .length;

      final userDoc = await fs.collection('users').doc(uid).get();
      final fridgeSearches =
          ((userDoc.data() ?? {})['fridgeSearchCount'] as num?)?.toInt() ?? 0;

      return UserProgress(
        recipeViews: countResults[0].count ?? 0,
        bookmarks: countResults[1].count ?? 0,
        comments: countResults[2].count ?? 0,
        communityPosts: countResults[3].count ?? 0,
        recipesCreated: countResults[4].count ?? 0,
        nationsExplored: nations,
        fridgeSearches: fridgeSearches,
        earlyBird: true,
      );
    } catch (e) {
      debugPrint('[AuthService] 업적 진행도 로드 실패: $e');
      return UserProgress.zero;
    }
  }

  // ─── 칭호 수정 ──────────────────────────────────────────

  Future<void> updateTitle(String? title) async {
    if (_currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.id)
        .update({'selectedTitle': title});
    _currentUser = _currentUser!.copyWith(selectedTitle: title);
    notifyListeners();
  }

  // ─── 닉네임 수정 ─────────────────────────────────────────

  Future<void> updateNickname(String newNickname) async {
    if (_currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.id)
        .update({'nickname': newNickname});

    if (_currentUser!.provider == 'google' || _currentUser!.provider == 'email') {
      await fb.FirebaseAuth.instance.currentUser?.updateDisplayName(newNickname);
    } else if (_currentUser!.provider == 'kakao') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyKakaoNick, newNickname);
    }

    _currentUser = _currentUser!.copyWith(nickname: newNickname);
    notifyListeners();
  }

  // ─── 내부 헬퍼 ──────────────────────────────────────────

  Future<void> _loadAdditionalUserData() async {
    if (_currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUser!.id).get();
      if (doc.exists) {
        final data = doc.data()!;
        _currentUser = _currentUser!.copyWith(
          name: data['name'],
          birthdate: data['birthdate'],
          contactEmail: data['contactEmail'],
          gender: data['gender'],
          nickname: data['nickname'],
          selectedTitle: data['selectedTitle'],
        );
      }
    } catch (e) {
      debugPrint('[AuthService] 추가 정보 로드 실패: $e');
    }
  }

  AppUser _fromFirebaseUser(fb.User user) {
    // providerId를 통해 제공자 구분 (google.com 등)
    String provider = 'email';
    if (user.providerData.any((p) => p.providerId == 'google.com')) {
      provider = 'google';
    }

    return AppUser(
      id: user.uid,
      nickname: user.displayName ?? user.email ?? '사용자',
      email: user.email,
      profileImageUrl: user.photoURL,
      provider: provider,
    );
  }

  Future<void> _saveUserToFirestore(AppUser user) async {
    final Map<String, dynamic> data = {
      'nickname': user.nickname,
      'email': user.email,
      'profileImageUrl': user.profileImageUrl,
      'provider': user.provider,
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    // null이 아닌 필드만 추가하여 기존 데이터를 덮어쓰지 않도록 함
    if (user.name != null) data['name'] = user.name;
    if (user.birthdate != null) data['birthdate'] = user.birthdate;
    if (user.contactEmail != null) data['contactEmail'] = user.contactEmail;
    if (user.gender != null) data['gender'] = user.gender;

    await FirebaseFirestore.instance.collection('users').doc(user.id).set(data, SetOptions(merge: true));
  }

  // ─── 비밀번호 찾기 ────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await fb.FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('[AuthService] 비밀번호 재설정 이메일 전송 오류: $e');
      rethrow;
    }
  }
}

// ─── 업적 진행도 모델 ─────────────────────────────────────────

class UserProgress {
  final int recipeViews;
  final int bookmarks;
  final int comments;
  final int communityPosts;
  final int recipesCreated;
  final int nationsExplored;
  final int fridgeSearches;
  final bool earlyBird;

  const UserProgress({
    required this.recipeViews,
    required this.bookmarks,
    required this.comments,
    required this.communityPosts,
    required this.recipesCreated,
    required this.nationsExplored,
    required this.fridgeSearches,
    required this.earlyBird,
  });

  static const zero = UserProgress(
    recipeViews: 0,
    bookmarks: 0,
    comments: 0,
    communityPosts: 0,
    recipesCreated: 0,
    nationsExplored: 0,
    fridgeSearches: 0,
    earlyBird: false,
  );

  Set<String> get earnedTitles {
    final earned = <String>{};

    if (earlyBird) earned.add('얼리버드');

    if (recipeViews >= 10) earned.add('식탐러');
    if (recipeViews >= 50) earned.add('레시피 헌터');
    if (recipeViews >= 100) earned.add('미식 탐험가');
    if (recipeViews >= 300) earned.add('전설의 미식가');

    if (bookmarks >= 5) earned.add('메모장');
    if (bookmarks >= 20) earned.add('레시피 수집가');
    if (bookmarks >= 50) earned.add('북마크 마니아');
    if (bookmarks >= 100) earned.add('레시피 도서관');

    if (comments >= 3) earned.add('맛 초보');
    if (comments >= 10) earned.add('맛 평론가');
    if (comments >= 30) earned.add('미슐랭 가이드');
    if (comments >= 50) earned.add('식신');

    if (communityPosts >= 1) earned.add('새내기');
    if (communityPosts >= 5) earned.add('이웃');
    if (communityPosts >= 15) earned.add('단골손님');
    if (communityPosts >= 30) earned.add('터줏대감');

    if (recipesCreated >= 1) earned.add('견습생');
    if (recipesCreated >= 3) earned.add('요리사');
    if (recipesCreated >= 10) earned.add('셰프');
    if (recipesCreated >= 20) earned.add('미슐랭 셰프');

    if (nationsExplored >= 3) earned.add('동네 미식가');
    if (nationsExplored >= 5) earned.add('세계 여행자');
    if (nationsExplored >= 7) earned.add('세계 미식 대가');

    if (fridgeSearches >= 5) earned.add('냉장고 청소부');
    if (fridgeSearches >= 20) earned.add('절약 요리사');
    if (fridgeSearches >= 50) earned.add('재료 연금술사');

    // 완벽주의자: 7개 카테고리 각각 최소 1개
    const groups = [
      ['식탐러', '레시피 헌터', '미식 탐험가', '전설의 미식가'],
      ['메모장', '레시피 수집가', '북마크 마니아', '레시피 도서관'],
      ['맛 초보', '맛 평론가', '미슐랭 가이드', '식신'],
      ['새내기', '이웃', '단골손님', '터줏대감'],
      ['견습생', '요리사', '셰프', '미슐랭 셰프'],
      ['동네 미식가', '세계 여행자', '세계 미식 대가'],
      ['냉장고 청소부', '절약 요리사', '재료 연금술사'],
    ];
    if (groups.every((g) => g.any(earned.contains))) {
      earned.add('완벽주의자');
    }

    // 전설: 일반 26개 + 얼리버드 + 완벽주의자 = 28개 모두 달성
    if (earned.length >= 28) earned.add('전설');

    return earned;
  }

  int get regularEarned {
    final e = earnedTitles;
    return e.length -
        (e.contains('얼리버드') ? 1 : 0) -
        (e.contains('완벽주의자') ? 1 : 0) -
        (e.contains('전설') ? 1 : 0);
  }
}
