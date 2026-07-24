import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../updates/state/update_controller.dart';
import '../../../widgets/zzz_gif_decoration.dart';
import '../state/settings_controller.dart';

const _zzzPreviewAssets = <String>[
  'assets/themes/zzz/shield.gif',
  'assets/themes/zzz/transform.gif',
  'assets/themes/zzz/equipment.gif',
  'assets/themes/zzz/flight.gif',
];
const _pageTitle = '主题与更新';
const _presetLabel = '主题预设';
const _modeSystem = '跟随系统';
const _modeLight = '浅色';
const _modeDark = '深色';
const _channelLabel = '更新通道';
const _stableLabel = '稳定版';
const _betaLabel = '测试版';
const _notifyTitle = '通知提醒';
const _notifySubtitle = '在通知栏和亮屏时提醒即将开始的日程';
const _leadLabel = '提前提醒时间';
const _voiceLabel = '语音录入';
const _versionTitle = '版本与更新';
const _checking = '正在检查更新…';
const _resourceUpdateHint =
    '资源主题、文案和装饰素材可以直接热更新；涉及 Flutter 逻辑和原生能力的改动仍然需要发新包。';
const _zzzPreviewTitle = '假面骑士 ZZZ 主题';
const _zzzPreviewBody = '文字固定在高对比信息区，GIF 只做下方装饰，不再影响可读性。';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _loaded = false;
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
    final isZzz =
        themeState.preset == PlannerThemePreset.kamenRiderZzz;

    return Stack(
      children: [
        Column(
          children: [
            // 保存加载指示器
            if (settingsState.loading)
              LinearProgressIndicator(
                minHeight: 2,
                valueColor: AlwaysStoppedAnimation(
                  isZzz
                      ? const Color(0xFF00FF41)
                      : Theme.of(context).colorScheme.primary,
                ),
                backgroundColor: isZzz
                    ? const Color(0xFF00FF41).withValues(alpha: 0.08)
                    : null,
              ),
            Expanded(
              child: Container(
                color: isZzz ? const Color(0xFF0A0A0F) : null,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                _pageTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isZzz ? const Color(0xFFE0F0E0) : null,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            color: isZzz ? const Color(0xFF0D0B12) : null,
            shape: isZzz
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF00FF41)),
                  )
                : null,
            elevation: isZzz ? 4 : null,
            shadowColor: isZzz
                ? const Color(0xFF00FF41).withValues(alpha: 0.12)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<PlannerThemePreset>(
                    initialValue: themeState.preset,
                    decoration: InputDecoration(
                      labelText: _presetLabel,
                      fillColor: isZzz
                          ? const Color(0xFF0D0B12)
                          : null,
                      filled: isZzz ? true : null,
                      focusedBorder: isZzz
                          ? const OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Color(0xFF00FF41)))
                          : null,
                    ),
                    items: themeState.availablePresets
                        .map(
                          (preset) => DropdownMenuItem(
                            value: preset,
                            child: Text(_labelOf(preset),
                                style: isZzz
                                    ? const TextStyle(color: Color(0xFFE0F0E0))
                                    : null),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      if (value == null || settings == null) return;
                      if (value == themeState.preset) return;
                      themeController.switchPreset(value);
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .save(
                            settings.copyWith(theme: value.name),
                          );
                    },
                  ),
                  if (themeState.preset ==
                      PlannerThemePreset.kamenRiderZzz) ...[
                    const SizedBox(height: 14),
                    const _ZzzThemePreview(),
                  ],
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(_modeSystem,
                              style: isZzz
                                  ? const TextStyle(
                                      color: Color(0xFFE0F0E0))
                                  : null)),
                      ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(_modeLight,
                              style: isZzz
                                  ? const TextStyle(
                                      color: Color(0xFFE0F0E0))
                                  : null)),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(_modeDark,
                              style: isZzz
                                  ? const TextStyle(
                                      color: Color(0xFFE0F0E0))
                                  : null)),
                    ],
                    selected: {themeState.mode},
                    style: isZzz
                        ? ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states
                                  .contains(WidgetState.selected)) {
                                return const Color(0xFF00FF41)
                                    .withValues(alpha: 0.2);
                              }
                              return null;
                            }),
                          )
                        : null,
                    onSelectionChanged: (value) async {
                      final selected = value.first;
                      if (selected == themeState.mode) return;
                      themeController.setThemeMode(selected);
                      if (settings == null) return;
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .save(
                            settings.copyWith(
                                themeMode: selected.name),
                          );
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: settings?.updateChannel ?? 'stable',
                    decoration: InputDecoration(
                      labelText: _channelLabel,
                      fillColor: isZzz
                          ? const Color(0xFF0D0B12)
                          : null,
                      filled: isZzz ? true : null,
                      focusedBorder: isZzz
                          ? const OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Color(0xFF00FF41)))
                          : null,
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'stable',
                          child: Text(_stableLabel,
                              style: isZzz
                                  ? const TextStyle(color: Color(0xFFE0F0E0))
                                  : null)),
                      DropdownMenuItem(
                          value: 'beta',
                          child: Text(_betaLabel,
                              style: isZzz
                                  ? const TextStyle(color: Color(0xFFE0F0E0))
                                  : null)),
                    ],
                    onChanged: settings == null
                        ? null
                        : (value) async {
                            if (value == null) return;
                            if (value == settings.updateChannel) return;
                            await ref
                                .read(
                                    settingsControllerProvider.notifier)
                                .save(
                                  settings.copyWith(
                                      updateChannel: value),
                                );
                          },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: settings?.notificationsEnabled ?? true,
                    activeColor: isZzz
                        ? const Color(0xFF00FF41)
                        : null,
                    onChanged: settings == null
                        ? null
                        : (value) => ref
                            .read(settingsControllerProvider.notifier)
                            .updateNotifications(enabled: value),
                    title: Text(_notifyTitle,
                        style: isZzz
                            ? const TextStyle(color: Color(0xFFE0F0E0))
                            : null),
                    subtitle: Text(_notifySubtitle,
                        style: isZzz
                            ? const TextStyle(color: Color(0xFFC8C8D8))
                            : null),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue:
                        settings?.notificationsLeadMinutes ?? 15,
                    decoration: InputDecoration(
                      labelText: _leadLabel,
                      fillColor: isZzz
                          ? const Color(0xFF0D0B12)
                          : null,
                      filled: isZzz ? true : null,
                      focusedBorder: isZzz
                          ? const OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Color(0xFF00FF41)))
                          : null,
                    ),
                    items: _notificationLeadOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('提前 $value 分钟',
                                style: isZzz
                                    ? const TextStyle(color: Color(0xFFE0F0E0))
                                    : null),
                          ),
                        )
                        .toList(),
                    onChanged:
                        settings == null || !(settings.notificationsEnabled)
                            ? null
                            : (value) async {
                                if (value == null) return;
                                if (value == settings.notificationsLeadMinutes) return;
                                await ref
                                    .read(settingsControllerProvider
                                        .notifier)
                                    .updateNotifications(
                                      enabled:
                                          settings.notificationsEnabled,
                                      leadMinutes: value,
                                    );
                              },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    value: settings?.voiceEnabled ?? true,
                    activeColor: isZzz
                        ? const Color(0xFF00FF41)
                        : null,
                    onChanged: settings == null
                        ? null
                        : (value) => ref
                            .read(settingsControllerProvider.notifier)
                            .save(
                              settings.copyWith(voiceEnabled: value),
                            ),
                    title: Text(_voiceLabel,
                        style: isZzz
                            ? const TextStyle(color: Color(0xFFE0F0E0))
                            : null),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: isZzz ? const Color(0xFF0D0B12) : null,
            shape: isZzz
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF00FF41)),
                  )
                : null,
            elevation: isZzz ? 4 : null,
            shadowColor: isZzz
                ? const Color(0xFF00FF41).withValues(alpha: 0.12)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _versionTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          color: isZzz
                              ? const Color(0xFFE0F0E0)
                              : null,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    updateInfo == null
                        ? _checking
                        : '最新版本 ${updateInfo.version} (${updateInfo.buildNumber})',
                    style: TextStyle(
                      color: isZzz
                          ? const Color(0xFFE0F0E0)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _resourceUpdateHint,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: isZzz
                              ? const Color(0xFFC8C8D8)
                              : null,
                        ),
                  ),
                  if (updateInfo != null &&
                      updateInfo.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...updateInfo.releaseNotes.take(3).map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $item',
                              style: TextStyle(
                                color: isZzz
                                    ? const Color(0xFFE0F0E0)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
          if (settingsState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18,
                    color: Theme.of(context).colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      settingsState.errorMessage!,
                      style: TextStyle(
                        color: isZzz
                            ? const Color(0xFFFF1744)
                            : Theme.of(context).colorScheme.error),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(settingsControllerProvider.notifier).load(),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          ],
        ],
        ), // ListView
      ), // Container
    ), // Expanded
  ], // Column children
        ), // Column
      if (isZzz)
        Positioned(
          right: 0,
          bottom: 0,
          child: ZzzCornerArt(
            spec: zzzSpecFromSeed(DateTime.now().day + 3),
            size: 68,
            opacity: 0.28,
          ),
        ),
    ]);
  }

  String _labelOf(PlannerThemePreset preset) {
    switch (preset) {
      case PlannerThemePreset.sakuraSeason:
        return '樱花季';
      case PlannerThemePreset.ocean:
        return '海洋';
      case PlannerThemePreset.forest:
        return '森林';
      case PlannerThemePreset.desertDusk:
        return '沙漠黄昏';
      case PlannerThemePreset.aurora:
        return '极光';
      case PlannerThemePreset.kamenRiderZzz:
        return '假面骑士 ZZZ';
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
        border: Border.all(
            color: const Color(0xFFE53935).withValues(alpha: 0.55)),
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
