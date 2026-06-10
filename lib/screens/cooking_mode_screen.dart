import 'dart:async';
import 'package:flutter/material.dart';

class CookingModeScreen extends StatefulWidget {
  final String recipeName;
  final List steps;
  final List? stepImages;

  const CookingModeScreen({
    super.key,
    required this.recipeName,
    required this.steps,
    this.stepImages,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.recipeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 진행률 표시 바
          LinearProgressIndicator(
            value: (_currentPage + 1) / widget.steps.length,
            backgroundColor: Colors.grey[200],
            color: Colors.orange,
            minHeight: 6,
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: widget.steps.length,
              itemBuilder: (context, index) {
                return _buildStepPage(index);
              },
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStepPage(int index) {
    final stepText = widget.steps[index].toString();
    final hasImage = widget.stepImages != null &&
        widget.stepImages!.length > index &&
        widget.stepImages![index].toString().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 단계 번호
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'STEP ${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 32),
          // 조리 이미지
          if (hasImage)
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.network(
                  widget.stepImages![index],
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.restaurant, size: 48, color: Colors.grey),
                  ),
                ),
              ),
            ),
          // 조리 설명 (큰 글씨)
          Text(
            stepText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 48),
          // 타이머 버튼
          _TimerWidget(stepText: stepText),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 이전 버튼
          _currentPage > 0
              ? _navButton(
                  onPressed: () => _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  icon: Icons.arrow_back_ios_new,
                  label: '이전',
                  isPrimary: false,
                )
              : const SizedBox(width: 110),
          
          // 페이지 카운트
          Text(
            '${_currentPage + 1} / ${widget.steps.length}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),

          // 다음/완료 버튼
          _navButton(
            onPressed: () {
              if (_currentPage < widget.steps.length - 1) {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('요리를 완료했습니다! 고생하셨어요! 🍳')),
                );
              }
            },
            icon: _currentPage < widget.steps.length - 1 ? Icons.arrow_forward_ios : Icons.check,
            label: _currentPage < widget.steps.length - 1 ? '다음' : '완료',
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _navButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    return SizedBox(
      width: 110,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.orange : Colors.grey[100],
          foregroundColor: isPrimary ? Colors.white : Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isPrimary) Icon(icon, size: 16),
            if (!isPrimary) const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (isPrimary) const SizedBox(width: 8),
            if (isPrimary) Icon(icon, size: 16),
          ],
        ),
      ),
    );
  }
}

class _TimerWidget extends StatefulWidget {
  final String stepText;
  const _TimerWidget({required this.stepText});

  @override
  State<_TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<_TimerWidget> {
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = _extractTime(widget.stepText);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _extractTime(String text) {
    // 간단한 정규표현식으로 'X분' 또는 'X초' 추출
    final minuteRegex = RegExp(r'(\d+)\s*분');
    final secondRegex = RegExp(r'(\d+)\s*초');

    final minuteMatch = minuteRegex.firstMatch(text);
    if (minuteMatch != null) {
      return int.parse(minuteMatch.group(1)!) * 60;
    }

    final secondMatch = secondRegex.firstMatch(text);
    if (secondMatch != null) {
      return int.parse(secondMatch.group(1)!);
    }

    return 0; // 기본값
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      if (_secondsRemaining <= 0) {
        _showTimePicker();
        return;
      }
      _startTimer();
    }
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        if (mounted) {
          setState(() => _isRunning = false);
          _showFinishedDialog();
        }
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsRemaining = _extractTime(widget.stepText);
    });
  }

  void _showTimePicker() async {
    int minutes = 0;
    int seconds = 0;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('타이머 설정'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _timeField('분', (v) => minutes = v),
            const SizedBox(width: 20),
            _timeField('초', (v) => seconds = v),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _secondsRemaining = (minutes * 60) + seconds;
              });
              Navigator.pop(context);
              if (_secondsRemaining > 0) _startTimer();
            },
            child: const Text('시작'),
          ),
        ],
      ),
    );
  }

  Widget _timeField(String label, Function(int) onChanged) {
    return SizedBox(
      width: 70,
      child: TextField(
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => onChanged(int.tryParse(value) ?? 0),
      ),
    );
  }

  void _showFinishedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림'),
        content: const Text('시간이 다 되었습니다!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text(
                '조리 타이머',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatTime(_secondsRemaining),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _timerActionButton(
                onPressed: _toggleTimer,
                icon: _isRunning ? Icons.pause : Icons.play_arrow,
                label: _isRunning ? '일시정지' : '시작',
                color: Colors.orange,
              ),
              const SizedBox(width: 16),
              _timerActionButton(
                onPressed: _resetTimer,
                icon: Icons.refresh,
                label: '초기화',
                color: Colors.grey[600]!,
              ),
              const SizedBox(width: 16),
              _timerActionButton(
                onPressed: _showTimePicker,
                icon: Icons.edit_note,
                label: '설정',
                color: Colors.blueGrey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timerActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}
