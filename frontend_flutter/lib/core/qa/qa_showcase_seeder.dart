import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../di/app_dependencies.dart';
import '../models/phase3_plus_models.dart';
import '../models/weekly_models.dart';

/// Builds a private, local-only evidence set for the explicit QA showcase
/// archive. Every row owned by this seeder uses the `qa_demo_` namespace.
/// Existing user rows are never replaced or deleted.
class QaShowcaseSeeder {
  static const _markerKey = 'qa_showcase_seed_date_v1';

  const QaShowcaseSeeder._();

  static Future<void> seed({
    required AppDependencies dependencies,
    required SharedPreferences preferences,
    DateTime? now,
  }) async {
    final localNow = (now ?? DateTime.now()).toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final todayKey = _dateKey(today);
    final db = await dependencies.localDatabase.database;

    final existing = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM signal_cards WHERE id LIKE 'qa_demo_signal_%'",
          ),
        ) ??
        0;
    if (preferences.getString(_markerKey) == todayKey && existing >= 14) {
      await _preparePreferences(preferences, today);
      return;
    }

    await _removeOwnedRows(db);
    await _preparePreferences(preferences, today);

    final samples = _signalSamples();
    await db.transaction((txn) async {
      for (var index = 0; index < samples.length; index += 1) {
        await _insertSignal(
          txn,
          sample: samples[index],
          index: index,
          today: today,
          localNow: localNow,
        );
      }
    });

    await _seedObservations(
      db,
      localUserId: dependencies.localUserId,
      today: today,
    );
    await _seedMicroActions(dependencies, today);
    await _seedExperiment(dependencies, today);
    await preferences.setString(_markerKey, todayKey);
  }

  static Future<void> _insertSignal(
    DatabaseExecutor db, {
    required _QaSignalSample sample,
    required int index,
    required DateTime today,
    required DateTime localNow,
  }) async {
    final id = 'qa_demo_signal_${(index + 1).toString().padLeft(2, '0')}';
    final localDate = today.subtract(Duration(days: sample.daysAgo));
    final createdLocal = sample.daysAgo == 0
        ? localNow.subtract(Duration(minutes: 20 + index * 13))
        : DateTime(
            localDate.year,
            localDate.month,
            localDate.day,
            8 + (index % 9),
            10 + (index * 7) % 45,
          );
    final timestamp = createdLocal.toUtc().toIso8601String();
    await db.insert(
      'signal_cards',
      {
        'id': id,
        'signal_card_id': id,
        'client_id': id,
        'server_id': id,
        'source_type': 'text',
        'raw_text': sample.content,
        'created_at': timestamp,
        'local_date': _dateKey(localDate),
        'timezone': localNow.timeZoneName,
        'language': 'zh-Hans',
        'ai_reply': sample.acknowledgement,
        'observation': sample.observation,
        'try_next': sample.tryNext,
        'scene': sample.scene,
        'friction': sample.friction,
        'positive_signal': sample.positiveSignal,
        'energy_load': sample.energyLoad,
        'linked_life_chain_stage': '[]',
        'raw_payload_json': jsonEncode({
          'qa_showcase': true,
          'schema_version': 1,
        }),
        'scene_tags_json': jsonEncode([sample.scene]),
        'intent_tags_json': jsonEncode(['qa_showcase']),
        'user_confirmation': 'confirmed',
        'user_correction_json': '{}',
        'included_in_summary': 1,
        'included_in_weekly': 1,
        'included_in_journey': 1,
        'privacy_level': 'private',
        'is_legacy': 0,
        'migration_status': 'qa_showcase',
        'is_local_draft': 0,
        'sync_failed': 0,
        'sync_status': 'local_only',
        'updated_at': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'signal_processing_state',
      {
        'signal_id': id,
        'sync_status': 'local_only',
        'assist_status': 'done',
        'reason_status': 'done',
        'daily_status': 'done',
        'weekly_status': 'done',
        'journey_status': 'done',
        'is_local_draft': 0,
        'sync_failed': 0,
        'retry_count': 0,
        'processing_version': 'qa_showcase_v1',
        'last_processed_at': timestamp,
        'created_at': timestamp,
        'updated_at': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'signal_analysis_policy',
      {
        'signal_id': id,
        'privacy_level': 'private',
        'is_sensitive': 0,
        'is_excluded': 0,
        'do_not_analyze': 0,
        'requires_user_confirmation': 0,
        'confirmed_by_user': 1,
        'inaccurate': 0,
        'updated_at': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.insert(
      'signal_sync_identity',
      {
        'client_id': id,
        'server_id': id,
        'local_signal_id': id,
        'sync_status': 'local_only',
        'last_synced_at': timestamp,
        'created_at': timestamp,
        'updated_at': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> _preparePreferences(
    SharedPreferences preferences,
    DateTime today,
  ) async {
    final started = today.subtract(const Duration(days: 21));
    await preferences.setBool('onboarding_completed', true);
    await preferences.setBool('onboardingCompleted', true);
    await preferences.setString(
      'local_app_started_date',
      started.toIso8601String(),
    );
    await preferences.setString('profile_display_name', 'Signal Path 测试');
  }

  static Future<void> _removeOwnedRows(Database db) async {
    final signalRows = await db.query(
      'signal_cards',
      columns: const ['id', 'client_id'],
      where: "id LIKE 'qa_demo_signal_%'",
    );
    final signalIds = signalRows
        .map((row) => row['id'] as String?)
        .whereType<String>()
        .toList(growable: false);
    final clientIds = signalRows
        .map((row) => row['client_id'] as String?)
        .whereType<String>()
        .toList(growable: false);

    for (final id in signalIds) {
      await db.delete(
        'signal_processing_state',
        where: 'signal_id = ?',
        whereArgs: [id],
      );
      await db.delete(
        'signal_analysis_policy',
        where: 'signal_id = ?',
        whereArgs: [id],
      );
      await db.delete(
        'trace_links',
        where: '(source_id = ? OR target_id = ?)',
        whereArgs: [id, id],
      );
    }
    for (final clientId in clientIds) {
      await db.delete(
        'signal_sync_identity',
        where: 'client_id = ?',
        whereArgs: [clientId],
      );
    }
    await db.delete(
      'signal_cards',
      where: "id LIKE 'qa_demo_signal_%'",
    );

    await db.delete(
      'micro_action_feedback',
      where: "micro_action_id LIKE 'qa_demo_action_%'",
    );
    await db.delete(
      'micro_actions',
      where: "id LIKE 'qa_demo_action_%'",
    );
    await db.delete(
      'trace_links',
      where: "source_id LIKE 'qa_demo_%' OR target_id LIKE 'qa_demo_%'",
    );
    final experimentRows = await db.query(
      'life_experiments',
      columns: const ['id'],
      where:
          "id LIKE 'qa_demo_experiment_%' OR origin_candidate_id LIKE 'qa_demo_%'",
    );
    for (final row in experimentRows) {
      final id = row['id'] as String?;
      if (id == null || id.isEmpty) continue;
      for (final table in [
        'life_experiment_feedback',
        'life_experiment_lifecycle_events',
        'life_experiment_rollups',
      ]) {
        await db.delete(table, where: 'experiment_id = ?', whereArgs: [id]);
      }
      await db.delete(
        'trace_links',
        where: 'source_id = ? OR target_id = ?',
        whereArgs: [id, id],
      );
      await db.delete(
        'life_experiments',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await db.delete(
      'observations',
      where: "id LIKE 'qa_demo_observation_%'",
    );
  }

  static Future<void> _seedObservations(
    Database db, {
    required String localUserId,
    required DateTime today,
  }) async {
    final periodStart = _dateKey(today.subtract(const Duration(days: 13)));
    final periodEnd = _dateKey(today);
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = <Map<String, Object?>>[
      {
        'id': 'qa_demo_observation_01',
        'observation_text': '连续切换任务后，能量下降会比工作量本身更明显。',
        'suggested_pattern': '频繁切换比单次高强度更消耗。',
        'evidence_text': '两周内多条工作信号与恢复反馈重复出现。',
      },
      {
        'id': 'qa_demo_observation_02',
        'observation_text': '短暂离开屏幕并走动十分钟，通常能让下午重新稳定。',
        'suggested_pattern': '低成本恢复动作对下午节奏有效。',
        'evidence_text': '散步、晒太阳与拉伸后的记录更稳定。',
      },
    ];
    for (final row in rows) {
      await db.insert(
        'observations',
        {
          ...row,
          'local_user_id': localUserId,
          'observation_type': 'pattern',
          'confidence': 'high',
          'status': 'confirmed',
          'source_period_start': periodStart,
          'source_period_end': periodEnd,
          'created_by': 'qa_showcase',
          'created_at': now,
          'updated_at': now,
          'confirmed_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _seedMicroActions(
    AppDependencies dependencies,
    DateTime today,
  ) async {
    final todayKey = _dateKey(today);
    final start = today.subtract(const Duration(days: 2));
    final end = start.add(const Duration(days: 6));
    final now = DateTime.now();
    final action = MicroActionModel(
      id: 'qa_demo_action_01',
      judgementId: 'qa_demo_judgement_01',
      title: '任务切换前留两分钟缓冲',
      reason: '减少连续切换造成的能量下坠。',
      status: 'active',
      feedbackStatus: 'in_progress',
      plannedDate: todayKey,
      localUserId: dependencies.localUserId,
      adoptedAt: start,
      progressStartDate: _dateKey(start),
      progressEndDate: _dateKey(end),
      linkedSignalCardIds: const [
        'qa_demo_signal_01',
        'qa_demo_signal_04',
        'qa_demo_signal_08',
      ],
      createdAt: start,
      updatedAt: now,
    );
    await dependencies.localPhase3PlusRepository.upsertMicroAction(action);

    for (var offset = 0; offset < 2; offset += 1) {
      final day = start.add(Duration(days: offset));
      await dependencies.localPhase3PlusRepository.insertMicroActionFeedback(
        MicroActionFeedbackModel(
          id: 'qa_demo_action_feedback_${offset + 1}',
          microActionId: action.id,
          localDate: _dateKey(day),
          happened: 'yes',
          effect: 'helpful',
          difficulty: 'easy',
          userNote: '切换前停一下，下一件事更容易开始。',
          nextAdjustment: 'continue',
          createdAt: day.add(const Duration(hours: 18)),
        ),
      );
    }
  }

  static Future<void> _seedExperiment(
    AppDependencies dependencies,
    DateTime today,
  ) async {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final repository = dependencies.localLifeExperimentRepository;
    final createdAt = today.subtract(const Duration(days: 3));
    final experiment = LifeExperimentModel(
      id: 'qa_demo_experiment_01',
      localUserId: dependencies.localUserId,
      sourceWeekStart: _dateKey(monday),
      sourceWeekEnd: _dateKey(monday.add(const Duration(days: 6))),
      title: '午后十分钟离屏恢复',
      hypothesis: '在切换密集的下午主动离屏十分钟，能减少后续疲惫感。',
      suggestedAction: '下午第一次明显疲惫时，离开屏幕走动或晒太阳十分钟。',
      linkedSignalCardIds: const [
        'qa_demo_signal_02',
        'qa_demo_signal_06',
        'qa_demo_signal_10',
      ],
      status: 'active',
      focusAreaId: 'emotional_stability',
      patternId: 'qa_demo_switch_recovery',
      plannedFrequency: 'daily',
      plannedDurationMinutes: 10,
      plannedTotalDays: 7,
      originCandidateId: 'qa_demo_candidate_experiment_01',
      adoptedAt: createdAt,
      progressStartDate: _dateKey(today.subtract(const Duration(days: 3))),
      progressEndDate: _dateKey(today.add(const Duration(days: 3))),
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
    final db = await dependencies.localDatabase.database;
    await db.insert(
      'life_experiments',
      repository.toStorageRow(experiment),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await repository.ensureAdoptionArtifacts(experiment);

    for (var offset = 3; offset >= 1; offset -= 1) {
      await repository.recordFeedback(
        experimentId: experiment.id,
        localUserId: dependencies.localUserId,
        completionStatus: offset == 2 ? 'adjusted' : 'done',
        helpfulnessScore: offset == 2 ? 3 : 4,
        feedbackText: offset == 2 ? '十分钟有点长，改成先走六分钟。' : '离屏后，下午重新进入状态更顺。',
        feedbackDate: today.subtract(Duration(days: offset)),
        conditionTags: const ['afternoon', 'recovery'],
        durationMinutes: offset == 2 ? 6 : 10,
        timeSlot: 'afternoon',
      );
    }
  }

  static List<_QaSignalSample> _signalSamples() => const [
        _QaSignalSample(
          daysAgo: 0,
          content: '上午连续切了三个任务，真正累的是不停重新进入状态。',
          acknowledgement: '这种来回切换确实很磨人，先把它留在这里。',
          observation: '任务切换的密度正在影响今天的能量。',
          tryNext: '下一次切换前，先留两分钟收尾和呼吸。',
          scene: 'work',
          friction: 'context_switching',
          energyLoad: 'high',
        ),
        _QaSignalSample(
          daysAgo: 0,
          content: '午饭后出去走了十分钟，回来后脑子清楚了很多。',
          acknowledgement: '你已经找到一个很具体的恢复入口。',
          observation: '短暂离屏和走动对午后恢复有帮助。',
          tryNext: '先保留这个十分钟窗口，不需要做得更复杂。',
          scene: 'recovery',
          friction: 'fatigue',
          positiveSignal: 'short_walk_helped',
          energyLoad: 'low',
        ),
        _QaSignalSample(
          daysAgo: 0,
          content: '下午把会议之间留出一点空白，整个人没那么赶。',
          acknowledgement: '这点空白看起来真的接住了你。',
          observation: '有缓冲时，会议并不会把能量全部带走。',
          tryNext: '继续观察哪一种缓冲最容易坚持。',
          scene: 'work',
          friction: 'dense_schedule',
          positiveSignal: 'buffer_helped',
          energyLoad: 'medium',
        ),
        _QaSignalSample(
          daysAgo: 0,
          content: '傍晚没有立刻继续工作，先坐了一会儿，心里安定很多。',
          acknowledgement: '先停一下，也是一种有效的选择。',
          observation: '短暂停顿让情绪和身体重新对齐。',
          tryNext: '把这个停顿留成今天的结束信号。',
          scene: 'emotional',
          friction: 'overextension',
          positiveSignal: 'pause_helped',
          energyLoad: 'low',
        ),
        _QaSignalSample(
          daysAgo: 1,
          content: '开会前已经有点紧，临时增加议题后更容易乱。',
          acknowledgement: '临时变化叠在已有压力上，难怪会乱。',
          observation: '不确定性会放大会议前的能量消耗。',
          tryNext: '会前只写下最需要守住的一件事。',
          scene: 'work',
          friction: 'uncertainty',
          energyLoad: 'high',
        ),
        _QaSignalSample(
          daysAgo: 1,
          content: '晚上关掉通知以后，读书半小时比想象中轻松。',
          acknowledgement: '安静下来后，你的注意力其实还在。',
          observation: '减少提醒能明显降低注意力切换。',
          tryNext: '保留一个不被通知打断的短窗口。',
          scene: 'home',
          friction: 'notifications',
          positiveSignal: 'quiet_focus',
          energyLoad: 'low',
        ),
        _QaSignalSample(
          daysAgo: 2,
          content: '把复杂任务拆成第一步之后，没有再一直拖着。',
          acknowledgement: '你不是缺动力，而是需要更小的入口。',
          observation: '明确第一步能减少启动阻力。',
          tryNext: '下一件复杂任务也只先写第一步。',
          scene: 'work',
          friction: 'starting',
          positiveSignal: 'small_start',
          energyLoad: 'medium',
        ),
        _QaSignalSample(
          daysAgo: 3,
          content: '一整天都在回复消息，真正重要的事几乎没推进。',
          acknowledgement: '忙了一天却没有推进感，确实会很挫败。',
          observation: '碎片回复正在挤压需要连续注意力的工作。',
          tryNext: '先圈出一个不回复消息的四十分钟。',
          scene: 'work',
          friction: 'interruptions',
          energyLoad: 'high',
        ),
        _QaSignalSample(
          daysAgo: 4,
          content: '午后晒到太阳以后，疲惫感没有继续往下掉。',
          acknowledgement: '身体收到了一点恢复信号。',
          observation: '自然光和短暂走动能缓住下午低谷。',
          tryNext: '疲惫刚出现时就去走一小圈。',
          scene: 'recovery',
          friction: 'fatigue',
          positiveSignal: 'sunlight_helped',
          energyLoad: 'low',
        ),
        _QaSignalSample(
          daysAgo: 5,
          content: '连续两场会议后，连简单决定都觉得很重。',
          acknowledgement: '这更像能量见底，不是你变得不会决定。',
          observation: '高密度会议后，决策负担会明显升高。',
          tryNext: '把重要决定移到会议前或恢复之后。',
          scene: 'work',
          friction: 'decision_fatigue',
          energyLoad: 'high',
        ),
        _QaSignalSample(
          daysAgo: 6,
          content: '周末没有排满，反而更愿意主动整理下周。',
          acknowledgement: '留白没有让你停下，反而让主动性回来。',
          observation: '恢复空间会带回计划感。',
          tryNext: '下周也保留一个不安排用途的空档。',
          scene: 'planning',
          friction: 'overplanning',
          positiveSignal: 'space_helped',
          energyLoad: 'low',
        ),
        _QaSignalSample(
          daysAgo: 7,
          content: '下午临时切换太多，回家后什么都不想做。',
          acknowledgement: '回家后的空掉，是白天切换太密集留下的余波。',
          observation: '工作切换会继续影响晚间恢复。',
          tryNext: '下班前留五分钟把未完成事项收起来。',
          scene: 'work',
          friction: 'context_switching',
          energyLoad: 'high',
        ),
        _QaSignalSample(
          daysAgo: 8,
          content: '午休只拉伸了几分钟，下午肩膀没有那么僵。',
          acknowledgement: '很小的动作也已经产生了可见变化。',
          observation: '低成本恢复动作更容易被真正执行。',
          tryNext: '继续保持小，不用急着加量。',
          scene: 'recovery',
          friction: 'body_tension',
          positiveSignal: 'stretch_helped',
          energyLoad: 'low',
        ),
        _QaSignalSample(
          daysAgo: 9,
          content: '早上先做最重要的一件事，后面被打断也没那么焦虑。',
          acknowledgement: '推进感先出现以后，后面的变化更容易承受。',
          observation: '优先完成核心任务能降低全天的不安。',
          tryNext: '明早继续先守住一个核心推进。',
          scene: 'work',
          friction: 'interruptions',
          positiveSignal: 'priority_helped',
          energyLoad: 'medium',
        ),
        _QaSignalSample(
          daysAgo: 10,
          content: '晚上太晚还在处理消息，睡前一直停不下来。',
          acknowledgement: '工作没有结束信号，身体也很难切回休息。',
          observation: '晚间消息会延迟恢复和入睡。',
          tryNext: '给最后一次查看消息设一个时间点。',
          scene: 'sleep',
          friction: 'late_messages',
          energyLoad: 'high',
        ),
        _QaSignalSample(
          daysAgo: 11,
          content: '和朋友聊完以后，原本卡着的情绪松开了一点。',
          acknowledgement: '被理解以后，你不需要一个人顶住全部。',
          observation: '有安全感的连接能帮助情绪恢复。',
          tryNext: '下次卡住时，早点向可信任的人说一句。',
          scene: 'relationship',
          friction: 'emotional_load',
          positiveSignal: 'connection_helped',
          energyLoad: 'low',
        ),
        _QaSignalSample(
          daysAgo: 12,
          content: '把日程排得太满以后，任何小变化都会让我急。',
          acknowledgement: '不是变化太大，而是已经没有缓冲。',
          observation: '缺少留白会放大临时变化的压力。',
          tryNext: '每半天至少留一个可移动的小空档。',
          scene: 'planning',
          friction: 'dense_schedule',
          energyLoad: 'high',
        ),
        _QaSignalSample(
          daysAgo: 13,
          content: '今天只完成了一件事，但那件事真的重要。',
          acknowledgement: '数量不多，不代表这一天没有价值。',
          observation: '清晰的优先级会带来更稳定的满足感。',
          tryNext: '明天也先选一件值得完成的事。',
          scene: 'planning',
          friction: 'self_pressure',
          positiveSignal: 'meaningful_progress',
          energyLoad: 'medium',
        ),
      ];

  static String _dateKey(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class _QaSignalSample {
  final int daysAgo;
  final String content;
  final String acknowledgement;
  final String observation;
  final String tryNext;
  final String scene;
  final String friction;
  final String? positiveSignal;
  final String energyLoad;

  const _QaSignalSample({
    required this.daysAgo,
    required this.content,
    required this.acknowledgement,
    required this.observation,
    required this.tryNext,
    required this.scene,
    required this.friction,
    this.positiveSignal,
    required this.energyLoad,
  });
}
