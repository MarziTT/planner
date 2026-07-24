import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_token_storage.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../widgets/zzz_gif_decoration.dart';
import '../state/auth_controller.dart';


class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedPhone();
  }

  Future<void> _loadSavedPhone() async {
    final storage = ref.read(tokenStorageProvider);
    final phone = await storage.getPhoneNumber();
    if (phone != null && phone.isNotEmpty) {
      _phoneController.text = phone;
    }
  }

  Future<void> _savePhone(String phone) async {
    await ref.read(tokenStorageProvider).savePhoneNumber(phone);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 60;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        setState(() {
          _countdown = 0;
        });
      } else {
        setState(() {
          _countdown = _countdown - 1;
        });
      }
    });
  }

  void _sendCode() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    _savePhone(phone);

    final notifier = ref.read(authControllerProvider.notifier);
    notifier.sendCode(phone: phone);
    _startCountdown();
  }

  void _submit() {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (phone.isEmpty || code.isEmpty) return;

    final notifier = ref.read(authControllerProvider.notifier);
    notifier.loginWithPhone(phone: phone, code: code);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, next) {
      if (next.session != null && prev?.session == null) {
        _savePhone(_phoneController.text.trim());
      }
    });

    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isZzz = ref.watch(themeControllerProvider).preset ==
        PlannerThemePreset.kamenRiderZzz;
    final canSendCode =
        _countdown == 0 && _phoneController.text.trim().isNotEmpty;

    final zzzSurface = zzzSurfaceColor;

    return Scaffold(
      backgroundColor: isZzz ? zzzBgColor : colorScheme.surface,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _BrandHeader(),
                      const SizedBox(height: 28),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: isZzz
                              ? zzzSurface
                              : colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isZzz
                                ? zzzGreen.withValues(alpha: 0.55)
                                : colorScheme.outlineVariant
                                    .withValues(alpha: 0.52),
                          ),
                          boxShadow: isZzz
                              ? [
                                  BoxShadow(
                                    color: zzzGreen.withValues(alpha: 0.18),
                                    blurRadius: 28,
                                    offset: const Offset(0, 18),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: colorScheme.shadow
                                        .withValues(alpha: 0.08),
                                    blurRadius: 28,
                                    offset: const Offset(0, 18),
                                  ),
                                ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '手机号登录',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isZzz ? zzzGreenLight : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '输入手机号获取验证码，新用户将自动注册。',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isZzz
                                      ? zzzGreenLight
                                      : colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: '手机号',
                                  hintText: '请输入手机号',
                                  prefixIcon: Icon(Icons.phone_android_rounded,
                                      color: isZzz ? zzzGreen : null),
                                  fillColor: isZzz ? zzzSurface : null,
                                  filled: isZzz ? true : null,
                                  focusedBorder: isZzz
                                      ? OutlineInputBorder(
                                          borderSide: BorderSide(color: zzzGreen),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _codeController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) =>
                                          authState.loading ? null : _submit(),
                                      decoration: InputDecoration(
                                        labelText: '验证码',
                                        hintText: '6位验证码',
                                        prefixIcon: Icon(Icons.pin_outlined,
                                            color: isZzz ? zzzGreen : null),
                                        fillColor: isZzz ? zzzSurface : null,
                                        filled: isZzz ? true : null,
                                        focusedBorder: isZzz
                                            ? OutlineInputBorder(
                                                borderSide:
                                                    BorderSide(color: zzzGreen),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    height: 56,
                                    child: OutlinedButton(
                                      onPressed: canSendCode && !authState.loading
                                          ? _sendCode
                                          : null,
                                      style: isZzz
                                          ? OutlinedButton.styleFrom(
                                              foregroundColor: zzzGreen,
                                              side: BorderSide(color: zzzGreen),
                                            )
                                          : null,
                                      child: Text(
                                        _countdown > 0
                                            ? '${_countdown}s 后重发'
                                            : '获取验证码',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (authState.errorMessage != null) ...[
                                _ErrorNotice(
                                  message: authState.errorMessage!,
                                  isZzz: isZzz,
                                ),
                                const SizedBox(height: 12),
                              ],
                              _LoginButton(
                                loading: authState.loading,
                                isZzz: isZzz,
                                onPressed: _submit,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '登录状态会保存在本机，重新打开也会自动恢复。',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isZzz
                              ? zzzGreenLight
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isZzz)
            Positioned(
              right: 0,
              bottom: 0,
              child: ZzzCornerArt(
                spec: zzzSpecFromSeed(DateTime.now().day + 1),
                size: 72,
                opacity: 0.3,
              ),
            ),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.loading,
    required this.isZzz,
    required this.onPressed,
  });

  final bool loading;
  final bool isZzz;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: loading ? null : onPressed,
      style: isZzz
          ? FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: zzzGreen,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            )
          : null,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.arrow_forward_rounded),
      label: Text(
        loading ? '正在登录...' : '登录 / 注册',
      ),
    );

    if (!isZzz) return button;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            zzzGreen,
            zzzGreen.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: zzzGreen.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: button,
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isZzz = _readIsZzz(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isZzz ? zzzGreen : colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isZzz
                    ? [
                        BoxShadow(
                          color: zzzGreen.withValues(alpha: 0.55),
                          blurRadius: 14,
                          offset: const Offset(0, 0),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                Icons.auto_awesome_motion_rounded,
                color:
                    isZzz ? zzzBgColor : colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DD',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      color: isZzz ? zzzGreenLight : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '你的专属私人管家',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isZzz
                          ? zzzGreenLight
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          '衣食住行、日程提醒，一句话交给管家搞定。',
          style: theme.textTheme.bodyLarge?.copyWith(
            color:
                isZzz ? zzzGreenLight : colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

bool _readIsZzz(BuildContext context) {
  final scope = ProviderScope.containerOf(context);
  final state = scope.read(themeControllerProvider);
  return state.preset == PlannerThemePreset.kamenRiderZzz;
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, this.isZzz = false});

  final String message;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isZzz ? zzzRed.withValues(alpha: 0.15) : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isZzz
            ? [
                BoxShadow(
                  color: zzzRed.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isZzz ? zzzRed : colorScheme.onErrorContainer,
          height: 1.35,
        ),
      ),
    );
  }
}
