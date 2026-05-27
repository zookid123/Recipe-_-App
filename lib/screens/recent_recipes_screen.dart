import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'recipe_detail_screen.dart';

class RecentRecipesScreen extends StatefulWidget {
  const RecentRecipesScreen({super.key});

  @override
  State<RecentRecipesScreen> createState() => _RecentRecipesScreenState();
}

class _RecentRecipesScreenState extends State<RecentRecipesScreen> {
  List<Map<String, dynamic>> _recipes = [];
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
          .collection('recentRecipes')
          .orderBy('viewedAt', descending: true)
          .limit(20)
          .get();
      result = snap.docs.map((d) => d.data()).toList();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('recent_recipes') ?? [];
      result = raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    }

    if (mounted) setState(() { _recipes = result; _loading = false; });
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('최근 본 레시피', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _recipes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('최근 본 레시피가 없어요.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recipes.length,
                  itemBuilder: (context, i) {
                    final r = _recipes[i];
                    final hasImg = (r['imgUrl'] ?? '').toString().isNotEmpty;
                    return GestureDetector(
                      onTap: () async {
                        final docId = r['id'] as String?;
                        if (docId == null) return;
                        final nav = Navigator.of(context);
                        final snap = await FirebaseFirestore.instance
                            .collection('recipes')
                            .doc(docId)
                            .get();
                        if (!snap.exists) return;
                        nav.push(MaterialPageRoute(
                          builder: (_) => RecipeDetailScreen(recipe: snap.data()!),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        r['nation'],
                                        style: const TextStyle(fontSize: 11, color: Colors.orange),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              _timeAgo(r['viewedAt']),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
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
