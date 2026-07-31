import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/daily_brief_repository.dart';
import '../domain/daily_brief.dart';
import '../../../core/butler/butler_name_provider.dart';

final dailyBriefProvider = FutureProvider<DailyBrief>((ref) {
  final butlerName = ref.watch(butlerNameProvider);
  return ref.read(dailyBriefRepositoryProvider).fetch(butlerName: butlerName);
});
