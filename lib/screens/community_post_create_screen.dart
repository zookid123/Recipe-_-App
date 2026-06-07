import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

class CommunityPostCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? existingPost;
  final String? docId;
  const CommunityPostCreateScreen({super.key, this.existingPost, this.docId});

  @override
  State<CommunityPostCreateScreen> createState() =>
      _CommunityPostCreateScreenState();
}

class _CommunityPostCreateScreenState
    extends State<CommunityPostCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  String _category = '자유';
  Uint8List? _imageBytes;
  String? _existingImageUrl;
  bool _saving = false;

  static const _categories = ['자유', 'Q&A', '나눔'];

  @override
  void initState() {
    super.initState();
    if (widget.existingPost != null) {
      _titleCtrl.text = widget.existingPost!['title'] ?? '';
      _contentCtrl.text = widget.existingPost!['content'] ?? '';
      _category = widget.existingPost!['category'] ?? '자유';
      _existingImageUrl = widget.existingPost!['imgUrl'];
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _imageBytes = bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지를 불러오지 못했습니다: $e')),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _existingImageUrl = null;
    });
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('제목을 입력해주세요.')));
      return;
    }
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('내용을 입력해주세요.')));
      return;
    }

    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      String imgUrl = _existingImageUrl ?? '';
      if (_imageBytes != null) {
        final path = 'community_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(path);
        await ref.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        imgUrl = await ref.getDownloadURL();
      }

      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'content': _contentCtrl.text.trim(),
        'category': _category,
        'imgUrl': imgUrl,
        'authorId': user.id,
        'authorName': user.nickname,
        'authorProfileImg': user.profileImageUrl ?? '',
        'authorTitle': user.selectedTitle,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance
            .collection('community').doc(widget.docId).update(data);
      } else {
        data['timestamp'] = FieldValue.serverTimestamp();
        data['commentCount'] = 0;
        data['likeCount'] = 0;
        data['viewCount'] = 0;
        await FirebaseFirestore.instance.collection('community').add(data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('storage')
                  ? '이미지 업로드 실패: Firebase Storage 권한을 확인해주세요.'
                  : '오류: $e',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(widget.docId != null ? '글 수정' : '글 작성',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          _saving
              ? const Center(child: Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))))
              : TextButton(
                  onPressed: _save,
                  child: const Text('등록',
                      style: TextStyle(color: Colors.orange,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 카테고리
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: _categories.map((cat) {
                  final selected = _category == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _category = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? Colors.orange : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(cat,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black54,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            )),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // 제목 + 내용
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      hintText: '제목을 입력해주세요',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  TextField(
                    controller: _contentCtrl,
                    decoration: const InputDecoration(
                      hintText: '내용을 입력해주세요',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                    maxLines: 12,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 이미지
            Stack(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
                      image: _imageBytes != null
                          ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                          : (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                              ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover)
                              : null,
                    ),
                    child: (_imageBytes == null && (_existingImageUrl == null || _existingImageUrl!.isEmpty))
                        ? const Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.add_photo_alternate, size: 36, color: Colors.grey),
                              SizedBox(height: 6),
                              Text('사진 추가 (선택)', style: TextStyle(color: Colors.grey)),
                            ]))
                        : null,
                  ),
                ),
                // 이미지 선택된 경우 제거 버튼
                if (_imageBytes != null || (_existingImageUrl != null && _existingImageUrl!.isNotEmpty))
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
