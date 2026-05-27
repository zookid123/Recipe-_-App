import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'community_post_create_screen.dart';
import 'chat_screen.dart';
import '../widgets/comment_section.dart';
import 'user_profile_screen.dart';

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
  bool _isLiked = false;
  int _likeCount = 0;
  int _viewCount = 0;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post['likeCount'] ?? 0;
    _viewCount = widget.post['viewCount'] ?? 0;
    _incrementViewCount();
    _loadLikeStatus();
  }

  Future<void> _incrementViewCount() async {
    await FirebaseFirestore.instance
        .collection('community').doc(widget.docId)
        .update({'viewCount': FieldValue.increment(1)});
    if (mounted) setState(() => _viewCount++);
  }

  Future<void> _loadLikeStatus() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.id)
        .collection('communityLikes').doc(widget.docId)
        .get();
    if (mounted) setState(() => _isLiked = doc.exists);
  }

  Future<void> _toggleLike() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 좋아요를 누를 수 있어요.')),
      );
      return;
    }
    final newVal = !_isLiked;
    setState(() { _isLiked = newVal; _likeCount += newVal ? 1 : -1; });
    try {
      final likeRef = FirebaseFirestore.instance
          .collection('users').doc(user.id)
          .collection('communityLikes').doc(widget.docId);
      if (newVal) {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
      } else {
        await likeRef.delete();
      }
      await FirebaseFirestore.instance
          .collection('community').doc(widget.docId)
          .update({'likeCount': FieldValue.increment(newVal ? 1 : -1)});
    } catch (e) {
      if (mounted) setState(() { _isLiked = !newVal; _likeCount += newVal ? -1 : 1; });
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
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseFirestore.instance
          .collection('community').doc(widget.docId).delete();
      if (mounted) Navigator.pop(context);
    }
  }

  void _startChat() {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final authorId = widget.post['authorId'];
    if (authorId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          targetUserId: authorId,
          targetNickname: widget.post['authorName'] ?? '익명',
          contextTitle: widget.post['title'] ?? '',
          contextImageUrl: widget.post['imgUrl'],
          contextId: widget.docId,
          contextType: 'community',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isPostAuthor = user != null && user.id == widget.post['authorId'];
    final hasImg = (widget.post['imgUrl'] ?? '').toString().isNotEmpty;
    final category = widget.post['category'] ?? '자유';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (isPostAuthor)
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
      body: SingleChildScrollView(
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _categoryColor(category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(category,
                        style: TextStyle(fontSize: 12, color: _categoryColor(category), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.post['title'] ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    GestureDetector(
                      onTap: () {
                        if (widget.post['authorId'] != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                userId: widget.post['authorId'],
                                nickname: widget.post['authorName'],
                                profileImageUrl: widget.post['authorProfileImg'],
                              ),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: (widget.post['authorProfileImg'] != null && widget.post['authorProfileImg'].toString().isNotEmpty)
                                ? NetworkImage(widget.post['authorProfileImg'])
                                : null,
                            child: (widget.post['authorProfileImg'] == null || widget.post['authorProfileImg'].toString().isEmpty)
                                ? const Icon(Icons.person, size: 14, color: Colors.grey)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Text(widget.post['authorName'] ?? '익명',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (user != null && !isPostAuthor) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _startChat,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('1:1 채팅', 
                            style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
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
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  // 좋아요 / 조회수
                  Row(children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isLiked ? Colors.red.withOpacity(0.1) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _isLiked ? Colors.red : Colors.grey.shade300),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 16, color: _isLiked ? Colors.red : Colors.grey),
                          const SizedBox(width: 5),
                          Text('$_likeCount',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _isLiked ? Colors.red : Colors.grey,
                                  fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.visibility_outlined, size: 15, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('$_viewCount',
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 댓글 섹션 (공통 위젯 사용)
            const Text('댓글',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            CommentSection(
              docId: widget.docId,
              collectionPath: 'community/${widget.docId}/comments',
              postAuthorId: widget.post['authorId'] ?? '',
              postTitle: widget.post['title'] ?? '',
              type: 'community',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Color _categoryColor(String cat) {    switch (cat) {
      case 'Q&A': return Colors.blue;
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
