import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileSetupPage extends StatelessWidget {
  const ProfileSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('完成资料')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('问卷与个人资料会在这里重写为原生表单流。', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const Text('当前先把重构链路打通，后续会接入 profile/settings API。'),
            const Spacer(),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('进入应用'),
            ),
          ],
        ),
      ),
    );
  }
}
