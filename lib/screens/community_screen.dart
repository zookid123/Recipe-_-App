import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'community_post_create_screen.dart';
import 'community_post_detail_screen.dart';
import 'user_profile_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  String _selectedCategory = '전체';
  static const _categories = ['전체', '자유', 'Q&A', '나눔'];

  void _goToCreate() {
    if (!AuthService.instance.isLoggedIn) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('로그인 필요'),
          content: const Text('글 작성은 로그인 후 이용할 수 있어요.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              child: const Text('로그인', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const CommunityPostCreateScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('커뮤니티',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_community_create',
        onPressed: _goToCreate,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.edit_outlined, color: Colors.white),
        label: const Text('글쓰기',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // 카테고리 탭
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _categories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: selected ? Colors.orange : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? Colors.orange : Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.bold : FontWeight.normal,
                              color: selected ? Colors.white : Colors.black54,
                            )),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          // 게시글 목록
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('community')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: Colors.orange));
                }
                var docs = snapshot.data!.docs;
                if (_selectedCategory != '전체') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return data['category'] == _selectedCategory;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.forum_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _selectedCategory == '전체'
                              ? '첫 번째 글을 작성해보세요!'
                              : '$_selectedCategory 게시글이 없습니다.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final docId = docs[i].id;
                    return _PostCard(
                      data: data,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityPostDetailScreen(
                              docId: docId, post: data),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _PostCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final category = data['category'] ?? '자유';
    final hasImg = (data['imgUrl'] ?? '').toString().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
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
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        final authorId = data['authorId'] as String?;
                        if (authorId != null && authorId.isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => UserProfileScreen(userId: authorId),
                          ));
                        }
                      },
                      child: Row(children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: const Color(0xFFFFE0B2),
                          backgroundImage: (data['authorProfileImg'] as String?)?.isNotEmpty == true
                              ? NetworkImage(data['authorProfileImg'] as String)
                              : null,
                          child: (data['authorProfileImg'] as String?)?.isNotEmpty == true
                              ? null
                              : const Icon(Icons.person, size: 11, color: Colors.orange),
                        ),
                        const SizedBox(width: 4),
                        Text(data['authorName'] ?? '익명',
                            style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                    const Spacer(),
                    Text(_formatDate(data['timestamp']),
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                  const SizedBox(height: 8),
                  Text(data['title'] ?? '',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(data['content'] ?? '',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.chat_bubble_outline, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${data['commentCount'] ?? 0}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 12),
                    const Icon(Icons.favorite_border, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${data['likeCount'] ?? 0}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 12),
                    const Icon(Icons.visibility_outlined, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('${data['viewCount'] ?? 0}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ],
              ),
            ),
            if (hasImg) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(data['imgUrl'],
                    width: 72, height: 72, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            ],
          ],
        ),
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
