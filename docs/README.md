# 냉장고 구조대 — 프로젝트 문서

발표 준비를 위한 앱 전체 문서입니다.

## 목차

| 파일 | 내용 |
|------|------|
| [01_overview.md](01_overview.md) | 프로젝트 개요, 기획 의도, 타겟 사용자, 지원 플랫폼 |
| [02_features.md](02_features.md) | 핵심 기능 전체 목록 (인증/게스트 모드, 레시피, 냉장고, 커뮤니티, 알림, 업적, 관리자) |
| [03_tech_stack.md](03_tech_stack.md) | 기술 스택 (의존성·dev 의존성), 프로젝트 파일 구조, 아키텍처, 데이터 흐름, 네비게이션 구조, 핵심 설정 파일 |
| [04_screens.md](04_screens.md) | 주요 화면별 상세 기능 설명 (게스트 모드, 이용약관, 오픈소스 라이선스 포함) |
| [05_data_model.md](05_data_model.md) | Firestore 컬렉션 스키마, Dart 데이터 클래스 |
| [06_roadmap.md](06_roadmap.md) | 개발 이력, 완성된 기능 체크리스트, 향후 로드맵 |
| [decisions/ADR-0001-flutter-platform.md](decisions/ADR-0001-flutter-platform.md) | Flutter 플랫폼 선택 근거 (React Native·Native 대비) |
| [decisions/ADR-0002-firebase-backend.md](decisions/ADR-0002-firebase-backend.md) | Firebase 백엔드 선택 근거 (자체 서버·Supabase 대비) |
| [decisions/ADR-0003-state-management.md](decisions/ADR-0003-state-management.md) | 상태 관리 방식 선택 근거 (Riverpod·Bloc 대비) |

## PPT 슬라이드 추천 순서

1. **표지** — 앱 이름, 팀원, 한줄 소개
2. **기획 의도** — `01_overview.md`
3. **핵심 기능 요약** — `02_features.md` 상단 표
4. **기술 스택** — `03_tech_stack.md`
5. **앱 구조 (아키텍처)** — `03_tech_stack.md` 네비게이션·데이터 흐름
6. **주요 화면 시연** — `04_screens.md` (홈, 레시피, 냉장고, 커뮤니티, 마이페이지)
7. **데이터 모델** — `05_data_model.md`
8. **개발 이력 & 로드맵** — `06_roadmap.md`
9. **Q&A**
