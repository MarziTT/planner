import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/fast_capture/data/schedule_text_parser.dart';
import 'package:pixel_planner_mobile/features/fast_capture/data/speech_capture_gateway.dart';
import 'package:pixel_planner_mobile/features/fast_capture/presentation/quick_capture_bar.dart';
import 'package:pixel_planner_mobile/features/fast_capture/state/fast_capture_controller.dart';
import 'package:pixel_planner_mobile/features/planner/data/planner_repository.dart';
import 'package:pixel_planner_mobile/features/planner/domain/planner_models.dart';
import 'package:pixel_planner_mobile/features/planner/state/planner_controller.dart';

const _hintText =
    '\u6bd4\u5982\uff1a\u4eca\u5929\u4e03\u70b9\u53bb\u5065\u8eab / \u660e\u5929\u4e94\u70b9\u7684\u98de\u673a';
const _confirmLabel = '\u786e\u8ba4';
const _flightText = '\u660e\u5929\u4e94\u70b9\u7684\u98de\u673a';
const _gymText = '\u4eca\u5929\u4e0b\u5348\u4e03\u70b9\u53bb\u5065\u8eab';
const _missingTimeText = '明天健身';
const _morningPeriodChoice = '上午 9:00';
const _afternoonPeriodChoice = '下午 3:00';
const _eveningPeriodChoice = '晚上 7:00';
const _allDayChoice = '全天提醒';
const _morningChoice = '\u65e9\u4e0a 5:00';
const _afternoonChoice = '\u4e0b\u5348 5:00';
const _listeningHint = '正在录音，说完点一下停止，系统会自动识别并写入速记。';
const _recognizingHint = '正在识别语音并整理行程...';
const _voiceInputTooltip = '\u8bed\u97f3\u5f55\u5165';
const _stopRecordingTooltip = '\u505c\u6b62\u5f55\u97f3';
const _meetingText = '\u4eca\u5929\u4e0b\u5348\u4e09\u70b9\u5f00\u4f1a';
const _meetingTitle = '\u5f00\u4f1a';
const _planeTitle = '\u98de\u673a';

class _FakePlannerRepository extends PlannerRepository {
  _FakePlannerRepository() : super(Dio());

  final List<PlannerEvent> createdEvents = [];

  @override
  Future<List<PlannerEvent>> fetchEvents() async => createdEvents;

  @override
  Future<List<PlannerTodo>> fetchTodos() async => const [];

  @override
  Future<PlannerEvent> createEvent({
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    int? tagId,
    List<int>? tagIds,
  }) async {
    final event = PlannerEvent(
      id: createdEvents.length + 1,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
      status: 'planned',
    );
    createdEvents.add(event);
    return event;
  }

  @override
  Future<PlannerEvent> createEventWithTags({
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    int? tagId,
    List<int>? tagIds,
  }) => createEvent(
        title: title,
        startsAt: startsAt,
        endsAt: endsAt,
        tagId: tagId,
        tagIds: tagIds,
      );
}

class _FakeSpeechCaptureGateway extends SpeechCaptureGateway {
  _FakeSpeechCaptureGateway({
    this.resultText = '',
    this.initializeReturns = true,
    this.stopCompleter,
  });

  final String resultText;
  final bool initializeReturns;
  final Completer<String>? stopCompleter;
  bool listeningStarted = false;
  bool listeningStopped = false;

  @override
  bool get isListening => listeningStarted && !listeningStopped;

  @override
  Future<bool> initialize() async => initializeReturns;

  @override
  Future<String> startListening({String localeId = 'zh_CN'}) async {
    listeningStarted = true;
    return resultText;
  }

  @override
  Future<String> stopListening() async {
    listeningStopped = true;
    if (stopCompleter != null) {
      return stopCompleter!.future;
    }
    return resultText;
  }
}

class _FakePlannerController extends PlannerController {
  _FakePlannerController(this._testRepository) : super(_testRepository);

  final _FakePlannerRepository _testRepository;
  int loadDashboardCalls = 0;

  @override
  Future<void> loadDashboard() async {
    loadDashboardCalls += 1;
    state = state.copyWith(
      events: await _testRepository.fetchEvents(),
      clearError: true,
    );
  }
}

void main() {
  testWidgets('home quick capture composer is visible', (tester) async {
    final repository = _FakePlannerRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: QuickCaptureBar(),
          ),
        ),
      ),
    );

    expect(find.text(_hintText), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.text(_confirmLabel), findsOneWidget);
  });

  testWidgets('successful direct submit clears composer text', (tester) async {
    final repository = _FakePlannerRepository();
    final plannerController = _FakePlannerController(repository);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWithValue(repository),
          plannerControllerProvider.overrideWith((ref) => plannerController),
        ],
        child: const MaterialApp(
          home: Scaffold(body: QuickCaptureBar()),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), _gymText);
    await tester.tap(find.text(_confirmLabel));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
    expect(repository.createdEvents, hasLength(1));
    expect(plannerController.loadDashboardCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('ambiguous flight time shows morning and afternoon choices',
      (tester) async {
    final repository = _FakePlannerRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.listen(fastCaptureControllerProvider, (previous, next) {
                final draft = next.pendingDraft;
                if (draft != null) {
                  showCaptureAmbiguitySheet(
                    context,
                    draft: draft,
                    onMorning: () {},
                    onAfternoon: () {},
                    onCancel: () {},
                  );
                }
              });
              return const Scaffold(
                body: QuickCaptureBar(),
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), _flightText);
    await tester.tap(find.text(_confirmLabel));
    await tester.pumpAndSettle();

    expect(find.text(_morningChoice), findsOneWidget);
    expect(find.text(_afternoonChoice), findsOneWidget);
  });

  testWidgets('missing time capture shows simple period choices',
      (tester) async {
    final repository = _FakePlannerRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.listen(fastCaptureControllerProvider, (previous, next) {
                final draft = next.pendingDraft;
                if (draft != null) {
                  showCaptureAmbiguitySheet(
                    context,
                    draft: draft,
                    onMorning: () {},
                    onAfternoon: () {},
                    onCancel: () {},
                  );
                }
              });
              return const Scaffold(body: QuickCaptureBar());
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), _missingTimeText);
    await tester.tap(find.text(_confirmLabel));
    await tester.pumpAndSettle();

    expect(find.text(_morningPeriodChoice), findsOneWidget);
    expect(find.text(_afternoonPeriodChoice), findsOneWidget);
    expect(find.text(_eveningPeriodChoice), findsOneWidget);
    expect(find.text(_allDayChoice), findsOneWidget);
  });
  testWidgets('confirming ambiguous time clears composer and creates one event',
      (tester) async {
    final repository = _FakePlannerRepository();
    final plannerController = _FakePlannerController(repository);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWithValue(repository),
          plannerControllerProvider.overrideWith((ref) => plannerController),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              ref.listen(fastCaptureControllerProvider, (previous, next) {
                final draft = next.pendingDraft;
                if (draft != null) {
                  showCaptureAmbiguitySheet(
                    context,
                    draft: draft,
                    onMorning: () {
                      ref
                          .read(fastCaptureControllerProvider.notifier)
                          .confirmAmbiguousHour(5);
                    },
                    onAfternoon: () {
                      ref
                          .read(fastCaptureControllerProvider.notifier)
                          .confirmAmbiguousHour(17);
                    },
                    onCancel: () {
                      ref
                          .read(fastCaptureControllerProvider.notifier)
                          .cancelPendingDraft();
                    },
                  );
                }
              });
              return const Scaffold(body: QuickCaptureBar());
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), _flightText);
    await tester.tap(find.text(_confirmLabel));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_afternoonChoice));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
    expect(repository.createdEvents, hasLength(1));
    expect(repository.createdEvents.single.title, _planeTitle);
    expect(plannerController.loadDashboardCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('mic button shows initial icon and toggles to listening state',
      (tester) async {
    final repository = _FakePlannerRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plannerRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(body: QuickCaptureBar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.text(_listeningHint), findsNothing);
  });

  testWidgets('voice auto-creates schedule from speech result', (tester) async {
    final repository = _FakePlannerRepository();
    final gateway = _FakeSpeechCaptureGateway(
      resultText: _meetingText,
    );

    final container = ProviderContainer(
      overrides: [
        plannerRepositoryProvider.overrideWithValue(repository),
        fastCaptureControllerProvider.overrideWith(
          (ref) => FastCaptureController(
            repository: ref.watch(plannerRepositoryProvider),
            parser: ScheduleTextParser(now: DateTime(2026, 7, 9, 9)),
            speechGateway: gateway,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: QuickCaptureBar(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip(_voiceInputTooltip));
    await tester.pumpAndSettle();

    expect(gateway.listeningStarted, isTrue);
    expect(container.read(fastCaptureControllerProvider).isListening, isFalse);
    expect(container.read(fastCaptureControllerProvider).errorMessage, isNull);
    expect(
        container.read(fastCaptureControllerProvider).recognizedText, isNull);
    expect(find.text('识别到：' + _meetingText), findsNothing);
    expect(repository.createdEvents, hasLength(1));
    expect(repository.createdEvents.single.title, _meetingTitle);
    expect(repository.createdEvents.single.startsAt, DateTime(2026, 7, 9, 15));
  });

  testWidgets('tapping mic while listening shows recognizing state and stops',
      (tester) async {
    final stopCompleter = Completer<String>();
    final gateway = _FakeSpeechCaptureGateway(stopCompleter: stopCompleter);
    final controller = FastCaptureController(
      repository: _FakePlannerRepository(),
      speechGateway: gateway,
    );

    final container = ProviderContainer(
      overrides: [
        fastCaptureControllerProvider.overrideWith((ref) => controller),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: QuickCaptureBar()),
        ),
      ),
    );
    await tester.pump();

    controller.state = controller.state.copyWith(isListening: true);
    gateway.listeningStarted = true;
    await tester.pump();

    expect(find.byTooltip(_stopRecordingTooltip), findsOneWidget);
    expect(find.text(_listeningHint), findsOneWidget);

    await tester.tap(find.byTooltip(_stopRecordingTooltip));
    await tester.pump();

    expect(container.read(fastCaptureControllerProvider).isListening, isFalse);
    expect(container.read(fastCaptureControllerProvider).isRecognizing, isTrue);
    expect(find.text(_recognizingHint), findsOneWidget);
    expect(gateway.listeningStopped, isTrue);

    stopCompleter.complete('');
    await tester.pumpAndSettle();
    expect(
        container.read(fastCaptureControllerProvider).isRecognizing, isFalse);
    expect(find.byTooltip(_voiceInputTooltip), findsOneWidget);
  });

  testWidgets('shows error when voice is unavailable', (tester) async {
    final gateway = _FakeSpeechCaptureGateway(initializeReturns: false);
    final controller = FastCaptureController(
      repository: _FakePlannerRepository(),
      speechGateway: gateway,
    );

    final container = ProviderContainer(
      overrides: [
        fastCaptureControllerProvider.overrideWith((ref) => controller),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: QuickCaptureBar()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip(_voiceInputTooltip));
    await tester.pumpAndSettle();

    expect(gateway.listeningStarted, isFalse);
    expect(container.read(fastCaptureControllerProvider).isListening, isFalse);
    expect(
      container.read(fastCaptureControllerProvider).errorMessage,
      '\u8bed\u97f3\u670d\u52a1\u4e0d\u53ef\u7528\uff0c\u8bf7\u68c0\u67e5\u9ea6\u514b\u98ce\u6743\u9650',
    );
  });
}
