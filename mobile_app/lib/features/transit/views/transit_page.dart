/// Transit page — 出行模块主页面
///
/// Displays today's trip, supports manual ticket entry, OCR scan,
/// route planning, and one-click taxi hailing.
///
/// Spec: §6.7

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/zzz_theme_extension.dart';
import '../models/transit.dart';
import '../services/external_app.dart';
import '../services/ocr_service.dart';
import '../services/reminder_chain.dart';
import '../services/route_service.dart';

final _ocrServiceProvider = Provider<OcrService>((ref) {
  final dio = ref.read(apiClientProvider);
  return OcrService(dio: dio);
});

final _routeServiceProvider = Provider<RouteService>((ref) {
  final dio = ref.read(apiClientProvider);
  return RouteService(dio: dio);
});

/// Whether the user has an active trip for today.
/// In Phase 2, trips are stored in-memory for the session; persistent storage
/// comes later.
final _currentTripProvider = StateProvider<TransitTrip?>((ref) => null);

final _currentTimelineProvider = Provider<ReminderTimeline?>((ref) {
  final trip = ref.watch(_currentTripProvider);
  if (trip == null) return null;
  return ReminderNode.build(trip, DateTime.now());
});

class TransitPage extends ConsumerStatefulWidget {
  const TransitPage({super.key});

  @override
  ConsumerState<TransitPage> createState() => _TransitPageState();
}

class _TransitPageState extends ConsumerState<TransitPage> {
  final _formKey = GlobalKey<FormState>();

  // Manual entry controllers
  final _trainNumberCtrl = TextEditingController();
  final _departureDateCtrl = TextEditingController();
  final _departureTimeCtrl = TextEditingController();
  final _departureStationCtrl = TextEditingController();
  final _arrivalStationCtrl = TextEditingController();
  final _carriageCtrl = TextEditingController();
  final _seatNumberCtrl = TextEditingController();

  // Route planning controllers
  final _fromStationCtrl = TextEditingController();
  final _toStationCtrl = TextEditingController();
  List<String> _fromSuggestions = [];
  List<String> _toSuggestions = [];
  Timer? _stationSearchTimer;

  bool _loading = false;
  String? _error;
  TransitRoute? _routeResult;

  // Inline OCR state
  bool _ocrLoading = false;

  // Manual save state
  bool _saveLoading = false;

  @override
  void dispose() {
    _trainNumberCtrl.dispose();
    _departureDateCtrl.dispose();
    _departureTimeCtrl.dispose();
    _departureStationCtrl.dispose();
    _arrivalStationCtrl.dispose();
    _carriageCtrl.dispose();
    _seatNumberCtrl.dispose();
    _fromStationCtrl.dispose();
    _toStationCtrl.dispose();
    _stationSearchTimer?.cancel();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // OCR
  // -----------------------------------------------------------------------

  Future<void> _onScanTicket() async {
    final ocrService = ref.read(_ocrServiceProvider);
    final file = await ocrService.pickFromGallery();
    if (file == null) return;

    setState(() => _ocrLoading = true);
    try {
      final trip = await ocrService.ocrTicket(file);
      // Populate form fields
      _trainNumberCtrl.text = trip.trainNumber;
      _departureStationCtrl.text = trip.departureStation;
      _arrivalStationCtrl.text = trip.arrivalStation;
      if (trip.carriage != null) _carriageCtrl.text = trip.carriage!;
      if (trip.seatNumber != null) _seatNumberCtrl.text = trip.seatNumber!;
      if (trip.departureTime != null)
        _departureTimeCtrl.text = trip.departureTime!;

      final d = trip.departureDate;
      _departureDateCtrl.text =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '识别完成: ${trip.trainNumber} ${trip.departureStation} → ${trip.arrivalStation}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _ocrLoading = false);
    }
  }

  // -----------------------------------------------------------------------
  // Manual save
  // -----------------------------------------------------------------------

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final trainNum = _trainNumberCtrl.text.trim();
    if (trainNum.isEmpty) {
      _showError('请输入车次');
      return;
    }

    final depDate = DateTime.tryParse(_departureDateCtrl.text.trim());
    if (depDate == null) {
      _showError('出发日期格式无效');
      return;
    }

    setState(() => _saveLoading = true);

    try {
      final trip = TransitTrip(
        tripId: DateTime.now().millisecondsSinceEpoch.toString(),
        trainNumber: trainNum,
        departureDate: depDate,
        departureStation: _departureStationCtrl.text.trim(),
        arrivalStation: _arrivalStationCtrl.text.trim(),
        departureTime: _departureTimeCtrl.text.trim().isEmpty
            ? null
            : _departureTimeCtrl.text.trim(),
        carriage: _carriageCtrl.text.trim().isEmpty
            ? null
            : _carriageCtrl.text.trim(),
        seatNumber: _seatNumberCtrl.text.trim().isEmpty
            ? null
            : _seatNumberCtrl.text.trim(),
      );

      // Schedule reminders
      ReminderChainService.schedule(trip);

      ref.read(_currentTripProvider.notifier).state = trip;

      if (mounted) {
        _clearForm();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '已保存行程: $trainNum ${trip.departureStation} → ${trip.arrivalStation}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saveLoading = false);
    }
  }

  void _clearForm() {
    _trainNumberCtrl.clear();
    _departureDateCtrl.clear();
    _departureTimeCtrl.clear();
    _departureStationCtrl.clear();
    _arrivalStationCtrl.clear();
    _carriageCtrl.clear();
    _seatNumberCtrl.clear();
    _formKey.currentState?.reset();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // -----------------------------------------------------------------------
  // Route planning
  // -----------------------------------------------------------------------

  Future<void> _onPlanRoute() async {
    final from = _fromStationCtrl.text.trim();
    final to = _toStationCtrl.text.trim();

    if (from.isEmpty || to.isEmpty) {
      _showError('请输入出发站和到达站');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _routeResult = null;
    });

    try {
      final routeService = ref.read(_routeServiceProvider);
      final route = await routeService.planRoute(from, to);
      setState(() {
        _routeResult = route;
        if (route == null) _error = '未找到路线，请检查站名是否正确';
      });
    } catch (e) {
      setState(() => _error = '路线查询失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onStationSearch(
    String keyword,
    bool isFrom,
  ) async {
    _stationSearchTimer?.cancel();

    if (keyword.trim().isEmpty) {
      setState(() {
        if (isFrom) {
          _fromSuggestions = [];
        } else {
          _toSuggestions = [];
        }
      });
      return;
    }

    _stationSearchTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final routeService = ref.read(_routeServiceProvider);
        final stations = await routeService.searchStations(keyword);
        if (!mounted) return;
        setState(() {
          if (isFrom) {
            _fromSuggestions = stations;
          } else {
            _toSuggestions = stations;
          }
        });
      } catch (_) {}
    });
  }

  // -----------------------------------------------------------------------
  // External app
  // -----------------------------------------------------------------------

  Future<void> _onTaxi() async {
    final trip = ref.read(_currentTripProvider);
    final destination =
        trip?.departureStation ?? _departureStationCtrl.text.trim();
    if (destination.isEmpty) {
      _showError('请先添加行程或输入出发站');
      return;
    }

    final opened = await ExternalAppService.openDidiTaxi(destination);
    if (!opened && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('未安装滴滴出行'),
          content: const Text('是否使用高德地图打开路线？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ExternalAppService.openAmapApp();
              },
              child: const Text('打开高德地图'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _onAmapRoute() async {
    final trip = ref.read(_currentTripProvider);
    final from = '我的位置';
    final to = trip?.departureStation ?? _departureStationCtrl.text.trim();

    if (to.isEmpty) {
      _showError('请先输入出发站');
      return;
    }

    final opened = await ExternalAppService.openAmapRoute(from, to);
    if (!opened && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('未安装高德地图'),
          content: const Text('请先安装高德地图 App'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('好的'),
            ),
          ],
        ),
      );
    }
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zzz = context.zzz;
    final trip = ref.watch(_currentTripProvider);
    final timeline = ref.watch(_currentTimelineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('出行')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Active trip card ---
            if (trip != null && timeline != null) ...[
              _ActiveTripCard(trip: trip, timeline: timeline),
              const SizedBox(height: 24),
            ] else ...[
              // Empty state when no active trip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color:
                      zzz?.surfaceLow ?? theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (zzz?.borderColor ?? theme.colorScheme.outline)
                        .withValues(alpha: 0.7),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.flight_takeoff,
                        size: 40,
                        color: (zzz?.textTertiary ??
                                theme.colorScheme.onSurfaceVariant)
                            .withValues(alpha: 0.7)),
                    const SizedBox(height: 10),
                    Text('暂无出行行程',
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: zzz?.textPrimary ??
                                theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text('扫描车票或手动录入来添加行程',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: (zzz?.textSecondary ??
                                    theme.colorScheme.onSurfaceVariant)
                                .withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],

            // --- Quick actions ---
            _SectionHeader(title: '快捷操作'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.document_scanner,
                    label: _ocrLoading ? '识别中...' : '扫描车票',
                    onTap: _ocrLoading ? null : _onScanTicket,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.local_taxi,
                    label: '一键打车',
                    onTap: _onTaxi,
                    color: zzz?.warning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.map,
                    label: '高德导航',
                    onTap: _onAmapRoute,
                    color: zzz?.signal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- Manual entry form ---
            _SectionHeader(title: '手动添加车票'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _trainNumberCtrl,
                              decoration: const InputDecoration(
                                labelText: '车次',
                                hintText: '如 G1234',
                                isDense: true,
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? '必填' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _departureDateCtrl,
                              decoration: const InputDecoration(
                                labelText: '出发日期',
                                hintText: 'YYYY-MM-DD',
                                isDense: true,
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? '必填' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _departureTimeCtrl,
                        decoration: const InputDecoration(
                          labelText: '发车时间（可选）',
                          hintText: 'HH:MM',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _departureStationCtrl,
                              decoration: const InputDecoration(
                                labelText: '出发站',
                                isDense: true,
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? '必填' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _arrivalStationCtrl,
                              decoration: const InputDecoration(
                                labelText: '到达站',
                                isDense: true,
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? '必填' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _carriageCtrl,
                              decoration: const InputDecoration(
                                labelText: '车厢（可选）',
                                hintText: '08',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _seatNumberCtrl,
                              decoration: const InputDecoration(
                                labelText: '座位号（可选）',
                                hintText: '12A',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saveLoading ? null : _onSave,
                          icon: _saveLoading
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                )
                              : const Icon(Icons.save, size: 18),
                          label: Text(_saveLoading ? '保存中...' : '保存行程'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Route planning ---
            _SectionHeader(title: '地铁线路查询'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _fromStationCtrl,
                      decoration: const InputDecoration(
                        labelText: '出发站',
                        hintText: '输入地铁站名',
                        isDense: true,
                      ),
                      onChanged: (v) => _onStationSearch(v, true),
                    ),
                    if (_fromSuggestions.isNotEmpty)
                      _SuggestionList(
                        items: _fromSuggestions,
                        onTap: (s) {
                          _fromStationCtrl.text = s;
                          setState(() => _fromSuggestions = []);
                        },
                      ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _toStationCtrl,
                      decoration: const InputDecoration(
                        labelText: '到达站',
                        hintText: '输入地铁站名',
                        isDense: true,
                      ),
                      onChanged: (v) => _onStationSearch(v, false),
                    ),
                    if (_toSuggestions.isNotEmpty)
                      _SuggestionList(
                        items: _toSuggestions,
                        onTap: (s) {
                          _toStationCtrl.text = s;
                          setState(() => _toSuggestions = []);
                        },
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _onPlanRoute,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.route, size: 18),
                        label: Text(_loading ? '查询中...' : '查询线路'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      TextStyle(color: zzz?.danger ?? theme.colorScheme.error)),
            ],

            if (_routeResult != null) ...[
              const SizedBox(height: 12),
              _RouteResultCard(route: _routeResult!),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _ActiveTripCard extends StatelessWidget {
  final TransitTrip trip;
  final ReminderTimeline timeline;

  const _ActiveTripCard({required this.trip, required this.timeline});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zzz = context.zzz;
    final d = trip.departureDate;
    final dateStr =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String timeStr = dateStr;
    if (trip.departureTime != null && trip.departureTime!.isNotEmpty) {
      timeStr += ' ${trip.departureTime}';
    }

    String seatInfo = '';
    if (trip.carriage != null && trip.carriage!.isNotEmpty) {
      seatInfo += '${trip.carriage}车';
    }
    if (trip.seatNumber != null && trip.seatNumber!.isNotEmpty) {
      seatInfo += ' ${trip.seatNumber}号';
    }

    return Card(
      color:
          zzz?.surfaceHigh ?? theme.colorScheme.primaryContainer.withAlpha(80),
      shape: zzz?.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.train,
                    size: 20, color: zzz?.signal ?? theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '今日行程',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                trip.trainNumber,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  trip.departureStation,
                  style: theme.textTheme.titleMedium,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.arrow_forward, size: 16),
                ),
                Text(
                  trip.arrivalStation,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                timeStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (seatInfo.isNotEmpty)
              Center(
                child: Text(
                  seatInfo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // Reminder timeline
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '提醒时间线',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...timeline.nodes.map(
              (node) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                      node.passed ? Icons.check_circle_outline : Icons.schedule,
                      size: 16,
                      color: node.passed
                          ? (zzz?.textTertiary ?? theme.colorScheme.outline)
                          : (zzz?.warning ?? theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      node.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: node.passed
                            ? (zzz?.textTertiary ?? theme.colorScheme.outline)
                            : (zzz?.textPrimary ?? theme.colorScheme.onSurface),
                        decoration:
                            node.passed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final zzz = context.zzz;
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: zzz?.accent,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _QuickAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zzz = context.zzz;
    final effectiveColor = color ?? zzz?.signal ?? theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: zzz?.surfaceLow,
          border: Border.all(color: effectiveColor.withAlpha(90)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: effectiveColor, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: effectiveColor,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  final List<String> items;
  final void Function(String) onTap;

  const _SuggestionList({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zzz = context.zzz;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border.all(
            color: zzz?.borderColor ?? theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 160),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: items.length > 8 ? 8 : items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, i) => ListTile(
          dense: true,
          title: Text(items[i], style: Theme.of(context).textTheme.bodySmall),
          onTap: () => onTap(items[i]),
        ),
      ),
    );
  }
}

class _RouteResultCard extends StatelessWidget {
  final TransitRoute route;

  const _RouteResultCard({required this.route});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final zzz = context.zzz;

    return Card(
      color: zzz?.surface,
      shape: zzz?.cardShape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_subway,
                    size: 20, color: zzz?.signal ?? theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${route.fromStation} → ${route.toStation}',
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '约 ${route.durationMinutes} 分钟',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: zzz?.signal ?? theme.colorScheme.primary,
              ),
            ),
            if (route.transferStations.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '换乘站: ${route.transferStations.join(" → ")}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      zzz?.textSecondary ?? theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...route.legs.map(
              (leg) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${leg.fromStation} → ${leg.toStation}  ${leg.line}  ${leg.minutes}分钟',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
