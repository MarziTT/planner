import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_response.dart';
import '../notify_manager.dart';

/// Routine service — manages standing reminders, sleep reminders,
/// and wake-time tracking.
///
/// Reads learned wake time from ``GET /api/v1/habits/summary`` (or falls back
/// to defaults).  Standing reminders fire every 45 minutes between 09:00-18:00,
/// auto-stopping after 5 consecutive skips.
class RoutineService extends ChangeNotifier {
  RoutineService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  // --- Configuration -------------------------------------------------------
  static const int _standingIntervalMinutes = 45;
  static const int _standingStartHour = 9;
  static const int _standingEndHour = 18;

  // --- State ----------------------------------------------------------------
  int _wakeHour = 7;
  int _wakeMinute = 30;
  String _wakeSource = 'default';

  int _sleepHour = 23;
  int _sleepMinute = 30;
  int _sleepRemindHour = 23;
  int _sleepRemindMinute = 0;

  bool _standingEnabled = true;
  bool _standingAutoStopped = false;
  int _standingTotalToday = 0;
  int _standingSkippedToday = 0;
  int _consecutiveSkips = 0;

  // --- Internal timers ------------------------------------------------------
  Timer? _standingTimer;
  Timer? _sleepReminderTimer;
  Timer? _lastStandingSentTime;

  // --- Getters --------------------------------------------------------------
  int get wakeHour => _wakeHour;
  int get wakeMinute => _wakeMinute;
  String get wakeSource => _wakeSource;
  int get sleepHour => _sleepHour;
  int get sleepMinute => _sleepMinute;
  int get sleepRemindHour => _sleepRemindHour;
  int get sleepRemindMinute => _sleepRemindMinute;
  bool get standingEnabled => _standingEnabled;
  bool get standingAutoStopped => _standingAutoStopped;
  int get standingTotalToday => _standingTotalToday;
  int get standingSkippedToday => _standingSkippedToday;
  int get consecutiveSkips => _consecutiveSkips;

  // -----------------------------------------------------------------------
  //  Lifecycle
  // -----------------------------------------------------------------------

  /// Fetch user data from backend and start timers.
  Future<void> start() async {
    await _fetchRoutineToday();
    _startStandingTimer();
    _scheduleSleepReminder();
  }

  /// Cancel all running timers.
  void stop() {
    _standingTimer?.cancel();
    _sleepReminderTimer?.cancel();
    _lastStandingSentTime?.cancel();
    _standingTimer = null;
    _sleepReminderTimer = null;
    _lastStandingSentTime = null;
  }

  /// Refresh state from backend.
  Future<void> refresh() async {
    await _fetchRoutineToday();
    notifyListeners();
  }

  /// Record a wake-up event to the backend (used when user taps "I'm awake").
  Future<Map<String, dynamic>?> recordWake({
    String? wakeTime,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (wakeTime != null) body['wake_time'] = wakeTime;

      final response = await _dio.post(
        '/routine/wake',
        data: body,
      );

      final parsed = ApiResponse.raw(response, null) as ApiResponse<Map<String, dynamic>>;
      if (parsed.isSuccess && parsed.data != null) {
        _wakeHour = parsed.data!['hour'] as int? ?? _wakeHour;
        _wakeMinute = parsed.data!['minute'] as int? ?? _wakeMinute;
        _wakeSource = 'manual';
        _recomputeSleepTimes();
        notifyListeners();
        return parsed.data;
      }
    } on DioException {
      // fall through
    }
    return null;
  }

  /// Manually override wake time.
  Future<bool> setWakeTime({
    required int hour,
    required int minute,
  }) async {
    try {
      await _dio.put(
        '/routine/wake_time',
        data: {'hour': hour, 'minute': minute},
      );

      _wakeHour = hour;
      _wakeMinute = minute;
      _wakeSource = 'manual';
      _recomputeSleepTimes();
      _rescheduleSleepReminder();
      notifyListeners();
      return true;
    } on DioException {
      return false;
    }
  }

  /// Toggle standing reminders on/off (client-side only).
  void toggleStanding(bool enabled) {
    if (_standingAutoStopped && enabled) {
      _standingAutoStopped = false;
      _consecutiveSkips = 0;
    }
    _standingEnabled = enabled;
    if (enabled) {
      _startStandingTimer();
    } else {
      _standingTimer?.cancel();
    }
    notifyListeners();
  }

  /// Handle a standing skip action — forward to engine.
  Future<void> handleStandingSkip({
    required int? scheduleId,
  }) async {
    _standingSkippedToday++;
    _consecutiveSkips++;

    if (_consecutiveSkips >= 5) {
      _standingAutoStopped = true;
      _standingEnabled = false;
      _standingTimer?.cancel();
    }

    notifyListeners();

    // Notify backend
    if (scheduleId != null) {
      try {
        final now = DateTime.now();
        await _dio.post(
          '/habits/skip/$scheduleId',
          data: {
            'notify_type': 'standing',
            'planned_time': now.toIso8601String(),
            'reminded_at': now.toIso8601String(),
          },
        );
      } on DioException {
        // best-effort; local state already updated
      }
    }
  }

  /// Handle a standing complete action.
  Future<void> handleStandingComplete() async {
    _standingTotalToday++;
    _consecutiveSkips = 0;
    if (_standingAutoStopped) {
      _standingAutoStopped = false;
      _standingEnabled = true;
      _startStandingTimer();
    }
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  //  Internal — networking
  // -----------------------------------------------------------------------

  Future<void> _fetchRoutineToday() async {
    try {
      final response = await _dio.get('/routine/today');
      final parsed = ApiResponse.raw(response, null) as ApiResponse<Map<String, dynamic>>;
      if (!parsed.isSuccess || parsed.data == null) return;

      final routine = parsed.data!;

      final wake = routine['wake_time'] as Map<String, dynamic>?;
      if (wake != null) {
        _wakeHour = wake['hour'] as int? ?? _wakeHour;
        _wakeMinute = wake['minute'] as int? ?? _wakeMinute;
        _wakeSource = wake['source'] as String? ?? _wakeSource;
      }

      final sleep = routine['sleep_time'] as Map<String, dynamic>?;
      if (sleep != null) {
        _sleepHour = sleep['hour'] as int? ?? _sleepHour;
        _sleepMinute = sleep['minute'] as int? ?? _sleepMinute;
      }

      final remind = routine['sleep_reminder'] as Map<String, dynamic>?;
      if (remind != null) {
        _sleepRemindHour = remind['hour'] as int? ?? _sleepRemindHour;
        _sleepRemindMinute = remind['minute'] as int? ?? _sleepRemindMinute;
      }

      final standing = routine['standing'] as Map<String, dynamic>?;
      if (standing != null) {
        _standingEnabled = standing['enabled'] as bool? ?? _standingEnabled;
        _standingAutoStopped = standing['auto_stopped'] as bool? ?? false;
        _standingTotalToday = standing['today_total'] as int? ?? 0;
        _standingSkippedToday = standing['today_skipped'] as int? ?? 0;
        _consecutiveSkips = standing['consecutive_skips'] as int? ?? 0;
      }
    } on DioException {
      // best-effort; keep existing state
    }
  }

  // -----------------------------------------------------------------------
  //  Internal — timers
  // -----------------------------------------------------------------------

  void _recomputeSleepTimes() {
    final wakeDt = _makeToday(_wakeHour, _wakeMinute);
    final sleepDt = wakeDt.subtract(const Duration(hours: 8));
    _sleepHour = sleepDt.hour;
    _sleepMinute = sleepDt.minute;

    final remindDt = sleepDt.subtract(const Duration(minutes: 30));
    _sleepRemindHour = remindDt.hour;
    _sleepRemindMinute = remindDt.minute;
  }

  void _rescheduleSleepReminder() {
    _sleepReminderTimer?.cancel();
    _scheduleSleepReminder();
  }

  void _scheduleSleepReminder() {
    final now = DateTime.now();
    var target = _makeToday(_sleepRemindHour, _sleepRemindMinute);
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    final delay = target.difference(now);
    _sleepReminderTimer?.cancel();
    _sleepReminderTimer = Timer(delay, () => _fireSleepReminder());
  }

  void _fireSleepReminder() {
    NotifyManager.show(
      channel: NotifyChannel.standing, // re-use standing for simplicity
      title: '该睡了',
      body: '已经 ${_sleepRemindHour.toString().padLeft(2, '0')}:${_sleepRemindMinute.toString().padLeft(2, '0')}，预计 ${_sleepHour.toString().padLeft(2, '0')}:${_sleepMinute.toString().padLeft(2, '0')} 入睡',
      priority: NotifyPriority.daily,
      payload: const NotifyPayload(eventType: 'sleep_reminder'),
    );

    // Re-schedule for tomorrow
    _sleepReminderTimer = Timer(
      const Duration(hours: 23, minutes: 50),
      _fireSleepReminder,
    );
  }

  void _startStandingTimer() {
    if (!_standingEnabled || _standingAutoStopped) return;

    _standingTimer?.cancel();

    // Calculate time until next aligned 45-min slot within 9-18
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _standingStartHour * 60;
    final endMinutes = _standingEndHour * 60;

    if (currentMinutes >= endMinutes) {
      // Outside window, schedule for tomorrow 9:00
      final next = _makeToday(_standingStartHour, 0).add(const Duration(days: 1));
      final delay = next.difference(now);
      _standingTimer = Timer(delay, _fireStandingAndReschedule);
      return;
    }

    if (currentMinutes < startMinutes) {
      // Before window, schedule for today 9:00
      final next = _makeToday(_standingStartHour, 0);
      _standingTimer = Timer(next.difference(now), _fireStandingAndReschedule);
      return;
    }

    // Inside window: align to next 45-min boundary
    final nextBoundary = ((currentMinutes ~/ _standingIntervalMinutes) + 1) *
        _standingIntervalMinutes;
    if (nextBoundary >= endMinutes) {
      // Last slot passed, schedule for tomorrow
      final next = _makeToday(_standingStartHour, 0).add(const Duration(days: 1));
      final delay = next.difference(now);
      _standingTimer = Timer(delay, _fireStandingAndReschedule);
      return;
    }

    final nextH = nextBoundary ~/ 60;
    final nextM = nextBoundary % 60;
    final next = _makeToday(nextH, nextM);
    _standingTimer = Timer(next.difference(now), _fireStandingAndReschedule);
  }

  void _fireStandingAndReschedule() {
    _fireStandingReminder();
    _startStandingTimer();
  }

  void _fireStandingReminder() {
    _standingTotalToday++;
    NotifyManager.show(
      channel: NotifyChannel.standing,
      title: '站一站',
      body: '已经坐了 $_standingIntervalMinutes 分钟，起来活动一下吧',
      priority: NotifyPriority.daily,
      payload: const NotifyPayload(eventType: 'standing'),
    );
    _lastStandingSentTime = Timer(const Duration(seconds: 5), () {});
  }

  DateTime _makeToday(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }
}
