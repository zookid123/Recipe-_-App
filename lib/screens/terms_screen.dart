import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('이용약관'),
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
        child: _TermsContent(),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header(
          '냉장고 구조대 서비스 이용약관',
          '시행일: 2026년 5월 20일',
        ),
        const SizedBox(height: 24),

        _section('제1조 (목적)', '''
본 약관은 냉장고 구조대(이하 "서비스")가 제공하는 레시피 검색, 커뮤니티, 즐겨찾기 등 모든 서비스의 이용 조건 및 절차, 회사와 이용자 간의 권리·의무 및 책임 사항을 규정함을 목적으로 합니다.'''),

        _section('제2조 (서비스 제공 범위)', '''
서비스는 다음의 기능을 제공합니다.

① 레시피 검색 및 조회
② 재료 기반 레시피 추천 (냉장고 파먹기)
③ 레시피 즐겨찾기 및 최근 본 레시피 관리
④ 커뮤니티 게시판 (요리 자랑, 후기 공유)
⑤ 회원 프로필 관리

서비스 내 레시피 데이터 일부는 농림축산식품부 공공데이터(공공 API)를 활용하여 제공됩니다.'''),

        _section('제3조 (회원가입 및 계정)', '''
① 이용자는 이메일, Google, 카카오 계정을 통해 회원가입할 수 있습니다.

② 1인 1계정을 원칙으로 하며, 타인의 정보를 이용한 계정 생성은 금지됩니다.

③ 만 14세 미만의 경우 법정대리인의 동의 없이 가입할 수 없습니다.

④ 계정 정보(비밀번호 등) 관리 책임은 이용자 본인에게 있으며, 타인에게 양도하거나 공유할 수 없습니다.

⑤ 계정 도용 또는 보안 위협이 발생한 경우 즉시 서비스 운영팀에 신고해야 합니다.'''),

        _section('제4조 (이용자 콘텐츠 및 저작권)', '''
① 이용자가 커뮤니티에 게시한 글, 사진, 댓글 등(이하 "게시물")의 저작권은 해당 이용자에게 귀속됩니다.

② 이용자는 게시물을 게시함으로써 서비스가 해당 게시물을 서비스 홍보·개선 목적으로 비상업적으로 활용할 수 있는 권한을 서비스에 부여합니다.

③ 이용자는 타인의 저작권, 초상권, 명예를 침해하는 게시물을 게시할 수 없습니다.

④ 다음에 해당하는 게시물은 사전 통보 없이 삭제될 수 있습니다.
  · 음란·폭력적 콘텐츠
  · 광고성 스팸 게시물
  · 타인 비방·혐오 발언
  · 개인정보 무단 공개
  · 허위 정보 유포'''),

        _section('제5조 (서비스 변경 및 중단)', '''
① 서비스는 운영 정책, 기술적 사유 등에 따라 서비스 내용을 변경할 수 있으며, 변경 시 앱 내 공지사항을 통해 사전 안내합니다.

② 다음의 경우 서비스 전부 또는 일부를 일시 중단하거나 종료할 수 있습니다.
  · 서버 점검, 시스템 장애, 보안 이슈 등 기술적 사유
  · 천재지변, 국가 비상사태 등 불가항력적 사유
  · 서비스 운영상 중대한 필요에 의한 경우

③ 서비스 종료 시 최소 30일 전 앱 내 공지를 통해 고지합니다.'''),

        _section('제6조 (면책 조항)', '''
① 서비스는 제공되는 레시피의 정확성(칼로리, 영양 정보, 알레르기 유발 성분 등)을 보장하지 않으며, 이를 참고한 이용자의 건강·안전 문제에 대해 책임을 지지 않습니다.

② 공공 API를 통해 제공되는 데이터의 오류, 누락, 변경으로 인한 손해에 대해 서비스는 책임을 지지 않습니다.

③ 이용자 간의 커뮤니티 활동에서 발생하는 분쟁에 대해 서비스는 직접 개입하지 않으며, 이로 인한 손해에 대해 책임을 지지 않습니다.

④ 이용자의 귀책 사유로 인한 계정 정보 유출, 데이터 손실에 대해 서비스는 책임을 지지 않습니다.'''),

        _section('제7조 (개인정보 보호)', '''
서비스는 이용자의 개인정보를 소중히 여기며, 관련 법령에 따라 보호합니다. 개인정보 수집·이용·보관에 관한 사항은 별도의 개인정보 처리방침을 통해 안내됩니다.'''),

        _section('제8조 (준거법 및 분쟁 해결)', '''
① 본 약관은 대한민국 법률에 따라 해석·적용됩니다.

② 서비스 이용과 관련하여 분쟁이 발생한 경우 당사자 간 협의를 통해 해결하며, 협의가 이루어지지 않을 경우 민사소송법에 따른 관할 법원에 소를 제기할 수 있습니다.'''),

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
            '본 약관은 2026년 5월 20일부터 시행됩니다.\n문의: support@refrigerator-rescue.kr',
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
