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

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final profile = state.profile;
    if (profile != null) {
      _cityController.text = _cityController.text.isEmpty ? profile.city : _cityController.text;
      _bioController.text = _bioController.text.isEmpty ? profile.bio : _bioController.text;
      _goalController.text = _goalController.text.isEmpty ? profile.fitnessGoal : _goalController.text;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('账号与资料', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(controller: _cityController, decoration: const InputDecoration(labelText: '城市')),
        const SizedBox(height: 12),
        TextField(controller: _bioController, decoration: const InputDecoration(labelText: '简介')),
        const SizedBox(height: 12),
        TextField(controller: _goalController, decoration: const InputDecoration(labelText: '训练目标')),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: state.loading
              ? null
              : () => ref.read(profileControllerProvider.notifier).save(
                    UserProfile(
                      gender: profile?.gender ?? '',
                      age: profile?.age,
                      city: _cityController.text.trim(),
                      bio: _bioController.text.trim(),
                      fitnessGoal: _goalController.text.trim(),
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
