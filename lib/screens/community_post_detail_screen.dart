import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'community_post_create_screen.dart';
import 'user_profile_screen.dart';
import 'chat_screen.dart';

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

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _startChat() {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 채팅할 수 있어요.')),
      );
      return;
    }
    if (user.id == widget.post['authorId']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자신과는 채팅할 수 없어요.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          targetUserId: widget.post['authorId'],
          targetNickname: widget.post['authorName'] ?? '익명',
          targetProfileImg: widget.post['authorProfileImg'],
          contextId: widget.docId,
          contextTitle: widget.post['title'] ?? '게시글',
        ),
      ),
    );
  }

  Future<void> _incrementViewCount() async {
    try {
      await FirebaseFirestore.instance
          .collection('community').doc(widget.docId)
          .update({'viewCount': FieldValue.increment(1)});
      if (mounted) setState(() => _viewCount++);
    } catch (_) {}
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

      // 좋아요 알림 — 작성자에게, 본인 제외
      if (newVal) {
        final postAuthorId = widget.post['authorId'] as String?;
        if (postAuthorId != null && postAuthorId != user.id) {
          () async {
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(postAuthorId)
                  .collection('notifications')
                  .add({
                'type': 'community_like',
                'title': '내 게시글에 좋아요가 달렸어요 ❤️',
                'body':
                    '${user.nickname}님이 "${widget.post['title'] ?? '내 게시글'}"을 좋아합니다.',
                'isRead': false,
                'targetId': widget.docId,
                'createdAt': FieldValue.serverTimestamp(),
              });
            } catch (_) {}
          }();
        }
      }
    } catch (e) {
      if (mounted) setState(() { _isLiked = !newVal; _likeCount += newVal ? -1 : 1; });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final user = AuthService.instance.currentUser;
    setState(() => _submitting = true);
    try {
      final ref = await FirebaseFirestore.instance
          .collection('community').doc(widget.docId)
          .collection('comments').add({
        'text': text,
        'authorId': user?.id,
        'authorName': user?.nickname ?? '익명',
        'authorProfileImg': user?.profileImageUrl,
        'authorTitle': user?.selectedTitle,
        'likeCount': 0,
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
            .collection('myCommunityComments').doc(ref.id)
            .set({
          'commentId': ref.id,
          'postId': widget.docId,
          'postTitle': widget.post['title'] ?? '',
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }

    // 알림은 CommentWatcher가 자동으로 감지해서 처리
  }

  Future<void> _deleteComment(String commentId, String? commentAuthorId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await FirebaseFirestore.instance
        .collection('community').doc(widget.docId)
        .collection('comments').doc(commentId).delete();
    await FirebaseFirestore.instance
        .collection('community').doc(widget.docId)
        .update({'commentCount': FieldValue.increment(-1)});

    // 작성자 활동 내역에서도 삭제
    if (commentAuthorId != null) {
      await FirebaseFirestore.instance
          .collection('users').doc(commentAuthorId)
          .collection('myCommunityComments').doc(commentId)
          .delete();
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
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            final authorId = widget.post['authorId'] as String?;
                            if (authorId != null && authorId.isNotEmpty) {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => UserProfileScreen(userId: authorId),
                              ));
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8F0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                            ),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: const Color(0xFFFFE0B2),
                                backgroundImage: (widget.post['authorProfileImg'] as String?)?.isNotEmpty == true
                                    ? NetworkImage(widget.post['authorProfileImg'] as String)
                                    : null,
                                child: (widget.post['authorProfileImg'] as String?)?.isNotEmpty == true
                                    ? null
                                    : const Icon(Icons.person, size: 22, color: Colors.orange),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Text(
                                        widget.post['authorName'] ?? '익명',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87),
                                      ),
                                      if ((widget.post['authorTitle'] as String?) != null) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.amber.shade300, width: 0.5),
                                          ),
                                          child: Text(
                                            widget.post['authorTitle'] as String,
                                            style: TextStyle(fontSize: 9, color: Colors.amber.shade700, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('작성자',
                                            style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ]),
                                    const SizedBox(height: 3),
                                    Text(
                                      _formatDate(widget.post['timestamp']),
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 20, color: Colors.orange),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 채팅하기 버튼 추가
                        if (user != null && user.id != widget.post['authorId'])
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _startChat,
                              icon: const Icon(Icons.chat_bubble_outline, size: 16),
                              label: const Text('작성자와 채팅하기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(color: Colors.orange),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
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
                          final canDelete = user != null &&
                              (c['authorId'] == user.id || isPostAuthor);
                          final canEdit = user != null && c['authorId'] == user.id;
                          return _CommentCard(
                            commentId: doc.id,
                            postId: widget.docId,
                            postAuthorId: widget.post['authorId'] as String?,
                            data: c,
                            canDelete: canDelete,
                            canEdit: canEdit,
                            onDelete: () => _deleteComment(doc.id, c['authorId']),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

// ── 댓글 카드 (좋아요 + 답글 + 삭제) ──────────────────
class _CommentCard extends StatefulWidget {
  final String commentId;
  final String postId;
  final String? postAuthorId;
  final Map<String, dynamic> data;
  final bool canDelete;
  final bool canEdit;
  final VoidCallback onDelete;

  const _CommentCard({
    required this.commentId,
    required this.postId,
    this.postAuthorId,
    required this.data,
    required this.canDelete,
    required this.canEdit,
    required this.onDelete,
  });

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _showReplyInput = false;
  bool _showReplies = false;
  bool _submittingReply = false;
  final _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _likeCount = widget.data['likeCount'] ?? 0;
    _loadLikeStatus();
    AuthService.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    _replyCtrl.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLikeStatus() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.id)
        .collection('commentLikes').doc(widget.commentId)
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
          .collection('commentLikes').doc(widget.commentId);
      if (newVal) {
        await likeRef.set({'likedAt': FieldValue.serverTimestamp()});
      } else {
        await likeRef.delete();
      }
      await FirebaseFirestore.instance
          .collection('community').doc(widget.postId)
          .collection('comments').doc(widget.commentId)
          .update({'likeCount': FieldValue.increment(newVal ? 1 : -1)});
    } catch (e) {
      if (mounted) setState(() { _isLiked = !newVal; _likeCount += newVal ? -1 : 1; });
    }
  }

  Future<void> _editComment() async {
    final ctrl = TextEditingController(text: widget.data['text'] ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('댓글 수정'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '댓글을 수정하세요',
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('저장', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
    ctrl.dispose();
    if (saved == null || saved.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('community').doc(widget.postId)
        .collection('comments').doc(widget.commentId)
        .update({'text': saved});
  }

  Future<void> _submitReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    final user = AuthService.instance.currentUser;
    setState(() => _submittingReply = true);
    try {
      await FirebaseFirestore.instance
          .collection('community').doc(widget.postId)
          .collection('comments').doc(widget.commentId)
          .collection('replies').add({
        'text': text,
        'authorId': user?.id,
        'authorName': user?.nickname ?? '익명',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('community').doc(widget.postId)
          .collection('comments').doc(widget.commentId)
          .update({'replyCount': FieldValue.increment(1)});

      // 댓글 작성자에게 답글 알림 (본인 제외)
      final commentAuthorId = widget.data['authorId'] as String?;
      if (commentAuthorId != null && commentAuthorId != user?.id) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(commentAuthorId)
            .collection('notifications')
            .add({
          'type': 'community_reply',
          'title': '내 댓글에 답글이 달렸어요 💬',
          'body': '${user?.nickname ?? '누군가'}님이 회원님의 댓글에 답글을 남겼어요.',
          'isRead': false,
          'targetId': widget.postId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _replyCtrl.clear();
      if (mounted) setState(() { _showReplyInput = false; _showReplies = true; });
    } finally {
      if (mounted) setState(() => _submittingReply = false);
    }
  }

  Future<void> _deleteReply(String replyId) async {
    await FirebaseFirestore.instance
        .collection('community').doc(widget.postId)
        .collection('comments').doc(widget.commentId)
        .collection('replies').doc(replyId).delete();
    await FirebaseFirestore.instance
        .collection('community').doc(widget.postId)
        .collection('comments').doc(widget.commentId)
        .update({'replyCount': FieldValue.increment(-1)});
  }

  Future<void> _editReply(String replyId, String currentText) async {
    final ctrl = TextEditingController(text: currentText);
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('답글 수정'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: '답글을 수정하세요',
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('저장', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
    ctrl.dispose();
    if (saved == null || saved.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('community').doc(widget.postId)
        .collection('comments').doc(widget.commentId)
        .collection('replies').doc(replyId)
        .update({'text': saved});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.data;
    final user = AuthService.instance.currentUser;
    final replyCount = c['replyCount'] ?? 0;

    final authorId = c['authorId'] as String?;
    void goToProfile() {
      if (authorId != null && authorId.isNotEmpty) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => UserProfileScreen(userId: authorId)));
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 6)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 아바타 ─────────────────────────────────────
          GestureDetector(
            onTap: goToProfile,
            child: CircleAvatar(
              radius: 15,
              backgroundColor: const Color(0xFFFFE0B2),
              backgroundImage: (c['authorProfileImg'] as String?)?.isNotEmpty == true
                  ? NetworkImage(c['authorProfileImg'] as String)
                  : null,
              child: (c['authorProfileImg'] as String?)?.isNotEmpty == true
                  ? null
                  : const Icon(Icons.person, size: 15, color: Colors.orange),
            ),
          ),
          const SizedBox(width: 10),
          // ── 오른쪽 콘텐츠 ──────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 닉네임 + 시간 + 수정/삭제
                Row(children: [
                  GestureDetector(
                    onTap: goToProfile,
                    child: Text(c['authorName'] ?? '익명',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ),
                  if ((c['authorTitle'] as String?) != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.shade300, width: 0.5),
                      ),
                      child: Text(
                        c['authorTitle'] as String,
                        style: TextStyle(fontSize: 9, color: Colors.amber.shade700, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  if (authorId != null &&
                      authorId.isNotEmpty &&
                      authorId == widget.postAuthorId) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('작성자',
                          style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const Spacer(),
                  Text(_formatDate(c['createdAt']),
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  if (widget.canEdit) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _editComment,
                      child: const Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
                    ),
                  ],
                  if (widget.canDelete) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: widget.onDelete,
                      child: const Icon(Icons.delete_outline, size: 14, color: Colors.grey),
                    ),
                  ],
                ]),
                const SizedBox(height: 6),
                // 댓글 본문
                Text(c['text'] ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
                const SizedBox(height: 8),
                // 좋아요 + 답글 버튼
                Row(children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 14, color: _isLiked ? Colors.red : Colors.grey),
                      const SizedBox(width: 3),
                      Text('$_likeCount',
                          style: TextStyle(fontSize: 12,
                              color: _isLiked ? Colors.red : Colors.grey)),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  if (user != null)
                    GestureDetector(
                      onTap: () => setState(() => _showReplyInput = !_showReplyInput),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.reply, size: 14,
                            color: _showReplyInput ? Colors.orange : Colors.grey),
                        const SizedBox(width: 3),
                        Text('답글',
                            style: TextStyle(fontSize: 12,
                                color: _showReplyInput ? Colors.orange : Colors.grey)),
                      ]),
                    ),
                  if (replyCount > 0) ...[
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () => setState(() => _showReplies = !_showReplies),
                      child: Text(
                        _showReplies ? '답글 숨기기' : '답글 $replyCount개 보기',
                        style: const TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ]),
                // 답글 입력창
                if (_showReplyInput) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _replyCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: '답글을 입력하세요',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _submittingReply
                        ? const SizedBox(width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                        : IconButton(
                            onPressed: _submitReply,
                            icon: const Icon(Icons.send, size: 18),
                            color: Colors.orange,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                  ]),
                ],
                // 답글 목록
                if (_showReplies)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('community').doc(widget.postId)
                        .collection('comments').doc(widget.commentId)
                        .collection('replies')
                        .orderBy('createdAt')
                        .snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const SizedBox();
                      return Column(
                        children: snap.data!.docs.map((doc) {
                          final r = doc.data() as Map<String, dynamic>;
                          final canDelete = user != null &&
                              (r['authorId'] == user.id || widget.canDelete);
                          final canEdit = user != null && r['authorId'] == user.id;
                          return _ReplyCard(
                            data: r,
                            canDelete: canDelete,
                            canEdit: canEdit,
                            onDelete: () => _deleteReply(doc.id),
                            onEdit: () => _editReply(doc.id, r['text'] ?? ''),
                          );
                        }).toList(),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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

// ── 답글 카드 ────────────────────────────────────────
class _ReplyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool canDelete;
  final bool canEdit;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ReplyCard({
    required this.data,
    required this.canDelete,
    required this.canEdit,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 16),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
            left: BorderSide(color: Colors.orange, width: 2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.subdirectory_arrow_right,
              size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(data['authorName'] ?? '익명',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(_formatDate(data['createdAt']),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  if (canEdit) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onEdit,
                      child: const Icon(Icons.edit_outlined,
                          size: 14, color: Colors.grey),
                    ),
                  ],
                  if (canDelete) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline,
                          size: 14, color: Colors.grey),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text(data['text'] ?? '',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
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
