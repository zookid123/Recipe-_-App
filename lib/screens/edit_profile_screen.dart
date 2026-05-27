import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nicknameController;
  String? _selectedTitle;
  bool _saving = false;
  String? _errorText;
  UserProgress? _progress;
  bool _progressLoading = true;

  @override
  void initState() {
    super.initState();
    final current = AuthService.instance.currentUser;
    _nicknameController = TextEditingController(text: current?.nickname ?? '');
    _selectedTitle = current?.selectedTitle;
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final p = await AuthService.instance.fetchUserProgress();
    if (mounted) setState(() { _progress = p; _progressLoading = false; });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nickname = _nicknameController.text.trim();

    if (nickname.isEmpty) {
      setState(() => _errorText = '닉네임을 입력해주세요');
      return;
    }
    if (nickname.length < 2) {
      setState(() => _errorText = '닉네임은 2자 이상이어야 합니다');
      return;
    }
    if (nickname.length > 12) {
      setState(() => _errorText = '닉네임은 12자 이하여야 합니다');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      final current = AuthService.instance.currentUser;
      if (nickname != current?.nickname) {
        await AuthService.instance.updateNickname(nickname);
      }
      if (_selectedTitle != current?.selectedTitle) {
        await AuthService.instance.updateTitle(_selectedTitle);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필이 저장되었습니다'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showTitlePicker() {
    if (_progressLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('업적 정보를 불러오는 중입니다...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    final earned = _progress?.earnedTitles ?? {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TitlePickerSheet(
        currentTitle: _selectedTitle,
        earnedTitles: earned,
        onSelected: (title) {
          setState(() => _selectedTitle = title);
          Navigator.pop(context);
        },
      ),
    );
  }

  String _providerText(String? provider) {
    switch (provider) {
      case 'google':
        return 'Google 계정';
      case 'kakao':
        return '카카오 계정';
      case 'email':
        return '이메일 계정';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('프로필 편집'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    '저장',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // 프로필 이미지
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.orange.shade100,
                  backgroundImage: user?.profileImageUrl != null
                      ? NetworkImage(user!.profileImageUrl!)
                      : null,
                  child: user?.profileImageUrl == null
                      ? const Icon(Icons.person, size: 56, color: Colors.orange)
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              _providerText(user?.provider),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 32),

            // ── 닉네임 섹션 ──────────────────────────────────
            _sectionLabel('닉네임'),
            const SizedBox(height: 8),
            ValueListenableBuilder(
              valueListenable: _nicknameController,
              builder: (context, value, _) {
                return TextField(
                  controller: _nicknameController,
                  maxLength: 12,
                  decoration: InputDecoration(
                    hintText: '닉네임을 입력하세요 (2~12자)',
                    errorText: _errorText,
                    counterText: '${value.text.length}/12',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.orange, width: 2),
                    ),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _nicknameController.clear(),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() => _errorText = null),
                );
              },
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '다른 사용자에게 표시되는 이름입니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 28),

            // ── 칭호 섹션 ─────────────────────────────────────
            _sectionLabel('칭호'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEEEEEE)),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 4),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 현재 칭호 표시
                  if (_selectedTitle != null) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.white, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                _selectedTitle!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // 칭호 제거 버튼
                        TextButton.icon(
                          onPressed: () => setState(() => _selectedTitle = null),
                          icon: const Icon(Icons.close, size: 15,
                              color: Colors.grey),
                          label: const Text('제거',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    const Text(
                      '설정된 칭호가 없습니다',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 칭호 선택 버튼
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _showTitlePicker,
                      icon: const Icon(Icons.emoji_events_outlined,
                          size: 18, color: Colors.orange),
                      label: Text(
                        _selectedTitle != null ? '칭호 변경하기' : '칭호 선택하기',
                        style: const TextStyle(color: Colors.orange),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '닉네임 위에 표시되는 업적 칭호입니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // 저장 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        '저장하기',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

// ── 칭호 선택 바텀 시트 ────────────────────────────────────────

class _TitlePickerSheet extends StatelessWidget {
  final String? currentTitle;
  final Set<String> earnedTitles;
  final ValueChanged<String?> onSelected;

  const _TitlePickerSheet({
    required this.currentTitle,
    required this.earnedTitles,
    required this.onSelected,
  });

  static const _categories = [
    _TitleCategory(
      icon: Icons.explore_rounded,
      color: Color(0xFFFF6B35),
      name: '레시피 탐험가',
      titles: ['식탐러', '레시피 헌터', '미식 탐험가', '전설의 미식가'],
    ),
    _TitleCategory(
      icon: Icons.bookmark_rounded,
      color: Color(0xFF4ECDC4),
      name: '즐겨찾기 수집가',
      titles: ['메모장', '레시피 수집가', '북마크 마니아', '레시피 도서관'],
    ),
    _TitleCategory(
      icon: Icons.rate_review_rounded,
      color: Color(0xFF9B59B6),
      name: '레시피 평론가',
      titles: ['맛 초보', '맛 평론가', '미슐랭 가이드', '식신'],
    ),
    _TitleCategory(
      icon: Icons.people_rounded,
      color: Color(0xFF3498DB),
      name: '커뮤니티 주민',
      titles: ['새내기', '이웃', '단골손님', '터줏대감'],
    ),
    _TitleCategory(
      icon: Icons.restaurant_menu_rounded,
      color: Color(0xFFE67E22),
      name: '레시피 창작자',
      titles: ['견습생', '요리사', '셰프', '미슐랭 셰프'],
    ),
    _TitleCategory(
      icon: Icons.public_rounded,
      color: Color(0xFF27AE60),
      name: '세계 요리 탐방',
      titles: ['동네 미식가', '세계 여행자', '세계 미식 대가'],
    ),
    _TitleCategory(
      icon: Icons.kitchen_rounded,
      color: Color(0xFF1ABC9C),
      name: '냉장고 파먹기',
      titles: ['냉장고 청소부', '절약 요리사', '재료 연금술사'],
    ),
    _TitleCategory(
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFFFB300),
      name: '특별 업적',
      titles: ['얼리버드', '완벽주의자', '전설'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들 바
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: Colors.orange, size: 22),
                const SizedBox(width: 8),
                const Text(
                  '칭호 선택',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF333333)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${earnedTitles.length} 달성',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 목록
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 칭호 없음 선택지
                _buildNoneChip(context),
                const SizedBox(height: 16),
                ..._categories.map((cat) => _buildCategorySection(context, cat)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoneChip(BuildContext context) {
    final isSelected = currentTitle == null;
    return GestureDetector(
      onTap: () => onSelected(null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orange.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.orange : const Color(0xFFEEEEEE),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.remove_circle_outline,
                color: isSelected ? Colors.orange : Colors.grey, size: 20),
            const SizedBox(width: 10),
            Text(
              '칭호 없음',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.orange : Colors.grey,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              const Icon(Icons.check_circle_rounded,
                  color: Colors.orange, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
      BuildContext context, _TitleCategory cat) {
    final earnedCount = cat.titles.where(earnedTitles.contains).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리 헤더
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(cat.icon, color: cat.color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                cat.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF555555),
                ),
              ),
              const Spacer(),
              Text(
                '$earnedCount / ${cat.titles.length} 달성',
                style: TextStyle(
                  fontSize: 11,
                  color: earnedCount > 0 ? cat.color : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 칭호 칩 목록
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cat.titles.map((title) {
              final isEarned = earnedTitles.contains(title);
              final isSelected = currentTitle == title;
              return GestureDetector(
                onTap: isEarned ? () => onSelected(title) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: !isEarned
                        ? Colors.grey.shade100
                        : isSelected
                            ? cat.color.withValues(alpha: 0.15)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: !isEarned
                          ? Colors.grey.shade300
                          : isSelected
                              ? cat.color
                              : const Color(0xFFDDDDDD),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isEarned) ...[
                        Icon(Icons.lock_outline,
                            color: Colors.grey.shade400, size: 12),
                        const SizedBox(width: 4),
                      ] else if (isSelected) ...[
                        Icon(Icons.star_rounded,
                            color: cat.color, size: 13),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: !isEarned
                              ? Colors.grey.shade400
                              : isSelected
                                  ? cat.color
                                  : const Color(0xFF555555),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TitleCategory {
  final IconData icon;
  final Color color;
  final String name;
  final List<String> titles;

  const _TitleCategory({
    required this.icon,
    required this.color,
    required this.name,
    required this.titles,
  });
}
