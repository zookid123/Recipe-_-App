// ===================== BACKUP =====================
// 롤백이 필요하면 이 파일 내용을 recipe_list_screen.dart에 덮어쓰세요
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'recipe_detail_screen.dart';

class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});
  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isSyncing = false;

  Future<void> syncToFirebase() async {
    setState(() => _isSyncing = true);
    const basicUrl =
        "http://211.237.50.150:7080/openapi/2ef64ea1d04581cf581f79eaec90862314df41f3c836075f4eeee7cbe096b7fa/json/Grid_20150827000000000226_1/1/100";
    const ingreUrl =
        "http://211.237.50.150:7080/openapi/2ef64ea1d04581cf581f79eaec90862314df41f3c836075f4eeee7cbe096b7fa/json/Grid_20150827000000000227_1/1/1000";
    const stepUrl =
        "http://211.237.50.150:7080/openapi/2ef64ea1d04581cf581f79eaec90862314df41f3c836075f4eeee7cbe096b7fa/json/Grid_20150827000000000228_1/1/1000";

    try {
      final responses = await Future.wait([
        http.get(Uri.parse(basicUrl)),
        http.get(Uri.parse(ingreUrl)),
        http.get(Uri.parse(stepUrl)),
      ]);
      var basicRows =
          jsonDecode(responses[0].body)['Grid_20150827000000000226_1']['row'] ??
          [];
      var ingreRows =
          jsonDecode(responses[1].body)['Grid_20150827000000000227_1']['row'] ??
          [];
      var stepRows =
          jsonDecode(responses[2].body)['Grid_20150827000000000228_1']['row'] ??
          [];

      for (var basic in basicRows) {
        String id = basic['RECIPE_ID'].toString().trim();
        List matchedIng = ingreRows
            .where((i) => i['RECIPE_ID'].toString().trim() == id)
            .map((i) => "${i['IRDNT_NM']} (${i['IRDNT_CPCTY'] ?? ''})")
            .toList();
        List matchedSteps =
            stepRows
                .where((s) => s['RECIPE_ID'].toString().trim() == id)
                .toList()
              ..sort(
                (a, b) => int.parse(
                  a['COOKING_NO'].toString(),
                ).compareTo(int.parse(b['COOKING_NO'].toString())),
              );
        List stepDescs = matchedSteps
            .map((s) => s['COOKING_DC'].toString())
            .toList();

        final existing = await _firestore.collection('recipes').doc(id).get();
        final existingData = existing.exists
            ? (existing.data() as Map<String, dynamic>)
            : <String, dynamic>{};

        final finalImgUrl = (existingData['imgUrl'] ?? '').isNotEmpty
            ? existingData['imgUrl']
            : (basic['IMG_URL'] ?? '');

        final viewCount = existingData['viewCount'] ?? 0;
        final todayViewCount = existingData['todayViewCount'] ?? 0;
        final yesterdayViewCount = existingData['yesterdayViewCount'] ?? 0;
        final todayDate = existingData['todayDate'] ?? '';
        final timeMinutes = _parseMinutes(basic['COOKING_TIME']);

        await _firestore.collection('recipes').doc(id).set({
          'name': basic['RECIPE_NM_KO'],
          'summary': basic['SUMRY'],
          'imgUrl': finalImgUrl,
          'calorie': basic['CALORIE'] ?? "정보 없음",
          'qnt': basic['QNT'] ?? "정보 없음",
          'time': basic['COOKING_TIME'] ?? "정보 없음",
          'timeMinutes': timeMinutes,
          'level': basic['LEVEL_NM'] ?? "정보 없음",
          'nation': basic['NATION_NM'] ?? "한식",
          'type': basic['TY_NM'] ?? "기타",
          'ingredients': matchedIng,
          'steps': stepDescs,
          'timestamp': FieldValue.serverTimestamp(),
          'viewCount': viewCount,
          'todayViewCount': todayViewCount,
          'yesterdayViewCount': yesterdayViewCount,
          'todayDate': todayDate,
        });
      }
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("동기화 완료!")));
    } catch (e) {
      debugPrint("Sync error: $e");
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  int _parseMinutes(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 999;
    int minutes = 0;
    final hourMatch = RegExp(r'(\d+)\s*시간').firstMatch(timeStr);
    final minMatch = RegExp(r'(\d+)\s*분').firstMatch(timeStr);
    if (hourMatch != null) minutes += int.parse(hourMatch.group(1)!) * 60;
    if (minMatch != null) minutes += int.parse(minMatch.group(1)!);
    return minutes > 0 ? minutes : 999;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("전체 레시피"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          _isSyncing
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(15),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: syncToFirebase,
                  icon: const Icon(Icons.sync),
                ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('recipes')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text("상단 동기화 버튼을 눌러주세요!"));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    child: const Icon(Icons.restaurant, color: Colors.orange),
                  ),
                  title: Text(
                    data['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${data['nation']} | ${data['time']}"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(recipe: data),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
