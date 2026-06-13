# ADR-0002: 백엔드 선택 — Firebase

| 항목 | 내용 |
|------|------|
| **상태** | 승인 (Accepted) |
| **결정일** | 2026년 초 |

---

## 컨텍스트

앱은 다음 백엔드 요구사항을 충족해야 한다:

- 사용자 인증 (Google·카카오·이메일 멀티 프로바이더)
- 레시피·커뮤니티·채팅 데이터 실시간 동기화
- 프로필·레시피 이미지 파일 저장
- 서버 구축 및 운영 비용 최소화
- 빠른 개발 속도 (별도 서버 코드 없이 바로 연동)

아래 4가지 선택지를 검토하였다.

---

## 검토된 선택지

### 1. Firebase (Firestore + Auth + Storage) ✅ 선택

| 구분 | 내용 |
|------|------|
| **장점** | 실시간 스트림 구독 → StreamBuilder 패턴과 자연스러운 연동; Auth·DB·Storage 통합 SDK; 별도 서버 코드 불필요; Flutter 공식 패키지 완비; 무료 티어로 MVP 개발 가능 |
| **단점** | 벤더 종속(Google); 무료 티어 쿼리·스토리지 제한; 복잡한 조인 쿼리 불가 |

### 2. 자체 서버 (Node.js + MySQL/PostgreSQL)

| 구분 | 내용 |
|------|------|
| **장점** | 완전한 쿼리 자유도; 벤더 종속 없음 |
| **단점** | 서버 개발·배포·운영 비용 발생; 실시간 기능 구현에 WebSocket 별도 구축 필요; 인증 시스템 직접 구현 필요 — 개발 기간 내 완성 불가 |

### 3. Supabase

| 구분 | 내용 |
|------|------|
| **장점** | PostgreSQL 기반 완전한 SQL 지원; 오픈소스; Firebase 유사 API |
| **단점** | Flutter SDK 성숙도 Firebase 대비 낮음; 카카오 소셜 로그인 공식 지원 없음; 레퍼런스 부족 |

### 4. AWS Amplify

| 구분 | 내용 |
|------|------|
| **장점** | 엔터프라이즈 수준 확장성; S3·Cognito 통합 |
| **단점** | 설정 복잡도 높음; Flutter 연동 레퍼런스 부족; 학습 비용 과다 |

---

## 결정

**Firebase** (Firestore + Authentication + Storage) 를 선택한다.

핵심 근거:

1. **실시간 스트림** — Firestore의 `snapshots()` 스트림이 Flutter `StreamBuilder`와 자연스럽게 연동되어 채팅·알림·레시피 목록 실시간 업데이트를 별도 폴링 없이 구현
2. **멀티 프로바이더 인증 통합** — Google·카카오·이메일 3종 로그인을 Firebase Auth 단일 SDK로 관리, 토큰·세션 처리 자동화
3. **스토리지 통합** — 프로필 이미지·레시피 이미지를 Firebase Storage에 업로드하고 Firestore에 URL만 저장하는 패턴으로 일관성 유지
4. **서버리스** — 별도 서버 구축·배포 없이 Flutter 클라이언트에서 직접 연동, 개발 기간 내 완성 가능
5. **Flutter 공식 패키지** — `firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_storage` 모두 Google 공식 지원

---

## 결과 (Consequences)

### 긍정적

- 서버 코드 없이 클라이언트 단에서 인증·DB·스토리지를 모두 처리
- Firestore 실시간 스트림으로 채팅·알림·커뮤니티 피드 실시간 반영
- Firebase Console로 데이터·사용자 관리 UI 무료 제공

### 부정적 / 감수하는 트레이드오프

- 복잡한 관계형 쿼리(JOIN)가 필요한 경우 클라이언트 사이드 필터링으로 대체 (검색 등)
- Google 벤더 종속 — 추후 마이그레이션 시 비용 발생
- 공공 레시피 API는 CORS 문제로 클라이언트 직접 호출 불가 → 관리자가 `node sync_recipes.js`로 Firestore에 사전 동기화

---

## 관련 문서

- `docs/decisions/ADR-0001-flutter-platform.md` — 플랫폼 선택 근거
- `docs/decisions/ADR-0003-state-management.md` — 상태 관리 방식 선택 근거
- `docs/05_data_model.md` — Firestore 컬렉션 스키마 상세
