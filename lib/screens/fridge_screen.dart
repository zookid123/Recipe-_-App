import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/ingredients.dart';
import '../services/auth_service.dart';
import 'ingredient_search_screen.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── 데이터 로드 ─────────────────────────────────────
  Future<void> _load() async {
    final user = AuthService.instance.currentUser;
    List<Map<String, dynamic>> items = [];

    if (user != null) {
      final snap = await FirebaseFirestore.instance
          .collection('users').doc(user.id)
          .collection('fridge')
          .orderBy('addedAt', descending: false)
          .get();
      items = snap.docs.map((d) => {'_id': d.id, ...d.data()}).toList();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('my_fridge') ?? [];
      items = raw.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    }

    if (mounted) setState(() { _items = items; _loading = false; });
  }

  // ── 재료 추가 다이얼로그 ────────────────────────────
  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    DateTime? expiryDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('재료 추가', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: _inputDeco('재료 이름 *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtyCtrl,
                decoration: _inputDeco('수량 (예: 2개, 500g) — 선택'),
              ),
              const SizedBox(height: 10),
              // 자주 쓰는 재료 칩
              Align(
                alignment: Alignment.centerLeft,
                child: const Text('자주 쓰는 재료',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: kCommonIngredients
                    .where((i) => !_items.any((e) => e['name'] == i))
                    .map((tag) => GestureDetector(
                          onTap: () => setDlg(() => nameCtrl.text = tag),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: nameCtrl.text == tag
                                  ? Colors.orange
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: nameCtrl.text == tag
                                    ? Colors.orange
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: nameCtrl.text == tag
                                      ? Colors.white
                                      : Colors.black87,
                                )),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now().subtract(const Duration(days: 1)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    helpText: '유통기한 선택',
                    builder: (c, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(primary: Colors.orange),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setDlg(() => expiryDate = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      expiryDate != null
                          ? '유통기한: ${_formatDate(expiryDate!)}'
                          : '유통기한 선택 (선택)',
                      style: TextStyle(
                        fontSize: 13,
                        color: expiryDate != null ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    if (expiryDate != null) ...[
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setDlg(() => expiryDate = null),
                        child: const Icon(Icons.close, size: 14, color: Colors.grey),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                _addItem(
                  name: nameCtrl.text.trim(),
                  quantity: qtyCtrl.text.trim(),
                  expiryDate: expiryDate,
                );
              },
              child: const Text('추가', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 재료 추가 저장 ──────────────────────────────────
  Future<void> _addItem({required String name, String quantity = '', DateTime? expiryDate}) async {
    final expStr = expiryDate != null ? _isoDate(expiryDate) : null;
    final user = AuthService.instance.currentUser;

    if (user != null) {
      final ref = await FirebaseFirestore.instance
          .collection('users').doc(user.id)
          .collection('fridge')
          .add({
        'name': name,
        'quantity': quantity,
        'expiryDate': expStr,
        'addedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _items.add({
        '_id': ref.id,
        'name': name,
        'quantity': quantity,
        'expiryDate': expStr,
      }));
    } else {
      final entry = {
        '_id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'quantity': quantity,
        'expiryDate': expStr,
        'addedAt': DateTime.now().toIso8601String(),
      };
      setState(() => _items.add(entry));
      await _saveLocal();
    }
  }

  // ── 재료 삭제 ──────────────────────────────────────
  Future<void> _deleteItem(int index) async {
    final item = _items[index];
    final user = AuthService.instance.currentUser;

    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users').doc(user.id)
          .collection('fridge').doc(item['_id'])
          .delete();
    }
    setState(() => _items.removeAt(index));
    if (user == null) await _saveLocal();
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('my_fridge', _items.map(jsonEncode).toList());
  }

  // ── 냉장고 파먹기 연동 ─────────────────────────────
  void _goToSearch() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 재료를 추가해주세요.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IngredientSearchScreen(
          initialIngredients: _items.map((e) => e['name'] as String).toList(),
        ),
      ),
    );
  }

  // ── 유통기한 상태 ──────────────────────────────────
  _ExpiryStatus _getStatus(String? expStr) {
    if (expStr == null || expStr.isEmpty) return _ExpiryStatus.none;
    final exp = DateTime.tryParse(expStr);
    if (exp == null) return _ExpiryStatus.none;
    final diff = exp.difference(DateTime.now()).inDays;
    if (diff < 0) return _ExpiryStatus.expired;
    if (diff <= 3) return _ExpiryStatus.soon;
    return _ExpiryStatus.ok;
  }

  // ── 날짜 포맷 ──────────────────────────────────────
  String _formatDate(DateTime dt) => '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  String _isoDate(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _dDayText(String? expStr) {
    if (expStr == null || expStr.isEmpty) return '';
    final exp = DateTime.tryParse(expStr);
    if (exp == null) return '';
    final diff = exp.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
    if (diff < 0) return 'D+${-diff}';
    if (diff == 0) return 'D-Day';
    return 'D-$diff';
  }

  // ── 정렬: 만료임박 → 여유 → 날짜없음 순 ─────────────
  List<Map<String, dynamic>> get _sortedItems {
    final expired = <Map<String, dynamic>>[];
    final soon = <Map<String, dynamic>>[];
    final ok = <Map<String, dynamic>>[];
    final none = <Map<String, dynamic>>[];

    for (final item in _items) {
      switch (_getStatus(item['expiryDate'])) {
        case _ExpiryStatus.expired: expired.add(item);
        case _ExpiryStatus.soon: soon.add(item);
        case _ExpiryStatus.ok: ok.add(item);
        case _ExpiryStatus.none: none.add(item);
      }
    }
    return [...expired, ...soon, ...ok, ...none];
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedItems;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('나만의 냉장고', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _goToSearch,
              icon: const Icon(Icons.search, size: 18, color: Colors.orange),
              label: const Text('요리 찾기', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_fridge_add',
        onPressed: _showAddDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Column(
              children: [
                // 요약 배너
                if (_items.isNotEmpty) _buildSummaryBanner(),
                // 재료 목록
                Expanded(
                  child: _items.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: sorted.length,
                          itemBuilder: (context, i) => _buildItem(sorted, i),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryBanner() {
    final expiredCount = _items.where((e) => _getStatus(e['expiryDate']) == _ExpiryStatus.expired).length;
    final soonCount = _items.where((e) => _getStatus(e['expiryDate']) == _ExpiryStatus.soon).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        const Icon(Icons.kitchen, color: Colors.orange, size: 20),
        const SizedBox(width: 8),
        Text('총 ${_items.length}가지 재료',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (expiredCount > 0)
          _badge('만료 $expiredCount', Colors.red),
        if (soonCount > 0) ...[
          const SizedBox(width: 6),
          _badge('임박 $soonCount', Colors.orange),
        ],
      ]),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
  );

  Widget _buildItem(List<Map<String, dynamic>> sorted, int i) {
    final item = sorted[i];
    final status = _getStatus(item['expiryDate']);
    final dDay = _dDayText(item['expiryDate']);
    final realIndex = _items.indexOf(item);

    final Color statusColor;
    final String statusLabel;
    switch (status) {
      case _ExpiryStatus.expired:
        statusColor = Colors.red; statusLabel = '만료됨';
      case _ExpiryStatus.soon:
        statusColor = Colors.orange; statusLabel = '임박';
      case _ExpiryStatus.ok:
        statusColor = Colors.green; statusLabel = '여유';
      case _ExpiryStatus.none:
        statusColor = Colors.grey; statusLabel = '';
    }

    return Dismissible(
      key: Key(item['_id'] ?? i.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => _deleteItem(realIndex),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6)],
          border: status != _ExpiryStatus.none
              ? Border.all(color: statusColor.withOpacity(0.3))
              : null,
        ),
        child: Row(children: [
          // 상태 인디케이터
          Container(
            width: 8, height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(status == _ExpiryStatus.none ? 0.2 : 0.7),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          // 재료 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(item['name'] ?? '',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  if ((item['quantity'] ?? '').isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(item['quantity'],
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ]),
                if (item['expiryDate'] != null && (item['expiryDate'] as String).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(
                      item['expiryDate'].toString().replaceAll('-', '.'),
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        dDay,
                        style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (statusLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(statusLabel, style: TextStyle(fontSize: 11, color: statusColor)),
                    ],
                  ]),
                ],
              ],
            ),
          ),
          // 삭제 버튼
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
            onPressed: () => _deleteItem(realIndex),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🥦', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 16),
        const Text('냉장고가 비어있어요!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('+ 버튼을 눌러 재료를 추가해보세요',
            style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add),
          label: const Text('재료 추가하기'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    ),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
    filled: true,
    fillColor: const Color(0xFFF8F8F8),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.orange, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

enum _ExpiryStatus { expired, soon, ok, none }
