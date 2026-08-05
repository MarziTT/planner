import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/weather_timeline_card.dart';
import '../weather_provider.dart';

/// Full-page weather smart-advisory detail.
///
/// Accessed via `/weather` route. Shows the complete timeline
/// card with all available time slots.
class WeatherPage extends ConsumerStatefulWidget {
  const WeatherPage({super.key});

  @override
  ConsumerState<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends ConsumerState<WeatherPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(smartAdvisoryProvider.notifier).loadAdvisory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('天气'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(smartAdvisoryProvider.notifier).manualRefresh(),
        child: ListView(
          children: const [
            WeatherTimelineCard(),
          ],
        ),
      ),
    );
  }
}
