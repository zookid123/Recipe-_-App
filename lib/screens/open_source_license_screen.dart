import 'package:flutter/material.dart';

class OpenSourceLicenseScreen extends StatelessWidget {
  const OpenSourceLicenseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('오픈소스 라이선스'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Open Source Licenses',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '냉장고 구조대는 아래의 오픈소스 소프트웨어를 사용하여 개발되었습니다.',
                    style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),

            // 라이선스 뱃지 범례
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildLicenseBadge('BSD 3-Clause', Colors.blue),
                  const SizedBox(width: 8),
                  _buildLicenseBadge('Apache 2.0', Colors.green),
                  const SizedBox(width: 8),
                  _buildLicenseBadge('MIT', Colors.purple),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 안내 문구 박스
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.1)),
              ),
              child: const Text(
                '본 소프트웨어는 각 오픈소스 라이선스 규정을 준수하며, 각 라이선스의 전문은 아래의 항목을 클릭하여 확인하실 수 있습니다.',
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.6),
              ),
            ),

            // 패키지 리스트
            _buildPackageTile('Flutter SDK', 'SDK', 'BSD 3-Clause', Colors.blue, 'https://flutter.dev', 'UI 프레임워크 및 코어 엔진'),
            _buildPackageTile('firebase_core', '^4.6.0', 'BSD 3-Clause', Colors.blue, 'https://pub.dev/packages/firebase_core', 'Firebase 서비스 초기화 및 연동'),
            _buildPackageTile('firebase_auth', '^6.3.0', 'BSD 3-Clause', Colors.blue, 'https://pub.dev/packages/firebase_auth', '사용자 인증 및 로그인 처리'),
            _buildPackageTile('cloud_firestore', '^6.2.0', 'BSD 3-Clause', Colors.blue, 'https://pub.dev/packages/cloud_firestore', '실시간 데이터베이스 및 레시피 저장'),
            _buildPackageTile('firebase_storage', '^13.2.0', 'BSD 3-Clause', Colors.blue, 'https://pub.dev/packages/firebase_storage', '이미지 파일 업로드 및 관리'),
            _buildPackageTile('google_sign_in', '^6.2.2', 'BSD 3-Clause', Colors.blue, 'https://pub.dev/packages/google_sign_in', 'Google 소셜 로그인 연동'),
            _buildPackageTile('kakao_flutter_sdk_user', '^1.9.8', 'Apache 2.0', Colors.green, 'https://pub.dev/packages/kakao_flutter_sdk_user', '카카오 소셜 로그인 연동'),
            _buildPackageTile('http', '^1.1.0', 'BSD 3-Clause', Colors.blue, 'https://pub.dev/packages/http', '공공 API 네트워크 통신'),
            _buildPackageTile('image_picker', '^1.0.7', 'BSD 3-Clause', Colors.blue, 'https://pub.dev/packages/image_picker', '프로필 사진 선택 및 카메라 기능'),
            _buildPackageTile('shared_preferences', '^2.2.2', 'BSD 3-Clause', Colors.blue, 'https://pub.dev/packages/shared_preferences', '로컬 데이터 영구 저장'),
            _buildPackageTile('package_info_plus', '^8.0.0', 'MIT', Colors.purple, 'https://pub.dev/packages/package_info_plus', '앱 버전 정보 조회'),
            _buildPackageTile('cupertino_icons', '^1.0.8', 'MIT', Colors.purple, 'https://pub.dev/packages/cupertino_icons', 'iOS 스타일 아이콘 폰트'),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPackageTile(String name, String version, String license, Color color, String url, String usage) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(version, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            _buildLicenseBadge(license, color),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(),
          const SizedBox(height: 8),
          _buildInfoRow('용도', usage),
          const SizedBox(height: 8),
          _buildInfoRow('주소', url, isLink: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLink = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: isLink ? Colors.blue : Colors.black87,
              decoration: isLink ? TextDecoration.underline : null,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
