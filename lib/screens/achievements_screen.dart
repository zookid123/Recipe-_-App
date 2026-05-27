import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  UserProgress? _progress;
  bool _loading = true;

  static final _categories = [
    _AchievementCategory(
      icon: Icons.explore_rounded,
      color: const Color(0xFFFF6B35),
      title: '레시피 탐험가',
      subtitle: '레시피 조회 횟수',
      progressOf: (p) => p.recipeViews,
      achievements: [
        _Achievement('식탐러', '레시피 10개 조회', 10),
        _Achievement('레시피 헌터', '레시피 50개 조회', 50),
        _Achievement('미식 탐험가', '레시피 100개 조회', 100),
        _Achievement('전설의 미식가', '레시피 300개 조회', 300),
      ],
    ),
    _AchievementCategory(
      icon: Icons.bookmark_rounded,
      color: const Color(0xFF4ECDC4),
      title: '즐겨찾기 수집가',
      subtitle: '즐겨찾기 등록 개수',
      progressOf: (p) => p.bookmarks,
      achievements: [
        _Achievement('메모장', '즐겨찾기 5개 등록', 5),
        _Achievement('레시피 수집가', '즐겨찾기 20개 등록', 20),
        _Achievement('북마크 마니아', '즐겨찾기 50개 등록', 50),
        _Achievement('레시피 도서관', '즐겨찾기 100개 등록', 100),
      ],
    ),
    _AchievementCategory(
      icon: Icons.rate_review_rounded,
      color: const Color(0xFF9B59B6),
      title: '레시피 평론가',
      subtitle: '댓글 작성 수',
      progressOf: (p) => p.comments,
      achievements: [
        _Achievement('맛 초보', '댓글 3개 작성', 3),
        _Achievement('맛 평론가', '댓글 10개 작성', 10),
        _Achievement('미슐랭 가이드', '댓글 30개 작성', 30),
        _Achievement('식신', '댓글 50개 작성', 50),
      ],
    ),
    _AchievementCategory(
      icon: Icons.people_rounded,
      color: const Color(0xFF3498DB),
      title: '커뮤니티 주민',
      subtitle: '게시글 작성 수',
      progressOf: (p) => p.communityPosts,
      achievements: [
        _Achievement('새내기', '게시글 1개 작성', 1),
        _Achievement('이웃', '게시글 5개 작성', 5),
        _Achievement('단골손님', '게시글 15개 작성', 15),
        _Achievement('터줏대감', '게시글 30개 작성', 30),
      ],
    ),
    _AchievementCategory(
      icon: Icons.restaurant_menu_rounded,
      color: const Color(0xFFE67E22),
      title: '레시피 창작자',
      subtitle: '레시피 등록 수',
      progressOf: (p) => p.recipesCreated,
      achievements: [
        _Achievement('견습생', '레시피 1개 등록', 1),
        _Achievement('요리사', '레시피 3개 등록', 3),
        _Achievement('셰프', '레시피 10개 등록', 10),
        _Achievement('미슐랭 셰프', '레시피 20개 등록', 20),
      ],
    ),
    _AchievementCategory(
      icon: Icons.public_rounded,
      color: const Color(0xFF27AE60),
      title: '세계 요리 탐방',
      subtitle: '즐겨찾기 국가 다양성',
      progressOf: (p) => p.nationsExplored,
      achievements: [
        _Achievement('동네 미식가', '3개국 이상 요리 즐겨찾기', 3),
        _Achievement('세계 여행자', '5개국 이상 요리 즐겨찾기', 5),
        _Achievement('세계 미식 대가', '7개국 이상 요리 즐겨찾기', 7),
      ],
    ),
    _AchievementCategory(
      icon: Icons.kitchen_rounded,
      color: const Color(0xFF1ABC9C),
      title: '냉장고 파먹기',
      subtitle: '재료 기반 검색 횟수',
      progressOf: (p) => p.fridgeSearches,
      achievements: [
        _Achievement('냉장고 청소부', '재료 검색 5회', 5),
        _Achievement('절약 요리사', '재료 검색 20회', 20),
        _Achievement('재료 연금술사', '재료 검색 50회', 50),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _loading = true);
    final p = await AuthService.instance.fetchUserProgress();
    if (mounted) setState(() { _progress = p; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final earned = progress?.earnedTitles ?? {};
    final totalEarned = earned.length;
    final isLoggedIn = AuthService.instance.isLoggedIn;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('업적 & 도전과제'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadProgress,
              tooltip: '새로고침',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(totalEarned, isLoggedIn),
                  const SizedBox(height: 20),

                  // 특별 업적
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('✨ 특별 업적'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _SpecialCard(
                                emoji: '🌅',
                                title: '얼리버드',
                                description: '가입 후 첫 로그인',
                                isEarned: earned.contains('얼리버드'),
                                color: const Color(0xFFFF6B35),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SpecialCard(
                                emoji: '🏆',
                                title: '완벽주의자',
                                description: '모든 카테고리 최소 1개',
                                isEarned: earned.contains('완벽주의자'),
                                color: const Color(0xFF3498DB),
                                current: _categoriesWithAchievement(earned),
                                max: 7,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SpecialCard(
                                emoji: '👑',
                                title: '전설',
                                description: '모든 업적 달성',
                                isEarned: earned.contains('전설'),
                                color: const Color(0xFF9B59B6),
                                current: progress?.regularEarned ?? 0,
                                max: 26,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 카테고리별 도전과제
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _sectionLabel('🎯 카테고리별 도전과제'),
                  ),
                  const SizedBox(height: 10),

                  if (!isLoggedIn)
                    _buildLoginPrompt()
                  else
                    ..._categories.map((cat) => _CategoryCard(
                          category: cat,
                          currentValue: cat.progressOf(progress!),
                          earnedTitles: earned,
                        )),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  int _categoriesWithAchievement(Set<String> earned) {
    return _categories
        .where((cat) => cat.achievements.any((a) => earned.contains(a.title)))
        .length;
  }

  Widget _buildHeader(int totalEarned, bool isLoggedIn) {
    final percent = isLoggedIn ? (totalEarned / 29).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '나의 업적',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '도전과제를 달성하고 나만의 프로필을 꾸며보세요!',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(
                icon: Icons.emoji_events_rounded,
                label: '획득',
                value: isLoggedIn ? '$totalEarned / 29' : '- / 29',
              ),
              const SizedBox(width: 12),
              _StatChip(
                icon: Icons.category_rounded,
                label: '카테고리',
                value: '7개',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('전체 진행도',
                  style: TextStyle(fontSize: 12, color: Colors.white70)),
              Text(
                '${(percent * 100).round()}%',
                style: const TextStyle(
                    fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              color: Colors.white,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.lock_outline_rounded, size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              '로그인 후 업적 진행도를 확인할 수 있어요',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
    );
  }
}

// ── 특별 업적 카드 ────────────────────────────────────────────

class _SpecialCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final bool isEarned;
  final Color color;
  final int? current;
  final int? max;

  const _SpecialCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.isEarned,
    required this.color,
    this.current,
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: isEarned ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
        border: Border.all(
          color: isEarned ? color.withValues(alpha: 0.3) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
              if (isEarned)
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isEarned ? color : Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          const SizedBox(height: 6),
          if (isEarned)
            Text('달성!',
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w700))
          else if (current != null && max != null) ...[
            Text(
              '$current / $max',
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (current! / max!).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                color: color,
                minHeight: 3,
              ),
            ),
          ] else
            Text('미달성',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

// ── 카테고리 카드 ─────────────────────────────────────────────

class _CategoryCard extends StatefulWidget {
  final _AchievementCategory category;
  final int currentValue;
  final Set<String> earnedTitles;

  const _CategoryCard({
    required this.category,
    required this.currentValue,
    required this.earnedTitles,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;
    final earnedCount =
        cat.achievements.where((a) => widget.earnedTitles.contains(a.title)).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
      ),
      child: Column(
        children: [
          // 헤더
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.title,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF333333))),
                        Text(cat.subtitle,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: earnedCount > 0
                          ? cat.color.withValues(alpha: 0.12)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$earnedCount / ${cat.achievements.length} 달성',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: earnedCount > 0 ? cat.color : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: cat.achievements.asMap().entries.map((e) {
                  final isEarned = widget.earnedTitles.contains(e.value.title);
                  final isLast = e.key == cat.achievements.length - 1;
                  return _AchievementTile(
                    achievement: e.value,
                    index: e.key,
                    color: cat.color,
                    currentValue: widget.currentValue,
                    isEarned: isEarned,
                    isLast: isLast,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 업적 타일 ─────────────────────────────────────────────────

class _AchievementTile extends StatelessWidget {
  final _Achievement achievement;
  final int index;
  final Color color;
  final int currentValue;
  final bool isEarned;
  final bool isLast;

  const _AchievementTile({
    required this.achievement,
    required this.index,
    required this.color,
    required this.currentValue,
    required this.isEarned,
    required this.isLast,
  });

  static const _tierIcons = ['🥉', '🥈', '🥇', '💎'];

  @override
  Widget build(BuildContext context) {
    final tierEmoji = index < _tierIcons.length ? _tierIcons[index] : '🏆';
    final progress = (currentValue / achievement.threshold).clamp(0.0, 1.0);
    final displayValue = currentValue.clamp(0, achievement.threshold);
    final activeColor = isEarned ? color : Colors.grey.shade400;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isEarned ? color.withValues(alpha: 0.06) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEarned ? color.withValues(alpha: 0.2) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(tierEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      achievement.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isEarned ? color : Colors.grey.shade600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$displayValue / ${achievement.threshold}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: activeColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    isEarned
                        ? Icon(Icons.check_circle_rounded,
                            color: color, size: 18)
                        : Icon(Icons.lock_outline_rounded,
                            color: Colors.grey.shade400, size: 18),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    color: activeColor,
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      achievement.description,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isEarned ? color : Colors.grey,
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
  }
}

// ── 헤더 StatChip ─────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text(label,
                  style: const TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 데이터 모델 ───────────────────────────────────────────────

class _AchievementCategory {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int Function(UserProgress) progressOf;
  final List<_Achievement> achievements;

  const _AchievementCategory({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.progressOf,
    required this.achievements,
  });
}

class _Achievement {
  final String title;
  final String description;
  final int threshold;

  const _Achievement(this.title, this.description, this.threshold);
}
