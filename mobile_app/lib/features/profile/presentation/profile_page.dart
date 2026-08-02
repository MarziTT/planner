import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/zzz_theme_extension.dart';
import '../../../widgets/zzz_gif_decoration.dart';
import '../domain/profile_model.dart';
import '../state/profile_controller.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _goalController = TextEditingController();
  final _focusController = TextEditingController();
  String _identity = 'worker';
  String _routineStart = '09:00';
  String _routineEnd = '18:00';
  bool _wantsFitness = false;
  String _fitnessMode = 'self';
  String? _seedKey;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileControllerProvider.notifier).load());
  }

  @override
  void dispose() {
    _goalController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  void _seedFromProfile(UserProfile profile) {
    final seedKey = profile.toJson().toString();
    if (_seedKey == seedKey) return;
    _seedKey = seedKey;
    _goalController.text = profile.fitnessGoal;
    _focusController.text = profile.focusArea;
    _identity = profile.identity;
    _routineStart = profile.routineStart;
    _routineEnd = profile.routineEnd;
    _wantsFitness = profile.wantsFitness;
    _fitnessMode = profile.fitnessMode;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final profile = state.profile;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isZzz = ref.watch(themeControllerProvider).preset ==
        PlannerThemePreset.kamenRiderZzz;
    final zzz = context.zzz;

    if (state.loading && profile == null) {
      return Scaffold(
        backgroundColor: isZzz ? zzz?.bg : null,
        appBar: AppBar(title: const Text('个人设置')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              SizedBox(height: 16),
              Text('加载中...', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (profile != null) _seedFromProfile(profile);

    final effectiveProfile = profile ??
        UserProfile(
          fitnessGoal: _goalController.text.trim(),
          identity: _identity,
          routineStart: _routineStart,
          routineEnd: _routineEnd,
          focusArea: _focusController.text.trim(),
          wantsFitness: _wantsFitness,
          fitnessMode: _fitnessMode,
        );
    final accent = isZzz ? zzz?.accent ?? scheme.primary : scheme.primary;
    final textPrimary = isZzz ? zzz?.textPrimary : null;
    final textSecondary = isZzz ? zzz?.textSecondary : scheme.onSurfaceVariant;

    return Stack(
      children: [
        Container(
          color: isZzz ? zzz?.bg : null,
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(profileControllerProvider.notifier).load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Row(
                  children: [
                    Container(
                      decoration: isZzz
                          ? BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                ),
                              ],
                            )
                          : null,
                      child: Icon(
                        Icons.person_outline,
                        size: 22,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '个人设置',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: textPrimary,
                          fontFamily: isZzz ? zzz?.terminalFontFamily : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '先告诉我你现在的生活形态，首页会按你的节奏切出更贴近的提醒和工作模式。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: '身份',
                  isZzz: isZzz,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UserProfile.identityLabels.entries.map((entry) {
                      final selected = _identity == entry.key;
                      return ChoiceChip(
                        label: Text(entry.value),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _identity = entry.key),
                        avatar: Icon(_identityIcon(entry.key), size: 16),
                        backgroundColor: isZzz ? zzz?.surfaceLow : null,
                        selectedColor:
                            isZzz ? accent.withValues(alpha: 0.16) : null,
                        labelStyle:
                            selected && isZzz ? TextStyle(color: accent) : null,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '日常节奏',
                  isZzz: isZzz,
                  child: Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label: effectiveProfile
                              .copyWith(identity: _identity)
                              .routineStartLabel,
                          value: _routineStart,
                          icon: Icons.wb_sunny_outlined,
                          isZzz: isZzz,
                          onChanged: (value) =>
                              setState(() => _routineStart = value),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          width: 28,
                          height: 2,
                          color:
                              isZzz ? zzz?.borderStrong : scheme.outlineVariant,
                        ),
                      ),
                      Expanded(
                        child: _TimeField(
                          label: effectiveProfile
                              .copyWith(identity: _identity)
                              .routineEndLabel,
                          value: _routineEnd,
                          icon: Icons.nightlight_round,
                          isZzz: isZzz,
                          onChanged: (value) =>
                              setState(() => _routineEnd = value),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '当前阶段重点',
                  isZzz: isZzz,
                  child: TextField(
                    controller: _focusController,
                    style: isZzz ? TextStyle(color: zzz?.textPrimary) : null,
                    decoration: _inputDecoration(
                      context,
                      isZzz: isZzz,
                      hintText: '比如：深度工作、考研冲刺、带娃与家务协同',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _SectionCard(
                  title: '健身模块',
                  isZzz: isZzz,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '开启健身模块',
                          style:
                              isZzz ? TextStyle(color: zzz?.textPrimary) : null,
                        ),
                        subtitle: Text(
                          '只有你确认自己有健身安排时，首页才展示训练入口。',
                          style: isZzz
                              ? TextStyle(color: zzz?.textSecondary)
                              : null,
                        ),
                        value: _wantsFitness,
                        activeThumbColor: isZzz ? accent : null,
                        onChanged: (value) =>
                            setState(() => _wantsFitness = value),
                      ),
                      if (_wantsFitness) ...[
                        const SizedBox(height: 4),
                        Text(
                          '健身方式',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: UserProfile.fitnessModeLabels.entries
                              .map((entry) {
                            final selected = _fitnessMode == entry.key;
                            return ChoiceChip(
                              label: Text(entry.value),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _fitnessMode = entry.key),
                              backgroundColor: isZzz ? zzz?.surfaceLow : null,
                              selectedColor:
                                  isZzz ? accent.withValues(alpha: 0.16) : null,
                              labelStyle: selected && isZzz
                                  ? TextStyle(color: accent)
                                  : null,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _goalController,
                          style:
                              isZzz ? TextStyle(color: zzz?.textPrimary) : null,
                          decoration: _inputDecoration(
                            context,
                            isZzz: isZzz,
                            labelText: '训练目标',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (state.errorMessage != null) ...[
                  _ErrorBanner(
                    message: state.errorMessage!,
                    isZzz: isZzz,
                    onRetry: () =>
                        ref.read(profileControllerProvider.notifier).load(),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: state.loading
                      ? null
                      : () => ref.read(profileControllerProvider.notifier).save(
                            effectiveProfile.copyWith(
                              fitnessGoal: _goalController.text.trim(),
                              identity: _identity,
                              routineStart: _routineStart,
                              routineEnd: _routineEnd,
                              focusArea: _focusController.text.trim(),
                              wantsFitness: _wantsFitness,
                              fitnessMode: _fitnessMode,
                            ),
                          ),
                  style: isZzz
                      ? FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: zzz?.bg ?? scheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 4,
                          shadowColor: accent.withValues(alpha: 0.24),
                        )
                      : null,
                  icon: state.loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(state.loading ? '保存中...' : '保存资料'),
                ),
              ],
            ),
          ),
        ),
        if (isZzz)
          Positioned(
            right: 0,
            bottom: 0,
            child: ZzzCornerArt(
              spec: zzzSpecFromSeed(DateTime.now().day + 4),
              size: 70,
              opacity: 0.26,
            ),
          ),
      ],
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context, {
  required bool isZzz,
  String? hintText,
  String? labelText,
}) {
  final theme = Theme.of(context);
  final zzz = context.zzz;
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    hintStyle: isZzz ? TextStyle(color: zzz?.textTertiary) : null,
    labelStyle: isZzz ? TextStyle(color: zzz?.textSecondary) : null,
    fillColor: isZzz ? zzz?.surfaceLow : null,
    filled: isZzz ? true : null,
    border: const OutlineInputBorder(),
    focusedBorder: isZzz
        ? OutlineInputBorder(
            borderSide: BorderSide(
              color: zzz?.accent ?? theme.colorScheme.primary,
            ),
          )
        : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

IconData _identityIcon(String identity) {
  switch (identity) {
    case 'worker':
      return Icons.work_outline;
    case 'student':
      return Icons.school_outlined;
    case 'caregiver':
      return Icons.favorite_outline;
    case 'freelancer':
      return Icons.laptop_outlined;
    default:
      return Icons.person_outline;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.isZzz = false,
  });

  final String title;
  final Widget child;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zzz = context.zzz;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isZzz ? zzz?.surface : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(isZzz ? 10 : 16),
        border: Border.all(
          color: isZzz
              ? zzz?.borderColor ?? theme.colorScheme.outlineVariant
              : theme.colorScheme.outlineVariant,
        ),
        boxShadow: isZzz
            ? [
                BoxShadow(
                  color: (zzz?.accent ?? theme.colorScheme.primary)
                      .withValues(alpha: 0.08),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: isZzz ? zzz?.accent : null,
              fontFamily: isZzz ? zzz?.terminalFontFamily : null,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
    this.isZzz = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final zzz = context.zzz;
    final accent = isZzz ? zzz?.signal ?? scheme.primary : scheme.primary;
    return InkWell(
      onTap: () async {
        final parts = value.split(':');
        final initial = TimeOfDay(
          hour: int.tryParse(parts.first) ?? 9,
          minute: int.tryParse(parts.last) ?? 0,
        );
        final result =
            await showTimePicker(context: context, initialTime: initial);
        if (result == null) return;
        onChanged(
          '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}',
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isZzz ? zzz?.surfaceLow : scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isZzz
                ? zzz?.borderColor ?? scheme.outlineVariant
                : scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isZzz ? zzz?.textSecondary : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isZzz ? zzz?.textPrimary : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isZzz ? zzz?.textSecondary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.isZzz,
    required this.onRetry,
  });

  final String message;
  final bool isZzz;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final zzz = context.zzz;
    final bg = isZzz
        ? (zzz?.danger ?? scheme.error).withValues(alpha: 0.10)
        : scheme.errorContainer;
    final fg = isZzz ? zzz?.danger ?? scheme.error : scheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: isZzz ? Border.all(color: fg.withValues(alpha: 0.28)) : null,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: fg, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: fg,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
