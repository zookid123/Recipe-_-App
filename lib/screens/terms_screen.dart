import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('이용약관'),
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
              '냉장고 구조대 이용약관',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '시행일: 2026년 6월 1일',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            _buildSection('제1조 (목적)', '본 약관은 "냉장고 구조대"(이하 "서비스")가 제공하는 제반 서비스의 이용과 관련하여 서비스와 이용자의 권리, 의무 및 책임사항을 규정함을 목적으로 합니다.'),
            
            _buildSection('제2조 (서비스 제공 범위)', '1. 서비스는 농림축산식품부에서 제공하는 공공 API를 출처로 하는 레시피 정보를 제공합니다.\n2. 이용자는 재료 기반 레시피 검색, 커뮤니티 활동, 냉장고 재료 관리 등의 기능을 이용할 수 있습니다.'),
            
            _buildSection('제3조 (회원가입 및 계정)', '1. 서비스는 Google 및 카카오 소셜 로그인을 통해 회원가입 및 서비스를 제공합니다.\n2. 만 14세 미만의 아동은 법정대리인의 동의 없이 가입이 제한될 수 있습니다.'),
            
            _buildSection('제4조 (이용자 콘텐츠 및 저작권)', '1. 이용자가 서비스 내에 게시한 게시물의 저작권은 해당 게시물의 저작자에게 귀속됩니다.\n2. 타인의 저작권을 침해하거나 명예를 훼손하는 게시물은 사전 예고 없이 삭제될 수 있습니다.'),
            
            _buildSection('제5조 (서비스 변경 및 중단)', '서비스는 운영상, 기술상의 필요에 따라 제공하고 있는 서비스의 전부 또는 일부를 변경하거나 중단할 수 있습니다.'),
            
            _buildSection('제6조 (면책 조항)', '1. 서비스는 제공되는 레시피 정보의 정확성(칼로리, 알레르기 유발 성분 등)을 완전히 보장하지 않으며, 조리 과정에서 발생하는 사고에 대해 책임을 지지 않습니다.\n2. 천재지변 또는 이에 준하는 불가항력으로 인해 서비스를 제공할 수 없는 경우 책임을 면합니다.'),
            
            _buildSection('제7조 (개인정보 보호)', '서비스는 이용자의 개인정보를 보호하기 위해 "개인정보 처리방침"을 수립하고 이를 준수합니다.'),
            
            _buildSection('제8조 (준거법 및 분쟁 해결)', '본 약관은 대한민국 법률에 따라 규제되고 해석되며, 서비스와 이용자 간 발생한 분쟁은 관련 법령에 따른 관할 법원에서 해결합니다.'),
            
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
