# ADR-0001: 플랫폼 선택 — Flutter

| 항목 | 내용 |
|------|------|
| **상태** | 승인 (Accepted) |
| **결정일** | 2026년 초 |

---

## 컨텍스트

냉장고 구조대는 Android·iOS·Web·Windows를 모두 타겟으로 하는 요리 플랫폼이다.
대학 과제 프로젝트로 제한된 개발 기간 내에 다음 조건을 만족해야 했다:

- Android · iOS · Web 동시 지원 필수
- Firebase Firestore 실시간 연동 필요
- 이미지 업로드·갤러리 접근 필요
- 빠른 이터레이션이 가능한 개발 환경

아래 4가지 선택지를 검토하였다.

---

## 검토된 선택지

### 1. Flutter (Dart) ✅ 선택

| 구분 | 내용 |
|------|------|
| **장점** | 단일 코드베이스로 Android·iOS·Web·Windows 동시 빌드; Firebase 공식 연동 패키지 완비; Hot Reload로 빠른 이터레이션; 독자 렌더링 엔진으로 커스텀 UI 자유도 |
| **단점** | Dart 언어 학습 필요; 네이티브 대비 바이너리 크기 큼 |

### 2. React Native (JS/TS)

| 구분 | 내용 |
|------|------|
| **장점** | JS/TS 기존 경험 재활용; 넓은 npm 생태계 |
| **단점** | JS Bridge 오버헤드; Web·Windows 지원 미흡; Firebase 연동 설정 복잡 |

### 3. Android (Kotlin) 단독

| 구분 | 내용 |
|------|------|
| **장점** | 풀 네이티브 성능; Android 생태계 성숙 |
| **단점** | iOS·Web·Windows 지원 불가 — 요구사항 미충족 |

### 4. iOS (Swift) 단독

| 구분 | 내용 |
|------|------|
| **장점** | Apple 생태계 깊은 활용; 네이티브 성능 |
| **단점** | Android·Web·Windows 지원 불가 — 요구사항 미충족; macOS 개발 환경 필수 |

---

## 결정

**Flutter (Dart)** 를 선택한다.

핵심 근거:

1. **크로스플랫폼** — 코드베이스 하나로 Android·iOS·Web·Windows를 모두 커버, 개발 공수 최소화
2. **Firebase 공식 연동** — `firebase_core`, `cloud_firestore`, `firebase_auth`, `firebase_storage` 패키지가 공식 지원되어 별도 브리지 없이 바로 연동
3. **독자 렌더링 엔진** — 네이티브 컴포넌트에 의존하지 않아 홈 화면 배너·카드 UI 등 커스텀 레이아웃 자유롭게 구현
4. **Hot Reload** — 짧은 개발 사이클에서 UI 이터레이션 속도 극대화

---

## 결과 (Consequences)

### 긍정적

- 단일 코드베이스로 4개 플랫폼 동시 지원
- Firebase 패키지 생태계를 그대로 활용
- `_AppScrollBehavior`로 데스크탑 마우스 드래그 스크롤 쉽게 추가 가능

### 부정적 / 감수하는 트레이드오프

- Dart 신규 학습 비용 발생 (초기 1~2주)
- 앱 바이너리 크기가 네이티브 대비 큼
- 카카오 로그인 등 일부 네이티브 SDK는 플랫폼별 추가 설정 필요

---

## 관련 문서

- `docs/ADR-0002-firebase-backend.md` — 백엔드 선택 근거
- `docs/ADR-0003-state-management.md` — 상태 관리 방식 선택 근거
