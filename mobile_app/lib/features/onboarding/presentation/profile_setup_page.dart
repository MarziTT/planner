import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/state/auth_controller.dart';
import '../../profile/domain/profile_model.dart';
import '../../profile/state/profile_controller.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _goalController = TextEditingController();

  @override
  void dispose() {
    _cityController.dispose();
    _bioController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(profileControllerProvider.notifier).save(
          UserProfile(
            gender: '',
            age: null,
            city: _cityController.text.trim(),
            bio: _bioController.text.trim(),
            fitnessGoal: _goalController.text.trim(),
          ),
        );

    final profileState = ref.read(profileControllerProvider);
    if (profileState.errorMessage != null) {
      return;
    }

    await ref.read(authControllerProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('完善资料')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('先把你的基础资料补齐，再进入应用。', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          const Text('这一步完成后就不会再被路由拦回资料页了，后续也能在账号页继续修改。'),
          const SizedBox(height: 24),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(labelText: '城市'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            decoration: const InputDecoration(labelText: '简介'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _goalController,
            decoration: const InputDecoration(labelText: '训练目标'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: profileState.loading ? null : _submit,
            child: Text(profileState.loading ? '保存中...' : '进入应用'),
          ),
          if (profileState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              profileState.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
