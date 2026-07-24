import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme_controller.dart';
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

  @override
  void dispose() {
    _focusController.dispose();
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
    final themeState = ref.watch(themeControllerProvider);
    final themeController = ref.read(themeControllerProvider.notifier);
    final theme = Theme.of(context);
    final isZzz = themeState.preset == PlannerThemePreset.kamenRiderZzz;

    return Scaffold(
      backgroundColor: isZzz ? const Color(0xFF0A0A0F) : null,
      appBar: AppBar(
        backgroundColor: isZzz ? const Color(0xFF0A0A0F) : null,
        title: Text('完善节奏档案',
            style: isZzz ? const TextStyle(color: Color(0xFF00FF41)) : null),
        actions: [
          TextButton(
            onPressed: profileState.loading ? null : _skip,
            style: isZzz ? TextButton.styleFrom(foregroundColor: const Color(0xFF00FF41)) : null,
            child: const Text('跳过'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            '先选一个最接近你的身份，管家会用它来调整首页、标签和上班模式。',
            style: theme.textTheme.titleMedium?.copyWith(
              height: 1.35,
              color: isZzz ? const Color(0xFFE0F0E0) : null,
            ),
          ),
          const SizedBox(height: 18),
          _IdentityPicker(
            isZzz: isZzz,
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
          _SectionTitle(title: _routineTitle, isZzz: isZzz),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TimeCard(
                  isZzz: isZzz,
                  label: _routineStartLabel,
                  value: _routineStart,
                  onTap: () => _pickTime(start: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeCard(
                  isZzz: isZzz,
                  label: _routineEndLabel,
                  value: _routineEnd,
                  onTap: () => _pickTime(start: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _focusController,
            style: isZzz ? const TextStyle(color: Color(0xFFE0F0E0)) : null,
            decoration: isZzz
                ? InputDecoration(
                    labelText: _focusLabel,
                    labelStyle: const TextStyle(color: Color(0xFF00FF41)),
                    prefixIcon: const Icon(Icons.flag_outlined, color: Color(0xFF00FF41)),
                    filled: true,
                    fillColor: const Color(0xFF0D0B12),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF41)),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF41)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF00FF41)),
                    ),
                  )
                : InputDecoration(
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
            activeColor: isZzz ? const Color(0xFF00FF41) : null,
            onChanged: (value) => setState(() => _wantsFitness = value),
          ),
          if (_wantsFitness) ...[
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              selected: {_fitnessMode},
              onSelectionChanged: (value) =>
                  setState(() => _fitnessMode = value.first),
              style: isZzz
                  ? ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF00FF41);
                        }
                        return null;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF0A0A0F);
                        }
                        return null;
                      }),
                    )
                  : null,
              segments: const [
                ButtonSegment(value: 'self', label: Text('自主健身')),
                ButtonSegment(value: 'coach', label: Text('私教陪练')),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _SectionTitle(title: '选一个你喜欢的主题', isZzz: isZzz),
          const SizedBox(height: 10),
          _ThemePicker(
            isZzz: isZzz,
            presets: _publicPresets,
            selected: themeState.preset,
            onSelected: (preset) => themeController.switchPreset(preset),
          ),
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
            style: isZzz
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF41),
                    foregroundColor: const Color(0xFF0A0A0F),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ).copyWith(
                    shadowColor: WidgetStateProperty.all(const Color(0xFF00FF41)),
                    elevation: WidgetStateProperty.all(6),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: profileState.loading ? null : _skip,
            style: isZzz
                ? OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00FF41),
                    side: const BorderSide(color: Color(0xFF00FF41)),
                  )
                : null,
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
  const _IdentityPicker({required this.value, required this.onChanged, this.isZzz = false});

  final String value;
  final ValueChanged<String> onChanged;
  final bool isZzz;

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
                  : (isZzz ? const Color(0xFF0D0B12) : theme.colorScheme.surfaceContainerLow),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? (isZzz ? const Color(0xFF00FF41) : theme.colorScheme.primary)
                    : (isZzz ? const Color(0xFFC8C8D8) : theme.colorScheme.outlineVariant),
              ),
              boxShadow: selected && isZzz
                  ? const [
                      BoxShadow(
                        color: Color(0xFF00FF41),
                        blurRadius: 8,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon,
                    color: selected
                        ? (isZzz ? const Color(0xFF00FF41) : theme.colorScheme.primary)
                        : null),
                const SizedBox(height: 8),
                Text(item.label, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  item.caption,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isZzz ? const Color(0xFFC8C8D8) : theme.colorScheme.onSurfaceVariant,
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
  const _SectionTitle({required this.title, this.isZzz = false});

  final String title;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: isZzz ? const Color(0xFF00FF41) : null,
          ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.value,
    required this.onTap,
    this.isZzz = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        alignment: Alignment.centerLeft,
        backgroundColor: isZzz ? const Color(0xFF0D0B12) : null,
        side: isZzz ? const BorderSide(color: Color(0xFF00FF41)) : null,
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

const _publicPresets = [
  PlannerThemePreset.sakuraSeason,
  PlannerThemePreset.ocean,
  PlannerThemePreset.forest,
  PlannerThemePreset.desertDusk,
  PlannerThemePreset.aurora,
];

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({
    required this.presets,
    required this.selected,
    required this.onSelected,
    this.isZzz = false,
  });

  final List<PlannerThemePreset> presets;
  final PlannerThemePreset selected;
  final ValueChanged<PlannerThemePreset> onSelected;
  final bool isZzz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: presets.map((preset) {
        final isSelected = preset == selected;
        final color = _colorOf(preset);
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelected(preset),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : (isZzz ? const Color(0xFF0D0B12) : theme.colorScheme.surfaceContainerLow),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? (isZzz ? const Color(0xFF00FF41) : theme.colorScheme.primary)
                    : (isZzz ? const Color(0xFFC8C8D8) : theme.colorScheme.outlineVariant),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected && isZzz
                  ? const [
                      BoxShadow(
                        color: Color(0xFF00FF41),
                        blurRadius: 8,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labelOf(preset),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w400,
                    height: 1.15,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _colorOf(PlannerThemePreset preset) {
    switch (preset) {
      case PlannerThemePreset.sakuraSeason:
        return const Color(0xFFD98CB3);
      case PlannerThemePreset.ocean:
        return const Color(0xFF4A7A9E);
      case PlannerThemePreset.forest:
        return const Color(0xFF5A8A6C);
      case PlannerThemePreset.desertDusk:
        return const Color(0xFFC1764A);
      case PlannerThemePreset.aurora:
        return const Color(0xFF4AB8A6);
      case PlannerThemePreset.kamenRiderZzz:
        return const Color(0xFFE53935);
    }
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
        return 'ZZZ';
    }
  }
}
