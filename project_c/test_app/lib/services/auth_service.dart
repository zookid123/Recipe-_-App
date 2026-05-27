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

  const AppUser({
    required this.id,
    required this.nickname,
    this.email,
    this.profileImageUrl,
    required this.provider,
  });

  AppUser copyWith({String? nickname, String? profileImageUrl}) {
    return AppUser(
      id: id,
      nickname: nickname ?? this.nickname,
      email: email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      provider: provider,
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
      notifyListeners();
      return _currentUser;
    } catch (e) {
      debugPrint('[AuthService] Google 로그인 오류: $e');
      rethrow;
    }
  }

  Future<AppUser?> signUpWithEmail({
    required String email,
    required String password,
    required String nickname,
  }) async {
    try {
      final result = await fb.FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user;
      if (user == null) return null;

      await user.updateDisplayName(nickname.trim());
      await user.reload();
      final refreshedUser = fb.FirebaseAuth.instance.currentUser ?? user;

      _currentUser = AppUser(
        id: refreshedUser.uid,
        nickname: nickname.trim(),
        email: refreshedUser.email,
        profileImageUrl: refreshedUser.photoURL,
        provider: 'email',
      );
      await _saveUserToFirestore(_currentUser!);
      notifyListeners();
      return _currentUser;
    } catch (e) {
      debugPrint('[AuthService] 이메일 회원가입 오류: $e');
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

  // ─── 로그아웃 ───────────────────────────────────────────

  Future<void> signOut() async {
    final provider = _currentUser?.provider;

    if (provider == 'google' || provider == 'email') {
      await fb.FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
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

  // ─── 닉네임 수정 ─────────────────────────────────────────

  Future<void> updateProfileImage(String imageUrl) async {
    if (_currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.id)
        .update({'profileImageUrl': imageUrl});

    if (_currentUser!.provider == 'google') {
      await fb.FirebaseAuth.instance.currentUser?.updatePhotoURL(imageUrl);
    } else if (_currentUser!.provider == 'kakao') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyKakaoImg, imageUrl);
    }

    _currentUser = _currentUser!.copyWith(profileImageUrl: imageUrl);
    notifyListeners();
  }

  Future<void> updateNickname(String newNickname) async {
    if (_currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser!.id)
        .update({'nickname': newNickname});

    if (_currentUser!.provider == 'google') {
      await fb.FirebaseAuth.instance.currentUser?.updateDisplayName(newNickname);
    } else if (_currentUser!.provider == 'kakao') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyKakaoNick, newNickname);
    }

    _currentUser = _currentUser!.copyWith(nickname: newNickname);
    notifyListeners();
  }

  // ─── 내부 헬퍼 ──────────────────────────────────────────

  AppUser _fromFirebaseUser(fb.User user) {
    return AppUser(
      id: user.uid,
      nickname: user.displayName ?? user.email?.split('@').first ?? '사용자',
      email: user.email,
      profileImageUrl: user.photoURL,
      provider: 'google',
    );
  }

  Future<void> _saveUserToFirestore(AppUser user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.id).set({
      'nickname': user.nickname,
      'email': user.email,
      'profileImageUrl': user.profileImageUrl,
      'provider': user.provider,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
