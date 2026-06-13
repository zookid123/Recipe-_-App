# 기술 스택 & 아키텍처

## 기술 스택

| 구분 | 기술 | 버전 | 선택 근거 |
|------|------|------|----------|
| **Frontend** | Flutter (Dart) | SDK ≥ 3.x | 단일 코드베이스로 Android·iOS·Web·Windows 동시 지원, 독자 렌더링 엔진 |
| **Database** | Firebase Firestore | ^6.2.0 | 실시간 스트림 구독 → StreamBuilder 패턴과 자연스러운 연동 |
| **인증** | Firebase Authentication | ^6.3.0 | Google·카카오·이메일 멀티 프로바이더를 단일 SDK로 통합 관리 |
| **파일 저장** | Firebase Storage | ^13.2.0 | Firebase 생태계 내 이미지 업로드, 별도 스토리지 서버 불필요 |
| **Google 로그인** | google_sign_in | ^6.2.2 | Firebase Auth 공식 연동 패키지, 웹·모바일 통합 지원 |
| **카카오 로그인** | kakao_flutter_sdk_user | ^1.9.8 | 국내 사용자 접근성 향상, 카카오 공식 Flutter SDK |
| **로컬 저장** | shared_preferences | ^2.2.2 | 북마크·최근 레시피·알림 설정 등 경량 키-값 로컬 캐시에 적합 |
| **이미지 선택** | image_picker | ^1.0.7 | 레시피·프로필 이미지 업로드, 갤러리·카메라 모두 지원 |
| **앱 버전 조회** | package_info_plus | ^8.0.0 | AppInfoScreen에서 앱 버전 정보를 동적으로 표시 |
| **외부 API 호출** | http | ^1.1.0 | 공공 레시피 API 호출용 경량 HTTP 클라이언트 |
| **외부 레시피 API** | 농림축산식품부 공공 레시피 API | — | 신뢰도 높은 공공 데이터 600+ 레시피 무료 제공 |
| **데이터 동기화** | Node.js (sync_recipes.js) | — | CORS 우회 및 데이터 누락 방지를 위한 서버사이드 동기화 |
| **iOS 스타일 아이콘** | cupertino_icons | ^1.0.8 | Material 아이콘과 혼용하여 플랫폼별 UI 일관성 확보 |

### 개발(dev) 의존성

| 구분 | 기술 | 버전 | 용도 |
|------|------|------|------|
| **린트 규칙** | flutter_lints | ^6.0.0 | Dart 코드 품질 정적 분석 규칙 세트 |
| **Firebase CLI 도구** | flutterfire_cli | ^1.3.1 | `firebase_options.dart` 자동 생성 CLI |

아키텍처 결정 근거는 `docs/decisions/` ADR 3건에 기록되어 있다.

---

## 프로젝트 파일 구조

```
C:\Recipe-_-App\
├── lib/
│   ├── main.dart                        ← 앱 진입점, MainShell (4탭 바텀 네비)
│   ├── admin_config.dart                ← 관리자 이메일 / API 키 상수
│   ├── firebase_options.dart            ← Firebase 플랫폼별 설정 (자동 생성)
│   ├── constants/
│   │   └── ingredients.dart             ← 냉장고 빠른 선택용 공통 재료 28종
│   ├── screens/                         ← 화면 파일 29개
│   │   ├── home_screen.dart
│   │   ├── recipe_list_screen.dart
│   │   ├── recipe_detail_screen.dart
│   │   ├── recipe_create_screen.dart
│   │   ├── search_screen.dart
│   │   ├── ingredient_search_screen.dart
│   │   ├── fridge_screen.dart
│   │   ├── cooking_mode_screen.dart
│   │   ├── bookmarks_screen.dart
│   │   ├── recent_recipes_screen.dart
│   │   ├── my_recipes_screen.dart
│   │   ├── community_screen.dart
│   │   ├── community_post_create_screen.dart
│   │   ├── community_post_detail_screen.dart
│   │   ├── chat_list_screen.dart
│   │   ├── chat_screen.dart
│   │   ├── user_profile_screen.dart
│   │   ├── my_page_screen.dart          ← AppInfoScreen 내장 (private class)
│   │   ├── edit_profile_screen.dart
│   │   ├── my_activity_screen.dart
│   │   ├── achievements_screen.dart
│   │   ├── notifications_screen.dart
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   ├── forgot_password_screen.dart
│   │   ├── terms_agreement_screen.dart
│   │   ├── terms_screen.dart
│   │   ├── privacy_policy_screen.dart
│   │   ├── open_source_license_screen.dart
│   │   └── admin_screen.dart
│   ├── services/
│   │   ├── auth_service.dart            ← 인증 상태 전역 관리 (ChangeNotifier 싱글톤)
│   │   └── comment_watcher.dart         ← 알림 감시 백그라운드 싱글톤
│   └── widgets/
│       ├── recommend_card.dart          ← 추천 레시피 카드 위젯
│       └── trending_card.dart           ← 트렌딩 카드 위젯
├── docs/                                ← 발표용 문서 (이 파일들)
├── test/
│   └── widget_test.dart
├── pubspec.yaml                         ← 의존성 정의
├── analysis_options.yaml                ← lint 규칙
└── CLAUDE.md                            ← Claude Code 전용 프로젝트 지침
```

---

## 앱 아키텍처

### 상태 관리

별도의 상태 관리 라이브러리 없이 Flutter 기본 패턴 사용:

| 방식 | 용도 |
|------|------|
| `StatefulWidget` + `StreamBuilder` | Firestore 실시간 데이터 연동 |
| `ChangeNotifier` (`AuthService`) | 로그인/로그아웃 상태 전역 관리 |
| `SharedPreferences` | 로컬 캐시 (북마크, 최근 레시피, 로그인 힌트) |

---

### 화면 구조 (네비게이션)

```
앱 진입 (main.dart)
│
├─ [비로그인]
│   ├─ LoginScreen         — 소셜·이메일 로그인
│   ├─ SignupScreen         — 이메일 회원가입
│   ├─ ForgotPasswordScreen — 비밀번호 재설정
│   └─ TermsAgreementScreen — 약관 동의
│
└─ [로그인]
    ├─ MainShell (IndexedStack 기반 4탭 바텀 네비게이션)
    │   ├─ Tab 0: HomeScreen         — 홈
    │   ├─ Tab 1: RecipeListScreen   — 레시피
    │   ├─ Tab 2: CommunityScreen    — 커뮤니티
    │   └─ Tab 3: MyPageScreen       — 마이페이지
    │
    ├─ [레시피 관련 서브 화면]
    │   ├─ RecipeDetailScreen        — 레시피 상세
    │   ├─ RecipeCreateScreen        — 레시피 작성/수정
    │   ├─ SearchScreen              — 검색
    │   ├─ IngredientSearchScreen    — 냉장고 파먹기
    │   ├─ FridgeScreen              — 냉장고 관리
    │   ├─ CookingModeScreen         — 조리 전용 모드
    │   ├─ BookmarksScreen           — 북마크 목록
    │   ├─ RecentRecipesScreen       — 최근 본 레시피
    │   └─ MyRecipesScreen           — 내가 작성한 레시피
    │
    ├─ [커뮤니티 관련 서브 화면]
    │   ├─ CommunityPostCreateScreen — 게시글 작성/수정
    │   ├─ CommunityPostDetailScreen — 게시글 상세
    │   ├─ ChatListScreen            — 채팅 목록
    │   ├─ ChatScreen                — 1:1 채팅
    │   └─ UserProfileScreen         — 타 사용자 프로필
    │
    ├─ [마이페이지 관련 서브 화면]
    │   ├─ EditProfileScreen         — 프로필 수정
    │   ├─ MyActivityScreen          — 활동 내역
    │   ├─ AchievementsScreen        — 업적/칭호
    │   ├─ NotificationsScreen       — 알림함
    │   ├─ TermsScreen               — 이용약관 전문 (앱 정보 → 이용약관)
    │   └─ OpenSourceLicenseScreen   — 오픈소스 라이선스 (앱 정보 → 오픈소스 라이선스)
    │
    └─ [관리자 전용]
        └─ AdminScreen               — 관리자 패널
```

---

### 데이터 흐름

```
┌─────────────────────────────────────────────────┐
│           농림축산식품부 공공 레시피 API           │
└────────────────────┬────────────────────────────┘
                     │ (관리자가 수동 실행)
                     ▼
              sync_recipes.js
              (Node.js 스크립트)
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│              Firebase Firestore                  │
│   recipes / users / community / chatRooms ...   │
└──────────────┬──────────────────────────────────┘
               │ StreamBuilder / FutureBuilder
               ▼
┌─────────────────────────────────────────────────┐
│              Flutter 앱 화면 UI                  │
│    HomeScreen / RecipeListScreen / 기타 ...      │
└─────────────────────────────────────────────────┘
```

> 클라이언트에서 직접 API를 호출하지 않는 이유: CORS 문제 및 데이터 누락 방지.
> 관리자가 `node sync_recipes.js`로 주기적으로 Firestore에 동기화.

---

### 알림 감시 서비스 (comment_watcher.dart)

로그인 직후 백그라운드에서 실행되는 싱글톤 감시 서비스:

```
CommentWatcher.start()
├─ _watchRecipeComments()     — 내 레시피에 새 댓글 감지 → 알림 저장
├─ _watchCommunityComments()  — 내 게시글에 새 댓글 감지 → 알림 저장
└─ _checkFridgeExpiry()       — 냉장고 유통기한 확인 (하루 1회) → 알림 저장
```

---

### 플랫폼별 대응

| 플랫폼 | 특이 사항 |
|--------|-----------|
| Android / iOS | Google·카카오 네이티브 SDK 지원 |
| Web | Firebase Auth 팝업 방식 사용 |
| Windows | Firestore·이미지 피커 완전 지원 |
| 데스크톱 스크롤 | `_AppScrollBehavior`로 마우스 드래그 가로 스크롤 지원 |

---

### Firebase 프로젝트 정보

- **Project ID:** `shingu-3aced`
- **지원 플랫폼:** Web, Android, iOS, macOS, Windows (각각 별도 API 키 구성)
- **설정 파일:** `lib/firebase_options.dart`

---

### 핵심 설정 파일

| 파일 | 역할 |
|------|------|
| `lib/admin_config.dart` | 관리자 이메일(`kAdminEmail`), 공공 API 키·베이스 URL 상수 — 변경 시 이 파일만 수정 |
| `lib/constants/ingredients.dart` | 냉장고 재료 빠른 선택용 공통 재료 28종 상수(`kCommonIngredients`) |
