import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/update_repository.dart';
import '../domain/app_version.dart';
import '../domain/update_policy.dart';
import '../state/update_controller.dart';

class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  AppLifecycleListener? _lifecycleListener;
  bool _dialogOpen = false;
  bool _checkingUpdate = false;
  bool _applyingResource = false;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: _checkForUpdates,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(updateControllerProvider, (previous, next) {
      final message = next.lastActionMessage;
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        ref.read(updateControllerProvider.notifier).clearMessage();
      }
    });

    final state = ref.watch(updateControllerProvider);
    final info = state.info;
    if (info == null) {
      return const SizedBox.shrink();
    }

    final decision = _evaluate(info);
    if (decision.kind == UpdateDecisionKind.none) {
      return const SizedBox.shrink();
    }

    final promptToken =
        '${decision.kind.name}:${info.version}:${info.buildNumber}:${info.resourceCount}';
    if (!_dialogOpen && state.lastPromptToken != promptToken) {
      _dialogOpen = true;
      final token = promptToken;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        ref.read(updateControllerProvider.notifier).markPromptShown(token);
        await _showUpdateDialog(context, info, decision);
        _dialogOpen = false;
      });
    }

    final isForce = decision.kind == UpdateDecisionKind.forceAppUpgrade;
    final title = switch (decision.kind) {
      UpdateDecisionKind.resourceOnly => '资源已可热更新',
      UpdateDecisionKind.optionalAppUpgrade => '发现新版本 ${info.version}',
      UpdateDecisionKind.forceAppUpgrade => '必须更新到 ${info.version}',
      UpdateDecisionKind.none => '',
    };

    return Material(
      color: isForce
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      child: ListTile(
        dense: true,
        title: Text(title),
        subtitle: Text(
          info.releaseNotes.isEmpty
              ? decision.reason
              : info.releaseNotes.join(' · '),
        ),
        trailing: FilledButton(
          onPressed: () => _showUpdateDialog(context, info, decision),
          child: Text(isForce ? '立即更新' : '查看'),
        ),
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      await ref.read(updateControllerProvider.notifier).check();
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  UpdateDecision _evaluate(UpdateInfo info) {
    final remoteBuild = int.tryParse(info.buildNumber) ?? currentAppBuildNumber;
    final hasLogicChange = remoteBuild > currentAppBuildNumber ||
        info.version != currentAppVersion;
    final hasResourceBundle = info.resourceCount > 0;
    return UpdatePolicy.evaluate(
      requiredUpgrade: info.required,
      hasResourceBundle: hasResourceBundle,
      hasLogicChange: hasLogicChange,
    );
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    UpdateInfo info,
    UpdateDecision decision,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: decision.kind != UpdateDecisionKind.forceAppUpgrade,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          decision.kind == UpdateDecisionKind.forceAppUpgrade
              ? '需要更新后继续使用'
              : '发现可用更新',
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前版本 $currentAppVersion ($currentAppBuildNumber)'),
              const SizedBox(height: 4),
              Text('目标版本 ${info.version} (${info.buildNumber})'),
              const SizedBox(height: 8),
              Text(decision.reason),
              if (info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...info.releaseNotes.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('- $item'),
                  ),
                ),
              ],
              if (info.downloadUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('下载地址'),
                const SizedBox(height: 6),
                SelectableText(info.downloadUrl),
              ],
            ],
          ),
        ),
        actions: [
          if (decision.kind != UpdateDecisionKind.forceAppUpgrade)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('稍后'),
            ),
          FilledButton(
            onPressed: _applyingResource ? null : () async {
              if (decision.kind == UpdateDecisionKind.resourceOnly) {
                setState(() => _applyingResource = true);
                try {
                  await ref
                      .read(updateControllerProvider.notifier)
                      .applyResourceUpdateNow();
                } finally {
                  if (mounted) setState(() => _applyingResource = false);
                }
              } else if (info.downloadUrl.isNotEmpty) {
                final opened = await _openDownloadUrl(info.downloadUrl);
                if (!opened) {
                  await Clipboard.setData(
                      ClipboardData(text: info.downloadUrl));
                }
                if (!mounted) return;
                ref.read(updateControllerProvider.notifier).announce(
                      opened ? '已打开下载页面。' : '无法直接打开，下载地址已复制。',
                    );
              } else {
                ref
                    .read(updateControllerProvider.notifier)
                    .announce('下载地址还没有配置。');
              }
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
            },
            child: _applyingResource
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    decision.kind == UpdateDecisionKind.resourceOnly ? '知道了' : '下载更新',
                  ),
          ),
        ],
      ),
    );
  }

  Future<bool> _openDownloadUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
