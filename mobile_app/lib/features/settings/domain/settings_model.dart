class PlannerSettings {
  const PlannerSettings({
    required this.theme,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.voiceEnabled,
    required this.updateChannel,
  });

  final String theme;
  final String themeMode;
  final bool notificationsEnabled;
  final bool voiceEnabled;
  final String updateChannel;

  factory PlannerSettings.fromJson(Map<String, dynamic> json) {
    return PlannerSettings(
      theme: json['theme'] as String? ?? 'premiumMinimal',
      themeMode: json['themeMode'] as String? ?? 'dark',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      voiceEnabled: json['voiceEnabled'] as bool? ?? true,
      updateChannel: json['updateChannel'] as String? ?? 'stable',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'themeMode': themeMode,
      'notificationsEnabled': notificationsEnabled,
      'voiceEnabled': voiceEnabled,
      'updateChannel': updateChannel,
    };
  }
}
