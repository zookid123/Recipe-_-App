import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'recipe_create_screen.dart';
import 'cooking_mode_screen.dart';
import '../widgets/comment_section.dart';
import 'user_profile_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  String? _docId;
  bool _isBookmarked = false;
  bool _isUserLiked = false;

  @override
  void initState() {
    super.initState();
    _initRecipe();
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
                if (_docId != null)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: CommentSection(
                      docId: _docId!,
                      collectionPath: 'recipes/$_docId/comments',
                      postAuthorId: widget.recipe['authorId'] ?? '',
                      postTitle: widget.recipe['name'] ?? '',
                      type: 'recipe',
                      showRating: true,
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
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
          child: _docId == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: CommentSection(
                    docId: _docId!,
                    collectionPath: 'recipes/$_docId/comments',
                    postAuthorId: widget.recipe['authorId'] ?? '',
                    postTitle: widget.recipe['name'] ?? '',
                    type: 'recipe',
                    showRating: true,
                  ),
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
              GestureDetector(
                onTap: () {
                  if (widget.recipe['authorId'] != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          userId: widget.recipe['authorId'],
                          nickname: widget.recipe['authorName'],
                          profileImageUrl: widget.recipe['authorProfileImg'],
                        ),
                      ),
                    );
                  }
                },
                child: Row(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '👨‍🍳 조리 순서',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (steps.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CookingModeScreen(
                            recipeName: widget.recipe['name'] ?? '레시피',
                            steps: steps,
                            stepImages: widget.recipe['stepImages'],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_circle_fill, size: 18),
                    label: const Text('요리 시작'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
              ],
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
