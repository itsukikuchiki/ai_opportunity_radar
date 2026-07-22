import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_deepening_observation_repository.dart';
import 'package:ai_opportunity_radar/core/models/deepening_observation_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDatabase database;
  late LocalDeepeningObservationRepository repository;
  var now = DateTime(2026, 7, 13, 12);

  setUp(() async {
    now = DateTime(2026, 7, 13, 12);
    tempDir = await Directory.systemTemp.createTemp('observation_plan_test_');
    database = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await database.init();
    repository = LocalDeepeningObservationRepository(
      localDatabase: database,
      localCaptureRepository: LocalCaptureRepository(database),
      nowLoader: () => now,
    );
  });

  tearDown(() async {
    await database.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('深化观察只在明确采纳时写入，且不创建 Signal 或尝试', () async {
    final db = await database.database;
    expect(await repository.forTargetWeek(now), isNull);
    expect(await db.query('observation_plans'), isEmpty);

    const proposal = DeepeningObservationProposal(
      sourceWeekStart: '2026-07-06',
      sourceWeekEnd: '2026-07-12',
      question: '任务切换是否与耗力感同时出现？',
      whatToWatch: ['任务切换', '耗力'],
      sourceSignalCardIds: ['sig-1', 'sig-2'],
      sourceHash: 'source-hash',
    );
    final adopted = await repository.adopt(proposal);
    final repeat = await repository.adopt(proposal);

    expect(adopted.targetWeekStart, '2026-07-13');
    expect(repeat.id, adopted.id);
    expect((await db.query('observation_plans')), hasLength(1));
    expect((await db.query('signal_cards')), isEmpty);
    expect((await db.query('micro_actions')), isEmpty);
    expect((await db.query('life_experiments')), isEmpty);
  });

  test('深化观察周日不结算，下一周一才产出结论', () async {
    final plan = await repository.adopt(
      const DeepeningObservationProposal(
        sourceWeekStart: '2026-07-06',
        sourceWeekEnd: '2026-07-12',
        question: '恢复是否更容易开始？',
        whatToWatch: ['恢复'],
        sourceSignalCardIds: ['sig-1'],
        sourceHash: 'source-hash',
      ),
    );
    final stillPlanned = await repository.resolveCompletedTargetWeek(now);
    expect(stillPlanned?.status, DeepeningObservationPlanStatus.planned);

    now = DateTime(2026, 7, 19, 23, 59);
    final sundayStillPlanned = await repository.resolveCompletedTargetWeek(
      DateTime(2026, 7, 19),
    );
    expect(sundayStillPlanned?.status, DeepeningObservationPlanStatus.planned);

    now = DateTime(2026, 7, 20, 9);
    final resolved = await repository.resolveCompletedTargetWeek(
      DateTime(2026, 7, 19),
    );
    expect(resolved?.id, plan.id);
    expect(resolved?.status, DeepeningObservationPlanStatus.resolved);
    expect(
      resolved?.resultStatus,
      DeepeningObservationResultStatus.notEnoughData,
    );
  });

  test('跨到下一周后能结算上一完整目标周，之前不会错误读取当前周', () async {
    final plan = await repository.adopt(
      const DeepeningObservationProposal(
        sourceWeekStart: '2026-07-06',
        sourceWeekEnd: '2026-07-12',
        question: '恢复是否更容易开始？',
        whatToWatch: ['恢复'],
        sourceSignalCardIds: ['sig-1'],
        sourceHash: 'source-hash',
      ),
    );

    // The target week (7/13--7/19) is still in progress, so this must not
    // resolve the plan or mistakenly look it up as a current-week plan.
    now = DateTime(2026, 7, 19, 12);
    expect(
      await repository.resolveLatestCompletedTargetWeek(now),
      isNull,
    );

    // On the next Monday, the latest completed week is 7/13--7/19.
    now = DateTime(2026, 7, 20, 9);
    final resolved = await repository.resolveLatestCompletedTargetWeek(now);
    expect(resolved?.id, plan.id);
    expect(resolved?.status, DeepeningObservationPlanStatus.resolved);
    expect(
      resolved?.resultStatus,
      DeepeningObservationResultStatus.notEnoughData,
    );
  });
}
