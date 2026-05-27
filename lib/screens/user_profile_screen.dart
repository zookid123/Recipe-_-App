import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'recipe_detail_screen.dart';
import 'community_post_detail_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic>? _userData;
  bool _loading = true;

  bool get _isOwnProfile =>
      AuthService.instance.currentUser?.id == widget.userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (mounted) {
      setState(() {
        _userData = doc.exists ? doc.data() : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    if (_userData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('프로필'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: const Center(child: Text('유저를 찾을 수 없습니다.')),
      );
    }

    final isPublic =
        _isOwnProfile || (_userData!['isProfilePublic'] as bool? ?? true);
    final showRecipes =
        _isOwnProfile || (_userData!['showRecipes'] as bool? ?? true);
    final showPosts =
        _isOwnProfile || (_userData!['showCommunityPosts'] as bool? ?? true);
    final nickname = _userData!['nickname'] as String? ?? '사용자';
    final profileImg = _userData!['profileImageUrl'] as String?;
    final provider = _userData!['provider'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(nickname,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          // ── 프로필 헤더 ──────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: Colors.orange.shade100,
                  backgroundImage:
                      (profileImg != null && profileImg.isNotEmpty)
                          ? NetworkImage(profileImg)
                          : null,
                  child: (profileImg == null || profileImg.isEmpty)
                      ? const Icon(Icons.person, size: 42, color: Colors.orange)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.badge_outlined,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          provider == 'google'
                              ? 'Google 계정'
                              : provider == 'kakao'
                                  ? '카카오 계정'
                                  : '계정',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ]),
                      if (!isPublic) ...[
                        const SizedBox(height: 6),
                        Row(children: const [
                          Icon(Icons.lock_outline, size: 13, color: Colors.grey),
                          SizedBox(width: 4),
                          Text('비공개 프로필',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ]),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── 비공개일 때 ────────────────────────────────────
          if (!isPublic)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 52, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('비공개 프로필입니다.',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 15)),
                  ],
                ),
              ),
            ),

          // ── 공개일 때: 탭 + 콘텐츠 ─────────────────────────
          if (isPublic) ...[
            Material(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.orange,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.orange,
                indicatorWeight: 2,
                tabs: const [
                  Tab(text: '레시피'),
                  Tab(text: '게시글'),
                ],
              ),
            ),
            const SizedBox(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _RecipesTab(
                      userId: widget.userId, showRecipes: showRecipes),
                  _PostsTab(
                      userId: widget.userId, showPosts: showPosts),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 레시피 탭 ──────────────────────────────────────────
class _RecipesTab extends StatelessWidget {
  final String userId;
  final bool showRecipes;
  const _RecipesTab({required this.userId, required this.showRecipes});

  @override
  Widget build(BuildContext context) {
    if (!showRecipes) {
      return const _PrivatePlaceholder(message: '레시피를 비공개로 설정했습니다.');
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .where('authorId', isEqualTo: userId)
          .where('source', isEqualTo: 'ugc')
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const _EmptyPlaceholder(
              icon: Icons.menu_book_outlined,
              message: '작성한 레시피가 없습니다.');
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = <String, dynamic>{
              ...docs[i].data() as Map<String, dynamic>,
              'id': docs[i].id,
            };
            final hasImg = (data['imgUrl'] ?? '').toString().isNotEmpty;
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(recipe: data)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Color(0x10000000), blurRadius: 8)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: hasImg
                            ? Image.network(data['imgUrl'],
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _imgPlaceholder())
                            : _imgPlaceholder(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['name'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                height: 1.3),
                          ),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.favorite,
                                size: 10, color: Colors.red),
                            const SizedBox(width: 2),
                            Text('${data['likeCount'] ?? 0}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                            const SizedBox(width: 6),
                            const Icon(Icons.visibility_outlined,
                                size: 10, color: Colors.grey),
                            const SizedBox(width: 2),
                            Text('${data['viewCount'] ?? 0}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _imgPlaceholder() => Container(
        color: Colors.grey.shade100,
        child: const Center(
            child: Icon(Icons.restaurant, color: Colors.orange, size: 32)),
      );
}

// ── 게시글 탭 ──────────────────────────────────────────
class _PostsTab extends StatelessWidget {
  final String userId;
  final bool showPosts;
  const _PostsTab({required this.userId, required this.showPosts});

  @override
  Widget build(BuildContext context) {
    if (!showPosts) {
      return const _PrivatePlaceholder(message: '게시글을 비공개로 설정했습니다.');
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community')
          .where('authorId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text('불러오기 실패: ${snap.error}',
                style: const TextStyle(color: Colors.grey)),
          );
        }
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }
        // 복합 인덱스 없이 클라이언트에서 최신순 정렬
        final docs = snap.data!.docs.toList()
          ..sort((a, b) {
            final ta = (a.data() as Map)['timestamp'] as Timestamp?;
            final tb = (b.data() as Map)['timestamp'] as Timestamp?;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) {
          return const _EmptyPlaceholder(
              icon: Icons.forum_outlined,
              message: '작성한 게시글이 없습니다.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final docId = docs[i].id;
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        CommunityPostDetailScreen(docId: docId, post: data)),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0A000000), blurRadius: 6)
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(data['category'] ?? '자유',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(_formatDate(data['timestamp']),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ]),
                    const SizedBox(height: 8),
                    Text(data['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(data['content'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            height: 1.4)),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 13, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text('${data['commentCount'] ?? 0}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 12),
                      const Icon(Icons.favorite_border,
                          size: 13, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text('${data['likeCount'] ?? 0}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
                  ],
                ),
              ),
            );
          },
        );
      },
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
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day}';
    }
    return '';
  }
}

// ── 공용 플레이스홀더 ────────────────────────────────────
class _PrivatePlaceholder extends StatelessWidget {
  final String message;
  const _PrivatePlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 44, color: Colors.grey),
          const SizedBox(height: 10),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyPlaceholder({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Colors.grey),
          const SizedBox(height: 10),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }
}
