import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/signup_validation_service.dart';

class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({super.key});

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _validationService = const SignupValidationService();

  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _isCheckingEmail = false;
  bool _isCheckingNickname = false;
  bool _isSubmitting = false;
  bool? _isEmailAvailable;
  bool? _isNicknameAvailable;
  String? _emailCheckMessage;
  String? _nicknameCheckMessage;

  static final _emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
  static final _passwordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d).{8,}$',
  );

  bool get _isEmailValid => _emailRegex.hasMatch(_emailCtrl.text.trim());
  bool get _isPasswordValid => _passwordRegex.hasMatch(_passwordCtrl.text);
  bool get _isPasswordMatched =>
      _passwordCtrl.text.isNotEmpty &&
      _passwordCtrl.text == _passwordConfirmCtrl.text;
  bool get _isNicknameLengthValid {
    final len = _nicknameCtrl.text.trim().length;
    return len >= 2 && len <= 12;
  }

  bool get _isFormReady =>
      _isEmailValid &&
      _isEmailAvailable == true &&
      _isPasswordValid &&
      _isPasswordMatched &&
      _isNicknameLengthValid &&
      _isNicknameAvailable == true &&
      !_isSubmitting;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  String? _emailValidator(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return '이메일을 입력해주세요';
    if (!_emailRegex.hasMatch(email)) return '올바른 이메일 형식이 아닙니다';
    return null;
  }

  String? _passwordValidator(String? value) {
    final pwd = value ?? '';
    if (pwd.isEmpty) return '비밀번호를 입력해주세요';
    if (!_passwordRegex.hasMatch(pwd)) {
      return '영문/숫자를 포함한 8자 이상으로 입력해주세요';
    }
    return null;
  }

  String? _passwordConfirmValidator(String? value) {
    if ((value ?? '').isEmpty) return '비밀번호 확인을 입력해주세요';
    if (value != _passwordCtrl.text) return '비밀번호가 일치하지 않습니다';
    return null;
  }

  String? _nicknameValidator(String? value) {
    final nickname = (value ?? '').trim();
    if (nickname.isEmpty) return '닉네임을 입력해주세요';
    if (nickname.length < 2 || nickname.length > 12) {
      return '닉네임은 2자 이상 12자 이하로 입력해주세요';
    }
    return null;
  }

  Future<void> _checkEmailDuplicate() async {
    FocusScope.of(context).unfocus();
    final emailError = _emailValidator(_emailCtrl.text);
    if (emailError != null) {
      setState(() {
        _isEmailAvailable = null;
        _emailCheckMessage = emailError;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _isEmailAvailable = null;
      _emailCheckMessage = null;
    });
    final isAvailable = await _validationService.isEmailAvailable(_emailCtrl.text);
    if (!mounted) return;
    setState(() {
      _isCheckingEmail = false;
      _isEmailAvailable = isAvailable;
      _emailCheckMessage = isAvailable
          ? '사용 가능한 이메일입니다'
          : '이미 사용 중인 이메일입니다';
    });
  }

  Future<void> _checkNicknameDuplicate() async {
    FocusScope.of(context).unfocus();
    final nicknameError = _nicknameValidator(_nicknameCtrl.text);
    if (nicknameError != null) {
      setState(() {
        _isNicknameAvailable = null;
        _nicknameCheckMessage = nicknameError;
      });
      return;
    }

    setState(() {
      _isCheckingNickname = true;
      _isNicknameAvailable = null;
      _nicknameCheckMessage = null;
    });
    final isAvailable =
        await _validationService.isNicknameAvailable(_nicknameCtrl.text);
    if (!mounted) return;
    setState(() {
      _isCheckingNickname = false;
      _isNicknameAvailable = isAvailable;
      _nicknameCheckMessage = isAvailable
          ? '사용 가능한 닉네임입니다'
          : '이미 사용 중인 닉네임입니다';
    });
  }

  Future<void> _submit() async {
    if (!_isFormReady) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await AuthService.instance.signUpWithEmail(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        nickname: _nicknameCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입이 완료되었습니다.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입에 실패했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '회원가입',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              const Text(
                '나만의 레시피 노트를\n만들어보세요!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              
              _buildSectionTitle('이메일 주소'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _buildInputDecoration('example@email.com'),
                      validator: _emailValidator,
                      onChanged: (_) {
                        setState(() {
                          _isEmailAvailable = null;
                          _emailCheckMessage = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildSideButton(
                    onPressed: _isCheckingEmail ? null : _checkEmailDuplicate,
                    isLoading: _isCheckingEmail,
                    text: '중복확인',
                  ),
                ],
              ),
              _buildValidationMessage(_emailCheckMessage, _isEmailAvailable),
              
              const SizedBox(height: 24),
              _buildSectionTitle('비밀번호'),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: _buildInputDecoration('영문, 숫자 포함 8자 이상').copyWith(
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ),
                ),
                validator: _passwordValidator,
                onChanged: (_) => setState(() {}),
              ),
              
              const SizedBox(height: 24),
              _buildSectionTitle('비밀번호 확인'),
              TextFormField(
                controller: _passwordConfirmCtrl,
                obscureText: _obscurePasswordConfirm,
                decoration: _buildInputDecoration('비밀번호를 한번 더 입력해주세요').copyWith(
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm),
                    icon: Icon(
                      _obscurePasswordConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ),
                ),
                validator: _passwordConfirmValidator,
                onChanged: (_) => setState(() {}),
              ),
              if (_passwordConfirmCtrl.text.isNotEmpty && !_isPasswordMatched)
                _buildValidationMessage('비밀번호가 일치하지 않습니다', false),
              
              const SizedBox(height: 24),
              _buildSectionTitle('닉네임'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nicknameCtrl,
                      decoration: _buildInputDecoration('2~12자 이내'),
                      validator: _nicknameValidator,
                      onChanged: (_) {
                        setState(() {
                          _isNicknameAvailable = null;
                          _nicknameCheckMessage = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildSideButton(
                    onPressed: _isCheckingNickname ? null : _checkNicknameDuplicate,
                    isLoading: _isCheckingNickname,
                    text: '중복확인',
                  ),
                ],
              ),
              _buildValidationMessage(_nicknameCheckMessage, _isNicknameAvailable),
              
              const SizedBox(height: 48),
              _buildSubmitButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Colors.grey[50],
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 11, height: 1),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSideButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required String text,
  }) {
    return SizedBox(
      height: 54,
      width: 90,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildValidationMessage(String? message, bool? isSuccess) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: isSuccess == true ? Colors.green[600] : Colors.redAccent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    final bool ready = _isFormReady;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: ready ? [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ] : null,
      ),
      child: ElevatedButton(
        onPressed: ready ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Text(
                '시작하기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
