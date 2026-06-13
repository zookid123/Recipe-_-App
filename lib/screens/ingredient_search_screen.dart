import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/ingredients.dart';
import 'recipe_detail_screen.dart';

class IngredientSearchScreen extends StatefulWidget {
  final List<String> initialIngredients;
  const IngredientSearchScreen({super.key, this.initialIngredients = const []});

  @override
  State<IngredientSearchScreen> createState() =>
      _IngredientSearchScreenState();
}

class _IngredientSearchScreenState extends State<IngredientSearchScreen> {
  final _ctrl = TextEditingController();
  final List<String> _myIngredients = [];
  List<_RecipeMatch> _results = [];
  bool _loading = false;
  List<Map<String, dynamic>> _allRecipes = [];

  String? _levelFilter;
  int? _maxTime;

  static const _levels = ['전체', '초급', '중급', '고급'];
  static const List<(int?, String)> _times = [
    (null, '⏱ 전체'),
    (30, '30분 이하'),
    (60, '1시간 이하'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialIngredients.isNotEmpty) {
      _myIngredients.addAll(widget.initialIngredients);
    }
    _loadRecipes();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() => _loading = true);
    final snap = await FirebaseFirestore.instance.collection('recipes').get();
    _allRecipes = snap.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();
    if (mounted) setState(() => _loading = false);
    _search();
  }

  void _addIngredient(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _myIngredients.contains(trimmed)) {
      _ctrl.clear();
      return;
    }
    setState(() {
      _myIngredients.add(trimmed);
      _ctrl.clear();
    });
    _search();
  }

  void _removeIngredient(String tag) {
    setState(() => _myIngredients.remove(tag));
    _search();
  }

  void _search() {
    if (_myIngredients.isEmpty) {
      setState(() => _results = []);
      return;
    }

    final matches = <_RecipeMatch>[];
    for (final recipe in _allRecipes) {
      // 난이도 필터
      if (_levelFilter != null) {
        final recipeLevel = recipe['level']?.toString() ?? '';
        if (!recipeLevel.contains(_levelFilter!)) continue;
      }
      // 시간 필터
      if (_maxTime != null) {
        final mins = recipe['timeMinutes'];
        if (mins == null || mins is! num || mins > _maxTime!) continue;
      }

      final ingList = recipe['ingredients'] as List? ?? [];
      if (ingList.isEmpty) continue;

      final recipeNames = ingList
          .map((i) => i.toString().split('(').first.trim().toLowerCase())
          .toList();

      int matched = 0;
      final missing = <String>[];

      for (int idx = 0; idx < recipeNames.length; idx++) {
        final ri = recipeNames[idx];
        final hit = _myIngredients.any((mi) {
          final m = mi.trim().toLowerCase();
          return ri.contains(m) || m.contains(ri);
        });
        if (hit) {
          matched++;
        } else {
          missing.add(ingList[idx].toString());
        }
      }

      final rate = matched / recipeNames.length;
      if (rate > 0) {
        matches.add(_RecipeMatch(recipe: recipe, rate: rate, missing: missing));
      }
    }

    matches.sort((a, b) => b.rate.compareTo(a.rate));
    setState(() => _results = matches);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('냉장고 재료로 찾기',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          // 재료 입력 영역
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            color: const Color(0xFFFFF8F0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '냉장고에 있는 재료를 입력해주세요',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        decoration: InputDecoration(
                          hintText: '예: 계란, 두부, 감자...',
                          hintStyle:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: Colors.orange.withOpacity(0.4)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: Colors.orange.withOpacity(0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                                color: Colors.orange, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: _addIngredient,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _addIngredient(_ctrl.text),
                      child: Container(
                        padding: const EdgeInsets.all(11),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                if (_myIngredients.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _myIngredients.map((tag) {
                      return Chip(
                        label: Text(tag,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.orange,
                        deleteIcon:
                            const Icon(Icons.close, size: 16, color: Colors.white),
                        onDeleted: () => _removeIngredient(tag),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 10),
                const Text('자주 쓰는 재료',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: kCommonIngredients
                      .where((i) => !_myIngredients.contains(i))
                      .map((tag) => GestureDetector(
                            onTap: () => _addIngredient(tag),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.orange.withOpacity(0.4)),
                              ),
                              child: Text(tag,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),

          // 필터 행
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: Row(
              children: [
                const Text('난이도',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 8),
                ..._levels.map((lv) {
                  final isAll = lv == '전체';
                  final selected = isAll
                      ? _levelFilter == null
                      : _levelFilter == lv;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _levelFilter = isAll ? null : lv);
                      _search();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.orange
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(lv,
                          style: TextStyle(
                              fontSize: 12,
                              color: selected
                                  ? Colors.white
                                  : Colors.black54,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ),
                  );
                }),
                const Spacer(),
                DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _maxTime,
                    isDense: true,
                    hint: const Text('⏱ 전체',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey)),
                    items: _times.map((t) {
                      final (val, label) = t;
                      return DropdownMenuItem<int?>(
                        value: val,
                        child: Text(label,
                            style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _maxTime = val);
                      _search();
                    },
                  ),
                ),
              ],
            ),
          ),

          // 결과 리스트
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange))
                : _myIngredients.isEmpty
                    ? _emptyPrompt()
                    : _results.isEmpty
                        ? _noResults()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                            itemCount: _results.length + 1,
                            itemBuilder: (context, i) {
                              if (i == 0) {
                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 8, 16, 10),
                                  child: Text(
                                    '${_results.length}개의 레시피를 찾았어요',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.grey),
                                  ),
                                );
                              }
                              return _MatchCard(match: _results[i - 1]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _emptyPrompt() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('🥦', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            Text('냉장고 재료를 입력하면',
                style: TextStyle(fontSize: 16, color: Colors.black87)),
            SizedBox(height: 4),
            Text('만들 수 있는 레시피를 알려드려요!',
                style: TextStyle(fontSize: 16, color: Colors.black87)),
            SizedBox(height: 8),
            Text('계란, 두부, 감자 처럼 입력해보세요',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );

  Widget _noResults() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.search_off, size: 52, color: Colors.grey),
            SizedBox(height: 12),
            Text('입력한 재료로 만들 수 있는',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
            Text('레시피가 없어요 😔',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
            SizedBox(height: 8),
            Text('다른 재료를 추가해보세요',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
}

// ── 데이터 모델 ───────────────────────────────────────
class _RecipeMatch {
  final Map<String, dynamic> recipe;
  final double rate;
  final List<String> missing;
  const _RecipeMatch(
      {required this.recipe, required this.rate, required this.missing});
}

// ── 매칭 결과 카드 ─────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final _RecipeMatch match;
  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final recipe = match.recipe;
    final pct = (match.rate * 100).round();
    final hasImage = recipe['imgUrl'] != null &&
        recipe['imgUrl'].toString().isNotEmpty;

    final Color rateColor;
    if (pct >= 80) {
      rateColor = Colors.green;
    } else if (pct >= 50) {
      rateColor = Colors.orange;
    } else {
      rateColor = Colors.red.shade300;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => RecipeDetailScreen(recipe: recipe)),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000),
                blurRadius: 8,
                offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16)),
              child: hasImage
                  ? Image.network(
                      recipe['imgUrl'],
                      width: 100,
                      height: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPlaceholder(),
                    )
                  : _imgPlaceholder(),
            ),
            // 정보
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: rateColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '재료 매칭 $pct%',
                            style: TextStyle(
                                fontSize: 12,
                                color: rateColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 56,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: match.rate,
                              backgroundColor: Colors.grey.shade200,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(rateColor),
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recipe['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${recipe['nation'] ?? ''} · ${recipe['time'] ?? '-'} · ${recipe['level'] ?? '-'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (match.missing.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      RichText(
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: const TextStyle(fontSize: 11),
                          children: [
                            const TextSpan(
                              text: '없는 재료: ',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500),
                            ),
                            TextSpan(
                              text: match.missing.join(', '),
                              style:
                                  TextStyle(color: Colors.red.shade300),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 100,
        height: 110,
        color: const Color(0xFFFFF8F0),
        child: const Center(
            child: Icon(Icons.restaurant, color: Colors.orange, size: 32)),
      );
}
