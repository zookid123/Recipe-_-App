# 데이터 모델 (Firestore 스키마)

## Firestore 컬렉션 구조 한눈에 보기

```
Firestore
├── recipes/                         — 레시피 (공공 API + 사용자 작성)
│   └── {recipeId}/
│       └── comments/                — 레시피 댓글
│           └── {commentId}/
│               └── replies/         — 댓글 답글 (대댓글)
│
├── users/                           — 사용자 정보
│   └── {userId}/
│       ├── bookmarks/               — 북마크한 레시피
│       ├── recentRecipes/           — 최근 본 레시피
│       ├── likes/                   — 좋아요한 레시피
│       ├── commentLikes/            — 좋아요한 댓글
│       ├── fridge/                  — 냉장고 재료
│       ├── myComments/              — 내가 작성한 레시피 댓글
│       ├── communityLikes/          — 커뮤니티 게시글 좋아요
│       └── notifications/           — 알림함
│
├── community/                       — 커뮤니티 게시글
│   └── {postId}/
│       └── comments/                — 커뮤니티 댓글
│
└── chatRooms/                       — 채팅방
    └── {roomId}/
        └── messages/                — 채팅 메시지
```

---

## 1. recipes 컬렉션

문서 ID = `RECIPE_ID` (공공 API 원본 값 또는 Firestore 자동 생성 ID)

| 필드 | 타입 | 설명 |
|------|------|------|
| `name` | String | 레시피명 (한국어) |
| `summary` | String | 한줄 소개 |
| `imgUrl` | String | 대표 이미지 URL |
| `calorie` | String | 칼로리 |
| `qnt` | String | 분량 |
| `time` | String | 조리 시간 표시용 (`"30분"`) |
| `timeMinutes` | Number | 조리 시간 분 단위 (필터·정렬용) |
| `level` | String | 난이도 |
| `nation` | String | 국가 (`한식`, `서양`, `중국`, `일본`, `동남아시아`, `이탈리아`, `퓨전`) |
| `type` | String | 요리 유형 (`기타`, `반찬` 등) |
| `ingredients` | Array\<String\> | `["재료명 (용량)", ...]` |
| `steps` | Array\<String\> | 조리 순서 (정렬 완료) |
| `timestamp` | Timestamp | 마지막 동기화 시각 |
| `viewCount` | Number | 누적 조회수 |
| `todayViewCount` | Number | 당일 조회수 |
| `yesterdayViewCount` | Number | 전일 조회수 |
| `todayDate` | String | 오늘 날짜 (`YYYY-MM-DD`) |
| `likeCount` | Number | 좋아요 수 |
| `source` | String? | `'ugc'` = 사용자 작성 레시피 (없으면 공공 API 데이터) |
| `authorId` | String? | 사용자 작성 레시피의 작성자 UID |
| `authorName` | String? | 사용자 작성 레시피의 작성자 닉네임 |
| `authorProfileImg` | String? | 사용자 작성 레시피의 작성자 프로필 이미지 URL |
| `stepImages` | Array\<String\> | 조리 단계별 이미지 URL 목록 (사용자 작성 레시피) |
| `lastTrendingNotifyDate` | String? | 인기 순위 진입 알림 마지막 발송일 (`YYYY-MM-DD`) |

### recipes/{recipeId}/comments 서브컬렉션

| 필드 | 타입 | 설명 |
|------|------|------|
| `userId` | String? | 작성자 UID (익명이면 null) |
| `author` | String | 작성자 닉네임 또는 `'익명'` |
| `authorProfileImg` | String? | 작성자 프로필 이미지 URL |
| `authorTitle` | String? | 작성자 대표 칭호 |
| `text` | String | 댓글 내용 |
| `rating` | Number? | 별점 (1~5, 선택 사항) |
| `likeCount` | Number | 댓글 좋아요 수 |
| `replyCount` | Number | 답글 수 |
| `createdAt` | Timestamp | 작성 시각 |

### recipes/{recipeId}/comments/{commentId}/replies 서브컬렉션 (대댓글)

| 필드 | 타입 | 설명 |
|------|------|------|
| `authorId` | String? | 작성자 UID |
| `authorName` | String | 작성자 닉네임 또는 `'익명'` |
| `text` | String | 답글 내용 |
| `createdAt` | Timestamp | 작성 시각 |

---

## 2. users 컬렉션

문서 ID = Firebase Auth UID

| 필드 | 타입 | 설명 |
|------|------|------|
| `nickname` | String | 닉네임 (고유) |
| `email` | String? | 이메일 |
| `profileImageUrl` | String? | 프로필 이미지 URL |
| `provider` | String | 로그인 방식 (`google` / `kakao` / `email`) |
| `name` | String? | 실명 |
| `birthdate` | String? | 생년월일 |
| `contactEmail` | String? | 연락용 이메일 |
| `gender` | String? | 성별 |
| `selectedTitle` | String? | 대표 칭호 |
| `isProfilePublic` | Boolean | 프로필 공개 여부 |
| `showRecipes` | Boolean | 작성 레시피 공개 여부 |
| `showCommunityPosts` | Boolean | 커뮤니티 게시글 공개 여부 |
| `createdAt` | Timestamp | 가입 시각 |

### users/{userId}/bookmarks

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | String | 레시피 ID |
| `name` | String | 레시피명 |
| `imgUrl` | String | 이미지 URL |
| `nation` | String | 국가 |
| `savedAt` | Timestamp | 저장 시각 |

### users/{userId}/commentLikes

| 필드 | 타입 | 설명 |
|------|------|------|
| `likedAt` | Timestamp | 좋아요 누른 시각 |

> 문서 ID = 댓글 ID (`commentId`)

### users/{userId}/fridge

| 필드 | 타입 | 설명 |
|------|------|------|
| `name` | String | 재료명 |
| `quantity` | String | 수량 |
| `expiryDate` | String | 유통기한 (`YYYY-MM-DD`) |
| `expiryNotifiedDate` | String? | 마지막 알림 발송일 |
| `addedAt` | Timestamp | 등록 시각 |

### users/{userId}/notifications

| 필드 | 타입 | 설명 |
|------|------|------|
| `type` | String | `recipe_comment` / `community_comment` / `fridge_expiry` |
| `title` | String | 알림 제목 |
| `body` | String | 알림 내용 |
| `isRead` | Boolean | 읽음 여부 |
| `targetId` | String | 대상 레시피·게시글 ID |
| `createdAt` | Timestamp | 발생 시각 |

---

## 3. community 컬렉션

| 필드 | 타입 | 설명 |
|------|------|------|
| `title` | String | 게시글 제목 |
| `content` | String | 본문 |
| `category` | String | `공지` / `자유` / `Q&A` / `나눔` |
| `authorId` | String | 작성자 UID |
| `authorName` | String | 작성자 닉네임 |
| `authorProfileImg` | String? | 작성자 프로필 이미지 URL |
| `imgUrl` | String? | 첨부 이미지 URL |
| `likeCount` | Number | 좋아요 수 |
| `viewCount` | Number | 조회수 |
| `createdAt` | Timestamp | 작성 시각 |

### community/{postId}/comments 서브컬렉션

| 필드 | 타입 | 설명 |
|------|------|------|
| `authorId` | String | 작성자 UID |
| `authorName` | String | 작성자 닉네임 |
| `authorProfileImg` | String? | 작성자 프로필 이미지 URL |
| `content` | String | 댓글 내용 |
| `createdAt` | Timestamp | 작성 시각 |

---

## 4. chatRooms 컬렉션

| 필드 | 타입 | 설명 |
|------|------|------|
| `participants` | Array\<String\> | 참여자 UID 목록 |
| `contextId` | String | 연결된 게시글·레시피 ID |
| `contextTitle` | String | 연결된 게시글·레시피 제목 |
| `lastMessage` | String | 마지막 메시지 내용 |
| `lastTimestamp` | Timestamp | 마지막 메시지 시각 |

> 채팅방 ID = `{user1_id}_{user2_id}_{contextId}` 형태로 중복 방지

### chatRooms/{roomId}/messages 서브컬렉션

| 필드 | 타입 | 설명 |
|------|------|------|
| `senderId` | String | 발신자 UID |
| `senderName` | String | 발신자 닉네임 |
| `text` | String | 메시지 내용 |
| `createdAt` | Timestamp | 발송 시각 |

---

## 주요 Dart 데이터 클래스

### AppUser

```dart
class AppUser {
  final String id;
  final String nickname;
  final String? email;
  final String? profileImageUrl;
  final String provider;       // 'google' | 'kakao' | 'email'
  final String? selectedTitle;
  final bool isProfilePublic;

  bool get isAdmin => email == kAdminEmail;
  String? get displayTitle => isAdmin ? '운영자' : selectedTitle;
}
```

### UserProgress (업적 계산용)

```dart
class UserProgress {
  final int recipeViews;       // 레시피 조회 수
  final int bookmarks;         // 북마크 수
  final int comments;          // 댓글 수
  final int communityPosts;    // 커뮤니티 게시글 수
  final int createdRecipes;    // 작성한 레시피 수
  final int nations;           // 탐색한 국가 수
  final int fridgeSearches;    // 냉장고 파먹기 검색 횟수
  final bool earlyBird;        // 얼리버드 여부

  Set<String> get earnedTitles { ... } // 26가지 칭호 달성 계산
}
```
