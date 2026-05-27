import 'package:flutter/material.dart';

class OpenSourceLicenseScreen extends StatelessWidget {
  const OpenSourceLicenseScreen({super.key});

  static const _packages = [
    _PackageInfo(
      name: 'Flutter',
      version: 'SDK',
      license: 'BSD 3-Clause',
      description: 'Google이 개발한 크로스 플랫폼 UI 프레임워크. 본 앱의 모든 화면과 인터랙션에 사용됩니다.',
      url: 'github.com/flutter/flutter',
    ),
    _PackageInfo(
      name: 'firebase_core',
      version: '^4.6.0',
      license: 'BSD 3-Clause',
      description: 'Flutter용 Firebase SDK 초기화 패키지.',
      url: 'pub.dev/packages/firebase_core',
    ),
    _PackageInfo(
      name: 'firebase_auth',
      version: '^6.3.0',
      license: 'BSD 3-Clause',
      description: '이메일, Google 소셜 로그인 및 회원 인증에 사용됩니다.',
      url: 'pub.dev/packages/firebase_auth',
    ),
    _PackageInfo(
      name: 'cloud_firestore',
      version: '^6.2.0',
      license: 'BSD 3-Clause',
      description: '레시피, 사용자 정보, 커뮤니티 게시글 등 앱 데이터 저장 및 실시간 조회에 사용됩니다.',
      url: 'pub.dev/packages/cloud_firestore',
    ),
    _PackageInfo(
      name: 'firebase_storage',
      version: '^13.2.0',
      license: 'BSD 3-Clause',
      description: '커뮤니티 게시글 사진 및 프로필 이미지 업로드·저장에 사용됩니다.',
      url: 'pub.dev/packages/firebase_storage',
    ),
    _PackageInfo(
      name: 'google_sign_in',
      version: '^6.2.2',
      license: 'BSD 3-Clause',
      description: 'Google 계정을 통한 소셜 로그인 기능에 사용됩니다.',
      url: 'pub.dev/packages/google_sign_in',
    ),
    _PackageInfo(
      name: 'kakao_flutter_sdk_user',
      version: '^1.9.8',
      license: 'Apache 2.0',
      description: '카카오 계정을 통한 소셜 로그인 기능에 사용됩니다.',
      url: 'pub.dev/packages/kakao_flutter_sdk_user',
    ),
    _PackageInfo(
      name: 'http',
      version: '^1.1.0',
      license: 'BSD 3-Clause',
      description: '농림축산식품부 공공 API와의 HTTP 통신에 사용됩니다.',
      url: 'pub.dev/packages/http',
    ),
    _PackageInfo(
      name: 'image_picker',
      version: '^1.0.7',
      license: 'BSD 3-Clause',
      description: '기기 갤러리 또는 카메라에서 사진을 선택하는 기능에 사용됩니다.',
      url: 'pub.dev/packages/image_picker',
    ),
    _PackageInfo(
      name: 'shared_preferences',
      version: '^2.2.2',
      license: 'BSD 3-Clause',
      description: '최근 본 레시피, 즐겨찾기 등 기기 내 로컬 데이터 저장에 사용됩니다.',
      url: 'pub.dev/packages/shared_preferences',
    ),
    _PackageInfo(
      name: 'package_info_plus',
      version: '^8.0.0',
      license: 'MIT',
      description: '앱 버전, 빌드 번호 등 패키지 정보 조회에 사용됩니다.',
      url: 'pub.dev/packages/package_info_plus',
    ),
    _PackageInfo(
      name: 'cupertino_icons',
      version: '^1.0.8',
      license: 'MIT',
      description: 'iOS 스타일의 아이콘 폰트 패키지.',
      url: 'pub.dev/packages/cupertino_icons',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('오픈소스 라이선스'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            const _Header('오픈소스 라이선스', '본 앱에서 사용하는 오픈소스 소프트웨어 목록'),
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
                '냉장고 구조대는 아래 오픈소스 라이브러리를 사용합니다. '
                '각 패키지의 저작권 및 라이선스 조건은 해당 항목에서 확인하실 수 있습니다.',
                style: TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.7),
              ),
            ),
            const SizedBox(height: 20),

            // 라이선스 요약 뱃지
            Row(
              children: [
                _LicenseBadge('BSD 3-Clause', Colors.blue),
                const SizedBox(width: 8),
                _LicenseBadge('Apache 2.0', Colors.green),
                const SizedBox(width: 8),
                _LicenseBadge('MIT', Colors.purple),
              ],
            ),
            const SizedBox(height: 20),

            // 패키지 목록
            ..._packages.map((pkg) => _PackageCard(pkg)),

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
                '각 패키지의 전체 라이선스 원문은 해당 pub.dev 페이지에서 확인하실 수 있습니다.',
                style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatefulWidget {
  final _PackageInfo pkg;
  const _PackageCard(this.pkg);

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard> {
  bool _expanded = false;

  Color get _licenseColor {
    switch (widget.pkg.license) {
      case 'Apache 2.0':
        return Colors.green;
      case 'MIT':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 4),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.pkg.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF333333),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.pkg.version,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _licenseColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.pkg.license,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _licenseColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                    size: 22,
                  ),
                ],
              ),
            ),
            if (_expanded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      widget.pkg.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.link, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          widget.pkg.url,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LicenseBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _LicenseBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
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
        Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 12),
        Container(height: 2, width: 40, color: Colors.orange),
      ],
    );
  }
}

class _PackageInfo {
  final String name;
  final String version;
  final String license;
  final String description;
  final String url;

  const _PackageInfo({
    required this.name,
    required this.version,
    required this.license,
    required this.description,
    required this.url,
  });
}
