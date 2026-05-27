import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'recipe_detail_screen.dart';
import 'community_post_detail_screen.dart';

class MyActivityScreen extends StatelessWidget {
  const MyActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('내 활동 내역',
              style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            isScrollable: true,
            tabs: [
              Tab(text: '레시피 댓글'),
              Tab(text: '커뮤니티 댓글'),
              Tab(text: '커뮤니티 글'),
              Tab(text: '작성한 레시피'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyRecipeCommentsTab(),
            _MyCommunityCommentsTab(),
            _MyCommunityPostsTab(),
            _MyRecipesTab(),
          ],
        ),
      ),
    );
  }
}

// ── 레시피 댓글 탭 ──────────────────────────────────
class _MyRecipeCommentsTab extends StatelessWidget {
  const _MyRecipeCommentsTab();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const _EmptyState(icon: Icons.lock_outline, message: '로그인 후 이용할 수 있어요.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(user.id)
          .collection('myComments')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _EmptyState(icon: Icons.chat_bubble_outline, message: '작성한 레시피 댓글이 없어요.');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }
        final docs = snap.data!.docs
          ..sort((a, b) {
            final ta = (a.data() as Map)['createdAt'] as Timestamp?;
            final tb = (b.data() as Map)['createdAt'] as Timestamp?;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) {
          return const _EmptyState(icon: Icons.chat_bubble_outline, message: '작성한 레시피 댓글이 없어요.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final c = docs[i].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () async {
                final recipeId = c['recipeId'] as String?;
                if (recipeId == null) return;
                final nav = Navigator.of(context);
                final snap = await FirebaseFirestore.instance
                    .collection('recipes').doc(recipeId).get();
                if (!snap.exists) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('삭제된 게시물입니다.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }
                nav.push(MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(recipe: <String, dynamic>{...snap.data()!, 'id': snap.id}),
                ));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.restaurant, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(c['recipeName'] ?? '',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.orange,
                                fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if ((c['rating'] ?? 0) > 0)
                        Row(children: List.generate(c['rating'] as int, (_) =>
                          const Icon(Icons.star, size: 12, color: Colors.amber))),
                    ]),
                    const SizedBox(height: 6),
                    Text(c['text'] ?? '',
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(_formatDate(c['createdAt']),
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── 커뮤니티 댓글 탭 ─────────────────────────────────
class _MyCommunityCommentsTab extends StatelessWidget {
  const _MyCommunityCommentsTab();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const _EmptyState(icon: Icons.lock_outline, message: '로그인 후 이용할 수 있어요.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(user.id)
          .collection('myCommunityComments')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _EmptyState(
              icon: Icons.chat_bubble_outline, message: '작성한 커뮤니티 댓글이 없어요.');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }
        final docs = snap.data!.docs
          ..sort((a, b) {
            final ta = (a.data() as Map)['createdAt'] as Timestamp?;
            final tb = (b.data() as Map)['createdAt'] as Timestamp?;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) {
          return const _EmptyState(
              icon: Icons.chat_bubble_outline, message: '작성한 커뮤니티 댓글이 없어요.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final c = docs[i].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () async {
                final postId = c['postId'] as String?;
                if (postId == null) return;
                final nav = Navigator.of(context);
                final snap = await FirebaseFirestore.instance
                    .collection('community').doc(postId).get();
                if (!snap.exists) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('삭제된 게시물입니다.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }
                nav.push(MaterialPageRoute(
                  builder: (_) => CommunityPostDetailScreen(
                      docId: postId, post: snap.data()!),
                ));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.forum_outlined, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(c['postTitle'] ?? '',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.orange,
                                fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(c['text'] ?? '',
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(_formatDate(c['createdAt']),
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── 커뮤니티 글 탭 ──────────────────────────────────
class _MyCommunityPostsTab extends StatelessWidget {
  const _MyCommunityPostsTab();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const _EmptyState(icon: Icons.lock_outline, message: '로그인 후 이용할 수 있어요.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community')
          .where('authorId', isEqualTo: user.id)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _EmptyState(icon: Icons.forum_outlined, message: '작성한 커뮤니티 글이 없어요.');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }
        final docs = snap.data!.docs
          ..sort((a, b) {
            final ta = (a.data() as Map)['timestamp'] as Timestamp?;
            final tb = (b.data() as Map)['timestamp'] as Timestamp?;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) {
          return const _EmptyState(icon: Icons.forum_outlined, message: '작성한 커뮤니티 글이 없어요.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final docId = docs[i].id;
            final category = data['category'] ?? '자유';
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => CommunityPostDetailScreen(
                    docId: docId, post: data),
              )),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _categoryColor(category).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(category,
                            style: TextStyle(
                                fontSize: 11,
                                color: _categoryColor(category),
                                fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Text(_formatDate(data['timestamp']),
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                    const SizedBox(height: 8),
                    Text(data['title'] ?? '',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(data['content'] ?? '',
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.chat_bubble_outline, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${data['commentCount'] ?? 0}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Q&A': return Colors.blue;
      case '나눔': return Colors.green;
      default: return Colors.orange;
    }
  }
}

// ── 작성한 레시피 탭 ─────────────────────────────────
class _MyRecipesTab extends StatelessWidget {
  const _MyRecipesTab();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const _EmptyState(icon: Icons.lock_outline, message: '로그인 후 이용할 수 있어요.');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .where('authorId', isEqualTo: user.id)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const _EmptyState(icon: Icons.edit_outlined, message: '작성한 레시피가 없어요.');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }
        final docs = snap.data!.docs
          ..sort((a, b) {
            final ta = (a.data() as Map)['timestamp'] as Timestamp?;
            final tb = (b.data() as Map)['timestamp'] as Timestamp?;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) {
          return const _EmptyState(icon: Icons.edit_outlined, message: '작성한 레시피가 없어요.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = <String, dynamic>{...docs[i].data() as Map<String, dynamic>, 'id': docs[i].id};
            final hasImg = (data['imgUrl'] ?? '').toString().isNotEmpty;
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(recipe: data),
              )),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
                ),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64, height: 64,
                      child: hasImg
                          ? Image.network(data['imgUrl'], fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder())
                          : _placeholder(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['name'] ?? '',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.visibility_outlined, size: 13, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text('${data['viewCount'] ?? 0}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 10),
                          const Icon(Icons.favorite_border, size: 13, color: Colors.grey),
                          const SizedBox(width: 3),
                          Text('${data['likeCount'] ?? 0}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ]),
                      ],
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _placeholder() => Container(
    color: Colors.grey.shade100,
    child: const Center(child: Icon(Icons.restaurant, color: Colors.orange, size: 24)),
  );
}

// ── 공통 빈 상태 위젯 ────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
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
