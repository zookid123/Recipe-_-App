import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'recipe_detail_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  List<Map<String, dynamic>> _bookmarks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = AuthService.instance.currentUser;
    List<Map<String, dynamic>> result = [];

    if (user != null) {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .collection('bookmarks')
          .orderBy('savedAt', descending: true)
          .get();
      result = snap.docs.map((d) => d.data()).toList();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList('liked_recipes') ?? [];
      // 게스트는 ID만 있으므로 Firestore에서 메타데이터 조회
      for (final id in ids.reversed.toList()) {
        final doc = await FirebaseFirestore.instance
            .collection('recipes').doc(id).get();
        if (doc.exists) {
          final d = doc.data()!;
          result.add({
            'id': id,
            'name': d['name'] ?? '',
            'imgUrl': d['imgUrl'] ?? '',
            'nation': d['nation'] ?? '',
          });
        }
      }
    }

    if (mounted) setState(() { _bookmarks = result; _loading = false; });
  }

  Future<void> _removeBookmark(String docId, int index) async {
    final user = AuthService.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users').doc(user.id)
          .collection('bookmarks').doc(docId)
          .delete();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('liked_recipes') ?? [];
      list.remove(docId);
      await prefs.setStringList('liked_recipes', list);
    }

    setState(() => _bookmarks.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('즐겨찾기', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _bookmarks.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('즐겨찾기한 레시피가 없어요.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookmarks.length,
                  itemBuilder: (context, i) {
                    final r = _bookmarks[i];
                    final hasImg = (r['imgUrl'] ?? '').toString().isNotEmpty;
                    return GestureDetector(
                      onTap: () async {
                        final docId = r['id'] as String?;
                        if (docId == null) return;
                        final nav = Navigator.of(context);
                        final snap = await FirebaseFirestore.instance
                            .collection('recipes').doc(docId).get();
                        if (!snap.exists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('삭제된 게시물입니다.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        nav.push(MaterialPageRoute(
                          builder: (_) => RecipeDetailScreen(recipe: <String, dynamic>{...snap.data()!, 'id': snap.id}),
                        ));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(color: Color(0x0A000000), blurRadius: 6),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 72,
                                height: 72,
                                child: hasImg
                                    ? Image.network(r['imgUrl'], fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _placeholder())
                                    : _placeholder(),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['name'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if ((r['nation'] ?? '').toString().isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        r['nation'],
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.orange),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.bookmark, color: Colors.orange),
                              onPressed: () => _removeBookmark(r['id'], i),
                              tooltip: '즐겨찾기 해제',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _placeholder() => Container(
    color: Colors.grey.shade100,
    child: const Center(child: Icon(Icons.restaurant, color: Colors.orange, size: 28)),
  );
}
