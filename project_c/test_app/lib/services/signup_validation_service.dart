class SignupValidationService {
  const SignupValidationService();

  Future<bool> isEmailAvailable(String email) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final blockedEmails = <String>{
      'test@test.com',
      'admin@test.com',
      'taken@example.com',
    };
    return !blockedEmails.contains(email.trim().toLowerCase());
  }

  Future<bool> isNicknameAvailable(String nickname) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final blockedNicknames = <String>{
      '관리자',
      'admin',
      '운영자',
      'tester',
    };
    return !blockedNicknames.contains(nickname.trim().toLowerCase());
  }
}
