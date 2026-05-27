import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// 내 레시피/게시글에 새 댓글이 달리면 알림함에 저장하는 감지 서비스.
/// 앱 실행 중 새로 작성한 글도 자동으로 감지에 포함됨.
class CommentWatcher {
  CommentWatcher._();
  static final CommentWatcher instance = CommentWatcher._();

  final List<StreamSubscription> _subs = [];

  void start() {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    stop();
    _watchRecipeComments(user.id);
    _watchCommunityComments(user.id);
  }

  void stop() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }

  // ── 내 레시피의 새 댓글 감지 ─────────────────────────────
  // 레시피 컬렉션을 스트림으로 구독 → 새 레시피 추가 시 자동으로 댓글 감지 추가
  void _watchRecipeComments(String userId) {
    final watching = <String>{};

    final recipeSub = FirebaseFirestore.instance
        .collection('recipes')
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final recipeId = change.doc.id;
        if (watching.contains(recipeId)) continue;
        watching.add(recipeId);

        final recipeName = (change.doc.data()?['name'] as String?) ?? '';
        var isFirst = true;

        final commentSub = FirebaseFirestore.instance
            .collection('recipes')
            .doc(recipeId)
            .collection('comments')
            .snapshots()
            .listen((commentSnap) {
          if (isFirst) {
            isFirst = false;
            return;
          }
          for (final c in commentSnap.docChanges) {
            if (c.type != DocumentChangeType.added) continue;
            final data = c.doc.data();
            if (data == null || data['userId'] == userId) continue;
            _save(
              userId: userId,
              type: 'recipe_comment',
              title: '새 댓글이 달렸어요 💬',
              body: '${data['author'] ?? '누군가'}님이 "$recipeName"에 댓글을 남겼어요.',
              targetId: recipeId,
            );
          }
        });
        _subs.add(commentSub);
      }
    });
    _subs.add(recipeSub);
  }

  // ── 내 커뮤니티 글의 새 댓글 감지 ──────────────────────────
  void _watchCommunityComments(String userId) {
    final watching = <String>{};

    final postSub = FirebaseFirestore.instance
        .collection('community')
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final postId = change.doc.id;
        if (watching.contains(postId)) continue;
        watching.add(postId);

        final postTitle = (change.doc.data()?['title'] as String?) ?? '';
        var isFirst = true;

        final commentSub = FirebaseFirestore.instance
            .collection('community')
            .doc(postId)
            .collection('comments')
            .snapshots()
            .listen((commentSnap) {
          if (isFirst) {
            isFirst = false;
            return;
          }
          for (final c in commentSnap.docChanges) {
            if (c.type != DocumentChangeType.added) continue;
            final data = c.doc.data();
            if (data == null || data['authorId'] == userId) continue;
            _save(
              userId: userId,
              type: 'community_comment',
              title: '내 게시글에 댓글이 달렸어요 💬',
              body: '${data['authorName'] ?? '누군가'}님이 "$postTitle"에 댓글을 남겼어요.',
              targetId: postId,
            );
          }
        });
        _subs.add(commentSub);
      }
    });
    _subs.add(postSub);
  }

  // ── 알림 저장 ────────────────────────────────────────────
  Future<void> _save({
    required String userId,
    required String type,
    required String title,
    required String body,
    required String targetId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': type,
        'title': title,
        'body': body,
        'isRead': false,
        'targetId': targetId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
