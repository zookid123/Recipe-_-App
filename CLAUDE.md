# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# 의존성 설치
flutter pub get

# 앱 실행 (기기/에뮬레이터 선택)
flutter run

# 특정 기기 지정 실행
flutter run -d chrome     # 웹 (8080 포트, 보안 해제 권장)
flutter run -d windows    # 윈도우 데스크탑

# 정적 분석
flutter analyze

# 테스트 실행
flutter test

# 데이터 동기화 (관리자 전용)
cd test_app
node sync_recipes.js
```

## 아키텍처 개요

### 앱 구조

`MainShell` (main.dart) — `IndexedStack` 기반 4탭 바텀 네비게이션

```
홈(HomeScreen) / 레시피(RecipeListScreen) / 커뮤니티(CommunityScreen) / 마이(MyPageScreen)
```

모든 화면은 `lib/screens/`에 위치하며, 재사용 카드 위젯은 `lib/widgets/`에 위치한다.
현재 별도의 상태 관리 라이브러리 없이 `StatefulWidget` + `StreamBuilder`로 Firestore 실시간 연동을 처리한다.

### 데이터 흐름

```
공공 API (농림축산식품부)
    ↓  sync_recipes.js (Node.js 스크립트) — 외부 실행
Firestore `recipes` 컬렉션
    ↓  StreamBuilder / FutureBuilder
각 화면 (HomeScreen, RecipeListScreen, SearchScreen 등)
```

- **중요:** 앱 내 `syncToFirebase()` 버튼 대신, 관리자가 터미널에서 `node sync_recipes.js`를 실행하여 데이터를 갱신한다. (CORS 문제 및 데이터 누락 방지)
- 검색은 클라이언트 사이드 필터링이며, 향후 Firestore 인덱싱을 통한 고도화 예정.
- 조회수 로직: `RecipeDetailScreen.initState`에서 직접 업데이트. `todayDate` 비교를 통해 일간 조회수 관리.

### Firestore 스키마 (`recipes` 컬렉션)

문서 ID = `RECIPE_ID` (공공 API 원본 값)

| 필드 | 타입 | 설명 |
|------|------|------|
| `name` | String | 레시피명 (한국어) |
| `summary` | String | 한줄 소개 |
| `imgUrl` | String | 대표 이미지 URL |
| `calorie` | String | 칼로리 |
| `qnt` | String | 분량 |
| `time` | String | 조리 시간 표시용 (`"30분"`) |
| `timeMinutes` | Number | 조리 시간 (분, 필터·정렬용) |
| `level` | String | 난이도 (`LEVEL_NM`) |
| `nation` | String | 국가 (`한식`, `서양`, `중국`, `일본`, `동남아시아`, `이탈리아`, `퓨전`) |
| `type` | String | 요리 유형 (`기타`, `반찬` 등) |
| `ingredients` | Array\<String\> | `["재료명 (용량)", ...]` |
| `steps` | Array\<String\> | 조리 순서 (정렬 완료) |
| `timestamp` | Timestamp | 마지막 동기화 시각 |
| `viewCount` | Number | 누적 조회수 |
| `todayViewCount` | Number | 당일 조회수 |
| `yesterdayViewCount` | Number | 전일 조회수 |
| `todayDate` | String | 오늘 날짜 (`YYYY-MM-DD`) |

### 인증 관련 미완료 사항 (2026-06-13 기준)

1. ~~Firebase Console → Authentication → Google 로그인 활성화~~ — 완료. Android 앱(`com.example.sg_recipes`)에 디버그 키스토어 SHA-1(`81:6A:48:A3:0A:56:1E:CA:4B:76:C1:46:0A:92:C8:BF:8C:06:60:DB`) 등록 후 정상 동작 확인.
   - 참고: 웹(Chrome)은 Firebase 웹 OAuth 클라이언트(도메인 기반)로 동작해 SHA-1이 필요 없었음. 안드로이드 네이티브 `google_sign_in`은 앱 서명 인증서(SHA-1) 검증이 필요해 별도 등록이 필요했음.
   - 릴리스 빌드 배포 시에는 릴리스 키스토어 SHA-1도 추가 등록 필요.
2. 카카오 Developers → 앱 등록, 패키지명(`com.example.flutter_application_1`) + 키 해시 등록 (진행 중)
3. `lib/main.dart`의 카카오 네이티브 앱 키 적용 완료.

### 향후 개발 우선순위 (Roadmap)

1.  **개인화 기능 (P0):** 즐겨찾기(북마크) 저장 기능, 최근 본 레시피 활동 내역.
2.  **커뮤니티 활성화 (P1):** 사용자 요리 자랑 게시판(CommunityScreen), 레시피 별 댓글 및 요리 후기 사진 리뷰 기능.
3.  **검색 경험 고도화 (P1):** 보유 재료 기반 '냉장고 파먹기' 매칭 검색(IngredientSearchScreen), 0kcal 필터링 강화.
4.  **사용자 편의 기능 (P2):** 요리 중 큰 글씨로 보여주는 '조리 전용 모드', 재료 장바구니 리스트 연동.

### 플랫폼 대응

`_AppScrollBehavior`를 앱 전역에 적용하여 데스크탑 환경에서 마우스 드래그로 가로 스크롤이 가능하다.
