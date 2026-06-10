import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_config.dart';

/// 앱 전체에서 사용하는 통합 사용자 모델
class AppUser {
  final String id;
  final String nickname;
  final String? email;
  final String? profileImageUrl;
  final String provider; // 'google' | 'kakao' | 'email'
  final String? name; // 이름
  final String? birthdate; // 생년월일
  final String? contactEmail; // 연락처 이메일
  final String? gender; // 성별
  final String? selectedTitle; // 선택된 칭호

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

  /// 관리자(루트) 계정 여부
  bool get isAdmin => email != null && email == kAdminEmail;

  /// 화면에 표시할 칭호. 관리자 계정은 항상 '운영자'로 표시됨.
  String? get displayTitle => isAdmin ? '운영자' : selectedTitle;

  AppUser copyWith({
    String? nickname,
    String? profileImageUrl,
    bool clearProfileImage = false,
    String? name,
    String? birthdate,
    String? contactEmail,
    String? gender,
    String? Function()? selectedTitle, // sentinel 패턴
  }) {
    return AppUser(
      id: id,
      nickname: nickname ?? this.nickname,
      email: email,
      profileImageUrl:
          clearProfileImage ? null : (profileImageUrl ?? this.profileImageUrl),
      provider: provider,
      name: name ?? this.name,
      birthdate: birthdate ?? this.birthdate,
      contactEmail: contactEmail ?? this.contactEmail,
      gender: gender ?? this.gender,
      selectedTitle: selectedTitle != null ? selectedTitle() : this.selectedTitle,
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

  /// 현재 로그인 계정이 관리자인지 여부
  bool get isAdmin {
    final email = _currentUser?.email;
    return email != null && email == kAdminEmail;
  }

  static const _prefKeyKakaoId = 'kakao_user_id';
  static const _prefKeyKakaoNick = 'kakao_user_nickname';
  static const _prefKeyKakaoEmail = 'kakao_user_email';
  static const _prefKeyKakaoImg = 'kakao_user_img';
  static const _prefKeyProvider = 'auth_provider';

  // 최근 로그인 힌트 (자동 로그인 없이 계정 정보만 보존)
  static const _hintProvider = 'hint_provider';
  static const _hintNickname = 'hint_nickname';
  static const _hintEmail = 'hint_email';
  static const _hintProfileImg = 'hint_profile_img';

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
    await _printKeyHash();
    // Firebase Auth 상태 확인
    final firebaseUser = fb.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _currentUser = _fromFirebaseUser(firebaseUser);
      await _loadAdditionalUserData();
      _loading = false;
      notifyListeners();
      _backfillCommentProfileImages(_currentUser!);
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
          await _loadAdditionalUserData();
          _backfillCommentProfileImages(_currentUser!);
        }
      }
    }

    _loading = false;
    notifyListeners();
  }

  /// Firestore에서 추가 사용자 데이터(칭호 등) 로드
  Future<void> _loadAdditionalUserData() async {
    if (_currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.id)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _currentUser = _currentUser!.copyWith(
          selectedTitle: () => data['selectedTitle'] as String?,
          name: data['name'] as String?,
          birthdate: data['birthdate'] as String?,
          contactEmail: data['contactEmail'] as String?,
          gender: data['gender'] as String?,
        );
      }
    } catch (e) {
      debugPrint('[AuthService] 추가 데이터 로드 실패: $e');
    }
  }

  /// 칭호 업데이트
  Future<void> updateTitle(String? title) async {
    if (_currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.id)
        .update({'selectedTitle': title});
    
    _currentUser = _currentUser!.copyWith(
      selectedTitle: () => title,
    );
    notifyListeners();
  }

  /// 이메일 중복 확인 (회원가입용)
  Future<bool> checkEmailExists(String email) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
    return query.docs.isNotEmpty;
  }

  /// 닉네임 중복 확인
  Future<bool> checkNicknameExists(String nickname) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('nickname', isEqualTo: nickname)
        .get();
    return query.docs.isNotEmpty;
  }

  /// 업적 진행도 조회를 위한 집계 쿼리
  Future<UserProgress> fetchUserProgress() async {
    if (_currentUser == null) return const UserProgress();

    // 관리자(루트) 계정은 모든 업적을 달성한 것으로 표시
    if (_currentUser!.isAdmin) {
      return const UserProgress(
        recipeViews: 300,
        bookmarks: 100,
        comments: 50,
        communityPosts: 30,
        createdRecipes: 20,
        nations: 7,
        fridgeSearches: 50,
        earlyBird: true,
      );
    }

    final id = _currentUser!.id;
    final db = FirebaseFirestore.instance;

    try {
      // 1. 기본 카운트 (서브컬렉션 집계)
      final recipesCount = (await db.collection('users').doc(id).collection('recentRecipes').count().get()).count ?? 0;
      final bookmarksCount = (await db.collection('users').doc(id).collection('bookmarks').count().get()).count ?? 0;
      final commentsCount = (await db.collection('users').doc(id).collection('myComments').count().get()).count ?? 0;
      
      // 2. 작성글/댓글 (작성자 필터링 집계)
      final communityPosts = (await db.collection('community').where('authorId', isEqualTo: id).count().get()).count ?? 0;
      final myRecipes = (await db.collection('recipes').where('authorId', isEqualTo: id).count().get()).count ?? 0;

      // 3. 세계 요리 (북마크된 국가 수)
      final bookmarkDocs = await db.collection('users').doc(id).collection('bookmarks').get();
      final nations = bookmarkDocs.docs.map((d) => d.data()['nation'] as String?).whereType<String>().toSet();
      final nationCount = nations.length;

      // 4. 냉장고 파먹기 횟수 (유저 문서 필드)
      final userDoc = await db.collection('users').doc(id).get();
      final fridgeCount = userDoc.data()?['fridgeSearchCount'] ?? 0;
      final isEarlyBird = userDoc.data()?['isEarlyBird'] ?? false;

      return UserProgress(
        recipeViews: recipesCount,
        bookmarks: bookmarksCount,
        comments: commentsCount,
        communityPosts: communityPosts,
        createdRecipes: myRecipes,
        nations: nationCount,
        fridgeSearches: fridgeCount,
        earlyBird: isEarlyBird,
      );
    } catch (e) {
      debugPrint('[AuthService] 진행도 조회 실패: $e');
      return const UserProgress();
    }
  }

  /// 기존 댓글에 authorProfileImg 가 없는 경우 현재 프로필 이미지로 채움.
  /// SharedPreferences 플래그로 기기당 한 번만 실행.
  Future<void> _backfillCommentProfileImages(AppUser user) async {
    const flagKey = 'comment_img_backfill_v1';
    try {
      final prefs = await SharedPreferences.getInstance();
      final userFlag = '${flagKey}_${user.id}';
      if (prefs.getBool(userFlag) == true) return;

      final db = FirebaseFirestore.instance;
      final imgUrl = user.profileImageUrl;

      // 레시피 댓글 (userId 기준)
      final recipeSnap = await db
          .collectionGroup('comments')
          .where('userId', isEqualTo: user.id)
          .get();
      if (recipeSnap.docs.isNotEmpty) {
        final batch = db.batch();
        for (final doc in recipeSnap.docs) {
          final existing = doc.data()['authorProfileImg'];
          if (existing == null || (existing as String).isEmpty) {
            batch.update(doc.reference, {'authorProfileImg': imgUrl});
          }
        }
        await batch.commit();
      }

      // 커뮤니티 댓글 + 답글 (authorId 기준)
      final communitySnap = await db
          .collectionGroup('comments')
          .where('authorId', isEqualTo: user.id)
          .get();
      if (communitySnap.docs.isNotEmpty) {
        final batch = db.batch();
        for (final doc in communitySnap.docs) {
          final existing = doc.data()['authorProfileImg'];
          if (existing == null || (existing as String).isEmpty) {
            batch.update(doc.reference, {'authorProfileImg': imgUrl});
          }
        }
        await batch.commit();
      }

      await prefs.setBool(userFlag, true);
      debugPrint('[AuthService] 댓글 프로필 이미지 일괄 업데이트 완료');
    } catch (e) {
      debugPrint('[AuthService] 댓글 프로필 이미지 업데이트 실패: $e');
    }
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
      await _loadAdditionalUserData();
      await _saveHint(_currentUser!);
      notifyListeners();
      _backfillCommentProfileImages(_currentUser!);
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
        await UserApi.instance.loginWithKakaoAccount();
      } else {
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

      // Firebase Storage 업로드를 위해 Firebase 익명 로그인 발급
      if (fb.FirebaseAuth.instance.currentUser == null) {
        await fb.FirebaseAuth.instance.signInAnonymously();
      }

      _currentUser = AppUser(
        id: 'kakao_$id',
        nickname: nickname,
        email: email,
        profileImageUrl: imgUrl,
        provider: 'kakao',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyProvider, 'kakao');
      await prefs.setString(_prefKeyKakaoId, 'kakao_$id');
      await prefs.setString(_prefKeyKakaoNick, nickname);
      if (email != null) await prefs.setString(_prefKeyKakaoEmail, email);
      if (imgUrl != null) await prefs.setString(_prefKeyKakaoImg, imgUrl);

      await _saveUserToFirestore(_currentUser!);
      await _loadAdditionalUserData();
      await _saveHint(_currentUser!);
      notifyListeners();
      _backfillCommentProfileImages(_currentUser!);
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
      await _loadAdditionalUserData();
      await _saveHint(_currentUser!);
      notifyListeners();
      _backfillCommentProfileImages(_currentUser!);
      return _currentUser;
    } catch (e) {
      debugPrint('[AuthService] 이메일 로그인 오류: $e');
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

      // Firebase 표시 이름 설정
      await user.updateDisplayName(nickname);

      _currentUser = AppUser(
        id: user.uid,
        nickname: nickname,
        email: email,
        provider: 'email',
        name: name,
        birthdate: birthdate,
        contactEmail: email,
        gender: gender,
      );

      await _saveUserToFirestore(_currentUser!);
      
      // 가입 즉시 로그아웃 (로그인 페이지로 유도)
      final signedUpUser = _currentUser;
      await signOut();
      
      return signedUpUser;
    } catch (e) {
      debugPrint('[AuthService] 이메일 회원가입 오류: $e');
      rethrow;
    }
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
      await fb.FirebaseAuth.instance.signOut(); // 익명 Firebase 세션 정리
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

  // ─── 닉네임 수정 ─────────────────────────────────────────

  Future<void> updateProfileImage(String? imageUrl) async {
    if (_currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.id)
        .update({'profileImageUrl': imageUrl});

    if (_currentUser!.provider == 'google' || _currentUser!.provider == 'email') {
      await fb.FirebaseAuth.instance.currentUser?.updatePhotoURL(imageUrl);
    } else if (_currentUser!.provider == 'kakao') {
      final prefs = await SharedPreferences.getInstance();
      if (imageUrl != null) {
        await prefs.setString(_prefKeyKakaoImg, imageUrl);
      } else {
        await prefs.remove(_prefKeyKakaoImg);
      }
    }

    _currentUser = _currentUser!.copyWith(
      profileImageUrl: imageUrl,
      clearProfileImage: imageUrl == null,
    );
    notifyListeners();
  }

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

  // ─── 최근 로그인 힌트 ────────────────────────────────────

  /// 로그인 성공 시 힌트 갱신
  Future<void> _saveHint(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hintProvider, user.provider);
    await prefs.setString(_hintNickname, user.nickname);
    if (user.email != null) await prefs.setString(_hintEmail, user.email!);
    if (user.profileImageUrl != null) {
      await prefs.setString(_hintProfileImg, user.profileImageUrl!);
    }
  }

  /// 최근 로그인 힌트 조회 (로그인 화면 표시용)
  Future<Map<String, String?>> getLastLoginHint() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'provider': prefs.getString(_hintProvider),
      'nickname': prefs.getString(_hintNickname),
      'email': prefs.getString(_hintEmail),
      'profileImg': prefs.getString(_hintProfileImg),
    };
  }

  // ─── Google 빠른 재로그인 (계정 선택창 없이) ─────────────────────────
  Future<AppUser?> signInWithGoogleQuick() async {
    try {
      fb.UserCredential result;
      if (kIsWeb) {
        final googleProvider = fb.GoogleAuthProvider();
        result = await fb.FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // signInSilently: UI 없이 캐시된 토큰으로 재인증 시도
        final googleSignIn = GoogleSignIn();
        var googleUser = await googleSignIn.signInSilently();
        if (googleUser == null) return null; // 캐시 없음 → 호출부에서 폴백 처리
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
      await _loadAdditionalUserData();
      await _saveHint(_currentUser!);
      notifyListeners();
      _backfillCommentProfileImages(_currentUser!);
      return _currentUser;
    } catch (e) {
      debugPrint('[AuthService] Google 빠른 로그인 오류: $e');
      rethrow;
    }
  }

  // ─── 내부 헬퍼 ──────────────────────────────────────────

  AppUser _fromFirebaseUser(fb.User user) {
    String provider = 'email';
    if (user.providerData.any((p) => p.providerId == 'google.com')) {
      provider = 'google';
    }

    return AppUser(
      id: user.uid,
      nickname: user.displayName ?? user.email?.split('@').first ?? '사용자',
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

    if (user.name != null) data['name'] = user.name;
    if (user.birthdate != null) data['birthdate'] = user.birthdate;
    if (user.contactEmail != null) data['contactEmail'] = user.contactEmail;
    if (user.gender != null) data['gender'] = user.gender;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .set(data, SetOptions(merge: true));
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

/// 유저의 업적 진행도를 담는 데이터 모델
class UserProgress {
  final int recipeViews;
  final int bookmarks;
  final int comments;
  final int communityPosts;
  final int createdRecipes;
  final int nations;
  final int fridgeSearches;
  final bool earlyBird;

  const UserProgress({
    this.recipeViews = 0,
    this.bookmarks = 0,
    this.comments = 0,
    this.communityPosts = 0,
    this.createdRecipes = 0,
    this.nations = 0,
    this.fridgeSearches = 0,
    this.earlyBird = false,
  });

  /// 전체 달성한 칭호 목록 계산 (Set으로 중복 제거)
  Set<String> get earnedTitles {
    final titles = <String>{};
    
    // 1. 레시피 탐험가
    if (recipeViews >= 10) titles.add('식탐러');
    if (recipeViews >= 50) titles.add('레시피 헌터');
    if (recipeViews >= 100) titles.add('미식 탐험가');
    if (recipeViews >= 300) titles.add('전설의 미식가');

    // 2. 즐겨찾기 수집가
    if (bookmarks >= 5) titles.add('메모장');
    if (bookmarks >= 20) titles.add('레시피 수집가');
    if (bookmarks >= 50) titles.add('북마크 마니아');
    if (bookmarks >= 100) titles.add('레시피 도서관');

    // 3. 레시피 평론가
    if (comments >= 3) titles.add('맛 초보');
    if (comments >= 10) titles.add('맛 평론가');
    if (comments >= 30) titles.add('미슐랭 가이드');
    if (comments >= 50) titles.add('식신');

    // 4. 커뮤니티 주민
    if (communityPosts >= 1) titles.add('새내기');
    if (communityPosts >= 5) titles.add('이웃');
    if (communityPosts >= 15) titles.add('단골손님');
    if (communityPosts >= 30) titles.add('터줏대감');

    // 5. 레시피 창작자
    if (createdRecipes >= 1) titles.add('견습생');
    if (createdRecipes >= 3) titles.add('요리사');
    if (createdRecipes >= 10) titles.add('셰프');
    if (createdRecipes >= 20) titles.add('미슐랭 셰프');

    // 6. 세계 요리 탐방
    if (nations >= 3) titles.add('동네 미식가');
    if (nations >= 5) titles.add('세계 여행자');
    if (nations >= 7) titles.add('세계 미식 대가');

    // 7. 냉장고 파먹기
    if (fridgeSearches >= 5) titles.add('냉장고 청소부');
    if (fridgeSearches >= 20) titles.add('절약 요리사');
    if (fridgeSearches >= 50) titles.add('재료 연금술사');

    // 특별 업적
    if (earlyBird) titles.add('얼리버드');
    
    // 완벽주의자 (각 카테고리에서 최소 1개 이상 달성 시)
    bool isPerfectionist = recipeViews >= 10 && bookmarks >= 5 && comments >= 3 && 
                           communityPosts >= 1 && createdRecipes >= 1 && nations >= 3 && 
                           fridgeSearches >= 5;
    if (isPerfectionist) titles.add('완벽주의자');

    // 전설 (모든 업적 26종 중 칭호가 있는 일반 업적들을 다 모았을 때 - 전설 자체 제외)
    if (titles.length >= 26) titles.add('전설');

    return titles;
  }

  /// 특별 업적 3종(얼리버드, 완벽주의자, 전설)을 제외한 일반 업적 달성 개수
  int get regularEarnedCount {
    final t = earnedTitles;
    int count = t.length;
    if (t.contains('얼리버드')) count--;
    if (t.contains('완벽주의자')) count--;
    if (t.contains('전설')) count--;
    return count;
  }
}
