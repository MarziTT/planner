import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../updates/state/update_controller.dart';
import '../state/settings_controller.dart';

const _zzzPreviewAssets = <String>[
  'assets/themes/zzz/shield.gif',
  'assets/themes/zzz/transform.gif',
  'assets/themes/zzz/equipment.gif',
  'assets/themes/zzz/flight.gif',
];
const _pageTitle = '\u4e3b\u9898\u4e0e\u66f4\u65b0';
const _presetLabel = '\u4e3b\u9898\u9884\u8bbe';
const _modeSystem = '\u8ddf\u968f\u7cfb\u7edf';
const _modeLight = '\u6d45\u8272';
const _modeDark = '\u6df1\u8272';
const _channelLabel = '\u66f4\u65b0\u901a\u9053';
const _stableLabel = '\u7a33\u5b9a\u7248';
const _betaLabel = '\u6d4b\u8bd5\u7248';
const _notifyTitle = '\u901a\u77e5\u63d0\u9192';
const _notifySubtitle =
    '\u5728\u901a\u77e5\u680f\u548c\u4eae\u5c4f\u65f6\u63d0\u9192\u5373\u5c06\u5f00\u59cb\u7684\u65e5\u7a0b';
const _leadLabel = '\u63d0\u524d\u63d0\u9192\u65f6\u95f4';
const _voiceLabel = '\u8bed\u97f3\u5f55\u5165';
const _versionTitle = '\u7248\u672c\u4e0e\u66f4\u65b0';
const _checking = '\u6b63\u5728\u68c0\u67e5\u66f4\u65b0\u2026';
const _resourceUpdateHint =
    '\u8d44\u6e90\u4e3b\u9898\u3001\u6587\u6848\u548c\u88c5\u9970\u7d20\u6750\u53ef\u4ee5\u76f4\u63a5\u70ed\u66f4\u65b0\uff1b\u6d89\u53ca Flutter \u903b\u8f91\u548c\u539f\u751f\u80fd\u529b\u7684\u6539\u52a8\u4ecd\u7136\u9700\u8981\u53d1\u65b0\u5305\u3002';
const _zzzPreviewTitle = '假面骑士 ZZZ 主题';
const _zzzPreviewBody = '文字固定在高对比信息区，GIF 只做下方装饰，不再影响可读性。';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _loaded = false;
  String? _lastAppliedSettingsKey;
  static const _notificationLeadOptions = [5, 10, 15, 30, 60];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      Future.microtask(
          () => ref.read(settingsControllerProvider.notifier).load());
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
        Text(_pageTitle, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<PlannerThemePreset>(
                  initialValue: themeState.preset,
                  decoration: const InputDecoration(labelText: _presetLabel),
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
                          settings.copyWith(theme: value.name),
                        );
                  },
                ),
                if (themeState.preset == PlannerThemePreset.kamenRiderZzz) ...[
                  const SizedBox(height: 14),
                  const _ZzzThemePreview(),
                ],
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.system, label: Text(_modeSystem)),
                    ButtonSegment(
                        value: ThemeMode.light, label: Text(_modeLight)),
                    ButtonSegment(
                        value: ThemeMode.dark, label: Text(_modeDark)),
                  ],
                  selected: {themeState.mode},
                  onSelectionChanged: (value) async {
                    final selected = value.first;
                    themeController.setThemeMode(selected);
                    if (settings == null) return;
                    await ref.read(settingsControllerProvider.notifier).save(
                          settings.copyWith(themeMode: selected.name),
                        );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: settings?.updateChannel ?? 'stable',
                  decoration: const InputDecoration(labelText: _channelLabel),
                  items: const [
                    DropdownMenuItem(
                        value: 'stable', child: Text(_stableLabel)),
                    DropdownMenuItem(value: 'beta', child: Text(_betaLabel)),
                  ],
                  onChanged: settings == null
                      ? null
                      : (value) async {
                          if (value == null) return;
                          await ref
                              .read(settingsControllerProvider.notifier)
                              .save(
                                settings.copyWith(updateChannel: value),
                              );
                        },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: settings?.notificationsEnabled ?? true,
                  onChanged: settings == null
                      ? null
                      : (value) => ref
                          .read(settingsControllerProvider.notifier)
                          .updateNotifications(enabled: value),
                  title: const Text(_notifyTitle),
                  subtitle: const Text(_notifySubtitle),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: settings?.notificationsLeadMinutes ?? 15,
                  decoration: const InputDecoration(labelText: _leadLabel),
                  items: _notificationLeadOptions
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('\u63d0\u524d $value \u5206\u949f'),
                        ),
                      )
                      .toList(),
                  onChanged:
                      settings == null || !(settings.notificationsEnabled)
                          ? null
                          : (value) async {
                              if (value == null) return;
                              await ref
                                  .read(settingsControllerProvider.notifier)
                                  .updateNotifications(
                                    enabled: settings.notificationsEnabled,
                                    leadMinutes: value,
                                  );
                            },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  value: settings?.voiceEnabled ?? true,
                  onChanged: settings == null
                      ? null
                      : (value) =>
                          ref.read(settingsControllerProvider.notifier).save(
                                settings.copyWith(voiceEnabled: value),
                              ),
                  title: const Text(_voiceLabel),
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
                Text(_versionTitle,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(updateInfo == null
                    ? _checking
                    : '\u6700\u65b0\u7248\u672c ${updateInfo.version} (${updateInfo.buildNumber})'),
                const SizedBox(height: 8),
                Text(
                  _resourceUpdateHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (updateInfo != null &&
                    updateInfo.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...updateInfo.releaseNotes.take(3).map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $item'),
                        ),
                      ),
                ],
              ],
            ),
          ),
        ),
        if (settingsState.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            settingsState.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
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
        return '\u9ad8\u7ea7\u7b80\u6d01';
      case PlannerThemePreset.professionalDark:
        return '\u6df1\u8272\u4e13\u4e1a';
      case PlannerThemePreset.warmLife:
        return '\u6696\u8272\u751f\u6d3b';
      case PlannerThemePreset.forestOcean:
        return '\u68ee\u6797\u6d77\u6d0b';
      case PlannerThemePreset.kamenRiderZzz:
        return '\u5047\u9762\u9a91\u58eb ZZZ';
    }
  }
}

class _ZzzThemePreview extends StatelessWidget {
  const _ZzzThemePreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF08090D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _zzzPreviewTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF101114),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _zzzPreviewBody,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF3B3D45),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: _zzzPreviewAssets.map((asset) {
              final isLast = asset == _zzzPreviewAssets.last;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.asset(
                        asset,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF191B22),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFFE53935),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}