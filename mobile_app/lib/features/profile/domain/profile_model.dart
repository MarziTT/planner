class UserProfile {
  const UserProfile({
    required this.gender,
    required this.age,
    required this.city,
    required this.bio,
    required this.fitnessGoal,
    this.identity = 'worker',
    this.routineStart = '09:00',
    this.routineEnd = '18:00',
    this.focusArea = '',
    this.wantsFitness = false,
    this.fitnessMode = 'self',
  });

  final String gender;
  final int? age;
  final String city;
  final String bio;
  final String fitnessGoal;
  final String identity;
  final String routineStart;
  final String routineEnd;
  final String focusArea;
  final bool wantsFitness;
  final String fitnessMode;

  static const identityLabels = {
    'worker': '上班族',
    'student': '学生',
    'caregiver': '家庭主理人',
    'freelancer': '自由职业',
  };

  static const fitnessModeLabels = {
    'self': '自主健身',
    'coach': '私教陪练',
  };

  String get identityLabel => identityLabels[identity] ?? '上班族';

  String get routineStartLabel {
    switch (identity) {
      case 'student':
        return '上课时间';
      case 'caregiver':
        return '忙碌开始';
      case 'freelancer':
        return '开工时间';
      default:
        return '上班时间';
    }
  }

  String get routineEndLabel {
    switch (identity) {
      case 'student':
        return '结束时间';
      case 'caregiver':
        return '休息时间';
      case 'freelancer':
        return '收工时间';
      default:
        return '下班时间';
    }
  }

  String get fitnessModeLabel =>
      fitnessModeLabels[fitnessMode] ?? fitnessModeLabels['self']!;

  bool isScheduleActiveAt(DateTime now) {
    final startMinutes = _parseMinutes(routineStart);
    final endMinutes = _parseMinutes(routineEnd);
    if (startMinutes == null || endMinutes == null) {
      return false;
    }

    final nowMinutes = now.hour * 60 + now.minute;
    if (endMinutes >= startMinutes) {
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  }

  UserProfile copyWith({
    String? gender,
    int? age,
    String? city,
    String? bio,
    String? fitnessGoal,
    String? identity,
    String? routineStart,
    String? routineEnd,
    String? focusArea,
    bool? wantsFitness,
    String? fitnessMode,
  }) {
    return UserProfile(
      gender: gender ?? this.gender,
      age: age ?? this.age,
      city: city ?? this.city,
      bio: bio ?? this.bio,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      identity: identity ?? this.identity,
      routineStart: routineStart ?? this.routineStart,
      routineEnd: routineEnd ?? this.routineEnd,
      focusArea: focusArea ?? this.focusArea,
      wantsFitness: wantsFitness ?? this.wantsFitness,
      fitnessMode: fitnessMode ?? this.fitnessMode,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      gender: json['gender'] as String? ?? '',
      age: (json['age'] as num?)?.toInt(),
      city: json['city'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      fitnessGoal: json['fitnessGoal'] as String? ?? '',
      identity: json['identity'] as String? ?? 'worker',
      routineStart: json['routineStart'] as String? ?? '09:00',
      routineEnd: json['routineEnd'] as String? ?? '18:00',
      focusArea: json['focusArea'] as String? ?? '',
      wantsFitness: json['wantsFitness'] as bool? ?? false,
      fitnessMode: json['fitnessMode'] as String? ?? 'self',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gender': gender,
      'age': age,
      'city': city,
      'bio': bio,
      'fitnessGoal': fitnessGoal,
      'identity': identity,
      'routineStart': routineStart,
      'routineEnd': routineEnd,
      'focusArea': focusArea,
      'wantsFitness': wantsFitness,
      'fitnessMode': fitnessMode,
    };
  }

  static int? _parseMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return hour * 60 + minute;
  }
}
