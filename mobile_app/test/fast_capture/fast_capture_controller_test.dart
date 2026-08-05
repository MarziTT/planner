import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_planner_mobile/features/fast_capture/data/schedule_text_parser.dart';
import 'package:pixel_planner_mobile/features/fast_capture/domain/capture_enums.dart';
import 'package:pixel_planner_mobile/features/fast_capture/state/fast_capture_controller.dart';
import 'package:pixel_planner_mobile/features/planner/data/planner_repository.dart';
import 'package:pixel_planner_mobile/features/planner/domain/planner_models.dart';

class _FakePlannerRepository extends PlannerRepository {
  _FakePlannerRepository({this.shouldThrow = false}) : super(Dio());

  final bool shouldThrow;
  final List<PlannerEvent> createdEvents = [];
  final List<List<int>?> createdTagIds = [];

  @override
  Future<PlannerEvent> createEvent({
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    int? tagId,
    List<int>? tagIds,
  }) async {
    if (shouldThrow) {
      throw Exception('create failed');
    }

    final event = PlannerEvent(
      id: createdEvents.length + 1,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
      status: 'planned',
    );
    createdEvents.add(event);
    createdTagIds.add(tagIds);
    return event;
  }

  @override
  Future<PlannerEvent> createEventWithTags({
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    int? tagId,
    List<int>? tagIds,
  }) =>
      createEvent(
        title: title,
        startsAt: startsAt,
        endsAt: endsAt,
        tagId: tagId,
        tagIds: tagIds,
      );
}

void main() {
  FastCaptureController buildController(_FakePlannerRepository repository) {
    return FastCaptureController(
      repository: repository,
      parser: ScheduleTextParser(now: DateTime(2026, 7, 9, 9)),
    );
  }

  test('submitting explicit time creates planner event immediately', () async {
    final repository = _FakePlannerRepository();
    final controller = buildController(repository);

    await controller
        .submitText('\u4eca\u5929\u4e0b\u5348\u4e03\u70b9\u53bb\u5065\u8eab');

    expect(repository.createdEvents, hasLength(1));
    expect(repository.createdEvents.single.title, '健身');
    expect(repository.createdEvents.single.startsAt, DateTime(2026, 7, 9, 19));
    expect(
        repository.createdEvents.single.endsAt, DateTime(2026, 7, 9, 20, 30));
    expect(controller.state.pendingDraft, isNull);
    expect(controller.state.errorMessage, isNull);
  });

  test('submitting ambiguous hour stores pending draft without creating',
      () async {
    final repository = _FakePlannerRepository();
    final controller = buildController(repository);

    await controller.submitText('\u660e\u5929\u4e94\u70b9\u7684\u98de\u673a');

    expect(repository.createdEvents, isEmpty);
    expect(controller.state.pendingDraft, isNotNull);
    expect(controller.state.pendingDraft!.title, '\u98de\u673a');
    expect(controller.state.pendingDraft!.startsAt, DateTime(2026, 7, 10, 5));
    expect(controller.state.errorMessage, isNull);
  });

  test('confirming ambiguous hour creates planner event with resolved time',
      () async {
    final repository = _FakePlannerRepository();
    final controller = buildController(repository);

    await controller.submitText('\u660e\u5929\u4e94\u70b9\u7684\u98de\u673a');
    await controller.confirmAmbiguousHour(17);

    expect(repository.createdEvents, hasLength(1));
    expect(repository.createdEvents.single.title, '\u98de\u673a');
    expect(repository.createdEvents.single.startsAt, DateTime(2026, 7, 10, 17));
    expect(controller.state.pendingDraft, isNull);
    expect(controller.state.errorMessage, isNull);
  });

  test('submitting missing time stores pending draft without creating',
      () async {
    final repository = _FakePlannerRepository();
    final controller = buildController(repository);

    await controller.submitText('明天健身');

    expect(repository.createdEvents, isEmpty);
    expect(controller.state.pendingDraft, isNotNull);
    expect(controller.state.pendingDraft!.title, '健身');
    expect(controller.state.pendingDraft!.ambiguityKind,
        TimeAmbiguityKind.missingTime);
    expect(controller.state.pendingDraft!.suggestedPeriod, TimePeriod.evening);
  });

  test('confirming missing time creates planner event with selected period',
      () async {
    final repository = _FakePlannerRepository();
    final controller = buildController(repository);

    await controller.submitText('明天健身');
    await controller.confirmMissingTime(TimePeriod.evening);

    expect(repository.createdEvents, hasLength(1));
    expect(repository.createdEvents.single.title, '健身');
    expect(repository.createdEvents.single.startsAt, DateTime(2026, 7, 10, 19));
    expect(
        repository.createdEvents.single.endsAt, DateTime(2026, 7, 10, 20, 30));
    expect(controller.state.pendingDraft, isNull);
    expect(controller.state.errorMessage, isNull);
  });

  test('explicit schedule wording is not tagged as workout event', () async {
    final repository = _FakePlannerRepository();
    final controller = buildController(repository);

    await controller.submitText('今天下午七点记录日程健身');

    expect(repository.createdEvents, hasLength(1));
    expect(repository.createdEvents.single.title, '健身');
    expect(repository.createdEvents.single.startsAt, DateTime(2026, 7, 9, 19));
    expect(repository.createdEvents.single.endsAt, DateTime(2026, 7, 9, 20));
    expect(repository.createdTagIds.single, isNull);
    expect(controller.state.pendingDraft, isNull);
    expect(controller.state.errorMessage, isNull);
  });

  test('failed creation exposes small error string', () async {
    final repository = _FakePlannerRepository(shouldThrow: true);
    final controller = buildController(repository);

    await controller
        .submitText('\u4eca\u5929\u4e0b\u5348\u4e03\u70b9\u53bb\u5065\u8eab');

    expect(repository.createdEvents, isEmpty);
    expect(controller.state.errorMessage, isNotEmpty);
  });
}
