# 변경 이력

---

## 2026-05-20 — 업적 진행도 표시 및 달성한 칭호만 선택 가능하도록 변경

### 수정 파일

#### `lib/services/auth_service.dart`
- `fetchUserProgress()` 메서드 추가 — Firestore 집계 쿼리로 실제 진행도 조회
  - `recentRecipes` / `bookmarks` / `myComments` 서브컬렉션 `.count()` 집계
  - `community` / `recipes` 컬렉션 `authorId` 필터 `.count()` 집계
  - `bookmarks` 서브컬렉션 `nation` 필드에서 distinct 국가 수 계산
  - `users/{id}` 문서 `fridgeSearchCount` 필드 읽기
- `UserProgress` 클래스 추가 (파일 하단)
  - 7개 카테고리 카운트 필드 + `earlyBird` boolean
  - `earnedTitles` getter: 전체 달성 칭호 Set 자동 계산 (완벽주의자·전설 포함)
  - `regularEarned` getter: 특별 업적 3종 제외 달성 수

#### `lib/screens/achievements_screen.dart`
- `StatelessWidget` → `StatefulWidget` 전환
- 화면 진입 시 `fetchUserProgress()` 호출, AppBar 새로고침 버튼 추가
- 헤더에 전체 진행도 퍼센트 + LinearProgressIndicator 추가
- 특별 업적 3종 카드: 완벽주의자 `X/7`, 전설 `X/26` 진행도 표시
- `_AchievementCategory`에 `progressOf` 함수 필드 추가 → 카테고리별 진행값 자동 매핑
- `_CategoryCard` 헤더에 `X/N 달성` 배지 추가
- `_AchievementTile` 전면 개편:
  - 현재값 / 기준값 텍스트 표시
  - LinearProgressIndicator (5px) 진행도 표시
  - 달성률 퍼센트 텍스트
  - 달성 시 ✅ 색상 강조, 미달성 시 🔒 회색 처리
- 비로그인 시 잠금 안내 메시지 표시

#### `lib/screens/edit_profile_screen.dart`
- `UserProgress? _progress` 상태 추가, initState에서 비동기 로드
- 진행도 로드 전 칭호 선택 버튼 누르면 안내 스낵바 표시
- `_TitlePickerSheet`에 `earnedTitles` 파라미터 추가
- 달성하지 않은 칭호: 🔒 아이콘 + 회색 처리 + 탭 비활성화
- 바텀 시트 헤더에 `N 달성` 배지 추가
- 카테고리 헤더에 `N/M 달성` 카운트 표시

---

## 2026-05-20 — 칭호 표시 및 프로필 편집 칭호 선택 기능 추가

### 수정 파일

#### `lib/services/auth_service.dart`
- `AppUser`에 `selectedTitle` 필드 추가
- `copyWith`에 sentinel 패턴 적용 — null을 명시적으로 전달해 칭호를 지울 수 있도록 처리
- `updateTitle(String?)` 메서드 추가 (Firestore `users/{id}` 업데이트 + 로컬 상태 갱신)
- `_loadAdditionalUserData()`에서 `selectedTitle` 로드

#### `lib/screens/my_page_screen.dart`
- 프로필 헤더에 칭호 칩 추가: 닉네임 위에 `⭐ 칭호명` 형태의 반투명 앰버 보더 칩 표시
- 칭호가 없으면 칩 미표시

#### `lib/screens/edit_profile_screen.dart`
- 상태 변수 `_selectedTitle` 추가 (현재 사용자 칭호로 초기화)
- **칭호 섹션** 추가 (닉네임 아래):
  - 설정된 칭호 미리보기 (그라디언트 오렌지 칩)
  - `제거` 버튼으로 칭호 즉시 해제
  - `칭호 선택하기 / 변경하기` 버튼으로 바텀 시트 오픈
- `_save()` 수정: 닉네임과 칭호를 함께 저장 (변경 사항만 Firestore 호출)
- `_TitlePickerSheet` 바텀 시트 추가:
  - 8개 카테고리별 칭호 Wrap 레이아웃
  - 선택 중인 칭호 강조 표시 (카테고리 색상 + 별 아이콘)
  - '칭호 없음' 선택지 제공
- `_TitleCategory` 모델 클래스 추가 (파일 내부)

---

## 2026-05-20 — 업적/도전과제 시스템 추가

### 추가 파일

#### `lib/screens/achievements_screen.dart` — 신규 생성

마이페이지 상단 오른쪽 별 버튼에서 진입하는 업적/도전과제 화면.

**구성**
- 상단 헤더: 오렌지 그라디언트 + 총 업적 수 / 카테고리 수 / 특별 업적 수 StatChip
- 특별 업적 3종: 얼리버드(가입 첫 로그인) / 완벽주의자(전 카테고리 1개 이상) / 전설(모든 업적 달성)
- 카테고리별 도전과제 7종 — 탭으로 펼침/접기 가능한 아코디언 구조

**카테고리 및 등급 목록**

| 카테고리 | 등급 (달성 기준) |
|---|---|
| 레시피 탐험가 | 식탐러(10) / 레시피 헌터(50) / 미식 탐험가(100) / 전설의 미식가(300) |
| 즐겨찾기 수집가 | 메모장(5) / 레시피 수집가(20) / 북마크 마니아(50) / 레시피 도서관(100) |
| 레시피 평론가 | 맛 초보(3) / 맛 평론가(10) / 미슐랭 가이드(30) / 식신(50) |
| 커뮤니티 주민 | 새내기(1) / 이웃(5) / 단골손님(15) / 터줏대감(30) |
| 레시피 창작자 | 견습생(1) / 요리사(3) / 셰프(10) / 미슐랭 셰프(20) |
| 세계 요리 탐방 | 동네 미식가(3개국) / 세계 여행자(5개국) / 세계 미식 대가(7개국) |
| 냉장고 파먹기 | 냉장고 청소부(5) / 절약 요리사(20) / 재료 연금술사(50) |

**등급 아이콘**: 🥉 🥈 🥇 💎 순서로 표시

---

### 수정 파일

#### `lib/screens/my_page_screen.dart`

- `achievements_screen.dart` import 추가
- AppBar `actions`에 원형 별 버튼 추가 → 탭 시 `AchievementsScreen`으로 이동

---

## 2026-05-20 — 마이페이지 법적 고지 항목 연결 및 오픈소스 라이선스 UI 교체

### 수정 파일

#### `lib/screens/my_page_screen.dart`

- 설정 섹션의 **개인정보 처리방침** 항목: `'준비 중'` → `PrivacyPolicyScreen`으로 이동하도록 연결
- 앱 정보 화면의 **오픈소스 라이선스** 항목: Flutter 내장 `showLicensePage()` → `OpenSourceLicenseScreen`으로 교체
- `open_source_license_screen.dart` import 추가

---

#### `lib/screens/open_source_license_screen.dart` — 신규 생성

이용약관·개인정보 처리방침과 동일한 디자인 시스템으로 제작한 커스텀 오픈소스 라이선스 화면.

**구성**
- 헤더: 제목 + 설명 + 오렌지 하단 선
- 안내 문구 박스
- 라이선스 종류 뱃지 3종: BSD 3-Clause(파랑) / Apache 2.0(초록) / MIT(보라)
- 패키지 카드 12개 — 탭 시 아코디언으로 펼쳐지는 구조
  - 접힌 상태: 패키지명 + 버전 + 라이선스 종류 뱃지 + 펼침 아이콘
  - 펼친 상태: 앱 내 용도 설명 + pub.dev URL

**포함 패키지 목록**

| 패키지 | 버전 | 라이선스 |
|---|---|---|
| Flutter SDK | SDK | BSD 3-Clause |
| firebase_core | ^4.6.0 | BSD 3-Clause |
| firebase_auth | ^6.3.0 | BSD 3-Clause |
| cloud_firestore | ^6.2.0 | BSD 3-Clause |
| firebase_storage | ^13.2.0 | BSD 3-Clause |
| google_sign_in | ^6.2.2 | BSD 3-Clause |
| kakao_flutter_sdk_user | ^1.9.8 | Apache 2.0 |
| http | ^1.1.0 | BSD 3-Clause |
| image_picker | ^1.0.7 | BSD 3-Clause |
| shared_preferences | ^2.2.2 | BSD 3-Clause |
| package_info_plus | ^8.0.0 | MIT |
| cupertino_icons | ^1.0.8 | MIT |

---

## 2026-05-20 — 마이페이지 앱 정보 화면 추가 및 법적 고지 페이지 작성

### 추가 파일

#### `lib/screens/my_page_screen.dart` — `_AppInfoScreen` 클래스 추가

기존 AlertDialog 형태의 앱 정보를 전용 화면으로 교체.

**구성**
- 상단 히어로 영역: 오렌지 그라디언트 + 앱 아이콘(🥦) + 앱명 + 버전 뱃지 + 슬로건
- 주요 기능 섹션: 레시피 검색 / 냉장고 파먹기 / 즐겨찾기 / 커뮤니티 / 인기 레시피 (아이콘 + 설명)
- 버전 정보 섹션: 앱 버전, 빌드 번호, 최소 지원 OS, 최종 업데이트일
- 고객지원 섹션: 문의 이메일, 개인정보 처리방침, 이용약관, 오픈소스 라이선스
- 푸터: © 2026 냉장고 구조대 팀

**보조 위젯 추가**
- `_InfoSection`: 섹션 컨테이너 (그림자, 둥근 모서리)
- `_FeatureRow`: 아이콘 + 제목 + 설명 행
- `_InfoRow`: 라벨-값 행, `onTap` 지정 시 오렌지 색상 + 화살표(›)로 자동 전환

**오픈소스 라이선스**
- `showLicensePage()` 연결 → Flutter 내장 라이선스 화면으로 이동
- 앱에 포함된 모든 패키지(firebase, kakao, google_sign_in 등) 라이선스 전문 자동 표시

---

#### `lib/screens/terms_screen.dart` — 신규 생성

이용약관 전문 화면. 총 8개 조항.

| 조 | 내용 |
|---|---|
| 제1조 | 목적 |
| 제2조 | 서비스 제공 범위 (농림축산식품부 공공 API 출처 명시) |
| 제3조 | 회원가입 및 계정 (소셜 로그인, 만 14세 미만 제한) |
| 제4조 | 이용자 콘텐츠 및 저작권 (커뮤니티 게시물 금지 행위 포함) |
| 제5조 | 서비스 변경 및 중단 |
| 제6조 | 면책 조항 (레시피 칼로리·알레르기 정확성 보장 불가) |
| 제7조 | 개인정보 보호 |
| 제8조 | 준거법 및 분쟁 해결 (대한민국 법률 적용) |

---

#### `lib/screens/privacy_policy_screen.dart` — 신규 생성

개인정보 처리방침 전문 화면. 총 9개 조항. 「개인정보 보호법」 기준 작성.

| 조 | 내용 |
|---|---|
| 제1조 | 수집 항목 (필수/선택/소셜/자동생성 구분) |
| 제2조 | 수집 및 이용 목적 |
| 제3조 | 보유 기간 및 파기 방법 (전자상거래법 등 법령 보존 기간 포함) |
| 제4조 | 제3자 제공 및 처리 위탁 (Firebase·Google·카카오 명시) |
| 제5조 | 이용자 권리 행사 방법 (열람·수정·삭제) |
| 제6조 | 자동 수집 정보 및 쿠키 (SharedPreferences 포함) |
| 제7조 | 기술적·관리적 보안 조치 (암호화·SSL·Firebase Security Rules) |
| 제8조 | 개인정보 보호책임자 및 신고 기관 (개인정보보호위원회·KISA) |
| 제9조 | 방침 변경 고지 방법 |

---

## 2026-05-20 — 회원가입 닉네임/이메일 중복확인 기능 수정

### 문제
`signup_screen.dart`의 중복확인 버튼이 눌려도 실제로 동작하지 않는 문제.

**원인 1 — 상태 관리 로직 오류 (`signup_screen.dart`)**
- `_emailError` / `_nicknameError` 변수에 성공 메시지("사용 가능한...")와 오류 메시지를 구분 없이 저장
- `_handleSignup()`에서 `_emailError != null || _nicknameError != null` 조건이 성공 메시지도 차단 → 중복확인을 통과해도 회원가입 불가
- 성공/실패 메시지 모두 빨간색으로 표시되는 UX 문제
- 텍스트 변경 시 이전 체크 결과가 초기화되지 않는 문제

**원인 2 — Firestore 보안 규칙**
- 비로그인 상태에서 `users` 컬렉션 읽기 권한 없음 → `permission-denied` 오류

**원인 3 — firebase_auth API 변경 시도 후 롤백**
- `firebase_auth ^6.x`에서 `fetchSignInMethodsForEmail()` 메서드가 완전 제거됨
- Firestore 쿼리 방식으로 원복

---

### 수정 파일 및 내용

#### `lib/screens/signup_screen.dart`

**1. 상태 변수 재설계**

| 변경 전 | 변경 후 |
|---|---|
| `String? _emailError` | `String? _emailStatus` (메시지) |
| `String? _nicknameError` | `bool _emailAvailable` (사용 가능 여부) |
| | `bool _emailChecked` (확인 완료 여부) |
| | `String? _nicknameStatus` |
| | `bool _nicknameAvailable` |
| | `bool _nicknameChecked` |

**2. `_checkNicknameDuplicate()` / `_checkEmailDuplicate()` 수정**
- 확인 완료 여부와 사용 가능 여부를 분리하여 저장
- 결과를 snackBar 대신 필드 하단 메시지로만 표시

**3. `_handleSignup()` 검증 로직 수정**
```dart
// 변경 전 — 성공 메시지도 차단하는 잘못된 조건
if (!isFormValid || _emailError != null || _nicknameError != null) { ... }

// 변경 후 — 상태에 따라 명확한 분기
if (!isFormValid) { ... }
if (!_nicknameChecked || !_nicknameAvailable) {
  _showSnackBar('닉네임 중복 확인을 해주세요.', isError: true); return;
}
if (!_emailChecked || !_emailAvailable) {
  _showSnackBar('이메일 중복 확인을 해주세요.', isError: true); return;
}
```

**4. 텍스트 변경 시 체크 상태 초기화**
- 닉네임/이메일 필드에 `onChanged` 추가
- 입력 변경 시 `_nicknameChecked`, `_emailChecked` 등을 `false`로 리셋하여 재확인 유도

**5. `_CustomFormField` 위젯 수정**
- `errorText` 파라미터 → `statusText` + `statusIsError` 파라미터로 교체
- `statusIsError: false` 이면 초록색, `true` 이면 빨간색으로 상태 메시지 표시

---

#### `lib/services/auth_service.dart`

**`checkEmailExists()` 메서드**
- `fetchSignInMethodsForEmail()` 사용 시도 → `firebase_auth ^6.x` 에서 해당 메서드 제거로 컴파일 오류
- Firestore `users` 컬렉션 쿼리 방식으로 원복 (닉네임 중복확인과 동일 방식으로 통일)

```dart
Future<bool> checkEmailExists(String email) async {
  final query = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: email)
      .get();
  return query.docs.isNotEmpty;
}
```

---

### 중복확인 동작을 위한 필수 설정 (Firebase 콘솔)

비로그인 상태의 `users` 컬렉션 읽기를 허용하도록 Firestore 보안 규칙 수정 필요.

**Firebase Console → Firestore Database → 규칙(Rules) 탭**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if true;   // 중복확인용 (비로그인 읽기 허용)
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```
