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
  String _identity = 'worker';
  String _routineStart = '09:00';
  String _routineEnd = '18:00';
  bool _wantsFitness = false;
  String _fitnessMode = 'self';
  final _focusController = TextEditingController();
  final _cityController = TextEditingController();

  @override
  void dispose() {
    _focusController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(profileControllerProvider.notifier).save(_buildProfile());

    final profileState = ref.read(profileControllerProvider);
    if (profileState.errorMessage != null) {
      return;
    }

    await _finishOnboarding();
  }

  Future<void> _skip() async {
    await ref.read(profileControllerProvider.notifier).save(_buildProfile());
    await _finishOnboarding();
  }

  UserProfile _buildProfile() {
    return UserProfile(
      gender: '',
      age: null,
      city: _cityController.text.trim(),
      bio: '',
      fitnessGoal: _wantsFitness ? _focusController.text.trim() : '',
      identity: _identity,
      routineStart: _routineStart,
      routineEnd: _routineEnd,
      focusArea: _focusController.text.trim(),
      wantsFitness: _wantsFitness,
      fitnessMode: _fitnessMode,
    );
  }

  Future<void> _finishOnboarding() async {
    await ref.read(authControllerProvider.notifier).completeOnboarding();
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _pickTime({required bool start}) async {
    final current = _parseTime(start ? _routineStart : _routineEnd);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
    );
    if (picked == null) return;
    setState(() {
      final value = _formatTime(picked);
      if (start) {
        _routineStart = value;
      } else {
        _routineEnd = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('完善节奏档案'),
        actions: [
          TextButton(
            onPressed: profileState.loading ? null : _skip,
            child: const Text('跳过'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            '先选一个最接近你的身份，FlowDay 会用它来调整首页、标签和上班模式。',
            style: theme.textTheme.titleMedium?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 18),
          _IdentityPicker(
            value: _identity,
            onChanged: (value) => setState(() {
              _identity = value;
              if (value == 'student') {
                _routineStart = '08:00';
                _routineEnd = '17:30';
              } else if (value == 'caregiver') {
                _routineStart = '07:30';
                _routineEnd = '21:30';
              } else if (value == 'freelancer') {
                _routineStart = '10:00';
                _routineEnd = '19:00';
              } else {
                _routineStart = '09:00';
                _routineEnd = '18:00';
              }
            }),
          ),
          const SizedBox(height: 18),
          _SectionTitle(title: _routineTitle),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeCard(
                  label: _routineStartLabel,
                  value: _routineStart,
                  onTap: () => _pickTime(start: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeCard(
                  label: _routineEndLabel,
                  value: _routineEnd,
                  onTap: () => _pickTime(start: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: '常驻城市（可选）',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _focusController,
            decoration: InputDecoration(
              labelText: _focusLabel,
              prefixIcon: const Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('我想显示训练/健身模块'),
            subtitle: const Text('开启后首页会显示训练面板。'),
            value: _wantsFitness,
            onChanged: (value) => setState(() => _wantsFitness = value),
          ),
          if (_wantsFitness) ...[
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              selected: {_fitnessMode},
              onSelectionChanged: (value) =>
                  setState(() => _fitnessMode = value.first),
              segments: const [
                ButtonSegment(value: 'self', label: Text('自主健身')),
                ButtonSegment(value: 'coach', label: Text('私教陪练')),
              ],
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: profileState.loading ? null : _submit,
            icon: profileState.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(profileState.loading ? '正在保存...' : '保存并进入应用'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: profileState.loading ? null : _skip,
            child: const Text('先跳过，直接进入应用'),
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

  String get _routineTitle {
    switch (_identity) {
      case 'student':
        return '学习时间';
      case 'caregiver':
        return '家庭节奏';
      case 'freelancer':
        return '工作节奏';
      default:
        return '上班模式时间';
    }
  }

  String get _routineStartLabel {
    switch (_identity) {
      case 'student':
        return '上课开始';
      case 'caregiver':
        return '忙碌开始';
      case 'freelancer':
        return '开工时间';
      default:
        return '上班时间';
    }
  }

  String get _routineEndLabel {
    switch (_identity) {
      case 'student':
        return '学习结束';
      case 'caregiver':
        return '休息时间';
      case 'freelancer':
        return '收工时间';
      default:
        return '下班时间';
    }
  }

  String get _focusLabel {
    switch (_identity) {
      case 'student':
        return '近期学习重点（可选）';
      case 'caregiver':
        return '最近最想照顾好的事（可选）';
      case 'freelancer':
        return '近期项目重点（可选）';
      default:
        return '近期工作重点（可选）';
    }
  }
}

class _IdentityPicker extends StatelessWidget {
  const _IdentityPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _items = [
    _IdentityOption('worker', '上班族', Icons.work_outline_rounded, '按上下班时间组织待办'),
    _IdentityOption('student', '学生', Icons.school_outlined, '围绕课程和自习安排'),
    _IdentityOption('caregiver', '家庭主理人', Icons.home_outlined, '照顾家庭事务和提醒'),
    _IdentityOption(
        'freelancer', '自由职业', Icons.laptop_mac_rounded, '按项目和弹性时间推进'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _items.map((item) {
        final selected = value == item.value;
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onChanged(item.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 158,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon,
                    color: selected ? theme.colorScheme.primary : null),
                const SizedBox(height: 8),
                Text(item.label, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  item.caption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _IdentityOption {
  const _IdentityOption(this.value, this.label, this.icon, this.caption);

  final String value;
  final String label;
  final IconData icon;
  final String caption;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return const TimeOfDay(hour: 9, minute: 0);
  return TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 9,
    minute: int.tryParse(parts[1]) ?? 0,
  );
}

String _formatTime(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
