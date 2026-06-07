import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  UserProgress _progress = const UserProgress();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _loading = true);
    final progress = await AuthService.instance.fetchUserProgress();
    if (mounted) {
      setState(() {
        _progress = progress;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.instance.isLoggedIn;
    final earned = _progress.earnedTitles;
    final totalEarned = _progress.regularEarnedCount;
    final percent = (totalEarned / 26 * 100).clamp(0, 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('업적 및 도전과제'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadProgress,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : !isLoggedIn
              ? _buildLockedOverlay()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // 상단 통계 헤더
                      _buildHeader(totalEarned, percent),
                      
                      const SizedBox(height: 20),
                      
                      // 특별 업적
                      _buildSpecialAchievements(earned),
                      
                      const SizedBox(height: 12),
                      
                      // 카테고리별 업적
                      _buildCategory(
                        '레시피 탐험가',
                        '다양한 요리법을 읽어보세요',
                        [
                          _Achievement('식탐러', 10, _progress.recipeViews),
                          _Achievement('레시피 헌터', 50, _progress.recipeViews),
                          _Achievement('미식 탐험가', 100, _progress.recipeViews),
                          _Achievement('전설의 미식가', 300, _progress.recipeViews),
                        ],
                      ),
                      _buildCategory(
                        '즐겨찾기 수집가',
                        '나만의 레시피북을 채워보세요',
                        [
                          _Achievement('메모장', 5, _progress.bookmarks),
                          _Achievement('레시피 수집가', 20, _progress.bookmarks),
                          _Achievement('북마크 마니아', 50, _progress.bookmarks),
                          _Achievement('레시피 도서관', 100, _progress.bookmarks),
                        ],
                      ),
                      _buildCategory(
                        '레시피 평론가',
                        '솔직한 요리 후기를 남겨주세요',
                        [
                          _Achievement('맛 초보', 3, _progress.comments),
                          _Achievement('맛 평론가', 10, _progress.comments),
                          _Achievement('미슐랭 가이드', 30, _progress.comments),
                          _Achievement('식신', 50, _progress.comments),
                        ],
                      ),
                      _buildCategory(
                        '커뮤니티 주민',
                        '냉장고 구조대 이웃들과 소통해요',
                        [
                          _Achievement('새내기', 1, _progress.communityPosts),
                          _Achievement('이웃', 5, _progress.communityPosts),
                          _Achievement('단골손님', 15, _progress.communityPosts),
                          _Achievement('터줏대감', 30, _progress.communityPosts),
                        ],
                      ),
                      _buildCategory(
                        '레시피 창작자',
                        '나만의 특별한 레시피를 공유하세요',
                        [
                          _Achievement('견습생', 1, _progress.createdRecipes),
                          _Achievement('요리사', 3, _progress.createdRecipes),
                          _Achievement('셰프', 10, _progress.createdRecipes),
                          _Achievement('미슐랭 셰프', 20, _progress.createdRecipes),
                        ],
                      ),
                      _buildCategory(
                        '세계 요리 탐방',
                        '여러 국가의 요리를 북마크하세요',
                        [
                          _Achievement('동네 미식가', 3, _progress.nations),
                          _Achievement('세계 여행자', 5, _progress.nations),
                          _Achievement('세계 미식 대가', 7, _progress.nations),
                        ],
                      ),
                      _buildCategory(
                        '냉장고 파먹기',
                        '재료 검색으로 낭비를 줄이세요',
                        [
                          _Achievement('냉장고 청소부', 5, _progress.fridgeSearches),
                          _Achievement('절약 요리사', 20, _progress.fridgeSearches),
                          _Achievement('재료 연금술사', 50, _progress.fridgeSearches),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader(int totalEarned, int percent) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange, Color(0xFFFFAB40)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip('총 업적', '$totalEarned/26'),
              _buildStatChip('카테고리', '7개'),
              _buildStatChip('특별 업적', '${_progress.earnedTitles.where((t) => ['얼리버드', '완벽주의자', '전설'].contains(t)).length}/3'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('전체 진행도', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('$percent%', style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildSpecialAchievements(Set<String> earned) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('특별 업적', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Row(
            children: [
              _buildSpecialCard('얼리버드', '첫 가입 로그인', earned.contains('얼리버드'), '🐥'),
              const SizedBox(width: 10),
              _buildSpecialCard('완벽주의자', '모든 카테고리 입문', earned.contains('완벽주의자'), '🎯', 
                               progress: '${_progress.earnedTitles.where((t) => !['얼리버드', '완벽주의자', '전설'].contains(t)).length}/7'),
              const SizedBox(width: 10),
              _buildSpecialCard('전설', '모든 업적 달성', earned.contains('전설'), '👑', 
                               progress: '${_progress.regularEarnedCount}/26'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialCard(String title, String desc, bool isEarned, String emoji, {String? progress}) {
    return Expanded(
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: isEarned ? Colors.white : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: isEarned ? Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5) : null,
          boxShadow: isEarned ? [const BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 4))] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: TextStyle(fontSize: 28, color: isEarned ? null : Colors.grey)),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isEarned ? Colors.orange : Colors.grey[600])),
            if (progress != null) ...[
              const SizedBox(height: 4),
              Text(progress, style: TextStyle(fontSize: 11, color: isEarned ? Colors.orange[300] : Colors.grey[500])),
            ] else ...[
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(fontSize: 10, color: Colors.grey[500]), textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(String title, String sub, List<_Achievement> list) {
    final earnedInCat = list.where((a) => a.isEarned).length;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 8),
              _buildBadge('$earnedInCat/${list.length}'),
            ],
          ),
          subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: list.map((a) => _buildAchievementTile(a)).toList(),
        ),
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAchievementTile(_Achievement a) {
    final percent = (a.current / a.goal * 100).clamp(0, 100).toInt();
    final isEarned = a.isEarned;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isEarned ? '✅' : '🔒',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  a.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isEarned ? FontWeight.bold : FontWeight.normal,
                    color: isEarned ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
              Text(
                '${a.current}/${a.goal}',
                style: TextStyle(fontSize: 12, color: isEarned ? Colors.orange : Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: a.current / a.goal,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(isEarned ? Colors.orange : Colors.grey[400]),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$percent%', style: TextStyle(fontSize: 11, color: isEarned ? Colors.orange : Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLockedOverlay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('로그인이 필요한 메뉴입니다', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('로그인하고 나만의 요리 업적을 달성해보세요!', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _Achievement {
  final String title;
  final int goal;
  final int current;
  _Achievement(this.title, this.goal, this.current);

  bool get isEarned => current >= goal;
}
