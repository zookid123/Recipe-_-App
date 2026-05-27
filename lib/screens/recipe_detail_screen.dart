import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'recipe_create_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  String? _docId;
  final _commentCtrl = TextEditingController();
  int _selectedRating = 0; // 0 = 별점 미선택
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
      } else {
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList('user_likes') ?? [];
        if (newVal) {
          if (!list.contains(_docId!)) list.add(_docId!);
        } else {
          list.remove(_docId!);
        }
        await prefs.setStringList('user_likes', list);
      }
      await FirebaseFirestore.instance.collection('recipes').doc(_docId).update(
        {'likeCount': FieldValue.increment(newVal ? 1 : -1)},
      );
    } catch (e) {
      if (mounted) setState(() => _isUserLiked = !newVal);
    }
  }

  Future<void> _initRecipe() async {
    final recipeName = widget.recipe['name'];
    if (recipeName == null) return;

    final query = await FirebaseFirestore.instance
        .collection('recipes')
        .where('name', isEqualTo: recipeName)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return;

    final doc = query.docs.first;
    if (mounted) setState(() => _docId = doc.id);

    _saveRecentRecipe(doc.id);
    _loadBookmarkStatus();
    _loadUserLikeStatus();

    final data = doc.data();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final storedDate = data['todayDate'] ?? '';

    if (storedDate == today) {
      await doc.reference.update({
        'viewCount': FieldValue.increment(1),
        'todayViewCount': FieldValue.increment(1),
      });
    } else {
      await doc.reference.update({
        'viewCount': FieldValue.increment(1),
        'yesterdayViewCount': data['todayViewCount'] ?? 0,
        'todayViewCount': 1,
        'todayDate': today,
      });
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
          // 본인 작성글일 경우 관리 메뉴 표시
          if (widget.recipe['authorId'] != null &&
              AuthService.instance.isLoggedIn &&
              AuthService.instance.currentUser!.id == widget.recipe['authorId'])
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
                const PopupMenuItem(value: 'edit', child: Text('수정하기')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('삭제하기', style: TextStyle(color: Colors.red)),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFFFFE0B2),
                    backgroundImage: widget.recipe['authorProfileImg'] != null
                        ? NetworkImage(widget.recipe['authorProfileImg']!)
                        : null,
                    child: widget.recipe['authorProfileImg'] == null
                        ? const Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.orange,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.recipe['authorName'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '셰프의 레시피',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
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
                  final ts = data['createdAt'] as Timestamp?;
                  final rating = data['rating'] as int?;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 12,
                              backgroundColor: Color(0xFFFFE0B2),
                              child: Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              data['author'] ?? '익명',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const Spacer(),
                            // 별점 표시
                            if (rating != null && rating > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(
                                  5,
                                  (idx) => Icon(
                                    idx < rating
                                        ? Icons.star_rounded
                                        : Icons.star_outline_rounded,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              ts != null ? _formatDate(ts.toDate()) : '',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['text'] ?? '',
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
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

  Widget _metaCol(IconData icon, String label, String value) => SizedBox(
    width: 72,
    child: Column(
      children: [
        Icon(icon, color: Colors.orange, size: 22),
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

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${dt.month}/${dt.day}';
  }
}
