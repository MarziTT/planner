import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../state/weather_tone_provider.dart';

class WeatherTonePage extends ConsumerStatefulWidget {
  const WeatherTonePage({super.key});

  @override
  ConsumerState<WeatherTonePage> createState() => _WeatherTonePageState();
}

class _WeatherTonePageState extends ConsumerState<WeatherTonePage> {
  late final TextEditingController _textController;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      Future.microtask(
          () => ref.read(weatherToneProvider.notifier).load());
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final tone = _textController.text;
    final success =
        await ref.read(weatherToneProvider.notifier).save(tone);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  }

  Future<void> _resetDefault() async {
    final success =
        await ref.read(weatherToneProvider.notifier).resetToDefault();
    if (success && mounted) {
      _textController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢复默认')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final toneState = ref.watch(weatherToneProvider);
    final theme = Theme.of(context);
    final isZzz =
        ref.watch(themeControllerProvider).preset ==
            PlannerThemePreset.kamenRiderZzz;

    // 首次加载完成后同步到 TextController
    if (!toneState.loading && _textController.text != toneState.tone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _textController.text != toneState.tone) {
          _textController.text = toneState.tone;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('天气管家语气'),
        actions: [
          TextButton(
            onPressed: toneState.saving ? null : _save,
            child: toneState.saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    '保存',
                    style: TextStyle(
                      color: isZzz
                          ? const Color(0xFF00FF41)
                          : theme.colorScheme.primary,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 错误提示
          if (toneState.error != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 18,
                      color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      toneState.error!,
                      style: TextStyle(
                          color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 语气文本编辑区
          Card(
            color: isZzz ? const Color(0xFF0D0B12) : null,
            shape: isZzz
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side:
                        const BorderSide(color: Color(0xFF00FF41)),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 20,
                          color: isZzz
                              ? const Color(0xFF00FF41)
                              : theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('语气 Prompt',
                          style:
                              theme.textTheme.titleSmall?.copyWith(
                            color: isZzz
                                ? const Color(0xFFE0F0E0)
                                : null,
                          )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '自定义天气管家的说话风格。留空表示使用默认温暖管家语气。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isZzz
                          ? const Color(0xFFC8C8D8)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textController,
                    maxLines: 8,
                    minLines: 5,
                    style: isZzz
                        ? const TextStyle(
                            color: Color(0xFFE0F0E0),
                            height: 1.6,
                          )
                        : const TextStyle(height: 1.6),
                    decoration: InputDecoration(
                      hintText: '输入语气描述，或从下方预设模板中选择…',
                      hintStyle: TextStyle(
                        color: isZzz
                            ? const Color(0xFF6A6A7A)
                            : null,
                      ),
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(14),
                      filled: isZzz,
                      fillColor: isZzz
                          ? const Color(0xFF14141A)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 恢复默认
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: toneState.saving ? null : _resetDefault,
              icon: Icon(Icons.restore,
                  size: 18,
                  color: isZzz
                      ? const Color(0xFF00FF41)
                      : theme.colorScheme.error),
              label: Text(
                '恢复默认',
                style: TextStyle(
                  color: isZzz
                      ? const Color(0xFF00FF41)
                      : theme.colorScheme.error,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 预设模板区标题
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined,
                  size: 20,
                  color: isZzz
                      ? const Color(0xFF00FF41)
                      : theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('预设模板',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color:
                        isZzz ? const Color(0xFFE0F0E0) : null,
                  )),
            ],
          ),
          const SizedBox(height: 8),

          // 预设模板卡片
          // Zero 模板仅 ZZZ 主题可见
          ...weatherTonePresets
              .where((p) => isZzz || p.name == '温暖管家')
              .map(
            (preset) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PresetCard(
                preset: preset,
                isZzz: isZzz,
                onUse: () {
                  _textController.text = preset.prompt;
                  ref
                      .read(weatherToneProvider.notifier)
                      .updateLocal(preset.prompt);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final WeatherTonePreset preset;
  final bool isZzz;
  final VoidCallback onUse;

  const _PresetCard({
    required this.preset,
    required this.isZzz,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    final preview = preset.prompt.length > 50
        ? '${preset.prompt.substring(0, 50)}…'
        : preset.prompt;

    return Card(
      color: isZzz ? const Color(0xFF0D0B12) : null,
      shape: isZzz
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF00FF41)),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    preset.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          color: isZzz
                              ? const Color(0xFFE0F0E0)
                              : null,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              preview,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isZzz
                        ? const Color(0xFFC8C8D8)
                        : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onUse,
                icon: const Icon(Icons.content_copy, size: 16),
                label: const Text('使用此模板'),
                style: isZzz
                    ? FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF00FF41).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF00FF41),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
