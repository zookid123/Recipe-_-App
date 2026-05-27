import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_detail_screen.dart';
import 'search_screen.dart';
import 'recipe_create_screen.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});
  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final _firestore = FirebaseFirestore.instance;
  String _selectedFilter = '전체';
  String _selectedType = '전체';
  String _sortBy = 'latest'; // 'latest' | 'popular'
  String? _expandedFilter; // null | 'nation' | 'type'

  // (firestoreValue, displayLabel, emoji)
  static const _filters = [
    ('전체', '전체', '🍽️'),
    ('한식', '한식', '🍚'),
    ('서양', '양식', '🍝'),
    ('중국', '중식', '🍜'),
    ('일본', '일식', '🍣'),
    ('동남아시아', '동남아', '🍛'),
    ('이탈리아', '이탈리아', '🍕'),
    ('퓨전', '퓨전', '🎭'),
  ];

  static const _typeFilters = [
    ('전체', '전체', '🍽️'),
    ('밥', '밥', '🍚'),
    ('국', '국', '🍵'),
    ('찌개/전골/스튜', '찌개/전골', '🫕'),
    ('구이', '구이', '🔥'),
    ('볶음', '볶음', '🥘'),
    ('조림', '조림', '🍲'),
    ('찜', '찜', '♨️'),
    ('부침', '부침', '🥞'),
    ('튀김/커틀릿', '튀김', '🍗'),
    ('만두/면류', '만두/면류', '🍜'),
    ('나물/생채/샐러드', '샐러드', '🥗'),
    ('밑반찬/김치', '김치류', '🥬'),
    ('떡/한과', '떡/한과', '🍡'),
    ('빵/과자', '빵/과자', '🍞'),
    ('도시락/간식', '도시락/간식', '🍱'),
    ('샌드위치/햄버거', '샌드위치', '🍔'),
    ('피자', '피자', '🍕'),
    ('그라탕/리조또', '그라탕', '🧀'),
    ('양식', '양식', '🍝'),
    ('양념장', '양념장', '🧄'),
    ('음료', '음료', '🥤'),
  ];

  Widget _buildFilterTabs({
    required List<(String, String, String)> filters,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, i) {
          final (value, label, emoji) = filters[i];
          final isSelected = selected == value;
          return GestureDetector(
            onTap: () => onSelect(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orange : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? Colors.orange : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 필터 버튼에 표시할 현재 선택값 레이블
  String _activeLabel(List<(String, String, String)> filters, String selected) {
    if (selected == '전체') return '';
    try {
      return filters.firstWhere((f) => f.$1 == selected).$2;
    } catch (_) {
      return selected;
    }
  }

  // 드롭다운 토글 버튼 하나
  Widget _buildDropdownBtn({
    required String emoji,
    required String label,
    required String mode,
    required String? activeLabel,
  }) {
    final isOpen = _expandedFilter == mode;
    final hasActive = activeLabel != null && activeLabel.isNotEmpty;
    final highlight = isOpen || hasActive;
    return GestureDetector(
      onTap: () => setState(
        () => _expandedFilter = isOpen ? null : mode,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.orange.withValues(alpha: 0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highlight ? Colors.orange : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              hasActive ? activeLabel : label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasActive ? FontWeight.bold : FontWeight.normal,
                color: highlight ? Colors.orange : Colors.black54,
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: highlight ? Colors.orange : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _goToCreate() {
    if (!AuthService.instance.isLoggedIn) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('로그인 필요'),
          content: const Text('레시피 작성은 로그인 후 이용할 수 있어요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('로그인', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecipeCreateScreen()),
    );
  }

  Query get _query {
    // timestamp 필드가 없는 문서가 있을 수 있으므로 정렬 없이 가져온 뒤
    // 클라이언트 측에서 정렬하는 방식이 더 안전할 수 있음.
    // 여기서는 일단 필터링을 위해 collection 전체를 가져오거나
    // 특정 필드 유무와 상관없이 가져오도록 함.
    return _firestore.collection('recipes');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          '레시피',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_recipe_create',
        onPressed: _goToCreate,
        backgroundColor: Colors.orange,
        elevation: 3,
        icon: const Icon(Icons.edit_outlined, color: Colors.white),
        label: const Text(
          '레시피 작성',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // ── 카테고리 드롭다운 필터 ───────────────
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 버튼 행
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      _buildDropdownBtn(
                        emoji: '🌍',
                        label: '국가',
                        mode: 'nation',
                        activeLabel: _activeLabel(_filters, _selectedFilter),
                      ),
                      const SizedBox(width: 8),
                      _buildDropdownBtn(
                        emoji: '🍳',
                        label: '유형',
                        mode: 'type',
                        activeLabel:
                            _activeLabel(_typeFilters, _selectedType),
                      ),
                      // 필터 적용 중일 때 초기화 버튼
                      if (_selectedFilter != '전체' || _selectedType != '전체') ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectedFilter = '전체';
                            _selectedType = '전체';
                            _expandedFilter = null;
                          }),
                          child: const Text(
                            '초기화',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 드롭다운 칩 패널
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: _expandedFilter == null
                      ? const SizedBox.shrink()
                      : Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          child: _expandedFilter == 'nation'
                              ? _buildFilterTabs(
                                  filters: _filters,
                                  selected: _selectedFilter,
                                  onSelect: (v) => setState(() {
                                    _selectedFilter = v;
                                    _expandedFilter = null;
                                  }),
                                )
                              : _buildFilterTabs(
                                  filters: _typeFilters,
                                  selected: _selectedType,
                                  onSelect: (v) => setState(() {
                                    _selectedType = v;
                                    _expandedFilter = null;
                                  }),
                                ),
                        ),
                ),
              ],
            ),
          ),
          // ── 정렬 + 구분선 ────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 15, color: Colors.grey),
                const SizedBox(width: 6),
                _SortChip(
                  label: '최신순',
                  selected: _sortBy == 'latest',
                  onTap: () => setState(() => _sortBy = 'latest'),
                ),
                const SizedBox(width: 6),
                _SortChip(
                  label: '인기순',
                  selected: _sortBy == 'popular',
                  onTap: () => setState(() => _sortBy = 'popular'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // ── 그리드 ──────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _query.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  );
                }
                final allDocs = snapshot.data!.docs;
                // 1. 필터링 (nation + type 복합 적용)
                var filtered = allDocs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final nationOk = _selectedFilter == '전체' || data['nation'] == _selectedFilter;
                  final typeOk = _selectedType == '전체' || data['type'] == _selectedType;
                  return nationOk && typeOk;
                }).toList();

                // 2. 수동 정렬 (Firestore 인덱스 이슈 및 누락 필드 대응)
                final docs = List<QueryDocumentSnapshot>.from(filtered);
                if (_sortBy == 'popular') {
                  docs.sort((a, b) {
                    final da = a.data() as Map<String, dynamic>;
                    final db = b.data() as Map<String, dynamic>;
                    final va = da['viewCount'] ?? 0;
                    final vb = db['viewCount'] ?? 0;
                    return vb.compareTo(va);
                  });
                } else {
                  docs.sort((a, b) {
                    final da = a.data() as Map<String, dynamic>;
                    final db = b.data() as Map<String, dynamic>;
                    final ta = da['timestamp'] as Timestamp?;
                    final tb = db['timestamp'] as Timestamp?;
                    if (ta == null && tb == null) return 0;
                    if (ta == null) return 1;
                    if (tb == null) return -1;
                    return tb.compareTo(ta);
                  });
                }

                final ugcCount = docs
                    .where(
                      (d) =>
                          (d.data() as Map<String, dynamic>)['source'] == 'ugc',
                    )
                    .length;
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFilter == '전체'
                              ? '동기화 버튼을 눌러주세요!'
                              : '$_selectedFilter 레시피가 없습니다.',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final crossAxisCount = w < 600
                        ? 2
                        : w < 960
                        ? 3
                        : 4;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(
                            children: [
                              Text(
                                '총 ${docs.length}개',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (ugcCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '✍️ 유저 $ugcCount',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(14),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.72,
                                ),
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final data = <String, dynamic>{
                                ...docs[i].data() as Map<String, dynamic>,
                                'id': docs[i].id,
                              };
                              return _RecipeGridCard(
                                data: data,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RecipeDetailScreen(recipe: data),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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

// ── 그리드 카드 ──────────────────────────────────
class _RecipeGridCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _RecipeGridCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        data['imgUrl'] != null && data['imgUrl'].toString().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지 영역
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 이미지 or 플레이스홀더
                    hasImage
                        ? Image.network(
                            data['imgUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),

                    // 하단 그라데이션 오버레이
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0xCC000000), Colors.transparent],
                          ),
                        ),
                      ),
                    ),

                    // 국가 태그
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          data['nation'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // UGC 뱃지
                    if (data['source'] == 'ugc')
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '✍️',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                      ),

                    // 조리 시간 (오버레이 위)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 11,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            data['time'] ?? '-',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 텍스트 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        size: 12,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          data['calorie'] ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.favorite, size: 11, color: Colors.red),
                      const SizedBox(width: 3),
                      Text(
                        '${data['likeCount'] ?? 0}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.visibility_outlined, size: 11, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(
                        '${data['viewCount'] ?? 0}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // 난이도 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _levelColor(data['level']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['level'] ?? '-',
                          style: TextStyle(
                            fontSize: 10,
                            color: _levelColor(data['level']),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // 작성자 (UGC 레시피만)
                      if (data['source'] == 'ugc' &&
                          (data['authorName'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.person, size: 10, color: Colors.grey),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            data['authorName'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _levelColor(String? level) {
    if (level == null) return Colors.grey;
    if (level.contains('초')) return Colors.green;
    if (level.contains('중')) return Colors.orange;
    if (level.contains('고')) return Colors.red;
    return Colors.grey;
  }

  Widget _placeholder() => Container(
    color: Colors.grey.shade100,
    child: const Center(
      child: Icon(Icons.restaurant, size: 40, color: Colors.orange),
    ),
  );
}

// ── 정렬 선택 칩 ─────────────────────────────────
class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.orange.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.orange : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.orange : Colors.grey,
          ),
        ),
      ),
    );
  }
}
