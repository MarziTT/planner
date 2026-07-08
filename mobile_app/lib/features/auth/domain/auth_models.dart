class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.nickname,
    required this.onboardingDone,
  });

  final int id;
  final String email;
  final String nickname;
  final bool onboardingDone;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      onboardingDone: json['onboardingDone'] as bool? ?? false,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;
}
