# ADR-0003: 상태 관리 방식 — StatefulWidget + StreamBuilder

| 항목 | 내용 |
|------|------|
| **상태** | 승인 (Accepted) |
| **결정일** | 2026년 초 |

---

## 컨텍스트

앱의 상태 관리 요구사항:

- Firestore 컬렉션을 실시간으로 구독하여 화면에 반영 (레시피, 채팅, 알림 등)
- 로그인/로그아웃 상태를 전역에서 공유
- 북마크·최근 레시피 등 로컬 캐시 관리
- 팀 규모가 작고 개발 기간이 짧아 학습 비용이 낮은 방식 선호

아래 4가지 상태 관리 방식을 검토하였다.

---

## 검토된 선택지

### 1. StatefulWidget + StreamBuilder + ChangeNotifier ✅ 선택

| 구분 | 내용 |
|------|------|
| **장점** | Flutter 기본 내장 — 추가 패키지 불필요; Firestore `snapshots()` 스트림을 StreamBuilder로 바로 소비; `ChangeNotifier` 하나로 전역 Auth 상태 관리; 학습 비용 없음 |
| **단점** | 상태가 복잡해질수록 위젯 트리 재빌드 범위가 넓어질 수 있음; 대규모 앱에서는 유지보수 난이도 증가 |

### 2. Riverpod

| 구분 | 내용 |
|------|------|
| **장점** | `BuildContext` 없이 Provider 접근; 테스트 격리 용이; 컴파일 타임 안전성 |
| **단점** | 추가 패키지 설치 및 API 학습 필요; 이 앱의 전역 상태가 `AuthService` 하나뿐이라 과도한 도입 |

### 3. Bloc / Cubit

| 구분 | 내용 |
|------|------|
| **장점** | 이벤트→상태 단방향 흐름으로 예측 가능성 높음; 대규모 앱에 적합 |
| **단점** | 간단한 상태 변경에도 Event·State 클래스 선언 필요 — 보일러플레이트 과다; Firestore 스트림 연동에 별도 래퍼 필요 |

### 4. GetX

| 구분 | 내용 |
|------|------|
| **장점** | 라우팅·상태·DI 통합; 코드량 최소화 |
| **단점** | 전역 싱글톤으로 테스트 격리 어려움; 컴파일 타임 안전성 없음; Flutter 공식 권장 방식 아님 |

---

## 결정

**StatefulWidget + StreamBuilder + ChangeNotifier** 조합을 선택한다.

핵심 근거:

1. **Firestore 스트림과의 자연스러운 연동** — `StreamBuilder<QuerySnapshot>`이 Firestore `snapshots()`를 직접 소비하는 것이 가장 직관적이며, 별도 래퍼 없이 바로 사용 가능
2. **전역 상태가 단순** — 앱 전체에서 공유해야 하는 상태가 로그인 정보(`AuthService`) 하나뿐이라, Riverpod·Bloc 같은 복잡한 솔루션을 도입할 필요 없음
3. **추가 패키지 없음** — Flutter SDK에 내장된 기능만으로 구현 가능, 의존성 최소화
4. **학습 비용 없음** — 팀원 모두 StatefulWidget 패턴에 익숙, 단기 프로젝트에 적합

---

## 상태 관리 역할 분담

| 방식 | 용도 | 예시 |
|------|------|------|
| `StreamBuilder` | Firestore 실시간 데이터 구독 | 레시피 목록, 채팅 메시지, 알림 |
| `FutureBuilder` | 일회성 Firestore 조회 | 레시피 상세, 사용자 프로필 |
| `ChangeNotifier` (`AuthService`) | 로그인/로그아웃 전역 상태 | 사용자 정보, 관리자 여부 판별 |
| `SharedPreferences` | 로컬 캐시 | 북마크, 최근 본 레시피, 알림 설정 ON/OFF |
| `setState` | 단일 화면 내 UI 상태 | 필터 선택, 탭 전환, 입력 폼 |

---

## 결과 (Consequences)

### 긍정적

- Firestore 실시간 기능(채팅·알림·피드)을 `StreamBuilder` 하나로 간결하게 구현
- `AuthService.instance`로 어디서든 로그인 상태 접근 가능
- 의존성 추가 없이 Flutter 기본 패턴만으로 앱 완성

### 부정적 / 감수하는 트레이드오프

- 상태가 복잡해지면 `setState` 남용으로 불필요한 리빌드 발생 가능
- 향후 기능 확장 시 Riverpod 또는 Bloc 도입 검토 필요 (로드맵 참고)

---

## 관련 문서

- `docs/decisions/ADR-0001-flutter-platform.md` — 플랫폼 선택 근거
- `docs/decisions/ADR-0002-firebase-backend.md` — Firebase 선택 근거
- `docs/06_roadmap.md` — 향후 Riverpod 도입 검토 항목
