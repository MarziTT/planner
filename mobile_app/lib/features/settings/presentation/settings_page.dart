import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../updates/state/update_controller.dart';
import '../domain/settings_model.dart';
import '../state/settings_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _loaded = false;
  String? _lastAppliedSettingsKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      Future.microtask(() => ref.read(settingsControllerProvider.notifier).load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final themeController = ref.read(themeControllerProvider.notifier);
    final settingsState = ref.watch(settingsControllerProvider);
    final updateInfo = ref.watch(updateControllerProvider).info;
    final settings = settingsState.settings;

    if (settings != null) {
      final appliedKey = '${settings.theme}|${settings.themeMode}';
      if (_lastAppliedSettingsKey != appliedKey) {
        _lastAppliedSettingsKey = appliedKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          themeController.switchPreset(_presetFromName(settings.theme));
          themeController.setThemeMode(_modeFromName(settings.themeMode));
        });
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('主题与更新', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<PlannerThemePreset>(
                  value: themeState.preset,
                  decoration: const InputDecoration(labelText: '主题预设'),
                  items: PlannerThemePreset.values
                      .map(
                        (preset) => DropdownMenuItem(
                          value: preset,
                          child: Text(_labelOf(preset)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null || settings == null) return;
                    themeController.switchPreset(value);
                    await ref.read(settingsControllerProvider.notifier).save(
                          PlannerSettings(
                            theme: value.name,
                            themeMode: settings.themeMode,
                            notificationsEnabled: settings.notificationsEnabled,
                            voiceEnabled: settings.voiceEnabled,
                            updateChannel: settings.updateChannel,
                          ),
                        );
                  },
                ),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
                    ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                  ],
                  selected: {themeState.mode},
                  onSelectionChanged: (value) async {
                    final selected = value.first;
                    themeController.setThemeMode(selected);
                    if (settings == null) return;
                    await ref.read(settingsControllerProvider.notifier).save(
                          PlannerSettings(
                            theme: settings.theme,
                            themeMode: selected.name,
                            notificationsEnabled: settings.notificationsEnabled,
                            voiceEnabled: settings.voiceEnabled,
                            updateChannel: settings.updateChannel,
                          ),
                        );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: settings?.updateChannel ?? 'stable',
                  decoration: const InputDecoration(labelText: '更新通道'),
                  items: const [
                    DropdownMenuItem(value: 'stable', child: Text('稳定版')),
                    DropdownMenuItem(value: 'beta', child: Text('测试版')),
                  ],
                  onChanged: settings == null
                      ? null
                      : (value) async {
                          if (value == null) return;
                          await ref.read(settingsControllerProvider.notifier).save(
                                PlannerSettings(
                                  theme: settings.theme,
                                  themeMode: settings.themeMode,
                                  notificationsEnabled: settings.notificationsEnabled,
                                  voiceEnabled: settings.voiceEnabled,
                                  updateChannel: value,
                                ),
                              );
                        },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: settings?.notificationsEnabled ?? true,
                  onChanged: settings == null
                      ? null
                      : (value) => ref.read(settingsControllerProvider.notifier).save(
                            PlannerSettings(
                              theme: settings.theme,
                              themeMode: settings.themeMode,
                              notificationsEnabled: value,
                              voiceEnabled: settings.voiceEnabled,
                              updateChannel: settings.updateChannel,
                            ),
                          ),
                  title: const Text('通知提醒'),
                ),
                SwitchListTile(
                  value: settings?.voiceEnabled ?? true,
                  onChanged: settings == null
                      ? null
                      : (value) => ref.read(settingsControllerProvider.notifier).save(
                            PlannerSettings(
                              theme: settings.theme,
                              themeMode: settings.themeMode,
                              notificationsEnabled: settings.notificationsEnabled,
                              voiceEnabled: value,
                              updateChannel: settings.updateChannel,
                            ),
                          ),
                  title: const Text('语音录入'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('版本与更新', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(updateInfo == null ? '正在检查更新…' : '最新版本 ${updateInfo.version} (${updateInfo.buildNumber})'),
                if (updateInfo != null && updateInfo.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...updateInfo.releaseNotes.take(3).map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $item'),
                      )),
                ],
              ],
            ),
          ),
        ),
        if (settingsState.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(settingsState.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }

  PlannerThemePreset _presetFromName(String value) {
    return PlannerThemePreset.values.firstWhere(
      (item) => item.name == value,
      orElse: () => PlannerThemePreset.premiumMinimal,
    );
  }

  ThemeMode _modeFromName(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  String _labelOf(PlannerThemePreset preset) {
    switch (preset) {
      case PlannerThemePreset.premiumMinimal:
        return '高级简洁';
      case PlannerThemePreset.professionalDark:
        return '深色专业';
      case PlannerThemePreset.warmLife:
        return '暖色生活';
      case PlannerThemePreset.forestOcean:
        return '森林海洋';
      case PlannerThemePreset.kamenRiderZzz:
        return '假面骑士 ZZZ';
    }
  }
}
