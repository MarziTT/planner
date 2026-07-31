import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/daily_brief_repository.dart';
import '../domain/daily_brief.dart';
import '../../../core/butler/butler_name_provider.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/butler/butler_persona.dart';

final dailyBriefProvider = FutureProvider<DailyBrief>((ref) {
  final butlerName = ref.watch(butlerNameProvider);
  final theme = ref.watch(themeControllerProvider);
  final persona = ButlerPersona.forTheme(theme.preset);
  return ref.read(dailyBriefRepositoryProvider).fetch(
    butlerName: butlerName,
    personaPreset: persona.preset == ButlerPersonaPreset.zzzTheme ? 'zzz_zero' : 'default',
  );
});
