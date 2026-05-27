import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../screens/user_profile_screen.dart';

/// 공통 댓글 위젯 (커뮤니티, 레시피 상세용)
/// 계층형 댓글(대댓글)과 작성자 배지 기능을 포함합니다.
class CommentSection extends StatefulWidget {
  final String docId;
  final String collectionPath; // e.g. 'community/docId/comments'
  final String postAuthorId;
  final String postTitle;
  final String type; // 'community' | 'recipe'
  final bool showRating;

  const CommentSection({
    super.key,
    required this.docId,
    required this.collectionPath,
    required this.postAuthorId,
    required this.postTitle,
    required this.type,
    this.showRating = false,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final _commentCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _isAnonymous = false;
  int _selectedRating = 0;
  String? _replyingToId; // 대댓글 작성 시 부모 댓글 ID
  String? _replyingToName;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final user = AuthService.instance.currentUser;
    setState(() => _isSubmitting = true);

    try {
      final authorName = _isAnonymous ? '익명' : (user?.nickname ?? '익명');
      final authorId = _isAnonymous ? null : user?.id;

      final commentData = {
        'text': text,
        'authorName': authorName,
        'authorId': authorId,
        'parentId': _replyingToId, // 대댓글인 경우 부모 ID 저장
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
      };

      if (widget.showRating && _replyingToId == null) {
        commentData['rating'] = _selectedRating > 0 ? _selectedRating : null;
      }

      final ref = await FirebaseFirestore.instance
          .collection(widget.collectionPath)
          .add(commentData);

      // 전체 카운트 업데이트
      await FirebaseFirestore.instance.doc(widget.collectionPath.replaceAll('/comments', '')).update({
        'commentCount': FieldValue.increment(1),
      });

      // 내 활동 내역 미러 저장
      if (authorId != null) {
        final mirrorPath = widget.type == 'community' ? 'myCommunityComments' : 'myComments';
        final Map<String, dynamic> mirrorData = {
          'commentId': ref.id,
          'postId': widget.docId,
          'postTitle': widget.postTitle,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        };
        if (widget.showRating) mirrorData['rating'] = commentData['rating'];
        if (widget.type == 'recipe') mirrorData['recipeId'] = widget.docId;
        if (widget.type == 'recipe') mirrorData['recipeName'] = widget.postTitle;

        await FirebaseFirestore.instance
            .collection('users').doc(authorId)
            .collection(mirrorPath).doc(ref.id)
            .set(mirrorData);
      }

      _commentCtrl.clear();
      setState(() {
        _selectedRating = 0;
        _replyingToId = null;
        _replyingToName = null;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

    await FirebaseFirestore.instance.collection(widget.collectionPath).doc(commentId).delete();
    
    // 카운트 감소
    await FirebaseFirestore.instance.doc(widget.collectionPath.replaceAll('/comments', '')).update({
      'commentCount': FieldValue.increment(-1),
    });

    if (commentAuthorId != null) {
      final mirrorPath = widget.type == 'community' ? 'myCommunityComments' : 'myComments';
      await FirebaseFirestore.instance
          .collection('users').doc(commentAuthorId)
          .collection(mirrorPath).doc(commentId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 댓글 목록
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(widget.collectionPath)
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            final allDocs = snapshot.data!.docs;
            
            // 대댓글 구조로 재구성
            final mainComments = allDocs.where((d) => (d.data() as Map)['parentId'] == null).toList();
            final replies = allDocs.where((d) => (d.data() as Map)['parentId'] != null).toList();

            if (mainComments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('첫 댓글을 남겨보세요!', style: TextStyle(color: Colors.grey))),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mainComments.length,
              itemBuilder: (context, index) {
                final commentDoc = mainComments[index];
                final commentData = commentDoc.data() as Map<String, dynamic>;
                final commentId = commentDoc.id;
                
                final commentReplies = replies.where((r) => (r.data() as Map)['parentId'] == commentId).toList();

                return Column(
                  children: [
                    _buildCommentTile(commentId, commentData, isReply: false),
                    ...commentReplies.map((r) => _buildCommentTile(r.id, r.data() as Map<String, dynamic>, isReply: true)),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        // 댓글 입력창
        _buildInputArea(user),
      ],
    );
  }

  Widget _buildCommentTile(String commentId, Map<String, dynamic> data, {required bool isReply}) {
    final user = AuthService.instance.currentUser;
    final isPostAuthor = data['authorId'] == widget.postAuthorId;
    final canDelete = user != null && (data['authorId'] == user.id || widget.postAuthorId == user.id);
    final ts = data['createdAt'] as Timestamp?;
    final rating = data['rating'] as int?;

    return Container(
      margin: EdgeInsets.only(bottom: 8, left: isReply ? 32 : 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReply ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isReply ? Colors.grey[200]! : Colors.transparent),
        boxShadow: isReply ? null : const [BoxShadow(color: Color(0x05000000), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isReply) ...[
                Icon(
                  Icons.subdirectory_arrow_right,
                  size: 16,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 4),
              ],
              GestureDetector(
                onTap: () {
                  if (data['authorId'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          userId: data['authorId'],
                          nickname: data['authorName'],
                          profileImageUrl: data['authorProfileImg'],
                        ),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (data['authorProfileImg'] != null && data['authorProfileImg'].toString().isNotEmpty)
                          ? NetworkImage(data['authorProfileImg'])
                          : null,
                      child: (data['authorProfileImg'] == null || data['authorProfileImg'].toString().isEmpty)
                          ? const Icon(Icons.person, size: 12, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Text(data['authorName'] ?? '익명',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (isPostAuthor) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('작성자', style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                ),
              ],
              const Spacer(),
              if (ts != null)
                Text(_formatDate(ts.toDate()), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              if (canDelete) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _deleteComment(commentId, data['authorId']),
                  child: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                ),
              ],
            ],
          ),
          if (rating != null && rating > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: List.generate(5, (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 14, color: Colors.amber,
              )),
            ),
          ],
          const SizedBox(height: 6),
          Text(data['text'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            children: [
              _LikeButton(
                collectionPath: widget.collectionPath,
                commentId: commentId,
                initialCount: data['likeCount'] ?? 0,
              ),
              if (!isReply && user != null) ...[
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => setState(() {
                    _replyingToId = commentId;
                    _replyingToName = data['authorName'];
                  }),
                  child: const Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('답글 쓰기', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(AppUser? user) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withOpacity(0.05),
              child: Row(
                children: [
                  Text('$_replyingToName님에게 답글 남기는 중', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() { _replyingToId = null; _replyingToName = null; }),
                    child: const Icon(Icons.close, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, -2))],
            ),
            child: Column(
              children: [
                if (widget.showRating && _replyingToId == null) ...[
                  Row(
                    children: [
                      const Text('별점', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(width: 8),
                      ...List.generate(5, (i) => GestureDetector(
                        onTap: () => setState(() => _selectedRating = i + 1),
                        child: Icon(i < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 24),
                      )),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        decoration: InputDecoration(
                          hintText: user != null ? '댓글을 입력하세요...' : '로그인 후 작성 가능',
                          filled: true,
                          fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        enabled: user != null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isSubmitting
                      ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                      : IconButton(
                          onPressed: user != null ? _submitComment : null,
                          icon: const Icon(Icons.send),
                          color: Colors.orange,
                        ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${dt.month}/${dt.day}';
  }
}

class _LikeButton extends StatefulWidget {
  final String collectionPath;
  final String commentId;
  final int initialCount;
  const _LikeButton({required this.collectionPath, required this.commentId, required this.initialCount});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  bool _isLiked = false;
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
    _checkStatus();
  }

  void _checkStatus() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.id).collection('commentLikes').doc(widget.commentId).get();
    if (mounted) setState(() => _isLiked = doc.exists);
  }

  void _toggle() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    final newVal = !_isLiked;
    setState(() { _isLiked = newVal; _count += newVal ? 1 : -1; });

    final userLikeRef = FirebaseFirestore.instance.collection('users').doc(user.id).collection('commentLikes').doc(widget.commentId);
    if (newVal) {
      await userLikeRef.set({'at': FieldValue.serverTimestamp()});
    } else {
      await userLikeRef.delete();
    }

    await FirebaseFirestore.instance.collection(widget.collectionPath).doc(widget.commentId).update({
      'likeCount': FieldValue.increment(newVal ? 1 : -1),
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Row(
        children: [
          Icon(_isLiked ? Icons.favorite : Icons.favorite_border, size: 14, color: _isLiked ? Colors.red : Colors.grey),
          const SizedBox(width: 4),
          Text('$_count', style: TextStyle(fontSize: 12, color: _isLiked ? Colors.red : Colors.grey)),
        ],
      ),
    );
  }
}
