class UserProfile {
  const UserProfile({
    required this.gender,
    required this.age,
    required this.city,
    required this.bio,
    required this.fitnessGoal,
  });

  final String gender;
  final int? age;
  final String city;
  final String bio;
  final String fitnessGoal;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      gender: json['gender'] as String? ?? '',
      age: (json['age'] as num?)?.toInt(),
      city: json['city'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      fitnessGoal: json['fitnessGoal'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'gender': gender,
      'age': age,
      'city': city,
      'bio': bio,
      'fitnessGoal': fitnessGoal,
    };
  }
}
