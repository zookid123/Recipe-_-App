import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('개인정보 처리방침'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: _PrivacyContent(),
      ),
    );
  }
}

class _PrivacyContent extends StatelessWidget {
  const _PrivacyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header(
          '개인정보 처리방침',
          '시행일: 2026년 5월 20일',
        ),
        const SizedBox(height: 16),

        // 안내 문구
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
          ),
          child: const Text(
            '냉장고 구조대는 이용자의 개인정보를 소중히 여기며, '
            '「개인정보 보호법」 및 관련 법령을 준수합니다. '
            '본 방침을 통해 수집하는 정보와 그 이용 목적을 투명하게 안내합니다.',
            style: TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.7),
          ),
        ),
        const SizedBox(height: 24),

        _section('제1조 (수집하는 개인정보 항목)', '''
서비스는 다음과 같은 개인정보를 수집합니다.

■ 회원가입 시 (필수)
  · 이메일 주소
  · 이름, 닉네임
  · 생년월일, 성별
  · 비밀번호 (암호화 저장)

■ 회원가입 시 (선택)
  · 프로필 이미지

■ 소셜 로그인 시
  · Google: 이메일, 이름, 프로필 사진
  · 카카오: 닉네임, 프로필 사진, 이메일 (동의 시)

■ 서비스 이용 중 자동 생성
  · 커뮤니티 게시글·사진·댓글
  · 레시피 조회 이력 (기기 내 로컬 저장)
  · 즐겨찾기 목록
  · 서비스 접속 로그, 접속 기기 정보'''),

        _section('제2조 (개인정보 수집 및 이용 목적)', '''
수집한 개인정보는 아래 목적으로만 이용됩니다.

① 회원 식별 및 서비스 제공
   가입·로그인·본인 확인, 맞춤 서비스 제공

② 개인화 기능 운영
   최근 본 레시피, 즐겨찾기, 추천 레시피 제공

③ 커뮤니티 서비스 운영
   게시글·댓글 작성, 다른 이용자와의 소통

④ 서비스 개선 및 부정 이용 방지
   접속 로그 분석, 비정상 이용 감지 및 차단

⑤ 고객 문의 처리
   서비스 관련 문의 응대 및 분쟁 해결'''),

        _section('제3조 (개인정보 보유 및 파기)', '''
■ 보유 기간
  · 회원 탈퇴 또는 이용 목적 달성 시까지 보유 후 즉시 파기
  · 단, 아래 법령에 따라 일정 기간 보관합니다.

    - 전자상거래법: 계약·청약 기록 5년
    - 전자상거래법: 소비자 불만·분쟁 기록 3년
    - 통신비밀보호법: 서비스 접속 로그 3개월

■ 파기 방법
  · 전자적 파일: 복구 불가능한 방법으로 영구 삭제
  · 출력물: 분쇄 또는 소각'''),

        _section('제4조 (개인정보 제3자 제공 및 처리 위탁)', '''
서비스는 이용자의 사전 동의 없이 개인정보를 제3자에게 제공하지 않습니다.
단, 서비스 운영을 위해 아래 업체에 처리를 위탁합니다.

┌─────────────────┬──────────────────────────┐
│ 수탁 업체         │ 위탁 업무                  │
├─────────────────┼──────────────────────────┤
│ Google Firebase  │ 회원 인증, DB, 파일 저장    │
│ Google LLC       │ Google 소셜 로그인          │
│ 카카오(Kakao)    │ 카카오 소셜 로그인           │
└─────────────────┴──────────────────────────┘

위탁 업체는 위탁받은 업무 외 개인정보를 이용할 수 없으며,
관련 법령에 따라 개인정보를 안전하게 처리할 의무가 있습니다.'''),

        _section('제5조 (이용자의 권리 및 행사 방법)', '''
이용자는 언제든지 아래 권리를 행사할 수 있습니다.

① 개인정보 열람 요청
   마이페이지 → 프로필 편집에서 확인 가능

② 개인정보 수정
   마이페이지 → 프로필 편집에서 직접 수정 가능

③ 개인정보 삭제 및 회원 탈퇴
   마이페이지 → 설정 → 회원 탈퇴 (준비 중)
   또는 이메일(support@refrigerator-rescue.kr)로 요청

④ 개인정보 처리 정지 요청
   위 이메일로 요청 시 지체 없이 처리

※ 만 14세 미만 아동의 경우 법정대리인이 권리를 행사할 수 있습니다.'''),

        _section('제6조 (자동 수집 정보 및 쿠키)', '''
① 서비스는 이용자의 최근 본 레시피, 즐겨찾기 등을 기기 내 로컬 저장소
   (SharedPreferences)에 저장합니다. 이 데이터는 서버에 전송되지 않으며
   앱 삭제 또는 데이터 초기화 시 함께 삭제됩니다.

② 웹 버전(Chrome 등) 이용 시 브라우저 쿠키 및 로컬스토리지를 통해
   로그인 상태 유지 등 기본 기능을 제공합니다.

③ 이용자는 브라우저 설정을 통해 쿠키 저장을 거부할 수 있으나,
   이 경우 일부 서비스 이용이 제한될 수 있습니다.'''),

        _section('제7조 (개인정보 보호를 위한 기술적·관리적 조치)', '''
① 비밀번호 암호화
   이용자의 비밀번호는 Firebase Authentication을 통해 암호화되어 저장되며,
   서비스 운영자도 확인할 수 없습니다.

② 보안 통신 (HTTPS/SSL)
   개인정보 전송 시 SSL 암호화 통신을 적용합니다.

③ 접근 권한 최소화
   개인정보에 접근 가능한 인원을 최소화하고, 접근 권한을 엄격히 관리합니다.

④ Firebase Security Rules 적용
   Firestore 및 Storage에 보안 규칙을 적용하여 허가된 접근만 허용합니다.'''),

        _section('제8조 (개인정보 보호책임자)', '''
서비스의 개인정보 처리에 관한 업무를 총괄하는 책임자는 아래와 같습니다.

  · 담당 부서: 냉장고 구조대 운영팀
  · 이메일: support@refrigerator-rescue.kr
  · 처리 기간: 접수 후 영업일 기준 3일 이내 회신

개인정보 침해 관련 신고·상담은 아래 기관에도 문의하실 수 있습니다.
  · 개인정보보호위원회: www.pipc.go.kr / 국번없이 182
  · 한국인터넷진흥원(KISA): privacy.kisa.or.kr / 국번없이 118'''),

        _section('제9조 (방침 변경 고지)', '''
본 개인정보 처리방침은 법령·정책 변경 또는 서비스 변경에 따라 수정될 수 있습니다.
변경 시 시행 7일 전 앱 내 공지사항을 통해 사전 안내하며,
중요한 변경의 경우 30일 전 고지합니다.'''),

        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
          ),
          child: const Text(
            '본 방침은 2026년 5월 20일부터 시행됩니다.\n'
            '이전 버전은 고객센터를 통해 확인하실 수 있습니다.\n'
            '문의: support@refrigerator-rescue.kr',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(color: Color(0x08000000), blurRadius: 4),
              ],
            ),
            child: Text(
              body,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF555555),
                height: 1.75,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Header(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF333333),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Container(height: 2, width: 40, color: Colors.orange),
      ],
    );
  }
}
