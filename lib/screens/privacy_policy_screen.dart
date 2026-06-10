import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('개인정보 처리방침'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '개인정보 처리방침',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '시행일: 2026년 6월 1일',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            _buildSection('제1조 (수집 항목)', '1. 필수 항목: 소셜 서비스(Google, 카카오)에서 제공하는 고유 식별자, 닉네임, 이메일, 프로필 사진\n2. 선택 항목: 서비스 내 작성한 댓글, 커뮤니티 게시물, 즐겨찾기 목록\n3. 자동 수집: 서비스 이용 기록, 접속 로그, 쿠키, 기기 정보'),
            
            _buildSection('제2조 (수집 및 이용 목적)', '1. 서비스 가입 및 본인 확인\n2. 레시피 추천 및 개인화 서비스 제공\n3. 커뮤니티 활동 관리 및 부정 이용 방지\n4. 서비스 개선 및 통계 분석'),
            
            _buildSection('제3조 (보유 기간 및 파기)', '1. 원칙적으로 이용자가 회원 탈퇴 시 수집된 개인정보는 즉시 파기됩니다.\n2. 다만, 관계 법령에 의해 보존할 필요가 있는 경우 해당 법령에서 정한 기간 동안 보관합니다.'),
            
            _buildSection('제4조 (제3자 제공 및 위탁)', '1. 서비스는 이용자의 동의 없이 개인정보를 외부에 제공하지 않습니다.\n2. 원활한 서비스 제공을 위해 Firebase(Google LLC)에 데이터 처리를 위탁하고 있습니다.'),
            
            _buildSection('제5조 (이용자의 권리)', '이용자는 언제든지 자신의 개인정보를 열람, 수정, 삭제할 수 있으며, 회원 탈퇴를 통해 개인정보 이용 동의를 철회할 수 있습니다.'),
            
            _buildSection('제6조 (쿠키 및 로컬 저장소)', '서비스는 이용자의 편의를 위해 SharedPreferences를 사용하여 로컬 데이터를 저장할 수 있습니다. 이용자는 기기 설정에서 이를 제어할 수 있습니다.'),
            
            _buildSection('제7조 (보안 조치)', '서비스는 Firebase Security Rules 및 암호화 전송(SSL) 등을 통해 이용자의 개인정보를 안전하게 관리하기 위해 최선을 다하고 있습니다.'),
            
            _buildSection('제8조 (개인정보 보호책임자)', '개인정보 보호와 관련한 문의사항은 서비스 내 고객지원을 통해 문의해 주시기 바랍니다.'),
            
            _buildSection('제9조 (방침 변경 고지)', '본 방침이 변경될 경우 시행 7일 전부터 서비스 내 공지사항을 통해 고지합니다.'),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.6),
          ),
        ],
      ),
    );
  }
}
