import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'community_post_create_screen.dart';

class CommunityPostDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> post;
  const CommunityPostDetailScreen(
      {super.key, required this.docId, required this.post});

  @override
  State<CommunityPostDetailScreen> createState() =>
      _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState
    extends State<CommunityPostDetailScreen> {
  final _commentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final user = AuthService.instance.currentUser;
    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance
          .collection('community').doc(widget.docId)
          .collection('comments').add({
        'text': text,
        'authorId': user?.id,
        'authorName': user?.nickname ?? '익명',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('community').doc(widget.docId)
          .update({'commentCount': FieldValue.increment(1)});
      _commentCtrl.clear();

      // 로그인 유저 활동 내역 미러
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users').doc(user.id)
            .collection('myCommunityPosts').doc(widget.docId)
            .set({
          'postId': widget.docId,
          'title': widget.post['title'] ?? '',
          'lastActivityAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deletePost() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance.collection('community').doc(widget.docId).delete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isAuthor = user != null && user.id == widget.post['authorId'];
    final hasImg = (widget.post['imgUrl'] ?? '').toString().isNotEmpty;
    final category = widget.post['category'] ?? '자유';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(category,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (isAuthor)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CommunityPostCreateScreen(
                      existingPost: widget.post, docId: widget.docId),
                  ));
                } else if (val == 'delete') {
                  _deletePost();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('수정')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('삭제', style: TextStyle(color: Colors.red))),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 게시글 본문
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 카테고리 뱃지
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _categoryColor(category).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(category,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _categoryColor(category),
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 12),
                        Text(widget.post['title'] ?? '',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(widget.post['authorName'] ?? '익명',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 12),
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(_formatDate(widget.post['timestamp']),
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ]),
                        const SizedBox(height: 16),
                        if (hasImg) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(widget.post['imgUrl'],
                                width: double.infinity, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(widget.post['content'] ?? '',
                            style: const TextStyle(fontSize: 14, height: 1.6)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 댓글 목록
                  const Text('댓글',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('community').doc(widget.docId)
                        .collection('comments')
                        .orderBy('createdAt', descending: false)
                        .snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const SizedBox();
                      final comments = snap.data!.docs;
                      if (comments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Text('첫 댓글을 남겨보세요!',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        );
                      }
                      return Column(
                        children: comments.map((doc) {
                          final c = doc.data() as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.person, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(c['authorName'] ?? '익명',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  Text(_formatDate(c['createdAt']),
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                ]),
                                const SizedBox(height: 6),
                                Text(c['text'] ?? '',
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          // 댓글 입력창
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, -2))],
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: InputDecoration(
                    hintText: user != null ? '댓글을 입력하세요' : '로그인 후 댓글 작성 가능',
                    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  enabled: user != null,
                ),
              ),
              const SizedBox(width: 8),
              _submitting
                  ? const SizedBox(width: 36, height: 36,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                  : IconButton(
                      onPressed: user != null ? _submitComment : null,
                      icon: const Icon(Icons.send),
                      color: Colors.orange,
                    ),
            ]),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Q&A': return Colors.blue;
      case '나눔': return Colors.green;
      default: return Colors.orange;
    }
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inHours < 1) return '${diff.inMinutes}분 전';
      if (diff.inDays < 1) return '${diff.inHours}시간 전';
      return '${dt.month}/${dt.day}';
    }
    return '';
  }
}
