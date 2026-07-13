enum UpdateDecisionKind {
  none,
  resourceOnly,
  optionalAppUpgrade,
  forceAppUpgrade,
}

class UpdateDecision {
  const UpdateDecision(this.kind, {this.reason = ''});

  final UpdateDecisionKind kind;
  final String reason;
}

class UpdatePolicy {
  static UpdateDecision evaluate({
    required bool requiredUpgrade,
    required bool hasResourceBundle,
    required bool hasLogicChange,
  }) {
    if (requiredUpgrade) {
      return const UpdateDecision(UpdateDecisionKind.forceAppUpgrade,
          reason: '服务端标记为强制更新');
    }
    if (hasLogicChange) {
      return const UpdateDecision(UpdateDecisionKind.optionalAppUpgrade,
          reason: '检测到逻辑版本变更');
    }
    if (hasResourceBundle) {
      return const UpdateDecision(UpdateDecisionKind.resourceOnly,
          reason: '仅资源包变更，可热更新');
    }
    return const UpdateDecision(UpdateDecisionKind.none, reason: '当前已是最新');
  }
}
