import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class StepData {
  final TextEditingController controller;
  Uint8List? imageBytes;
  String? existingImageUrl;

  StepData({required String text, this.existingImageUrl})
    : controller = TextEditingController(text: text);

  void dispose() => controller.dispose();
}

class RecipeCreateScreen extends StatefulWidget {
  final Map<String, dynamic>? existingRecipe;
  final String? docId;

  const RecipeCreateScreen({super.key, this.existingRecipe, this.docId});

  @override
  State<RecipeCreateScreen> createState() => _RecipeCreateScreenState();
}

class _RecipeCreateScreenState extends State<RecipeCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _calorieCtrl = TextEditingController();
  final _qntCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  String _nation = '한식';
  String _type = '기타';
  String _level = '초급';

  // 대표 이미지
  Uint8List? _mainImageBytes;
  String? _existingMainImageUrl;

  final List<TextEditingController> _ingredients = [TextEditingController()];
  final List<StepData> _stepDataList = [StepData(text: '')];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingRecipe != null) {
      _loadExistingData();
    } else {
      _loadDraft();
    }
  }

  void _loadExistingData() {
    final r = widget.existingRecipe!;
    _nameCtrl.text = r['name'] ?? '';
    _summaryCtrl.text = r['summary'] ?? '';
    _calorieCtrl.text = (r['calorie'] ?? '')
        .toString()
        .replaceAll('kcal', '')
        .replaceAll('정보 없음', '');
    _qntCtrl.text = (r['qnt'] ?? '')
        .toString()
        .replaceAll('인분', '')
        .replaceAll('정보 없음', '');
    _timeCtrl.text = r['timeMinutes']?.toString() ?? '';
    _nation = r['nation'] ?? '한식';
    _type = r['type'] ?? '기타';
    _level = r['level'] ?? '초급';
    _existingMainImageUrl = r['imgUrl'];

    _ingredients.clear();
    for (var ing in (r['ingredients'] as List? ?? [])) {
      _ingredients.add(TextEditingController(text: ing.toString()));
    }
    if (_ingredients.isEmpty) _ingredients.add(TextEditingController());

    _stepDataList.clear();
    final steps = r['steps'] as List? ?? [];
    final stepImages = r['stepImages'] as List? ?? [];

    for (int i = 0; i < steps.length; i++) {
      String? img;
      if (i < stepImages.length) img = stepImages[i];
      _stepDataList.add(
        StepData(text: steps[i].toString(), existingImageUrl: img),
      );
    }
    if (_stepDataList.isEmpty) _stepDataList.add(StepData(text: ''));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _summaryCtrl.dispose();
    _calorieCtrl.dispose();
    _qntCtrl.dispose();
    _timeCtrl.dispose();
    for (final c in _ingredients) c.dispose();
    for (final s in _stepDataList) s.dispose();
    super.dispose();
  }

  // ── 임시 저장 관련 ─────────────────────────────────
  Future<void> _saveDraft() async {
    if (widget.existingRecipe != null) return;
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'name': _nameCtrl.text,
      'summary': _summaryCtrl.text,
      'ingredients': _ingredients.map((c) => c.text).toList(),
      'steps': _stepDataList.map((s) => s.controller.text).toList(),
    };
    await prefs.setString('recipe_draft', jsonEncode(draft));
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('recipe_draft');
    if (raw == null) return;
    try {
      final draft = jsonDecode(raw);
      setState(() {
        _nameCtrl.text = draft['name'] ?? '';
        _summaryCtrl.text = draft['summary'] ?? '';
        final ings = draft['ingredients'] as List? ?? [];
        if (ings.isNotEmpty) {
          _ingredients.clear();
          for (var i in ings) _ingredients.add(TextEditingController(text: i));
        }
        final steps = draft['steps'] as List? ?? [];
        if (steps.isNotEmpty) {
          _stepDataList.clear();
          for (var s in steps) _stepDataList.add(StepData(text: s));
        }
      });
    } catch (_) {}
  }

  // ── 이미지 선택 ──────────────────────────────────
  Future<void> _pickImage({int? stepIndex}) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 80,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      if (stepIndex == null) {
        _mainImageBytes = bytes;
      } else {
        _stepDataList[stepIndex].imageBytes = bytes;
      }
    });
  }

  Future<String> _uploadToStorage(Uint8List bytes, String folder) async {
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  // ── 저장 ─────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final ingredients = _ingredients
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (ingredients.isEmpty) {
      _showSnack('재료를 1개 이상 입력해주세요');
      return;
    }

    setState(() => _isSaving = true);
    try {
      String mainUrl = _existingMainImageUrl ?? '';
      if (_mainImageBytes != null) {
        mainUrl = await _uploadToStorage(_mainImageBytes!, 'recipe_images');
      }

      final List<String> steps = [];
      final List<String> stepImages = [];
      for (var s in _stepDataList) {
        steps.add(s.controller.text.trim());
        String sImg = s.existingImageUrl ?? '';
        if (s.imageBytes != null) {
          sImg = await _uploadToStorage(s.imageBytes!, 'step_images');
        }
        stepImages.add(sImg);
      }

      final timeRaw = _timeCtrl.text.trim();
      final timeMinutes = int.tryParse(timeRaw) ?? 0;
      final user = AuthService.instance.currentUser;

      final data = {
        'name': _nameCtrl.text.trim(),
        'summary': _summaryCtrl.text.trim(),
        'imgUrl': mainUrl,
        'calorie': _calorieCtrl.text.trim().isEmpty
            ? '정보 없음'
            : '${_calorieCtrl.text.trim()}kcal',
        'qnt': _qntCtrl.text.trim().isEmpty
            ? '정보 없음'
            : '${_qntCtrl.text.trim()}인분',
        'time': timeRaw.isEmpty ? '정보 없음' : '$timeRaw분',
        'timeMinutes': timeMinutes,
        'level': _level,
        'nation': _nation,
        'type': _type,
        'ingredients': ingredients,
        'steps': steps,
        'stepImages': stepImages,
        'authorId': user?.id,
        'authorName': user?.nickname ?? '익명',
        'authorProfileImg': user?.profileImageUrl,
      };

      if (widget.docId != null) {
        await FirebaseFirestore.instance
            .collection('recipes')
            .doc(widget.docId)
            .update(data);
      } else {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        data['timestamp'] = FieldValue.serverTimestamp();
        data['viewCount'] = 0;
        data['todayViewCount'] = 0;
        data['yesterdayViewCount'] = 0;
        data['todayDate'] = today;
        data['source'] = 'ugc';
        await FirebaseFirestore.instance.collection('recipes').add(data);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('recipe_draft');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.docId != null ? '수정되었습니다!' : '등록되었습니다! 🎉'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final bool busy = _isSaving;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          widget.docId != null ? '레시피 수정' : '레시피 작성',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (busy)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                '저장',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _SectionCard(
                icon: Icons.image_outlined,
                title: '대표 이미지',
                child: _buildMainImagePicker(),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                icon: Icons.info_outline,
                title: '기본 정보',
                child: _buildBasicInfo(),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                icon: Icons.shopping_basket_outlined,
                title: '재료',
                child: _buildIngredients(),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                icon: Icons.format_list_numbered,
                title: '조리 순서 및 사진',
                child: _buildSteps(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainImagePicker() {
    return GestureDetector(
      onTap: () => _pickImage(),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          image: (_mainImageBytes != null)
              ? DecorationImage(
                  image: MemoryImage(_mainImageBytes!),
                  fit: BoxFit.cover,
                )
              : (_existingMainImageUrl != null)
              ? DecorationImage(
                  image: NetworkImage(_existingMainImageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: (_mainImageBytes == null && _existingMainImageUrl == null)
            ? const Icon(
                Icons.add_photo_alternate,
                size: 40,
                color: Colors.grey,
              )
            : null,
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: _inputDeco('레시피 이름 *'),
          onChanged: (_) => _saveDraft(),
          validator: (v) => v == null || v.trim().isEmpty ? '이름을 입력해주세요' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _summaryCtrl,
          onChanged: (_) => _saveDraft(),
          decoration: _inputDeco('한줄 소개'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdown('국가', _nation, [
                '한식',
                '서양',
                '중국',
                '일본',
                '동남아시아',
                '이탈리아',
                '퓨전',
              ], (v) => setState(() => _nation = v!)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdown('유형', _type, [
                '기타',
                '반찬',
                '국/찌개',
                '디저트',
                '면/밥',
                '음료',
              ], (v) => setState(() => _type = v!)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIngredients() {
    return Column(
      children: [
        ..._ingredients.asMap().entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: e.value,
                    decoration: _inputDeco('재료와 분량'),
                    onChanged: (_) => _saveDraft(),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _ingredients.removeAt(e.key)),
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () =>
              setState(() => _ingredients.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text('재료 추가'),
        ),
      ],
    );
  }

  Widget _buildSteps() {
    return Column(
      children: [
        ..._stepDataList.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.orange,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: s.controller,
                        decoration: _inputDeco('조리 단계를 설명해주세요'),
                        maxLines: 2,
                        onChanged: (_) => _saveDraft(),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _stepDataList.removeAt(i)),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _pickImage(stepIndex: i),
                  child: Container(
                    height: 100,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      image: (s.imageBytes != null)
                          ? DecorationImage(
                              image: MemoryImage(s.imageBytes!),
                              fit: BoxFit.cover,
                            )
                          : (s.existingImageUrl != null)
                          ? DecorationImage(
                              image: NetworkImage(s.existingImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: (s.imageBytes == null && s.existingImageUrl == null)
                        ? const Center(
                            child: Icon(
                              Icons.add_a_photo,
                              color: Colors.grey,
                              size: 24,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () =>
              setState(() => _stepDataList.add(StepData(text: ''))),
          icon: const Icon(Icons.add),
          label: const Text('단계 추가'),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDeco(label),
      isExpanded: true,
      items: items
          .map((i) => DropdownMenuItem(value: i, child: Text(i)))
          .toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
    filled: true,
    fillColor: const Color(0xFFF8F8F8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Colors.orange, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
