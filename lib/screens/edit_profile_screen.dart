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
    _loadPrivacySettings();
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
      final finalImageUrl = _resetToDefault ? null : (newImageUrl ?? _currentImageUrl);

      // 2. 닉네임 업데이트
      if (nicknameChanged) {
        await AuthService.instance.updateNickname(nickname);
      }

      // 3. 프로필 사진 업데이트
      if (imageChanged) {
        await AuthService.instance.updateProfileImage(finalImageUrl);
      }

      // 4. 공개 설정 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update({
        'isProfilePublic': _isProfilePublic,
        'showRecipes': _showRecipes,
        'showCommunityPosts': _showCommunityPosts,
      });

      // 5. 기존 글/댓글에 닉네임/사진 반영
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

    // 레시피 댓글 (userId 필드 기준)
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

    // 커뮤니티 댓글 + 답글 (authorId 필드 기준)
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

    // 답글 (authorId 필드 기준)
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

            // 프로필 이미지 (탭 가능)
            GestureDetector(
              onTap: _resetToDefault
                  ? null
                  : () async {
                      await _pickImage();
                      if (_newImageBytes != null) {
                        setState(() => _resetToDefault = false);
                      }
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
                    child: (_resetToDefault ||
                            (_newImageBytes == null && _currentImageUrl == null))
                        ? const Icon(Icons.person, size: 56, color: Colors.orange)
                        : null,
                  ),
                  if (!_resetToDefault)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.orange, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt,
                          size: 16, color: Colors.white),
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
                    if (_newImageBytes != null) {
                      setState(() => _resetToDefault = false);
                    }
                  },
                  icon: const Icon(Icons.photo_library_outlined,
                      size: 16, color: Colors.orange),
                  label: const Text('사진 변경',
                      style: TextStyle(fontSize: 13, color: Colors.orange)),
                ),
                if (_currentImageUrl != null || _newImageBytes != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _resetToDefault = true;
                      _newImageBytes = null;
                    }),
                    icon: const Icon(Icons.person_outline,
                        size: 16, color: Colors.grey),
                    label: Text(
                      _resetToDefault ? '기본 이미지 선택됨' : '기본 이미지로',
                      style: TextStyle(
                          fontSize: 13,
                          color: _resetToDefault
                              ? Colors.orange
                              : Colors.grey),
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
            Align(
              alignment: Alignment.centerLeft,
              child: Text('닉네임',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700)),
            ),
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
                        borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFDDDDDD))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.orange, width: 2)),
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
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('닉네임 변경 시 작성한 글에도 자동으로 반영됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),

            const SizedBox(height: 32),

            // 공개 설정
            Align(
              alignment: Alignment.centerLeft,
              child: Text('공개 설정',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700)),
            ),
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
                    subtitle: const Text('다른 사람이 내 프로필을 볼 수 있어요',
                        style: TextStyle(fontSize: 12)),
                    value: _isProfilePublic,
                    activeColor: Colors.orange,
                    onChanged: (v) => setState(() => _isProfilePublic = v),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  const Divider(height: 1, indent: 14, endIndent: 14),
                  SwitchListTile(
                    title: const Text('레시피 공개', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('내가 작성한 레시피 목록 표시',
                        style: TextStyle(fontSize: 12)),
                    value: _showRecipes,
                    activeColor: Colors.orange,
                    onChanged: _isProfilePublic
                        ? (v) => setState(() => _showRecipes = v)
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  const Divider(height: 1, indent: 14, endIndent: 14),
                  SwitchListTile(
                    title: const Text('게시글 공개', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('내가 작성한 커뮤니티 글 목록 표시',
                        style: TextStyle(fontSize: 12)),
                    value: _showCommunityPosts,
                    activeColor: Colors.orange,
                    onChanged: _isProfilePublic
                        ? (v) => setState(() => _showCommunityPosts = v)
                        : null,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('프로필 비공개 시 레시피·게시글 설정은 무시됩니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('저장하기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
