class PlannerSettings {
  const PlannerSettings({
    required this.theme,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.notificationsLeadMinutes,
    required this.voiceEnabled,
    required this.updateChannel,
    required this.availableThemes,
  });

  final String theme;
  final String themeMode;
  final bool notificationsEnabled;
  final int notificationsLeadMinutes;
  final bool voiceEnabled;
  final String updateChannel;
  final List<String> availableThemes;

  PlannerSettings copyWith({
    String? theme,
    String? themeMode,
    bool? notificationsEnabled,
    int? notificationsLeadMinutes,
    bool? voiceEnabled,
    String? updateChannel,
    List<String>? availableThemes,
  }) {
    return PlannerSettings(
      theme: theme ?? this.theme,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationsLeadMinutes:
          notificationsLeadMinutes ?? this.notificationsLeadMinutes,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      updateChannel: updateChannel ?? this.updateChannel,
      availableThemes: availableThemes ?? this.availableThemes,
    );
  }

  factory PlannerSettings.fromJson(Map<String, dynamic> json) {
    return PlannerSettings(
      theme: json['theme'] as String? ?? 'forest',
      themeMode: json['themeMode'] as String? ?? 'dark',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      notificationsLeadMinutes:
          (json['notificationsLeadMinutes'] as num?)?.toInt() ?? 15,
      voiceEnabled: json['voiceEnabled'] as bool? ?? true,
      updateChannel: json['updateChannel'] as String? ?? 'stable',
      availableThemes: (json['availableThemes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [
            'sakuraSeason',
            'ocean',
            'forest',
            'desertDusk',
            'aurora',
          ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'themeMode': themeMode,
      'notificationsEnabled': notificationsEnabled,
      'notificationsLeadMinutes': notificationsLeadMinutes,
      'voiceEnabled': voiceEnabled,
      'updateChannel': updateChannel,
      'availableThemes': availableThemes,
    };
  }
}
