import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/local/local_phase3_plus_repository.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late LocalDatabase localDatabase;
  late LocalPhase3PlusRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phase3_plus_repo_test_');
    localDatabase = LocalDatabase(
      dbPathOverride: p.join(tempDir.path, 'local.db'),
      databaseFactoryOverride: databaseFactoryFfi,
    );
    await localDatabase.init();
    repository = LocalPhase3PlusRepository(localDatabase);
  });

  tearDown(() async {
    await localDatabase.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('title-only schedule becomes an unscheduled pending signal', () async {
    final schedule = await repository.createScheduleSignal(
      title: '准备明天的材料',
    );

    expect(schedule.scheduleStatus, 'unscheduled');
    expect(schedule.datePrecision, 'none');
    expect(schedule.timePrecision, 'none');
    expect(schedule.localDate, isNull);
    expect(schedule.reminderEnabled, isFalse);

    final today = await repository.listTodaySchedules();
    expect(today.map((item) => item.id), contains(schedule.id));
  });

  test('time-only schedule defaults to today and can join density later',
      () async {
    final schedule = await repository.createScheduleSignal(
      title: '晚上十分钟恢复',
      time: DateTime(0, 1, 1, 21, 30),
      expectedEnergyLoad: 'restoring',
    );

    expect(schedule.scheduleStatus, 'planned');
    expect(schedule.datePrecision, 'date');
    expect(schedule.timePrecision, 'time');
    expect(schedule.localDate, isNotNull);
    expect(schedule.startTime?.hour, 21);
    expect(schedule.startTime?.minute, 30);
  });

  test('schedule can store note, end time, update details, and soft delete',
      () async {
    final date = DateTime(2026, 6, 23);
    final schedule = await repository.createScheduleSignal(
      title: '项目会议',
      date: date,
      time: DateTime(0, 1, 1, 15),
      endTime: DateTime(0, 1, 1, 16),
      scene: 'work',
      expectedEnergyLoad: 'medium',
      reminderEnabled: true,
      note: '准备演示材料',
    );

    expect(schedule.scheduleStatus, 'planned');
    expect(schedule.timePrecision, 'time');
    expect(schedule.startTime?.hour, 15);
    expect(schedule.endTime?.hour, 16);
    expect(schedule.scene, 'work');
    expect(schedule.expectedEnergyLoad, 'medium');
    expect(schedule.note, '准备演示材料');

    final updated = await repository.updateScheduleSignal(
      id: schedule.id,
      title: '项目会议改期',
      date: date.add(const Duration(days: 1)),
      time: DateTime(0, 1, 1, 10, 30),
      endTime: DateTime(0, 1, 1, 11, 30),
      scene: 'study',
      expectedEnergyLoad: 'light',
      reminderEnabled: false,
      note: '改为线上确认',
    );

    expect(updated, isNotNull);
    expect(updated!.title, '项目会议改期');
    expect(updated.localDate, '2026-06-24');
    expect(updated.startTime?.hour, 10);
    expect(updated.startTime?.minute, 30);
    expect(updated.endTime?.hour, 11);
    expect(updated.scene, 'study');
    expect(updated.expectedEnergyLoad, 'light');
    expect(updated.reminderEnabled, isFalse);
    expect(updated.note, '改为线上确认');

    await repository.deleteScheduleSignal(schedule.id);
    final afterDelete = await repository.listSchedulesBetween(
      startDate: '2026-06-24',
      endDate: '2026-06-24',
    );
    expect(afterDelete.map((item) => item.id), isNot(contains(schedule.id)));
  });

  test('goal creation builds a plan, a today task, and stores feedback',
      () async {
    final goal = await repository.createGoalWithPlan(
      title: '下班后恢复',
      desiredFrequency: '每周 3 次',
      desiredDurationMinutes: 12,
    );
    final tasks = await repository.listTodayGoalTasks();

    expect(goal.title, '下班后恢复');
    expect(tasks, hasLength(1));
    expect(tasks.first.title, contains('下班后恢复'));

    await repository.submitGoalFeedback(
      goalId: goal.id,
      goalTaskInstanceId: tasks.first.id,
      happened: 'yes',
      effect: 'helpful',
    );
    final summary = await repository.summarizeRange(
      startDate: tasks.first.localDate,
      endDate: tasks.first.localDate,
    );
    expect(summary.activeGoalCount, 1);
    expect(summary.goalFeedbackCount, 1);
  });
}
