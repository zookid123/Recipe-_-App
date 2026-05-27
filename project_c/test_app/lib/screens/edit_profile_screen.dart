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

  @override
  void initState() {
    super.initState();
    final user = AuthService.instance.currentUser;
    _nicknameController = TextEditingController(text: user?.nickname ?? '');
    _currentImageUrl = user?.profileImageUrl;
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

      // 1. 프로필 사진 업로드
      if (_newImageBytes != null) {
        final path = 'profile_images/${user.id}.jpg';
        final ref = FirebaseStorage.instance.ref().child(path);
        await ref.putData(_newImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        newImageUrl = await ref.getDownloadURL();
      }

      final finalImageUrl = newImageUrl ?? _currentImageUrl;
      final nicknameChanged = nickname != user.nickname;
      final imageChanged = newImageUrl != null;

      // 2. 닉네임 업데이트
      if (nicknameChanged) {
        await AuthService.instance.updateNickname(nickname);
      }

      // 3. 프로필 사진 업데이트
      if (imageChanged) {
        await AuthService.instance.updateProfileImage(finalImageUrl!);
      }

      // 4. 기존 글에 닉네임/사진 반영
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

  // 기존 커뮤니티 글 + 레시피에 닉네임/사진 일괄 반영
  Future<void> _propagateProfileChange({
    required String uid,
    required String newNickname,
    String? newImageUrl,
  }) async {
    final db = FirebaseFirestore.instance;
    final update = <String, dynamic>{'authorName': newNickname};
    if (newImageUrl != null) update['authorProfileImg'] = newImageUrl;

    // 커뮤니티 글 업데이트
    final communitySnap = await db.collection('community')
        .where('authorId', isEqualTo: uid).get();
    if (communitySnap.docs.isNotEmpty) {
      final batch = db.batch();
      for (final doc in communitySnap.docs) {
        batch.update(doc.reference, update);
      }
      await batch.commit();
    }

    // 레시피 글 업데이트
    final recipeSnap = await db.collection('recipes')
        .where('authorId', isEqualTo: uid).get();
    if (recipeSnap.docs.isNotEmpty) {
      final batch = db.batch();
      for (final doc in recipeSnap.docs) {
        batch.update(doc.reference, {'authorName': newNickname});
      }
      await batch.commit();
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
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.orange.shade100,
                    backgroundImage: _newImageBytes != null
                        ? MemoryImage(_newImageBytes!) as ImageProvider
                        : (_currentImageUrl != null
                            ? NetworkImage(_currentImageUrl!)
                            : null),
                    child: (_newImageBytes == null && _currentImageUrl == null)
                        ? const Icon(Icons.person, size: 56, color: Colors.orange)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Colors.orange, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text('사진을 탭하여 변경',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
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
