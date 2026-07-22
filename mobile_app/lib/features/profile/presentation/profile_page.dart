import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          children: [
            Icon(Icons.person_outline, size: 22, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text('个人设置', style: theme.textTheme.titleLarge)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '先告诉我你现在的生活形态，首页会按你的节奏切出更贴近的提醒和工作模式。',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),

        // --- 身份 ---
        _SectionCard(
          title: '身份',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserProfile.identityLabels.entries.map((entry) {
              final selected = _identity == entry.key;
              return ChoiceChip(
                label: Text(entry.value),
                selected: selected,
                onSelected: (_) => setState(() => _identity = entry.key),
                avatar: Icon(_identityIcon(entry.key), size: 16),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // --- 日常节奏 ---
        _SectionCard(
          title: '日常节奏',
          child: Row(
            children: [
              Expanded(child: _TimeField(
                label: effectiveProfile.copyWith(identity: _identity).routineStartLabel,
                value: _routineStart,
                icon: Icons.wb_sunny_outlined,
                onChanged: (value) => setState(() => _routineStart = value),
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  width: 28, height: 2,
                  color: scheme.outlineVariant,
                ),
              ),
              Expanded(child: _TimeField(
                label: effectiveProfile.copyWith(identity: _identity).routineEndLabel,
                value: _routineEnd,
                icon: Icons.nightlight_round,
                onChanged: (value) => setState(() => _routineEnd = value),
              )),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // --- 阶段重点 ---
        _SectionCard(
          title: '当前阶段重点',
          child: TextField(
            controller: _focusController,
            decoration: const InputDecoration(
              hintText: '比如：深度工作、考研冲刺、带娃与家务协同',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // --- 健身模块 ---
        _SectionCard(
          title: '健身模块',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('开启健身模块'),
                subtitle: const Text('只有你确认自己有健身安排时，首页才展示训练入口。'),
                value: _wantsFitness,
                onChanged: (value) => setState(() => _wantsFitness = value),
              ),
              if (_wantsFitness) ...[
                const SizedBox(height: 4),
                Text('健身方式', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: UserProfile.fitnessModeLabels.entries.map((entry) {
                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: _fitnessMode == entry.key,
                      onSelected: (_) => setState(() => _fitnessMode = entry.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _goalController,
                  decoration: const InputDecoration(
                    labelText: '训练目标',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --- 错误 & 保存 ---
        if (state.errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 18, color: scheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(state.errorMessage!,
                      style: TextStyle(color: scheme.onErrorContainer, fontSize: 13)),
                ),
              ],
            ),
          ),
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
          icon: state.loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check, size: 18),
          label: Text(state.loading ? '保存中...' : '保存资料'),
        ),
      ],
    );
  }
}

IconData _identityIcon(String identity) {
  switch (identity) {
    case 'worker': return Icons.work_outline;
    case 'student': return Icons.school_outlined;
    case 'caregiver': return Icons.favorite_outline;
    case 'freelancer': return Icons.laptop_outlined;
    default: return Icons.person_outline;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label, required this.value,
    required this.icon, required this.onChanged,
  });
  final String label;
  final String value;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final parts = value.split(':');
        final initial = TimeOfDay(
          hour: int.tryParse(parts.first) ?? 9,
          minute: int.tryParse(parts.last) ?? 0,
        );
        final result = await showTimePicker(context: context, initialTime: initial);
        if (result == null) return;
        onChanged(
          '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}',
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      )),
                ],
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
