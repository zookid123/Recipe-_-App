import 'package:flutter/material.dart';
import 'signup_screen.dart';

class TermsAgreementScreen extends StatefulWidget {
  const TermsAgreementScreen({super.key});

  @override
  State<TermsAgreementScreen> createState() => _TermsAgreementScreenState();
}

class _TermsAgreementScreenState extends State<TermsAgreementScreen> {
  bool _isAllAgreed = false;
  bool _isServiceTermsAgreed = false;
  bool _isPrivacyPolicyAgreed = false;
  bool _isMarketingAgreed = false;

  void _updateAllAgreed(bool? value) {
    if (value == null) return;
    setState(() {
      _isAllAgreed = value;
      _isServiceTermsAgreed = value;
      _isPrivacyPolicyAgreed = value;
      _isMarketingAgreed = value;
    });
  }

  void _checkAllAgreed() {
    setState(() {
      _isAllAgreed = _isServiceTermsAgreed && _isPrivacyPolicyAgreed && _isMarketingAgreed;
    });
  }

  bool get _canProceed => _isServiceTermsAgreed && _isPrivacyPolicyAgreed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFB),
      appBar: AppBar(
        title: const Text(
          '약관 동의',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assignment_turned_in_outlined, color: Colors.orange, size: 28),
                        SizedBox(width: 12),
                        Text(
                          '반가워요!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF333333),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '냉장고 구조대 서비스를 이용하기 위해\n아래 약관에 동의가 필요합니다.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // 전체 동의 카드
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isAllAgreed ? Colors.orange : const Color(0xFFEEEEEE),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildAgreementItem(
                        title: '전체 동의하기',
                        value: _isAllAgreed,
                        onChanged: _updateAllAgreed,
                        isBold: true,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // 상세 약관 리스트
                    _buildAgreementItem(
                      title: '[필수] 서비스 이용약관 동의',
                      value: _isServiceTermsAgreed,
                      onChanged: (val) {
                        setState(() => _isServiceTermsAgreed = val ?? false);
                        _checkAllAgreed();
                      },
                      showDetail: true,
                      detailContent: '제 1 조 (목적)\n본 약관은 냉장고 구조대(이하 "회사")가 제공하는 제반 서비스의 이용과 관련하여 회사와 회원과의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.\n\n제 2 조 (용어의 정의)\n1. "서비스"라 함은 회사가 제공하는 냉장고 관리 및 레시피 공유 플랫폼을 의미합니다.\n2. "회원"이라 함은 회사의 서비스에 접속하여 이 약관에 따라 회사와 이용계약을 체결하고 회사가 제공하는 서비스를 이용하는 고객을 말합니다.',
                    ),
                    const SizedBox(height: 16),
                    _buildAgreementItem(
                      title: '[필수] 개인정보 수집 및 이용 동의',
                      value: _isPrivacyPolicyAgreed,
                      onChanged: (val) {
                        setState(() => _isPrivacyPolicyAgreed = val ?? false);
                        _checkAllAgreed();
                      },
                      showDetail: true,
                      detailContent: '1. 수집하는 개인정보 항목: 이메일 주소, 비밀번호, 이름, 닉네임, 생년월일, 성별\n2. 수집 및 이용 목적: 회원 식별, 서비스 제공, 부정 이용 방지\n3. 보유 및 이용 기간: 회원 탈퇴 시까지 (단, 법령에 따른 보존 필요 시 해당 기간까지)',
                    ),
                    const SizedBox(height: 16),
                    _buildAgreementItem(
                      title: '[선택] 마케팅 정보 수신 동의',
                      value: _isMarketingAgreed,
                      onChanged: (val) {
                        setState(() => _isMarketingAgreed = val ?? false);
                        _checkAllAgreed();
                      },
                      showDetail: true,
                      detailContent: '이벤트 정보, 신규 레시피 추천 등 광고성 정보를 푸시 알림이나 이메일 등으로 받아보실 수 있습니다.',
                    ),
                  ],
                ),
              ),
            ),
            
            // 다음 버튼
            Padding(
              padding: const EdgeInsets.all(28),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _canProceed
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SignupScreen()),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFEEEEEE),
                    disabledForegroundColor: const Color(0xFFBBBBBB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '다음으로',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgreementItem({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
    bool isBold = false,
    bool showDetail = false,
    String? detailContent,
    double fontSize = 15,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? Colors.orange : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? Colors.orange : const Color(0xFFCCCCCC),
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: value ? const Color(0xFF333333) : const Color(0xFF666666),
                ),
              ),
            ),
            if (showDetail)
              GestureDetector(
                onTap: () {
                  _showDetailDialog(title, detailContent ?? '');
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.keyboard_arrow_right, color: Color(0xFF999999), size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetailDialog(String title, String content) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF333333),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('닫기', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }
}
