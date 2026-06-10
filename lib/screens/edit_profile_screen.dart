import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nicknameController;
  bool _saving = false;
  String? _errorText;
  Uint8List? _newImageBytes;
  String? _currentImageUrl;
  bool _resetToDefault = false;

  // 칭호 및 진행도
  String? _selectedTitle;
  UserProgress? _progress;
  bool _loadingProgress = true;

  // 공개 설정
  bool _isProfilePublic = true;
  bool _showRecipes = true;
  bool _showCommunityPosts = true;

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _currentImageUrl = user?.profileImageUrl;
    _selectedTitle = user?.selectedTitle;
    _loadPrivacySettings();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress = await AuthService.instance.fetchUserProgress();
    if (mounted) {
      setState(() {
        _progress = progress;
        _loadingProgress = false;
      });
    }
  }

  Future<void> _loadPrivacySettings() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.id)
        .get();
    if (!mounted || !doc.exists) return;
    final data = doc.data()!;
    setState(() {
      _isProfilePublic = data['isProfilePublic'] as bool? ?? true;
      _showRecipes = data['showRecipes'] as bool? ?? true;
      _showCommunityPosts = data['showCommunityPosts'] as bool? ?? true;
    });
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _newImageBytes = bytes);
  }

  void _showTitlePicker() {
    if (_loadingProgress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('칭호 정보를 불러오는 중입니다...')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TitlePickerSheet(
        initialTitle: _selectedTitle,
        earnedTitles: _progress?.earnedTitles ?? {},
        onSelect: (title) => setState(() => _selectedTitle = title),
      ),
    );
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

    setState(() { _saving = true; _errorText = null; });

    try {
      final user = AuthService.instance.currentUser!;
      String? newImageUrl;

      // 1. 프로필 사진 업로드 또는 초기화
      if (_resetToDefault) {
        newImageUrl = null;
      } else if (_newImageBytes != null) {
        final path = 'profile_images/${user.id}.jpg';
        final ref = FirebaseStorage.instance.ref().child(path);
        await ref.putData(_newImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        newImageUrl = await ref.getDownloadURL();
      }

      final nicknameChanged = nickname != user.nickname;
      final imageChanged = _resetToDefault || _newImageBytes != null;
      final titleChanged = _selectedTitle != user.selectedTitle;
      final finalImageUrl = _resetToDefault ? null : (newImageUrl ?? _currentImageUrl);

      // 2. 닉네임 업데이트
      if (nicknameChanged) {
        await AuthService.instance.updateNickname(nickname);
      }

      // 3. 프로필 사진 업데이트
      if (imageChanged) {
        await AuthService.instance.updateProfileImage(finalImageUrl);
      }

      // 4. 칭호 업데이트
      if (titleChanged) {
        await AuthService.instance.updateTitle(_selectedTitle);
      }

      // 5. 공개 설정 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update({
        'isProfilePublic': _isProfilePublic,
        'showRecipes': _showRecipes,
        'showCommunityPosts': _showCommunityPosts,
      });

      // 6. 기존 글/댓글에 닉네임/사진 반영
      if (nicknameChanged || imageChanged) {
        await _propagateProfileChange(
          uid: user.id,
          newNickname: nickname,
          newImageUrl: finalImageUrl,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필이 업데이트되었습니다'),
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

  // 기존 글/댓글/답글에 닉네임/사진 일괄 반영
  Future<void> _propagateProfileChange({
    required String uid,
    required String newNickname,
    String? newImageUrl,
  }) async {
    final db = FirebaseFirestore.instance;
    final postUpdate = <String, dynamic>{
      'authorName': newNickname,
      'authorProfileImg': newImageUrl,
    };

    // 커뮤니티 글
    final communitySnap = await db
        .collection('community')
        .where('authorId', isEqualTo: uid)
        .get();
    if (communitySnap.docs.isNotEmpty) {
      final batch = db.batch();
      for (final doc in communitySnap.docs) {
        batch.update(doc.reference, postUpdate);
      }
      await batch.commit();
    }

    // 레시피 글
    final recipeSnap = await db
        .collection('recipes')
        .where('authorId', isEqualTo: uid)
        .get();
    if (recipeSnap.docs.isNotEmpty) {
      final batch = db.batch();
      for (final doc in recipeSnap.docs) {
        batch.update(doc.reference, postUpdate);
      }
      await batch.commit();
    }

    // 레시피 댓글
    try {
      final recipeCommentSnap = await db
          .collectionGroup('comments')
          .where('userId', isEqualTo: uid)
          .get();
      if (recipeCommentSnap.docs.isNotEmpty) {
        final batch = db.batch();
        for (final doc in recipeCommentSnap.docs) {
          batch.update(doc.reference, {
            'author': newNickname,
            'authorProfileImg': newImageUrl,
          });
        }
        await batch.commit();
      }
    } catch (_) {}

    // 커뮤니티 댓글 + 답글
    try {
      final communityCommentSnap = await db
          .collectionGroup('comments')
          .where('authorId', isEqualTo: uid)
          .get();
      if (communityCommentSnap.docs.isNotEmpty) {
        final batch = db.batch();
        for (final doc in communityCommentSnap.docs) {
          batch.update(doc.reference, {
            'authorName': newNickname,
            'authorProfileImg': newImageUrl,
          });
        }
        await batch.commit();
      }
    } catch (_) {}

    // 답글
    try {
      final replySnap = await db
          .collectionGroup('replies')
          .where('authorId', isEqualTo: uid)
          .get();
      if (replySnap.docs.isNotEmpty) {
        final batch = db.batch();
        for (final doc in replySnap.docs) {
          batch.update(doc.reference, {
            'authorName': newNickname,
            'authorProfileImg': newImageUrl,
          });
        }
        await batch.commit();
      }
    } catch (_) {}
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
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('저장',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
            GestureDetector(
              onTap: _resetToDefault ? null : () async {
                await _pickImage();
                if (_newImageBytes != null) setState(() => _resetToDefault = false);
              },
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.orange.shade100,
                    backgroundImage: _resetToDefault
                        ? null
                        : (_newImageBytes != null
                            ? MemoryImage(_newImageBytes!) as ImageProvider
                            : (_currentImageUrl != null
                                ? NetworkImage(_currentImageUrl!)
                                : null)),
                    child: (_resetToDefault || (_newImageBytes == null && _currentImageUrl == null))
                        ? const Icon(Icons.person, size: 56, color: Colors.orange)
                        : null,
                  ),
                  if (!_resetToDefault)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await _pickImage();
                    if (_newImageBytes != null) setState(() => _resetToDefault = false);
                  },
                  icon: const Icon(Icons.photo_library_outlined, size: 16, color: Colors.orange),
                  label: const Text('사진 변경', style: TextStyle(fontSize: 13, color: Colors.orange)),
                ),
                if (_currentImageUrl != null || _newImageBytes != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _resetToDefault = true;
                      _newImageBytes = null;
                    }),
                    icon: const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                    label: Text(
                      _resetToDefault ? '기본 이미지 선택됨' : '기본 이미지로',
                      style: TextStyle(fontSize: 13, color: _resetToDefault ? Colors.orange : Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              user?.provider == 'google' ? 'Google 계정' : '카카오 계정',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 32),

            // 닉네임 입력
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
                    border: _inputBorder(),
                    enabledBorder: _inputBorder(),
                    focusedBorder: _inputBorder(focus: true),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _nicknameController.clear())
                        : null,
                  ),
                  onChanged: (_) => setState(() => _errorText = null),
                );
              },
            ),

            const SizedBox(height: 24),

            // 칭호 선택 섹션
            _sectionLabel('나의 칭호'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDDDDD)),
              ),
              child: Column(
                children: [
                  if (user?.isAdmin == true) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.orange, Color(0xFFFFAB40)]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('⭐ 운영자', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const Spacer(),
                        const Text('관리자 전용 칭호', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ] else ...[
                    if (_selectedTitle != null) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Colors.orange, Color(0xFFFFAB40)]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('⭐ $_selectedTitle', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() => _selectedTitle = null),
                            child: const Text('제거', style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _showTitlePicker,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          _selectedTitle == null ? '칭호 선택하기' : '칭호 변경하기',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 공개 설정
            _sectionLabel('공개 설정'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDDDDDD)),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('프로필 공개', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('다른 사람이 내 프로필을 볼 수 있어요', style: TextStyle(fontSize: 12)),
                    value: _isProfilePublic,
                    activeColor: Colors.orange,
                    onChanged: (v) => setState(() => _isProfilePublic = v),
                  ),
                  const Divider(height: 1, indent: 14, endIndent: 14),
                  SwitchListTile(
                    title: const Text('레시피 공개', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('내가 작성한 레시피 목록 표시', style: TextStyle(fontSize: 12)),
                    value: _showRecipes,
                    activeColor: Colors.orange,
                    onChanged: _isProfilePublic ? (v) => setState(() => _showRecipes = v) : null,
                  ),
                  const Divider(height: 1, indent: 14, endIndent: 14),
                  SwitchListTile(
                    title: const Text('게시글 공개', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('내가 작성한 커뮤니티 글 목록 표시', style: TextStyle(fontSize: 12)),
                    value: _showCommunityPosts,
                    activeColor: Colors.orange,
                    onChanged: _isProfilePublic ? (v) => setState(() => _showCommunityPosts = v) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                    : const Text('저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
    );
  }

  OutlineInputBorder _inputBorder({bool focus = false}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: focus ? Colors.orange : const Color(0xFFDDDDDD), width: focus ? 2 : 1),
    );
  }
}

class _TitlePickerSheet extends StatelessWidget {
  final String? initialTitle;
  final Set<String> earnedTitles;
  final Function(String?) onSelect;

  const _TitlePickerSheet({
    required this.initialTitle,
    required this.earnedTitles,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('칭호 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              _earnedBadge(earnedTitles.length),
            ],
          ),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _category('레시피 탐험가', ['식탐러', '레시피 헌터', '미식 탐험가', '전설의 미식가']),
                  _category('즐겨찾기 수집가', ['메모장', '레시피 수집가', '북마크 마니아', '레시피 도서관']),
                  _category('레시피 평론가', ['맛 초보', '맛 평론가', '미슐랭 가이드', '식신']),
                  _category('커뮤니티 주민', ['새내기', '이웃', '단골손님', '터줏대감']),
                  _category('레시피 창작자', ['견습생', '요리사', '셰프', '미슐랭 셰프']),
                  _category('세계 요리 탐방', ['동네 미식가', '세계 여행자', '세계 미식 대가']),
                  _category('냉장고 파먹기', ['냉장고 청소부', '절약 요리사', '재료 연금술사']),
                  _category('특별 업적', ['얼리버드', '완벽주의자', '전설']),
                  
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('칭호 없음', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    onTap: () { onSelect(null); Navigator.pop(context); },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _earnedBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12)),
      child: Text('$count개 달성', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _category(String name, List<String> titles) {
    int catEarned = titles.where((t) => earnedTitles.contains(t)).length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
              const SizedBox(width: 8),
              Text('$catEarned/${titles.length}', style: TextStyle(fontSize: 12, color: Colors.orange[300])),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: titles.map((t) => _titleChip(t)).toList(),
        ),
      ],
    );
  }

  Widget _titleChip(String title) {
    final isEarned = earnedTitles.contains(title);
    final isSelected = initialTitle == title;

    return GestureDetector(
      onTap: isEarned ? () => onSelect(title) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : (isEarned ? Colors.white : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.orange : (isEarned ? Colors.orange.withOpacity(0.3) : Colors.transparent)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isEarned) Icon(Icons.lock, size: 12, color: Colors.grey[400]),
            if (isSelected) const Icon(Icons.star, size: 12, color: Colors.white),
            if (!isEarned || isSelected) const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : (isEarned ? Colors.orange : Colors.grey[400]),
                fontWeight: isSelected || isEarned ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
