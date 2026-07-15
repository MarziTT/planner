class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    this.email,
    required this.nickname,
    required this.onboardingDone,
  });

  final int id;
  final String phone;
  final String? email;
  final String nickname;
  final bool onboardingDone;

  AuthUser copyWith({
    int? id,
    String? phone,
    String? email,
    String? nickname,
    bool? onboardingDone,
  }) {
    return AuthUser(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      nickname: nickname ?? this.nickname,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num).toInt(),
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      nickname: json['nickname'] as String? ?? '',
      onboardingDone: json['onboardingDone'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'email': email,
      'nickname': nickname,
      'onboardingDone': onboardingDone,
    };
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

  AuthSession copyWith({
    AuthUser? user,
    String? accessToken,
    String? refreshToken,
  }) {
    return AuthSession(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }
}
