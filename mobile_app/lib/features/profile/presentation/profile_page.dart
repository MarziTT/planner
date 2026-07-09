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
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
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
    _cityController.dispose();
    _bioController.dispose();
    _goalController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  void _seedFromProfile(UserProfile profile) {
    final seedKey = profile.toJson().toString();
    if (_seedKey == seedKey) {
      return;
    }
    _seedKey = seedKey;
    _cityController.text = profile.city;
    _bioController.text = profile.bio;
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
    if (profile != null) {
      _seedFromProfile(profile);
    }

    final effectiveProfile = profile ??
        UserProfile(
          gender: '',
          age: null,
          city: _cityController.text.trim(),
          bio: _bioController.text.trim(),
          fitnessGoal: _goalController.text.trim(),
          identity: _identity,
          routineStart: _routineStart,
          routineEnd: _routineEnd,
          focusArea: _focusController.text.trim(),
          wantsFitness: _wantsFitness,
          fitnessMode: _fitnessMode,
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('身份与节奏', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '先告诉我你现在的生活形态，首页会按你的节奏切出更贴近的提醒和工作模式。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: UserProfile.identityLabels.entries.map((entry) {
            final selected = _identity == entry.key;
            return ChoiceChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (_) => setState(() => _identity = entry.key),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TimeField(
                label: effectiveProfile.copyWith(identity: _identity).routineStartLabel,
                value: _routineStart,
                onChanged: (value) => setState(() => _routineStart = value),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeField(
                label: effectiveProfile.copyWith(identity: _identity).routineEndLabel,
                value: _routineEnd,
                onChanged: (value) => setState(() => _routineEnd = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _focusController,
          decoration: const InputDecoration(
            labelText: '当前阶段重点',
            hintText: '比如：深度工作、考研冲刺、带娃与家务协同',
          ),
        ),
        const SizedBox(height: 24),
        Text('账号与资料', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(controller: _cityController, decoration: const InputDecoration(labelText: '城市')),
        const SizedBox(height: 12),
        TextField(controller: _bioController, decoration: const InputDecoration(labelText: '简介')),
        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('开启健身模块'),
          subtitle: const Text('只有你确认自己有健身安排时，首页才展示训练入口。'),
          value: _wantsFitness,
          onChanged: (value) => setState(() => _wantsFitness = value),
        ),
        if (_wantsFitness) ...[
          const SizedBox(height: 12),
          Text('健身方式', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
            decoration: const InputDecoration(labelText: '训练目标'),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: state.loading
              ? null
              : () => ref.read(profileControllerProvider.notifier).save(
                    effectiveProfile.copyWith(
                      city: _cityController.text.trim(),
                      bio: _bioController.text.trim(),
                      fitnessGoal: _goalController.text.trim(),
                      identity: _identity,
                      routineStart: _routineStart,
                      routineEnd: _routineEnd,
                      focusArea: _focusController.text.trim(),
                      wantsFitness: _wantsFitness,
                      fitnessMode: _fitnessMode,
                    ),
                  ),
          child: Text(state.loading ? '保存中...' : '保存资料'),
        ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(state.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final initialParts = value.split(':');
        final initialTime = TimeOfDay(
          hour: int.tryParse(initialParts.first) ?? 9,
          minute: int.tryParse(initialParts.last) ?? 0,
        );
        final result = await showTimePicker(
          context: context,
          initialTime: initialTime,
        );
        if (result == null) return;
        onChanged(
          '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}',
        );
      },
      icon: const Icon(Icons.schedule_outlined),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
