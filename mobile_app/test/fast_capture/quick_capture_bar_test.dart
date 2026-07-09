import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/fast_capture/data/speech_capture_gateway.dart';
import 'package:pixel_planner_mobile/features/fast_capture/presentation/quick_capture_bar.dart';
import 'package:pixel_planner_mobile/features/fast_capture/state/fast_capture_controller.dart';
import 'package:pixel_planner_mobile/features/planner/data/planner_repository.dart';
import 'package:pixel_planner_mobile/features/planner/domain/planner_models.dart';

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
}

class _FakeSpeechCaptureGateway extends SpeechCaptureGateway {
  _FakeSpeechCaptureGateway({
    this.resultText = '',
    this.initializeReturns = true,
  });

  final String resultText;
  final bool initializeReturns;
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
    return '';
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

    expect(find.text('\u6bd4\u5982\uff1a\u4eca\u5929\u4e0b\u5348\u4e03\u70b9\u53bb\u5065\u8eab'), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(find.text('\u53d1\u9001'), findsOneWidget);
  });

  testWidgets('ambiguous flight time shows morning and afternoon choices', (tester) async {
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

    await tester.enterText(
      find.byType(TextField),
      '\u660e\u5929\u4e94\u70b9\u7684\u98de\u673a',
    );
    await tester.tap(find.text('\u53d1\u9001'));
    await tester.pumpAndSettle();

    expect(find.text('\u65e9\u4e0a 5:00'), findsOneWidget);
    expect(find.text('\u4e0b\u5348 5:00'), findsOneWidget);
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
    expect(find.text('\u6b63\u5728\u8046\u542c...'), findsNothing);
  });

  testWidgets('voice auto-creates schedule from speech result',
      (tester) async {
    final repository = _FakePlannerRepository();
    final gateway = _FakeSpeechCaptureGateway(
      resultText: '\u4eca\u5929\u4e0b\u5348\u4e09\u70b9\u5f00\u4f1a',
    );

    final container = ProviderContainer(
      overrides: [
        plannerRepositoryProvider.overrideWithValue(repository),
        fastCaptureControllerProvider.overrideWith(
          (ref) => FastCaptureController(
            repository: ref.watch(plannerRepositoryProvider),
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
          home: Scaffold(body: QuickCaptureBar()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('\u8bed\u97f3\u5f55\u5165'));
    await tester.pumpAndSettle();

    expect(gateway.listeningStarted, isTrue);
    expect(container.read(fastCaptureControllerProvider).isListening, isFalse);
    expect(container.read(fastCaptureControllerProvider).errorMessage, isNull);
    expect(repository.createdEvents, hasLength(1));
    expect(repository.createdEvents.single.title, '\u5f00\u4f1a');
    expect(repository.createdEvents.single.startsAt, DateTime(2026, 7, 9, 15));
  });

  testWidgets('tapping mic while listening shows stop tooltip and stops',
      (tester) async {
    final gateway = _FakeSpeechCaptureGateway();
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

    expect(find.byTooltip('\u505c\u6b62\u5f55\u97f3'), findsOneWidget);
    expect(find.text('\u6b63\u5728\u8046\u542c...'), findsOneWidget);

    await tester.tap(find.byTooltip('\u505c\u6b62\u5f55\u97f3'));
    await tester.pumpAndSettle();

    expect(gateway.listeningStopped, isTrue);
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

    await tester.tap(find.byTooltip('\u8bed\u97f3\u5f55\u5165'));
    await tester.pumpAndSettle();

    expect(gateway.listeningStarted, isFalse);
    expect(container.read(fastCaptureControllerProvider).isListening, isFalse);
    expect(
      container.read(fastCaptureControllerProvider).errorMessage,
      '\u8bed\u97f3\u670d\u52a1\u4e0d\u53ef\u7528\uff0c\u8bf7\u68c0\u67e5\u9ea6\u514b\u98ce\u6743\u9650',
    );
  });
}
