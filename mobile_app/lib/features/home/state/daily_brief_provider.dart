import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/daily_brief_repository.dart';
import '../domain/daily_brief.dart';

final dailyBriefProvider = FutureProvider<DailyBrief>((ref) {
  return ref.read(dailyBriefRepositoryProvider).fetch();
});
