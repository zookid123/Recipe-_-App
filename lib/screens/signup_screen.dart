import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  DateTime _selectedDate = DateTime(2000, 1, 1);
  String? _selectedGender;
  bool _isLoading = false;

  // 중복 체크 관련 상태
  String? _emailStatus;
  bool _emailAvailable = false;
  bool _emailChecked = false;
  String? _nicknameStatus;
  bool _nicknameAvailable = false;
  bool _nicknameChecked = false;
  bool _isCheckingEmail = false;
  bool _isCheckingNickname = false;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 닉네임 중복 체크
  Future<void> _checkNicknameDuplicate() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showSnackBar('닉네임을 입력해주세요.', isError: true);
      return;
    }
    setState(() => _isCheckingNickname = true);
    try {
      final exists = await AuthService.instance.checkNicknameExists(nickname);
      if (!mounted) return;
      setState(() {
        _isCheckingNickname = false;
        _nicknameChecked = true;
        _nicknameAvailable = !exists;
        _nicknameStatus = exists ? '이미 사용 중인 닉네임입니다' : '사용 가능한 닉네임입니다';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingNickname = false);
      _showSnackBar('중복 확인 실패: $e', isError: true);
    }
  }

  // 이메일 중복 체크
  Future<void> _checkEmailDuplicate() async {
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar('유효한 이메일 형식이 아닙니다.', isError: true);
      return;
    }
    setState(() => _isCheckingEmail = true);
    try {
      final exists = await AuthService.instance.checkEmailExists(email);
      if (!mounted) return;
      setState(() {
        _isCheckingEmail = false;
        _emailChecked = true;
        _emailAvailable = !exists;
        _emailStatus = exists ? '이미 가입된 이메일입니다' : '사용 가능한 이메일입니다';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingEmail = false);
      _showSnackBar('중복 확인 실패: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  // 생년월일 피커 표시
  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                color: Color(0xFFF9F9F9),
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소', style: TextStyle(color: Color(0xFF999999), fontSize: 16)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('확인', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _selectedDate,
                maximumDate: DateTime.now(),
                onDateTimeChanged: (date) {
                  setState(() => _selectedDate = date);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignup() async {
    final isFormValid = _formKey.currentState!.validate();
    
    if (_isCheckingEmail || _isCheckingNickname) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('중복 체크가 진행 중입니다. 잠시만 기다려주세요.')),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성별을 선택해주세요.')),
      );
      return;
    }

    if (!isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력 정보를 다시 확인해주세요.')),
      );
      return;
    }
    if (!_nicknameChecked || !_nicknameAvailable) {
      _showSnackBar('닉네임 중복 확인을 해주세요.', isError: true);
      return;
    }
    if (!_emailChecked || !_emailAvailable) {
      _showSnackBar('이메일 중복 확인을 해주세요.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final birthdateStr = "${_selectedDate.year}${_selectedDate.month.toString().padLeft(2, '0')}${_selectedDate.day.toString().padLeft(2, '0')}";
      
      final user = await AuthService.instance.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        nickname: _nicknameController.text.trim(),
        name: _nameController.text.trim(),
        birthdate: birthdateStr,
        gender: _selectedGender!,
      );

      if (!mounted) return;
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('회원가입이 완료되었습니다. 로그인해주세요.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Signup -> Terms
        Navigator.of(context).pop(); // Terms -> Login
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 실패: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFB),
      appBar: AppBar(
        title: const Text('회원가입', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF333333),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '기본 정보 입력',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF333333),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '회원님의 소중한 정보를 안전하게 관리합니다.',
                style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 32),
              
              _buildSectionTitle('이름'),
              _CustomFormField(
                controller: _nameController,
                hintText: '성함을 입력해주세요',
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) return '이름을 입력하세요';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('성별'),
              Row(
                children: [
                  Expanded(
                    child: _GenderToggleButton(
                      label: '남성',
                      isSelected: _selectedGender == '남성',
                      onTap: () => setState(() => _selectedGender = '남성'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GenderToggleButton(
                      label: '여성',
                      isSelected: _selectedGender == '여성',
                      onTap: () => setState(() => _selectedGender = '여성'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GenderToggleButton(
                      label: '비공개',
                      isSelected: _selectedGender == '비공개',
                      onTap: () => setState(() => _selectedGender = '비공개'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('생년월일'),
              Row(
                children: [
                  Expanded(
                    child: _DatePartButton(
                      label: '${_selectedDate.year}년',
                      onTap: _showDatePicker,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DatePartButton(
                      label: '${_selectedDate.month}월',
                      onTap: _showDatePicker,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DatePartButton(
                      label: '${_selectedDate.day}일',
                      onTap: _showDatePicker,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Divider(color: Color(0xFFEEEEEE), thickness: 1),
              const SizedBox(height: 32),

              _buildSectionTitle('계정 정보'),
              _CustomFormField(
                controller: _nicknameController,
                hintText: '닉네임 (최대 10자)',
                icon: Icons.face_outlined,
                statusText: _nicknameStatus,
                statusIsError: _nicknameChecked && !_nicknameAvailable,
                suffix: TextButton(
                  onPressed: _checkNicknameDuplicate,
                  child: _isCheckingNickname
                      ? const CupertinoActivityIndicator(radius: 8)
                      : const Text('중복확인', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                onChanged: (_) => setState(() {
                  _nicknameChecked = false;
                  _nicknameAvailable = false;
                  _nicknameStatus = null;
                }),
                validator: (value) {
                  if (value == null || value.isEmpty) return '닉네임을 입력하세요';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _CustomFormField(
                controller: _emailController,
                hintText: '이메일 주소',
                icon: Icons.email_outlined,
                statusText: _emailStatus,
                statusIsError: _emailChecked && !_emailAvailable,
                suffix: TextButton(
                  onPressed: _checkEmailDuplicate,
                  child: _isCheckingEmail
                      ? const CupertinoActivityIndicator(radius: 8)
                      : const Text('중복확인', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                onChanged: (_) => setState(() {
                  _emailChecked = false;
                  _emailAvailable = false;
                  _emailStatus = null;
                }),
                validator: (value) {
                  if (value == null || value.isEmpty) return '이메일을 입력하세요';
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(value)) return '유효한 이메일 형식이 아닙니다';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _CustomFormField(
                controller: _passwordController,
                hintText: '비밀번호 (6자 이상)',
                icon: Icons.lock_outline,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return '비밀번호를 입력하세요';
                  if (value.length < 6) return '비밀번호는 6자 이상이어야 합니다';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _CustomFormField(
                controller: _confirmPasswordController,
                hintText: '비밀번호 확인',
                icon: Icons.lock_reset_outlined,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) return '비밀번호 확인을 입력하세요';
                  if (value != _passwordController.text) return '비밀번호가 일치하지 않습니다';
                  return null;
                },
              ),
              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFEEEEEE),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CupertinoActivityIndicator(color: Colors.white)
                      : const Text(
                          '회원가입 완료',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF333333),
        ),
      ),
    );
  }
}

class _GenderToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orange : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.orange : const Color(0xFFEEEEEE),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? Colors.orange.withOpacity(0.2) 
                  : Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: isSelected ? Colors.white : const Color(0xFF666666),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DatePartButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DatePartButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, color: Color(0xFF333333), fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _CustomFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final String? statusText;
  final bool statusIsError;
  final Widget? suffix;
  final Function(String)? onChanged;
  final String? Function(String?)? validator;

  const _CustomFormField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.statusText,
    this.statusIsError = true,
    this.suffix,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            validator: validator,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
              prefixIcon: Icon(icon, color: const Color(0xFFCCCCCC), size: 22),
              suffixIcon: suffix,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.orange, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
        if (statusText != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Text(
              statusText!,
              style: TextStyle(
                color: statusIsError ? Colors.redAccent : Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
