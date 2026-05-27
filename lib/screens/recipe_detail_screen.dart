import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'recipe_create_screen.dart';
import 'user_profile_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  String? _docId;
  String? _recipeAuthorId;
  final _commentCtrl = TextEditingController();
  int _selectedRating = 0;
  bool _isSubmitting = false;
  bool _isBookmarked = false;
  bool _isUserLiked = false;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _initRecipe();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarkStatus() async {
    if (_docId == null) return;
    final user = AuthService.instance.currentUser;
    bool bookmarked = false;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('bookmarks')
          .doc(_docId)
          .get();
      bookmarked = doc.exists;
    } else {
      final prefs = await SharedPreferences.getInstance();
      bookmarked = (prefs.getStringList('liked_recipes') ?? []).contains(
        _docId,
      );
    }
    if (mounted) setState(() => _isBookmarked = bookmarked);
  }

  Future<void> _loadUserLikeStatus() async {
    if (_docId == null) return;
    final user = AuthService.instance.currentUser;
    bool liked = false;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('likes')
          .doc(_docId)
          .get();
      liked = doc.exists;
    } else {
      final prefs = await SharedPreferences.getInstance();
      liked = (prefs.getStringList('user_likes') ?? []).contains(_docId);
    }
    if (mounted) setState(() => _isUserLiked = liked);
  }

  Future<void> _toggleBookmark() async {
    if (_docId == null) return;
    final user = AuthService.instance.currentUser;
    final newVal = !_isBookmarked;
    setState(() => _isBookmarked = newVal);
    try {
      if (user != null) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('bookmarks')
            .doc(_docId);
        if (newVal) {
          await ref.set({
            'id': _docId,
            'name': widget.recipe['name'] ?? '',
            'imgUrl': widget.recipe['imgUrl'] ?? '',
            'nation': widget.recipe['nation'] ?? '',
            'savedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await ref.delete();
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList('liked_recipes') ?? [];
        if (newVal) {
          if (!list.contains(_docId!)) list.add(_docId!);
        } else {
          list.remove(_docId!);
        }
        await prefs.setStringList('liked_recipes', list);
      }
    } catch (e) {
      if (mounted) setState(() => _isBookmarked = !newVal);
    }
  }

  Future<void> _toggleUserLike() async {
    if (_docId == null) return;
    final user = AuthService.instance.currentUser;
    final newVal = !_isUserLiked;
    setState(() => _isUserLiked = newVal);
    try {
      if (user != null) {
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('likes')
            .doc(_docId);
        if (newVal) {
          await ref.set({
            'id': _docId,
            'likedAt': FieldValue.serverTimestamp(),
          });
        } else {
          await ref.delete();
        }
        // likeCount는 로그인 유저만 반영
        await FirebaseFirestore.instance
            .collection('recipes')
            .doc(_docId)
            .update({'likeCount': FieldValue.increment(newVal ? 1 : -1)});

        // 좋아요 알림 — 작성자에게, 본인 제외
        if (newVal && _recipeAuthorId != null && _recipeAuthorId != user.id) {
          () async {
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_recipeAuthorId)
                  .collection('notifications')
                  .add({
                'type': 'recipe_like',
                'title': '내 레시피에 좋아요가 달렸어요 ❤️',
                'body':
                    '${user.nickname}님이 "${widget.recipe['name'] ?? '내 레시피'}"를 좋아합니다.',
                'isRead': false,
                'targetId': _docId,
                'createdAt': FieldValue.serverTimestamp(),
              });
            } catch (_) {}
          }();
        }
      } else {
        // 비로그인: 기기 로컬에만 저장 (Firestore 미반영)
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList('user_likes') ?? [];
        if (newVal) {
          if (!list.contains(_docId!)) list.add(_docId!);
        } else {
          list.remove(_docId!);
        }
        await prefs.setStringList('user_likes', list);
      }
    } catch (e) {
      if (mounted) setState(() => _isUserLiked = !newVal);
    }
  }

  Future<void> _initRecipe() async {
    final recipeId = widget.recipe['id'] as String?;
    final recipeName = widget.recipe['name'];
    if (recipeId == null && recipeName == null) return;

    DocumentSnapshot<Map<String, dynamic>> docSnap;
    if (recipeId != null) {
      final snap = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(recipeId)
          .get();
      if (!snap.exists) return;
      docSnap = snap;
    } else {
      final query = await FirebaseFirestore.instance
          .collection('recipes')
          .where('name', isEqualTo: recipeName)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return;
      docSnap = query.docs.first;
    }

    final data = docSnap.data()!;
    if (mounted) {
      setState(() {
        _docId = docSnap.id;
        _recipeAuthorId = data['authorId'] as String?;
      });
    }

    _saveRecentRecipe(docSnap.id);
    _loadBookmarkStatus();
    _loadUserLikeStatus();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = data['todayDate'] ?? '';

    if (storedDate == today) {
      await docSnap.reference.update({
        'viewCount': FieldValue.increment(1),
        'todayViewCount': FieldValue.increment(1),
      });
    } else {
      await docSnap.reference.update({
        'viewCount': FieldValue.increment(1),
        'yesterdayViewCount': data['todayViewCount'] ?? 0,
        'todayViewCount': 1,
        'todayDate': today,
      });
    }

    // 인기 순위 진입 알림 (하루 1회)
    final lastNotifyDate = data['lastTrendingNotifyDate'] ?? '';
    if (lastNotifyDate != today && _recipeAuthorId != null) {
      final trendingSnap = await FirebaseFirestore.instance
          .collection('recipes')
          .orderBy('todayViewCount', descending: true)
          .limit(10)
          .get();
      final trendingIds = trendingSnap.docs.map((d) => d.id).toList();
      if (trendingIds.contains(docSnap.id)) {
        final rank = trendingIds.indexOf(docSnap.id) + 1;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_recipeAuthorId)
            .collection('notifications')
            .add({
          'type': 'trending',
          'title': '내 레시피가 인기 순위에 올랐어요! 🔥',
          'body':
              '"${data['name'] ?? '내 레시피'}"이 오늘 인기 순위 $rank위에 올랐어요!',
          'isRead': false,
          'targetId': docSnap.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await docSnap.reference.update({'lastTrendingNotifyDate': today});
      }
    }
  }

  // ── 최근 본 레시피 저장 ──────────────────────────
  Future<void> _saveRecentRecipe(String docId) async {
    final entry = {
      'id': docId,
      'name': widget.recipe['name'] ?? '',
      'imgUrl': widget.recipe['imgUrl'] ?? '',
      'nation': widget.recipe['nation'] ?? '',
      'viewedAt': DateTime.now().toIso8601String(),
    };

    final user = AuthService.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('recentRecipes')
          .doc(docId)
          .set(entry);

      // 20개 초과 시 가장 오래된 것 삭제
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('recentRecipes')
          .orderBy('viewedAt', descending: false)
          .get();
      if (snap.docs.length > 20) {
        for (final old in snap.docs.take(snap.docs.length - 20)) {
          await old.reference.delete();
        }
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('recent_recipes') ?? [];
      final list = raw
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
      list.removeWhere((e) => e['id'] == docId);
      list.insert(0, entry);
      if (list.length > 20) list.removeLast();
      await prefs.setStringList(
        'recent_recipes',
        list.map(jsonEncode).toList(),
      );
    }
  }

  // ── 레시피 수정 ─────────────────────────────────
  void _editRecipe() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RecipeCreateScreen(existingRecipe: widget.recipe, docId: _docId),
      ),
    );
  }

  // ── 레시피 삭제 ─────────────────────────────────
  Future<void> _deleteRecipe() async {
    if (_docId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('레시피 삭제'),
        content: const Text('정말로 이 레시피를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('recipes')
            .doc(_docId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('레시피가 삭제되었습니다.')));
          Navigator.pop(context); // 목록으로 돌아가기
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('삭제 중 오류 발생: $e')));
        }
      }
    }
  }

  Future<void> _deleteComment(String commentId, String? commentUserId) async {
    if (_docId == null) return;
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
        .collection('recipes').doc(_docId)
        .collection('comments').doc(commentId)
        .delete();

    // 댓글 작성자의 활동 내역에서도 삭제
    if (commentUserId != null) {
      await FirebaseFirestore.instance
          .collection('users').doc(commentUserId)
          .collection('myComments').doc(commentId)
          .delete();
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _docId == null) return;

    final user = AuthService.instance.currentUser;
    final author = (!_isAnonymous && user != null) ? user.nickname : '익명';

    setState(() => _isSubmitting = true);
    try {
      final commentRef = await FirebaseFirestore.instance
          .collection('recipes')
          .doc(_docId)
          .collection('comments')
          .add({
            'text': text,
            'author': author,
            'userId': (!_isAnonymous && user != null) ? user.id : null,
            'authorProfileImg': (!_isAnonymous && user != null)
                ? user.profileImageUrl
                : null,
            'rating': _selectedRating > 0 ? _selectedRating : null,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // 로그인 유저는 활동 내역용 미러 저장
      if (!_isAnonymous && user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .collection('myComments')
            .doc(commentRef.id)
            .set({
              'commentId': commentRef.id,
              'recipeId': _docId,
              'recipeName': widget.recipe['name'] ?? '',
              'text': text,
              'rating': _selectedRating > 0 ? _selectedRating : null,
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      _commentCtrl.clear();
      setState(() => _selectedRating = 0);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }

    // 알림은 CommentWatcher가 자동으로 감지해서 처리
  }

  @override
  Widget build(BuildContext context) {
    final List ingredients = widget.recipe['ingredients'] ?? [];
    final List steps = widget.recipe['steps'] ?? [];
    final hasImage =
        widget.recipe['imgUrl'] != null &&
        widget.recipe['imgUrl'].toString().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.recipe['name'] ?? '레시피 상세',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          // 본인 작성글 or 관리자 메뉴
          if (AuthService.instance.isLoggedIn &&
              (AuthService.instance.isAdmin ||
                  (widget.recipe['authorId'] != null &&
                      AuthService.instance.currentUser!.id ==
                          widget.recipe['authorId'])))
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  _editRecipe();
                } else if (val == 'delete') {
                  _deleteRecipe();
                }
              },
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              itemBuilder: (context) => [
                if (!AuthService.instance.isAdmin ||
                    widget.recipe['source'] == 'ugc')
                  const PopupMenuItem(value: 'edit', child: Text('수정하기')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    AuthService.instance.isAdmin ? '🗑️ 관리자 삭제' : '삭제하기',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          // 즐겨찾기
          IconButton(
            onPressed: _toggleBookmark,
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? Colors.orange : Colors.black87,
            ),
            tooltip: '즐겨찾기',
          ),
          // 좋아요
          IconButton(
            onPressed: _toggleUserLike,
            icon: Icon(
              _isUserLiked ? Icons.favorite : Icons.favorite_border,
              color: _isUserLiked ? Colors.red : Colors.black87,
            ),
            tooltip: '좋아요',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return isWide
              ? _buildWideLayout(context, hasImage, ingredients, steps)
              : _buildNarrowLayout(context, hasImage, ingredients, steps);
        },
      ),
    );
  }

  // ── 좁은 화면 (기존 레이아웃) ──────────────────────────
  Widget _buildNarrowLayout(
    BuildContext context,
    bool hasImage,
    List ingredients,
    List steps,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._recipeContent(hasImage, ingredients, steps),
                _buildCommentsSection(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        _buildCommentInput(context),
      ],
    );
  }

  // ── 넓은 화면 (2컬럼 레이아웃) ────────────────────────
  Widget _buildWideLayout(
    BuildContext context,
    bool hasImage,
    List ingredients,
    List steps,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 왼쪽: 이미지 + 레시피 정보
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _recipeContent(hasImage, ingredients, steps),
            ),
          ),
        ),
        // 구분선
        Container(width: 1, color: const Color(0xFFEEEEEE)),
        // 오른쪽: 댓글
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildCommentsSection(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              _buildCommentInput(context),
            ],
          ),
        ),
      ],
    );
  }

  // ── 레시피 본문 (공통) ─────────────────────────────────
  List<Widget> _recipeContent(bool hasImage, List ingredients, List steps) {
    return [
      // 이미지
      hasImage
          ? Image.network(
              widget.recipe['imgUrl'],
              width: double.infinity,
              height: 260,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _placeholder(widget.recipe['name'] ?? ''),
            )
          : _placeholder(widget.recipe['name'] ?? ''),

      Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 태그 행
            Row(
              children: [
                _tag('${widget.recipe['nation']} · ${widget.recipe['type']}'),
                if (widget.recipe['source'] == 'ugc') ...[
                  const SizedBox(width: 8),
                  _tag(
                    '✍️ 유저 레시피',
                    bgColor: Colors.green.withOpacity(0.1),
                    textColor: Colors.green,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              widget.recipe['name'] ?? '',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
            // 작성자 표시 (UGC 레시피에만) - 좀 더 세련되게 수정
            if (widget.recipe['source'] == 'ugc' &&
                (widget.recipe['authorName'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  final authorId = widget.recipe['authorId'] as String?;
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
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFFFFE0B2),
                        backgroundImage: (widget.recipe['authorProfileImg'] as String?)?.isNotEmpty == true
                            ? NetworkImage(widget.recipe['authorProfileImg'] as String)
                            : null,
                        child: (widget.recipe['authorProfileImg'] as String?)?.isNotEmpty == true
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
                                widget.recipe['authorName'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
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
                            const Text(
                              '레시피 작성자 · 프로필 보기',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 20, color: Colors.orange),
                    ],
                  ),
                ),
              ),
            ],
            if ((widget.recipe['summary'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                widget.recipe['summary'],
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 24),
            // 메타 정보 카드
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _metaCol(
                    Icons.local_fire_department,
                    '칼로리',
                    widget.recipe['calorie'] ?? '-',
                  ),
                  _vDivider(),
                  _metaCol(
                    Icons.access_time,
                    '시간',
                    widget.recipe['time'] ?? '-',
                  ),
                  _vDivider(),
                  _metaCol(Icons.people, '분량', widget.recipe['qnt'] ?? '-'),
                  _vDivider(),
                  _metaCol(
                    Icons.trending_up,
                    '난이도',
                    widget.recipe['level'] ?? '-',
                  ),
                  _vDivider(),
                  _metaCol(
                    Icons.favorite,
                    '좋아요',
                    '${widget.recipe['likeCount'] ?? 0}',
                    iconColor: Colors.red,
                  ),
                  _vDivider(),
                  _metaCol(
                    Icons.visibility_outlined,
                    '조회수',
                    '${widget.recipe['viewCount'] ?? 0}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // 재료
      _sectionDivider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🛒 필요 재료',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            ingredients.isEmpty
                ? const Text(
                    '재료 정보가 없습니다.',
                    style: TextStyle(color: Colors.grey),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ingredients.map((i) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8F0),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          i.toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
      ),

      // 조리 순서
      _sectionDivider(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '👨‍🍳 조리 순서',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...steps.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.orange,
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              e.value.toString(),
                              style: const TextStyle(fontSize: 15, height: 1.6),
                            ),
                          ),
                          if (widget.recipe['stepImages'] != null &&
                              (widget.recipe['stepImages'] as List).length >
                                  e.key &&
                              (widget.recipe['stepImages'][e.key] ?? '')
                                  .toString()
                                  .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  widget.recipe['stepImages'][e.key],
                                  width: double.infinity,
                                  height: 180,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      _sectionDivider(),
    ];
  }

  // ── 댓글 목록 ───────────────────────────────────
  Widget _buildCommentsSection() {
    if (_docId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    final commentsStream = FirebaseFirestore.instance
        .collection('recipes')
        .doc(_docId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 댓글 수 + 평균 별점
          StreamBuilder<QuerySnapshot>(
            stream: commentsStream,
            builder: (context, snapshot) {
              final docs = snapshot.hasData
                  ? snapshot.data!.docs
                  : <QueryDocumentSnapshot>[];
              final count = docs.length;

              // 별점이 있는 댓글만 평균 계산
              final rated = docs.where((d) {
                final r = (d.data() as Map<String, dynamic>)['rating'];
                return r != null && r is int && r > 0;
              }).toList();
              final avgRating = rated.isEmpty
                  ? 0.0
                  : rated.fold<int>(
                          0,
                          (sum, d) =>
                              sum +
                              ((d.data() as Map<String, dynamic>)['rating']
                                  as int),
                        ) /
                        rated.length;

              return Row(
                children: [
                  const Text(
                    '💬 댓글',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (rated.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 18,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      ' (${rated.length}명)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // 댓글 목록
          StreamBuilder<QuerySnapshot>(
            stream: commentsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final comments = snapshot.data!.docs;

              if (comments.isEmpty) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 36,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '첫 댓글을 남겨보세요!',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, i) {
                  final data = comments[i].data() as Map<String, dynamic>;
                  final commentId = comments[i].id;
                  final commentUserId = data['userId'] as String?;
                  final currentUser = AuthService.instance.currentUser;

                  final canDelete = currentUser != null && (
                    commentUserId == currentUser.id ||
                    widget.recipe['authorId'] == currentUser.id
                  );
                  final canEdit = currentUser != null &&
                      commentUserId == currentUser.id;

                  return _RecipeCommentCard(
                    commentId: commentId,
                    recipeId: _docId!,
                    recipeAuthorId: _recipeAuthorId,
                    data: data,
                    canDelete: canDelete,
                    canEdit: canEdit,
                    onDelete: () => _deleteComment(commentId, commentUserId),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // ── 하단 고정 입력창 (별점 + 댓글) ──────────────────
  Widget _buildCommentInput(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 익명 토글 (로그인 상태일 때만 표시)
          if (AuthService.instance.isLoggedIn)
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _isAnonymous
                      ? '익명으로 작성'
                      : AuthService.instance.currentUser!.nickname,
                  style: TextStyle(
                    fontSize: 13,
                    color: _isAnonymous ? Colors.grey : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _isAnonymous = !_isAnonymous),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _isAnonymous
                          ? const Color(0xFFF0F0F0)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isAnonymous
                            ? Colors.grey.shade300
                            : Colors.orange.withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      _isAnonymous ? '닉네임으로 전환' : '익명으로 전환',
                      style: TextStyle(
                        fontSize: 11,
                        color: _isAnonymous ? Colors.grey : Colors.orange,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (AuthService.instance.isLoggedIn) const SizedBox(height: 8),

          // 별점 선택 행
          Row(
            children: [
              const Text(
                '별점',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(width: 10),
              ...List.generate(5, (i) {
                final starIdx = i + 1;
                return GestureDetector(
                  onTap: () => setState(
                    () => _selectedRating = _selectedRating == starIdx
                        ? 0
                        : starIdx,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      starIdx <= _selectedRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 28,
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              Text(
                _selectedRating == 0 ? '선택 안 함' : '$_selectedRating점',
                style: TextStyle(
                  fontSize: 12,
                  color: _selectedRating > 0 ? Colors.orange : Colors.grey,
                  fontWeight: _selectedRating > 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 댓글 입력 행
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: InputDecoration(
                    hintText: '댓글을 입력하세요...',
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _isSubmitting ? null : _submitComment,
                  child: const Padding(
                    padding: EdgeInsets.all(11),
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 공통 위젯 ─────────────────────────────────────
  Widget _tag(String label, {Color? bgColor, Color? textColor}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: bgColor ?? Colors.orange.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: (textColor ?? Colors.orange).withOpacity(0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: textColor ?? Colors.orange,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
  );

  Widget _metaCol(IconData icon, String label, String value, {Color? iconColor}) => SizedBox(
    width: 64,
    child: Column(
      children: [
        Icon(icon, color: iconColor ?? Colors.orange, size: 22),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  Widget _vDivider() =>
      Container(width: 1, height: 36, color: Colors.orange.withOpacity(0.15));

  Widget _sectionDivider() =>
      Container(height: 8, color: const Color(0xFFF5F5F5));

  Widget _placeholder(String name) => Container(
    width: double.infinity,
    height: 260,
    color: const Color(0xFFFFF8F0),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.restaurant, size: 64, color: Colors.orange),
        const SizedBox(height: 10),
        Text(
          name,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

}

// ── 레시피 댓글 카드 (좋아요 + 답글) ────────────────────
class _RecipeCommentCard extends StatefulWidget {
  final String commentId;
  final String recipeId;
  final String? recipeAuthorId;
  final Map<String, dynamic> data;
  final bool canDelete;
  final bool canEdit;
  final VoidCallback onDelete;

  const _RecipeCommentCard({
    required this.commentId,
    required this.recipeId,
    this.recipeAuthorId,
    required this.data,
    required this.canDelete,
    required this.canEdit,
    required this.onDelete,
  });

  @override
  State<_RecipeCommentCard> createState() => _RecipeCommentCardState();
}

class _RecipeCommentCardState extends State<_RecipeCommentCard> {
  bool _showReplyInput = false;
  bool _showReplies = false;
  bool _submittingReply = false;
  final _replyCtrl = TextEditingController();

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
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
        .collection('recipes').doc(widget.recipeId)
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
          .collection('recipes').doc(widget.recipeId)
          .collection('comments').doc(widget.commentId)
          .collection('replies').add({
        'text': text,
        'authorId': user?.id,
        'authorName': user?.nickname ?? '익명',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance
          .collection('recipes').doc(widget.recipeId)
          .collection('comments').doc(widget.commentId)
          .update({'replyCount': FieldValue.increment(1)});

      _replyCtrl.clear();
      if (mounted) setState(() { _showReplyInput = false; _showReplies = true; });
    } finally {
      if (mounted) setState(() => _submittingReply = false);
    }

    // 답글 알림 (댓글 저장과 별도 처리)
    _sendReplyNotification(user);
  }

  Future<void> _sendReplyNotification(dynamic user) async {
    final commentAuthorId = widget.data['userId'] as String?;
    if (commentAuthorId == null) return;
    if (commentAuthorId == user?.id) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(commentAuthorId)
          .collection('notifications')
          .add({
        'type': 'recipe_reply',
        'title': '내 댓글에 답글이 달렸어요 💬',
        'body': '${user?.nickname ?? '누군가'}님이 회원님의 댓글에 답글을 남겼어요.',
        'isRead': false,
        'targetId': widget.recipeId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[알림 오류] 레시피 답글 알림 실패: $e');
    }
  }

  Future<void> _deleteReply(String replyId) async {
    await FirebaseFirestore.instance
        .collection('recipes').doc(widget.recipeId)
        .collection('comments').doc(widget.commentId)
        .collection('replies').doc(replyId).delete();
    await FirebaseFirestore.instance
        .collection('recipes').doc(widget.recipeId)
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
        .collection('recipes').doc(widget.recipeId)
        .collection('comments').doc(widget.commentId)
        .collection('replies').doc(replyId)
        .update({'text': saved});
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final ts = d['createdAt'] as Timestamp?;
    final rating = d['rating'] as int?;
    final replyCount = d['replyCount'] ?? 0;
    final user = AuthService.instance.currentUser;

    final userId = d['userId'] as String?;
    void goToProfile() {
      if (userId != null && userId.isNotEmpty) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)));
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
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
              backgroundImage: (d['authorProfileImg'] as String?)?.isNotEmpty == true
                  ? NetworkImage(d['authorProfileImg'] as String)
                  : null,
              child: (d['authorProfileImg'] as String?)?.isNotEmpty == true
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
                // 닉네임 + 별점 + 시간 + 수정/삭제
                Row(children: [
                  GestureDetector(
                    onTap: goToProfile,
                    child: Text(
                      d['author'] ?? '익명',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                  if (userId != null &&
                      userId.isNotEmpty &&
                      userId == widget.recipeAuthorId) ...[
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
                  if (rating != null && rating > 0) ...[
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (i) => Icon(
                        i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 13, color: Colors.amber,
                      )),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    ts != null ? _formatDate(ts.toDate()) : '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
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
                Text(d['text'] ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
                const SizedBox(height: 8),
                // 좋아요 + 답글 버튼
                Row(children: [
                  _RecipeCommentLike(
                    commentId: widget.commentId,
                    recipeId: widget.recipeId,
                    initialCount: d['likeCount'] ?? 0,
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
                          fillColor: const Color(0xFFF0F0F0),
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
                        .collection('recipes').doc(widget.recipeId)
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
                          return _RecipeReplyCard(
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

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${dt.month}/${dt.day}';
  }
}

// ── 레시피 답글 카드 ─────────────────────────────────────
class _RecipeReplyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool canDelete;
  final bool canEdit;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _RecipeReplyCard({
    required this.data,
    required this.canDelete,
    required this.canEdit,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final ts = data['createdAt'] as Timestamp?;
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 16),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
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
                  Text(
                    ts != null ? _formatDate(ts.toDate()) : '',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
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

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${dt.month}/${dt.day}';
  }
}

// ── 레시피 댓글 좋아요 위젯 ──────────────────────────────
class _RecipeCommentLike extends StatefulWidget {
  final String commentId;
  final String recipeId;
  final int initialCount;
  const _RecipeCommentLike({
    required this.commentId,
    required this.recipeId,
    required this.initialCount,
  });

  @override
  State<_RecipeCommentLike> createState() => _RecipeCommentLikeState();
}

class _RecipeCommentLikeState extends State<_RecipeCommentLike> {
  bool _isLiked = false;
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(user.id)
        .collection('commentLikes').doc(widget.commentId)
        .get();
    if (mounted) setState(() => _isLiked = doc.exists);
  }

  Future<void> _toggle() async {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 좋아요를 누를 수 있어요.')),
      );
      return;
    }
    final newVal = !_isLiked;
    setState(() { _isLiked = newVal; _count += newVal ? 1 : -1; });
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
          .collection('recipes').doc(widget.recipeId)
          .collection('comments').doc(widget.commentId)
          .update({'likeCount': FieldValue.increment(newVal ? 1 : -1)});
    } catch (e) {
      if (mounted) setState(() { _isLiked = !newVal; _count += newVal ? -1 : 1; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          _isLiked ? Icons.favorite : Icons.favorite_border,
          size: 14,
          color: _isLiked ? Colors.red : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text('$_count',
            style: TextStyle(
                fontSize: 12,
                color: _isLiked ? Colors.red : Colors.grey)),
      ]),
    );
  }
}
