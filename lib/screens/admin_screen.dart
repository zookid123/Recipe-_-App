import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../admin_config.dart';

// ════════════════════════════════════════════════════
// AdminScreen — 최상위 탭 컨테이너
// ════════════════════════════════════════════════════
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              '관리자 패널',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined, size: 20), text: '대시보드'),
            Tab(icon: Icon(Icons.restaurant_menu, size: 20), text: '레시피'),
            Tab(icon: Icon(Icons.forum_outlined, size: 20), text: '커뮤니티'),
            Tab(icon: Icon(Icons.people_outline, size: 20), text: '유저'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _DashboardTab(),
          _RecipeManageTab(),
          _CommunityManageTab(),
          _UserManageTab(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// Tab 1 — 대시보드
// ════════════════════════════════════════════════════
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '현황 요약',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: '레시피',
                  collection: 'recipes',
                  color: Colors.orange,
                  icon: Icons.restaurant_menu,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: '유저',
                  collection: 'users',
                  color: Colors.blue,
                  icon: Icons.people,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: '게시글',
                  collection: 'community',
                  color: Colors.green,
                  icon: Icons.forum,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Container()),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '최근 가입 유저',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('lastLoginAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.orange));
              }
              final docs = snap.data!.docs;
              return Column(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage:
                          (data['profileImageUrl'] ?? '').toString().isNotEmpty
                              ? NetworkImage(data['profileImageUrl'])
                              : null,
                      child: (data['profileImageUrl'] ?? '').toString().isEmpty
                          ? const Icon(Icons.person,
                              size: 18, color: Colors.grey)
                          : null,
                    ),
                    title: Text(
                      data['nickname'] ?? '이름 없음',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      data['email'] ?? data['provider'] ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    trailing: _providerBadge(data['provider']),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _providerBadge(String? provider) {
    final label = provider == 'google'
        ? 'G'
        : provider == 'kakao'
            ? 'K'
            : '?';
    final color =
        provider == 'google' ? Colors.blue : Colors.yellow.shade700;
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String collection;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.collection,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AggregateQuerySnapshot>(
      future:
          FirebaseFirestore.instance.collection(collection).count().get(),
      builder: (ctx, snap) {
        final count = snap.data?.count ?? 0;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 8,
                  offset: Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                  Text(
                    snap.hasData ? '$count개' : '-',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════
// Tab 2 — 레시피 관리 + DB 동기화
// ════════════════════════════════════════════════════
class _RecipeManageTab extends StatefulWidget {
  const _RecipeManageTab();

  @override
  State<_RecipeManageTab> createState() => _RecipeManageTabState();
}

class _RecipeManageTabState extends State<_RecipeManageTab> {
  bool _isSyncing = false;
  String _syncStatus = '';
  double _syncProgress = 0;
  int _syncCount = 0;

  // 공공 API 페이지네이션 수집
  Future<List<Map<String, dynamic>>> _fetchAll(
      String endpoint, String label) async {
    final rows = <Map<String, dynamic>>[];
    int start = 1;
    const pageSize = 1000;

    while (true) {
      final end = start + pageSize - 1;
      final url = '$kRecipeApiBase/$endpoint/$start/$end';
      setState(
          () => _syncStatus = '[$label] $start ~ $end 수집 중... (${rows.length}건)');
      try {
        final res = await http.get(Uri.parse(url));
        final body = json.decode(res.body) as Map<String, dynamic>;
        final data = body[endpoint] as Map<String, dynamic>?;
        if (data == null || data['row'] == null) break;
        final page = (data['row'] as List).cast<Map<String, dynamic>>();
        rows.addAll(page);
        if (page.length < pageSize) break;
        start += pageSize;
      } catch (e) {
        setState(() => _syncStatus = '[$label] 오류: $e');
        break;
      }
    }
    return rows;
  }

  int _parseMinutes(String? s) {
    if (s == null || s.isEmpty) return 999;
    int m = 0;
    final h = RegExp(r'(\d+)\s*시간').firstMatch(s);
    final min = RegExp(r'(\d+)\s*분').firstMatch(s);
    if (h != null) m += int.parse(h.group(1)!) * 60;
    if (min != null) m += int.parse(min.group(1)!);
    return m > 0 ? m : 999;
  }

  Future<void> _runSync() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'API 연결 중...';
      _syncProgress = 0;
      _syncCount = 0;
    });

    try {
      // 1단계: API 수집
      final basic =
          await _fetchAll('Grid_20150827000000000226_1', '기본 정보');
      setState(() => _syncProgress = 0.3);
      final ingre =
          await _fetchAll('Grid_20150827000000000227_1', '재료');
      setState(() => _syncProgress = 0.6);
      final steps =
          await _fetchAll('Grid_20150827000000000228_1', '조리 순서');
      setState(() {
        _syncProgress = 0.7;
        _syncStatus = 'Firestore에 저장 중...';
      });

      // 2단계: Firestore 배치 쓰기
      final db = FirebaseFirestore.instance;
      WriteBatch batch = db.batch();
      int batchCount = 0;
      int total = 0;

      for (final b in basic) {
        final id = b['RECIPE_ID'].toString().trim();
        final cal =
            (b['CALORIE'] ?? '').toString().trim().toLowerCase();
        if (cal == '0kcal' || cal == '0 kcal' || cal == '0') continue;

        final ingredients = ingre
            .where((i) => i['RECIPE_ID'].toString().trim() == id)
            .map((i) => '${i['IRDNT_NM']} (${i['IRDNT_CPCTY'] ?? ''})')
            .toList();

        final sortedSteps = steps
            .where((s) => s['RECIPE_ID'].toString().trim() == id)
            .toList()
          ..sort((a, b) => int.parse(a['COOKING_NO'].toString())
              .compareTo(int.parse(b['COOKING_NO'].toString())));
        final stepList =
            sortedSteps.map((s) => s['COOKING_DC'].toString()).toList();

        final ref = db.collection('recipes').doc(id);
        batch.set(
          ref,
          {
            'name': b['RECIPE_NM_KO'],
            'summary': b['SUMRY'],
            'calorie': b['CALORIE'] ?? '정보 없음',
            'qnt': b['QNT'] ?? '정보 없음',
            'time': b['COOKING_TIME'] ?? '정보 없음',
            'timeMinutes': _parseMinutes(b['COOKING_TIME']?.toString()),
            'level': b['LEVEL_NM'] ?? '정보 없음',
            'nation': b['NATION_NM'] ?? '한식',
            'type': b['TY_NM'] ?? '기타',
            'ingredients': ingredients,
            'steps': stepList,
            'imgUrl': b['IMG_URL'] ?? '',
            'timestamp': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        total++;
        batchCount++;
        if (batchCount >= 500) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
          setState(() {
            _syncCount = total;
            _syncProgress = 0.7 + (total / basic.length) * 0.3;
            _syncStatus = '$total개 저장 완료...';
          });
        }
      }

      if (batchCount > 0) await batch.commit();

      setState(() {
        _syncProgress = 1.0;
        _syncCount = total;
        _syncStatus = '✅ 총 $total개 동기화 완료!';
        _isSyncing = false;
      });
    } catch (e) {
      setState(() {
        _syncStatus = '❌ 오류 발생: $e';
        _isSyncing = false;
      });
    }
  }

  Future<void> _deleteRecipe(String docId, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('레시피 삭제'),
        content: Text('"$name" 을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(docId)
        .delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('삭제되었습니다.'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 동기화 패널 ──────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync, size: 18, color: Colors.orange),
                  const SizedBox(width: 6),
                  const Text(
                    '레시피 DB 동기화',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  if (_syncCount > 0) ...[
                    const Spacer(),
                    Text(
                      '마지막: $_syncCount개',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '공공 API에서 최신 레시피를 가져와 업데이트합니다. (Windows·모바일 권장)',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (_syncStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _syncStatus,
                  style: TextStyle(
                    fontSize: 12,
                    color: _syncStatus.startsWith('✅')
                        ? Colors.green
                        : _syncStatus.startsWith('❌')
                            ? Colors.red
                            : Colors.orange,
                  ),
                ),
                if (_isSyncing) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _syncProgress,
                    color: Colors.orange,
                    backgroundColor:
                        Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSyncing ? null : _runSync,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_sync_outlined),
                  label: Text(
                    _isSyncing ? '동기화 중...' : '동기화 시작',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),

        // ── 레시피 목록 ─────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('recipes')
                .orderBy('timestamp', descending: true)
                .limit(200)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: Colors.orange));
              }
              final docs = snap.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final data =
                      docs[i].data() as Map<String, dynamic>;
                  final docId = docs[i].id;
                  final name = data['name'] ?? '제목 없음';
                  final source = data['source'] ?? 'public';
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                            color: Colors.grey.shade200)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            (data['imgUrl'] ?? '').toString().isNotEmpty
                                ? Image.network(
                                    data['imgUrl'],
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _imgPlaceholder(),
                                  )
                                : _imgPlaceholder(),
                      ),
                      title: Text(name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${data['nation'] ?? ''} · ${data['type'] ?? ''} · ${data['calorie'] ?? ''}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (source == 'ugc')
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('UGC',
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                            onPressed: () =>
                                _deleteRecipe(docId, name),
                            tooltip: '삭제',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 48,
        height: 48,
        color: Colors.grey.shade100,
        child: const Icon(Icons.restaurant, size: 24, color: Colors.orange),
      );
}

// ════════════════════════════════════════════════════
// Tab 3 — 커뮤니티 관리
// ════════════════════════════════════════════════════
class _CommunityManageTab extends StatelessWidget {
  const _CommunityManageTab();

  Future<void> _deletePost(
      BuildContext context, String docId, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('게시글 삭제'),
        content: Text('"$title" 을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('community')
        .doc(docId)
        .delete();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('삭제되었습니다.'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child: Text('게시글이 없습니다.',
                  style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final docId = docs[i].id;
            final title = data['title'] ?? '제목 없음';
            final author = data['authorName'] ?? '익명';
            final category = data['category'] ?? '';
            final ts = data['timestamp'] as Timestamp?;
            final dateStr = ts != null
                ? ts.toDate().toString().substring(0, 10)
                : '-';
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.article_outlined,
                      color: Colors.green, size: 20),
                ),
                title: Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '$author · $category · $dateStr',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () => _deletePost(context, docId, title),
                  tooltip: '삭제',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════
// Tab 4 — 유저 관리
// ════════════════════════════════════════════════════
class _UserManageTab extends StatelessWidget {
  const _UserManageTab();

  Future<void> _showUserDetail(
      BuildContext context, Map<String, dynamic> data) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(data['nickname'] ?? '이름 없음',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((data['email'] ?? '').toString().isNotEmpty)
              _infoRow(Icons.email_outlined, '이메일', data['email']),
            _infoRow(Icons.login, '로그인', data['provider'] ?? '-'),
            if (data['lastLoginAt'] != null)
              _infoRow(
                Icons.access_time,
                '마지막 로그인',
                (data['lastLoginAt'] as Timestamp)
                    .toDate()
                    .toString()
                    .substring(0, 16),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기',
                style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('lastLoginAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child:
                  Text('유저가 없습니다.', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final isAdmin = data['email'] == kAdminEmail;
            final ts = data['lastLoginAt'] as Timestamp?;
            final dateStr = ts != null
                ? ts.toDate().toString().substring(0, 10)
                : '-';
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                      color: isAdmin
                          ? Colors.orange.shade200
                          : Colors.grey.shade200)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                onTap: () => _showUserDetail(context, data),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: (data['profileImageUrl'] ?? '')
                          .toString()
                          .isNotEmpty
                      ? NetworkImage(data['profileImageUrl'])
                      : null,
                  child: (data['profileImageUrl'] ?? '').toString().isEmpty
                      ? const Icon(Icons.person,
                          size: 20, color: Colors.grey)
                      : null,
                ),
                title: Row(
                  children: [
                    Text(
                      data['nickname'] ?? '이름 없음',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('ADMIN',
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${data['email'] ?? data['provider'] ?? ''} · 마지막 $dateStr',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.info_outline,
                      color: Colors.grey, size: 20),
                  onPressed: () => _showUserDetail(context, data),
                  tooltip: '상세 보기',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
