import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/trending_card.dart';
import '../widgets/recommend_card.dart';
import 'recipe_detail_screen.dart';
import 'my_page_screen.dart';
import 'search_screen.dart';
import 'ingredient_search_screen.dart';

// ── 홈 탭 루트 ────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _bannerCtrl = PageController();
  int _bannerPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (!_bannerCtrl.hasClients) return;
      final next = (_bannerPage + 1) % 4;
      _bannerCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bannerCtrl.dispose();
    super.dispose();
  }

  // 콘텐츠를 최대 1200px 너비로 중앙 정렬
  static Widget _cx(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1200),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cx(_Header()),
              const SizedBox(height: 16),
              _cx(
                _HeroBanner(
                  controller: _bannerCtrl,
                  currentPage: _bannerPage,
                  onPageChanged: (i) => setState(() => _bannerPage = i),
                ),
              ),
              const SizedBox(height: 20),
              _cx(_SearchBar()),
              const SizedBox(height: 16),
              _cx(_IngredientSearchBanner()),
              const SizedBox(height: 20),
              _cx(const _CategoryGrid()),
              const SizedBox(height: 8),
              // 트렌딩 – 흰 배경 (배경은 풀 width, 내용만 제한)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _cx(const _TrendingSection()),
              ),
              const SizedBox(height: 8),
              // 오늘의 추천 – 회색 배경
              Container(
                color: const Color(0xFFF5F5F5),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _cx(const _FeaturedSection()),
              ),
              const SizedBox(height: 8),
              // 어제 인기 – 흰 배경
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _cx(
                  _SimpleHorizontalSection(
                    emoji: '📅',
                    title: '어제 많이 본 레시피',
                    subtitle: '어제 인기 급상승 메뉴',
                    query: FirebaseFirestore.instance
                        .collection('recipes')
                        .orderBy('yesterdayViewCount', descending: true)
                        .limit(6),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 초간단 – 회색 배경
              Container(
                color: const Color(0xFFF5F5F5),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _cx(
                  _SimpleHorizontalSection(
                    emoji: '⚡',
                    title: '초간단 레시피',
                    subtitle: '25분 이하로 뚝딱!',
                    query: FirebaseFirestore.instance
                        .collection('recipes')
                        .where('timeMinutes', isGreaterThan: 0)
                        .where('timeMinutes', isLessThan: 25)
                        .orderBy('timeMinutes')
                        .limit(6),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 세계 요리 – 흰 배경
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _cx(
                  _SimpleHorizontalSection(
                    emoji: '🌏',
                    title: '세계 요리 탐험',
                    subtitle: '다양한 나라의 음식을 만나보세요',
                    query: FirebaseFirestore.instance
                        .collection('recipes')
                        .orderBy('nation')
                        .limit(6),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 헤더 ──────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '냉장고 구조대 🥦',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                '오늘도 맛있는 하루 되세요!',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyPageScreen()),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.15),
              child: const Icon(Icons.person, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 히어로 배너 슬라이더 ─────────────────────────────
class _HeroBanner extends StatelessWidget {
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  const _HeroBanner({
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .orderBy('viewCount', descending: true)
          .limit(4)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            height: 220,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        return Column(
          children: [
            SizedBox(
              height: 220,
              child: PageView.builder(
                controller: controller,
                onPageChanged: onPageChanged,
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final hasImage =
                      data['imgUrl'] != null &&
                      data['imgUrl'].toString().isNotEmpty;
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(recipe: data),
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        hasImage
                            ? Image.network(
                                data['imgUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _bannerPlaceholder(),
                              )
                            : _bannerPlaceholder(),
                        // 그라데이션 오버레이
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xCC000000)],
                              stops: [0.4, 1.0],
                            ),
                          ),
                        ),
                        // 순위 뱃지
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '🔥 인기 ${i + 1}위',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // 하단 텍스트
                        Positioned(
                          bottom: 20,
                          left: 16,
                          right: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 8)],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.restaurant,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    data['nation'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.access_time,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    data['time'] ?? '-',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.trending_up,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    data['level'] ?? '-',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 닷 인디케이터
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                docs.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == currentPage ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == currentPage
                        ? Colors.orange
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bannerPlaceholder() => Container(
    color: Colors.grey[200],
    child: const Center(
      child: Icon(Icons.restaurant, size: 64, color: Colors.orange),
    ),
  );
}

// ── 검색 바 ───────────────────────────────────────
class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 6),
            ],
          ),
          child: Row(
            children: const [
              Icon(Icons.search, color: Colors.orange),
              SizedBox(width: 10),
              Text(
                '요리명 또는 재료를 검색해보세요',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 카테고리 원형 그리드 ─────────────────────────────
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid();

  static const _categories = [
    ('🍚', '한식', '한식'),
    ('🍝', '양식', '서양'),
    ('🍜', '중식', '중국'),
    ('🍣', '일식', '일본'),
    ('🍛', '동남아', '동남아시아'),
    ('🍕', '이탈리아', '이탈리아'),
    ('🎭', '퓨전', '퓨전'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '카테고리',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          // 너비에 따라 열 수 자동 조정
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 500
                  ? 4
                  : constraints.maxWidth < 800
                  ? 7
                  : 7;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.88,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, i) {
                  final (emoji, label, query) = _categories[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(initialQuery: query),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
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
}

// ── 트렌딩 섹션 (1위 카드 크게) ───────────────────────
class _TrendingSection extends StatelessWidget {
  const _TrendingSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🔥  지금 뜨고 있는 요리!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 3),
              Text(
                '이번 주 조회수 급상승 레시피',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('recipes')
              .orderBy('viewCount', descending: true)
              .limit(6)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              );
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const SizedBox.shrink();
            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                if (isWide) {
                  // 넓은 화면: Wrap 그리드
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: docs.asMap().entries.map((e) {
                        final data = e.value.data() as Map<String, dynamic>;
                        return TrendingCard(
                          rank: e.key + 1,
                          data: data,
                          isLarge: e.key == 0,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecipeDetailScreen(recipe: data),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }
                // 좁은 화면: 가로 스크롤
                return SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      return TrendingCard(
                        rank: i + 1,
                        data: data,
                        isLarge: i == 0,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipe: data),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ── 오늘의 추천 피처드 섹션 ───────────────────────────
class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recipes')
          .orderBy('todayViewCount', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final title = const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '⭐  오늘의 추천 레시피',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            );
            final smallCards = docs.skip(1).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return RecommendCard(
                data: data,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(recipe: data),
                  ),
                ),
              );
            }).toList();

            if (isWide) {
              // 넓은 화면: 왼쪽 피처드 카드 + 오른쪽 추천 카드
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _FeaturedCard(
                            data: docs[0].data() as Map<String, dynamic>,
                            margin: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: Column(children: smallCards)),
                      ],
                    ),
                  ),
                ],
              );
            }

            // 좁은 화면: 기존 세로 배치
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 14),
                _FeaturedCard(data: docs[0].data() as Map<String, dynamic>),
                const SizedBox(height: 10),
                ...smallCards,
              ],
            );
          },
        );
      },
    );
  }
}

// ── 피처드 대형 카드 ─────────────────────────────────
class _FeaturedCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final EdgeInsets? margin;
  const _FeaturedCard({required this.data, this.margin});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        data['imgUrl'] != null && data['imgUrl'].toString().isNotEmpty;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: data)),
      ),
      child: Container(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 20),
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x25000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              hasImage
                  ? Image.network(
                      data['imgUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
              // 그라데이션
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xDD000000)],
                    stops: [0.3, 1.0],
                  ),
                ),
              ),
              // 추천 뱃지
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '⭐ 오늘의 추천 1위',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // 하단 정보
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 8)],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _infoChip(Icons.restaurant, data['nation'] ?? ''),
                        const SizedBox(width: 10),
                        _infoChip(Icons.access_time, data['time'] ?? '-'),
                        const SizedBox(width: 10),
                        _infoChip(Icons.trending_up, data['level'] ?? '-'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: Colors.white70),
      const SizedBox(width: 3),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    ],
  );

  Widget _placeholder() => Container(
    color: Colors.grey[300],
    child: const Center(
      child: Icon(Icons.restaurant, size: 48, color: Colors.white),
    ),
  );
}

// ── 일반 가로 스크롤 섹션 ──────────────────────────────
class _SimpleHorizontalSection extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Query query;

  const _SimpleHorizontalSection({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$emoji  $title',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                ),
              );
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const SizedBox.shrink();
            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                if (isWide) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return TrendingCard(
                          rank: -1,
                          data: data,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecipeDetailScreen(recipe: data),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }
                return SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      return TrendingCard(
                        rank: -1,
                        data: data,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipe: data),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ── 재료 검색 배너 ────────────────────────────────────
class _IngredientSearchBanner extends StatelessWidget {
  const _IngredientSearchBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IngredientSearchScreen()),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF9A56), Color(0xFFFFA726)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3FFF9A56),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              Icon(Icons.local_grocery_store, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '냉장고 재료로 찾기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '있는 재료로 만들 수 있는 요리는?',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
