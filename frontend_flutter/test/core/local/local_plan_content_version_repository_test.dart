import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_plan_content_version_repository.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDatabase localDatabase;
  late LocalPlanContentVersionRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('plan_versions_test_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await localDatabase.init();
    repository = LocalPlanContentVersionRepository(localDatabase);
  });

  tearDown(() async {
    await localDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('ensureInitial is idempotent and resolve uses date then version',
      () async {
    final first = await repository.ensureInitial(
      localUserId: 'local',
      objectKind: PlanContentObjectKind.quickTry,
      objectId: 'action-1',
      effectiveFromLocalDate: '2026-07-06',
      content: const {'title': '原来的小尝试', 'reason': '先从小处开始'},
      createdAt: DateTime.utc(2026, 7, 6, 1),
    );
    final repeated = await repository.ensureInitial(
      localUserId: 'local',
      objectKind: PlanContentObjectKind.quickTry,
      objectId: 'action-1',
      effectiveFromLocalDate: '2026-07-06',
      content: const {'title': '不能覆盖 v1'},
    );
    expect(repeated.id, first.id);
    expect(repeated.content['title'], '原来的小尝试');

    final second = await repository.append(
      localUserId: 'local',
      objectKind: PlanContentObjectKind.quickTry,
      objectId: 'action-1',
      effectiveFromLocalDate: '2026-07-10',
      content: const {'title': '调整后的小尝试', 'reason': '更轻一点'},
      createdAt: DateTime.utc(2026, 7, 9, 1),
    );
    final third = await repository.append(
      localUserId: 'local',
      objectKind: PlanContentObjectKind.quickTry,
      objectId: 'action-1',
      effectiveFromLocalDate: '2026-07-10',
      content: const {'title': '当天最终计划', 'reason': '仍未发生'},
      createdAt: DateTime.utc(2026, 7, 9, 2),
    );
    expect(second.versionNo, 2);
    expect(third.versionNo, 3);

    expect(
      (await repository.resolveContent(
        localUserId: 'local',
        objectKind: PlanContentObjectKind.quickTry,
        objectId: 'action-1',
        selectedLocalDate: '2026-07-09',
      ))?['title'],
      '原来的小尝试',
    );
    expect(
      (await repository.resolveContent(
        localUserId: 'local',
        objectKind: PlanContentObjectKind.quickTry,
        objectId: 'action-1',
        selectedLocalDate: '2026-07-10',
      ))?['title'],
      '当天最终计划',
    );
    expect(
      await repository.resolve(
        localUserId: 'local',
        objectKind: PlanContentObjectKind.quickTry,
        objectId: 'action-1',
        selectedLocalDate: '2026-07-05',
      ),
      isNull,
    );

    final versions = await repository.listForObject(
      localUserId: 'local',
      objectKind: PlanContentObjectKind.quickTry,
      objectId: 'action-1',
    );
    expect(versions.map((item) => item.versionNo), [1, 2, 3]);
    expect(versions.first.content['title'], '原来的小尝试');
  });

  test('goal content uses the same append-only API', () async {
    await repository.ensureInitial(
      localUserId: 'person-1',
      objectKind: PlanContentObjectKind.goal,
      objectId: 'goal-1',
      effectiveFromLocalDate: '2026-07-13',
      content: const {
        'title': '下周目标',
        'hypothesis': '留出恢复空间会更稳定',
        'suggested_action': '每天午后离开屏幕十分钟',
        'planned_total_days': 7,
      },
    );

    final resolved = await repository.resolve(
      localUserId: 'person-1',
      objectKind: PlanContentObjectKind.goal,
      objectId: 'goal-1',
      selectedLocalDate: '2026-07-16',
    );
    expect(resolved?.objectKind, PlanContentObjectKind.goal);
    expect(resolved?.versionNo, 1);
    expect(resolved?.content['planned_total_days'], 7);
  });

  test('append requires an initial immutable version', () async {
    expect(
      () => repository.append(
        localUserId: 'local',
        objectKind: PlanContentObjectKind.quickTry,
        objectId: 'missing-action',
        effectiveFromLocalDate: '2026-07-16',
        content: const {'title': '没有 v1'},
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('v35 migration creates table and backfills adopted plans as v1',
      () async {
    final legacyPath = p.join(tempDir.path, 'legacy-v35.db');
    final legacy = await databaseFactoryFfi.openDatabase(
      legacyPath,
      options: OpenDatabaseOptions(
        version: 35,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE micro_actions (
              id TEXT PRIMARY KEY,
              local_user_id TEXT,
              title TEXT NOT NULL,
              reason TEXT,
              action_type TEXT,
              difficulty TEXT,
              planned_date TEXT,
              planned_time TEXT,
              progress_start_date TEXT,
              adopted_at TEXT,
              origin_candidate_id TEXT,
              status TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE life_experiments (
              id TEXT PRIMARY KEY,
              local_user_id TEXT,
              title TEXT NOT NULL,
              hypothesis TEXT NOT NULL,
              suggested_action TEXT NOT NULL,
              focus_area_id TEXT,
              pattern_id TEXT,
              feedback_pattern_id TEXT,
              icon_asset_id TEXT,
              planned_frequency TEXT,
              planned_duration_minutes INTEGER,
              planned_total_days INTEGER,
              progress_start_date TEXT,
              source_week_start TEXT,
              adopted_at TEXT,
              origin_candidate_id TEXT,
              status TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await legacy.insert('micro_actions', {
      'id': 'legacy-action',
      'local_user_id': 'local',
      'title': '旧小尝试',
      'reason': '旧理由',
      'action_type': 'today_try',
      'difficulty': 'very_light',
      'planned_date': '2026-07-08',
      'progress_start_date': '2026-07-08',
      'adopted_at': '2026-07-08T01:00:00.000Z',
      'origin_candidate_id': 'candidate-action',
      'status': 'accepted',
      'created_at': '2026-07-08T01:00:00.000Z',
    });
    await legacy.insert('micro_actions', {
      'id': 'unadopted-action',
      'local_user_id': 'local',
      'title': '未采纳候选',
      'reason': '不应回填',
      'action_type': 'today_try',
      'difficulty': 'very_light',
      'planned_date': '2026-07-08',
      'status': 'suggested',
      'created_at': '2026-07-08T01:00:00.000Z',
    });
    await legacy.insert('life_experiments', {
      'id': 'legacy-goal',
      'local_user_id': 'local',
      'title': '旧目标',
      'hypothesis': '旧假设',
      'suggested_action': '旧做法',
      'planned_frequency': 'daily',
      'planned_total_days': 7,
      'progress_start_date': '2026-07-13',
      'source_week_start': '2026-07-13',
      'adopted_at': '2026-07-10T01:00:00.000Z',
      'origin_candidate_id': 'candidate-goal',
      'status': 'saved',
      'created_at': '2026-07-10T01:00:00.000Z',
    });
    await legacy.close();

    final migratedDatabase = LocalDatabase(
      dbPathOverride: legacyPath,
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await migratedDatabase.init();
    addTearDown(migratedDatabase.close);
    final migratedRepository =
        LocalPlanContentVersionRepository(migratedDatabase);
    final migratedDb = await migratedDatabase.database;

    // The v35 fixture continues through the v36 plan-content migration and
    // every later migration, so the opened database must reach the version
    // currently owned by LocalDatabase.
    expect(await migratedDb.getVersion(), LocalDatabase.schemaVersion);
    expect(
      (await migratedRepository.resolveContent(
        localUserId: 'local',
        objectKind: PlanContentObjectKind.quickTry,
        objectId: 'legacy-action',
        selectedLocalDate: '2026-07-08',
      ))?['title'],
      '旧小尝试',
    );
    expect(
      (await migratedRepository.resolveContent(
        localUserId: 'local',
        objectKind: PlanContentObjectKind.goal,
        objectId: 'legacy-goal',
        selectedLocalDate: '2026-07-13',
      ))?['suggested_action'],
      '旧做法',
    );
    expect(
      await migratedRepository.resolve(
        localUserId: 'local',
        objectKind: PlanContentObjectKind.quickTry,
        objectId: 'unadopted-action',
        selectedLocalDate: '2026-07-08',
      ),
      isNull,
    );
  });
}
