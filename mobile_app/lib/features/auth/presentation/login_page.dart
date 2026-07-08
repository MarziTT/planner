import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/auth_controller.dart';

enum _AuthMode { login, register }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  _AuthMode _mode = _AuthMode.login;
  final _emailController = TextEditingController(text: 'demo@pixelplanner.app');
  final _passwordController = TextEditingController(text: '12345678');
  final _nicknameController = TextEditingController(text: 'Pixel User');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isRegister = _mode == _AuthMode.register;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.18),
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pixel Planner', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 10),
                    Text(
                      '全新 Flutter 客户端认证入口，直接接入新的 Python API。',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: authState.loading
                                  ? null
                                  : () => setState(() => _mode = _AuthMode.login),
                              style: FilledButton.styleFrom(
                                backgroundColor: _mode == _AuthMode.login
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                foregroundColor: _mode == _AuthMode.login
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                                elevation: 0,
                              ),
                              child: const Text('登录'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: authState.loading
                                  ? null
                                  : () => setState(() => _mode = _AuthMode.register),
                              style: FilledButton.styleFrom(
                                backgroundColor: _mode == _AuthMode.register
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                foregroundColor: _mode == _AuthMode.register
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurfaceVariant,
                                elevation: 0,
                              ),
                              child: const Text('注册'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRegister ? '创建新账号' : '欢迎回来',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isRegister
                                  ? '注册后会自动登录，并进入资料完善流程。'
                                  : '登录后会恢复你的会话和个人计划数据。',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (isRegister) ...[
                              TextField(
                                controller: _nicknameController,
                                decoration: const InputDecoration(
                                  labelText: '昵称',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: '邮箱',
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: '密码',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (authState.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  authState.errorMessage!,
                                  style: TextStyle(color: theme.colorScheme.error),
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: authState.loading ? null : _submit,
                                icon: Icon(
                                  isRegister ? Icons.person_add_alt_1 : Icons.login,
                                ),
                                label: Text(
                                  authState.loading
                                      ? (isRegister ? '正在注册...' : '正在登录...')
                                      : (isRegister ? '注册并进入' : '登录进入'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '当前默认指向新后端接口；如果接口不可用，页面会直接给出失败提示。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final notifier = ref.read(authControllerProvider.notifier);
    if (_mode == _AuthMode.register) {
      notifier.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nickname: _nicknameController.text.trim().isEmpty
            ? 'Pixel User'
            : _nicknameController.text.trim(),
      );
      return;
    }

    notifier.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }
}
