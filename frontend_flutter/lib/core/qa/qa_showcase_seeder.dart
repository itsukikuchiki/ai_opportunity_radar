import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../di/app_dependencies.dart';
import '../i18n/runtime_locale_text.dart';
import '../models/phase3_plus_models.dart';
import '../models/weekly_models.dart';

/// Builds a private, local-only evidence set for the explicit QA showcase
/// archive. Every row owned by this seeder uses the `qa_demo_` namespace.
/// Existing user rows are never replaced or deleted.
class QaShowcaseSeeder {
  static const _markerKey = 'qa_showcase_seed_signature_v2';
  static const _legacyMarkerKey = 'qa_showcase_seed_date_v1';
  static const _datasetVersion = 'localized_v5';
  static const _profilePreferenceKey = 'profile_display_name';
  static const _qaProfileNames = <String>{
    'Signal Path QA',
    'Signal Path 测试',
    'Signal Path 測試',
    'Signal Path テスト',
  };

  const QaShowcaseSeeder._();

  /// Removes preferences that are owned by an earlier QA showcase launch.
  ///
  /// This is intentionally separate from [purgeOwnedData] so production
  /// startup can restore the onboarding decision before the router chooses an
  /// initial page. A marker (current or legacy) is the ownership proof for the
  /// non-namespaced onboarding and installation-date preferences. A profile
  /// name is removed only when it still exactly matches one of the seeder's
  /// fixed labels, preserving any name the person entered afterwards.
  static Future<void> purgeOwnedPreferences(
    SharedPreferences preferences,
  ) async {
    final ownsPreferences = preferences.containsKey(_markerKey) ||
        preferences.containsKey(_legacyMarkerKey);
    final profileName = preferences.getString(_profilePreferenceKey)?.trim();

    await preferences.remove(_markerKey);
    await preferences.remove(_legacyMarkerKey);
    if (!ownsPreferences && !_qaProfileNames.contains(profileName)) return;

    if (_qaProfileNames.contains(profileName)) {
      await preferences.remove(_profilePreferenceKey);
    }
    if (ownsPreferences) {
      await preferences.remove('onboarding_completed');
      await preferences.remove('onboardingCompleted');
      await preferences.remove('local_app_started_date');
    }
  }

  /// Deletes only rows owned by the `qa_demo_` showcase namespace.
  ///
  /// User-created rows use different identifiers and are never selected by
  /// these predicates. Generated report caches are also left in place; their
  /// normal source-hash invalidation rebuilds them after the QA sources are
  /// gone.
  static Future<void> purgeOwnedData({
    required AppDependencies dependencies,
  }) async {
    final db = await dependencies.localDatabase.database;
    await _removeOwnedRows(db);
  }

  static Future<void> seed({
    required AppDependencies dependencies,
    required SharedPreferences preferences,
    DateTime? now,
    String? language,
  }) async {
    final localNow = (now ?? DateTime.now()).toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final todayKey = _dateKey(today);
    final seedLanguage = _normalizeSeedLanguage(language);
    final seedSignature = '$todayKey|$seedLanguage|$_datasetVersion';
    final samples = _signalSamples(seedLanguage);
    final db = await dependencies.localDatabase.database;

    final existing = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM signal_cards WHERE id LIKE 'qa_demo_signal_%'",
          ),
        ) ??
        0;
    if (preferences.getString(_markerKey) == seedSignature &&
        existing == samples.length) {
      await _preparePreferences(preferences, today, seedLanguage);
      return;
    }

    await _removeOwnedRows(db);
    await _preparePreferences(preferences, today, seedLanguage);

    await db.transaction((txn) async {
      for (var index = 0; index < samples.length; index += 1) {
        await _insertSignal(
          txn,
          sample: samples[index],
          index: index,
          today: today,
          localNow: localNow,
          language: seedLanguage,
        );
      }
    });

    await _seedObservations(
      db,
      localUserId: dependencies.localUserId,
      today: today,
      language: seedLanguage,
    );
    await _seedMicroActions(dependencies, today, seedLanguage);
    await _seedExperiment(dependencies, today, seedLanguage);
    await preferences.setString(_markerKey, seedSignature);
  }

  static Future<void> _insertSignal(
    DatabaseExecutor db, {
    required _QaSignalSample sample,
    required int index,
    required DateTime today,
    required DateTime localNow,
    required String language,
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
        'language': language,
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
          'focus_domain_id': sample.focusDomainId,
          'energy_level': sample.energyLevel,
          'energy_state': _energyState(sample.energyLevel),
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
    String language,
  ) async {
    final started = today.subtract(const Duration(days: 21));
    await preferences.setBool('onboarding_completed', true);
    await preferences.setBool('onboardingCompleted', true);
    await preferences.setString(
      'local_app_started_date',
      started.toIso8601String(),
    );
    await preferences.setString(
      'profile_display_name',
      _copy(
        language,
        en: 'Signal Path QA',
        zhHans: 'Signal Path 测试',
        zhHant: 'Signal Path 測試',
        ja: 'Signal Path テスト',
      ),
    );
  }

  static Future<void> _removeOwnedRows(Database db) async {
    final signalRows = await db.query(
      'signal_cards',
      columns: const ['id', 'client_id'],
      where:
          "id LIKE 'qa_demo_%' OR signal_card_id LIKE 'qa_demo_%' OR client_id LIKE 'qa_demo_%' OR server_id LIKE 'qa_demo_%'",
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
      'signal_processing_state',
      where: "signal_id LIKE 'qa_demo_%'",
    );
    await db.delete(
      'signal_analysis_policy',
      where: "signal_id LIKE 'qa_demo_%'",
    );
    await db.delete(
      'signal_sync_identity',
      where:
          "client_id LIKE 'qa_demo_%' OR server_id LIKE 'qa_demo_%' OR local_signal_id LIKE 'qa_demo_%'",
    );
    await db.delete(
      'signal_card_drafts',
      where:
          "draft_id LIKE 'qa_demo_%' OR client_id LIKE 'qa_demo_%' OR remote_signal_card_id LIKE 'qa_demo_%' OR server_id LIKE 'qa_demo_%'",
    );
    await db.delete(
      'signal_tombstones',
      where:
          "signal_id LIKE 'qa_demo_%' OR signal_card_id LIKE 'qa_demo_%' OR client_id LIKE 'qa_demo_%' OR server_id LIKE 'qa_demo_%'",
    );
    await db.delete(
      'signal_cards',
      where:
          "id LIKE 'qa_demo_%' OR signal_card_id LIKE 'qa_demo_%' OR client_id LIKE 'qa_demo_%' OR server_id LIKE 'qa_demo_%'",
    );

    await db.delete(
      'micro_action_feedback',
      where: "id LIKE 'qa_demo_%' OR micro_action_id LIKE 'qa_demo_%'",
    );
    await db.delete(
      'micro_action_review_events',
      where: "id LIKE 'qa_demo_%' OR micro_action_id LIKE 'qa_demo_%'",
    );
    await db.delete(
      'plan_content_versions',
      where: "id LIKE 'qa_demo_%' OR object_id LIKE 'qa_demo_%'",
    );
    await db.delete(
      'micro_actions',
      where: "id LIKE 'qa_demo_%' OR judgement_id LIKE 'qa_demo_%'",
    );
    await db.delete(
      'trace_links',
      where:
          "id LIKE 'qa_demo_%' OR source_id LIKE 'qa_demo_%' OR target_id LIKE 'qa_demo_%'",
    );
    final experimentRows = await db.query(
      'life_experiments',
      columns: const ['id'],
      where: "id LIKE 'qa_demo_%' OR origin_candidate_id LIKE 'qa_demo_%'",
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
        'plan_content_versions',
        where: 'object_id = ?',
        whereArgs: [id],
      );
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
      'observation_signal_links',
      where: "observation_id LIKE 'qa_demo_%' OR signal_id LIKE 'qa_demo_%'",
    );
    await db.delete(
      'observations',
      where:
          "id LIKE 'qa_demo_%' OR source_ai_judgement_id LIKE 'qa_demo_%' OR created_by = 'qa_showcase'",
    );
  }

  static Future<void> _seedObservations(
    Database db, {
    required String localUserId,
    required DateTime today,
    required String language,
  }) async {
    final periodStart = _dateKey(today.subtract(const Duration(days: 13)));
    final periodEnd = _dateKey(today);
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = <Map<String, Object?>>[
      {
        'id': 'qa_demo_observation_01',
        'observation_text': _copy(
          language,
          en: 'After repeated task switching, the energy drop stands out more than the workload itself.',
          zhHans: '连续切换任务后，能量下降会比工作量本身更明显。',
          zhHant: '連續切換任務後，能量下降會比工作量本身更明顯。',
          ja: 'タスクを続けて切り替えると、作業量そのものよりエネルギーの低下が目立つ。',
        ),
        'suggested_pattern': _copy(
          language,
          en: 'Frequent switching is more draining than one intense task.',
          zhHans: '频繁切换比单次高强度更消耗。',
          zhHant: '頻繁切換比單次高強度更消耗。',
          ja: '頻繁な切り替えは、1回の高負荷な作業よりも消耗しやすい。',
        ),
        'evidence_text': _copy(
          language,
          en: 'Work Signals and recovery feedback repeated across the past two weeks.',
          zhHans: '两周内多条工作信号与恢复反馈重复出现。',
          zhHant: '兩週內多條工作訊號與恢復回饋重複出現。',
          ja: '2週間に、仕事のSignalと回復に関するフィードバックが何度も現れている。',
        ),
      },
      {
        'id': 'qa_demo_observation_02',
        'observation_text': _copy(
          language,
          en: 'A ten-minute walk away from the screen usually helps the afternoon feel steady again.',
          zhHans: '短暂离开屏幕并走动十分钟，通常能让下午重新稳定。',
          zhHant: '短暫離開螢幕並走動十分鐘，通常能讓午後重新穩定。',
          ja: '短時間画面から離れて10分ほど歩くと、午後の調子が戻りやすい。',
        ),
        'suggested_pattern': _copy(
          language,
          en: 'A low-effort reset helps restore the afternoon rhythm.',
          zhHans: '低成本恢复动作对下午节奏有效。',
          zhHant: '低成本恢復動作對午後節奏有效。',
          ja: '負担の小さい回復行動が、午後のリズムを整えるのに役立っている。',
        ),
        'evidence_text': _copy(
          language,
          en: 'Records after walking, sunlight, or stretching tend to be more stable.',
          zhHans: '散步、晒太阳与拉伸后的记录更稳定。',
          zhHant: '散步、曬太陽與伸展後的記錄更穩定。',
          ja: '散歩、日光を浴びること、ストレッチの後は記録がより安定している。',
        ),
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
    String language,
  ) async {
    final todayKey = _dateKey(today);
    final start = today.subtract(const Duration(days: 2));
    final end = start.add(const Duration(days: 6));
    final now = DateTime.now();
    final action = MicroActionModel(
      id: 'qa_demo_action_01',
      judgementId: 'qa_demo_judgement_01',
      title: _copy(
        language,
        en: 'Leave a two-minute buffer before switching tasks',
        zhHans: '任务切换前留两分钟缓冲',
        zhHant: '任務切換前留兩分鐘緩衝',
        ja: 'タスクを切り替える前に2分間の余白をつくる',
      ),
      reason: _copy(
        language,
        en: 'Reduce the energy dip caused by back-to-back switching.',
        zhHans: '减少连续切换造成的能量下坠。',
        zhHant: '減少連續切換造成的能量下墜。',
        ja: '続けて切り替えることによるエネルギー低下を和らげる。',
      ),
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
          userNote: _copy(
            language,
            en: 'Pausing before the switch made the next task easier to start.',
            zhHans: '切换前停一下，下一件事更容易开始。',
            zhHant: '切換前停一下，下一件事更容易開始。',
            ja: '切り替える前に一度止まると、次のことを始めやすかった。',
          ),
          nextAdjustment: 'continue',
          createdAt: day.add(const Duration(hours: 18)),
        ),
      );
    }
  }

  static Future<void> _seedExperiment(
    AppDependencies dependencies,
    DateTime today,
    String language,
  ) async {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final repository = dependencies.localLifeExperimentRepository;
    final createdAt = today.subtract(const Duration(days: 3));
    final experiment = LifeExperimentModel(
      id: 'qa_demo_experiment_01',
      localUserId: dependencies.localUserId,
      sourceWeekStart: _dateKey(monday),
      sourceWeekEnd: _dateKey(monday.add(const Duration(days: 6))),
      title: _copy(
        language,
        en: 'Ten-minute afternoon screen break',
        zhHans: '午后十分钟离屏恢复',
        zhHant: '午後十分鐘離屏恢復',
        ja: '午後に10分間画面から離れて回復する',
      ),
      hypothesis: _copy(
        language,
        en: 'Taking a ten-minute screen break during a busy afternoon may reduce later fatigue.',
        zhHans: '在切换密集的下午主动离屏十分钟，能减少后续疲惫感。',
        zhHant: '在切換密集的午後主動離屏十分鐘，能減少後續疲憊感。',
        ja: '切り替えの多い午後に自分から10分間画面を離れると、その後の疲れを減らせる。',
      ),
      suggestedAction: _copy(
        language,
        en: 'At the first clear sign of afternoon fatigue, step away to walk or get sunlight for ten minutes.',
        zhHans: '下午第一次明显疲惫时，离开屏幕走动或晒太阳十分钟。',
        zhHant: '午後第一次明顯疲憊時，離開螢幕走動或曬太陽十分鐘。',
        ja: '午後に最初の明確な疲れを感じたら、画面から離れて歩くか、日光を10分間浴びる。',
      ),
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
        feedbackText: offset == 2
            ? _copy(
                language,
                en: 'Ten minutes felt a little long, so I started with a six-minute walk.',
                zhHans: '十分钟有点长，改成先走六分钟。',
                zhHant: '十分鐘有點長，改成先走六分鐘。',
                ja: '10分は少し長いので、まず6分歩く形に変えた。',
              )
            : _copy(
                language,
                en: 'After stepping away from the screen, it was easier to get back into the afternoon.',
                zhHans: '离屏后，下午重新进入状态更顺。',
                zhHant: '離屏後，午後重新進入狀態更順。',
                ja: '画面から離れた後は、午後の作業にスムーズに戻れた。',
              ),
        feedbackDate: today.subtract(Duration(days: offset)),
        conditionTags: const ['afternoon', 'recovery'],
        durationMinutes: offset == 2 ? 6 : 10,
        timeSlot: 'afternoon',
      );
    }
  }

  static List<_QaSignalSample> _signalSamples(String language) =>
      language == 'en'
          ? _englishSignalSamples
          : language == 'ja'
              ? _japaneseSignalSamples
              : [
                  _QaSignalSample(
                    daysAgo: 0,
                    focusDomainId: 'emotional_stability',
                    energyLevel: 2,
                    content: _copy(
                      language,
                      zhHans: '上午连续切了三个任务，真正累的是不停重新进入状态。',
                      zhHant: '上午連續切了三個任務，真正累的是不停重新進入狀態。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '这种来回切换确实很磨人，先把它留在这里。',
                      zhHant: '這種來回切換確實很磨人，先把它留在這裡。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '任务切换的密度正在影响今天的能量。',
                      zhHant: '任務切換的密度正在影響今天的能量。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '下一次切换前，先留两分钟收尾和呼吸。',
                      zhHant: '下一次切換前，先留兩分鐘收尾和呼吸。',
                    ),
                    scene: 'work',
                    friction: 'context_switching',
                    energyLoad: 'high',
                  ),
                  _QaSignalSample(
                    daysAgo: 0,
                    focusDomainId: 'food_sleep',
                    energyLevel: 2,
                    content: _copy(
                      language,
                      zhHans: '午饭后出去走了十分钟，回来后脑子清楚了很多。',
                      zhHant: '午飯後出去走了十分鐘，回來後腦子清楚了很多。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '你已经找到一个很具体的恢复入口。',
                      zhHant: '你已經找到一個很具體的恢復入口。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '短暂离屏和走动对午后恢复有帮助。',
                      zhHant: '短暫離屏和走動對午後恢復有幫助。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '先保留这个十分钟窗口，不需要做得更复杂。',
                      zhHant: '先保留這個十分鐘時段，不需要做得更複雜。',
                    ),
                    scene: 'recovery',
                    friction: 'fatigue',
                    positiveSignal: 'short_walk_helped',
                    energyLoad: 'low',
                  ),
                  _QaSignalSample(
                    daysAgo: 0,
                    focusDomainId: 'emotional_stability',
                    energyLevel: 2,
                    content: _copy(
                      language,
                      zhHans: '下午把会议之间留出一点空白，整个人没那么赶。',
                      zhHant: '午後把會議之間留出一點空白，整個人沒那麼趕。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '这点空白看起来真的接住了你。',
                      zhHant: '這點空白看起來真的接住了你。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '有缓冲时，会议并不会把能量全部带走。',
                      zhHant: '有緩衝時，會議並不會把能量全部帶走。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '继续观察哪一种缓冲最容易坚持。',
                      zhHant: '繼續觀察哪一種緩衝最容易持續。',
                    ),
                    scene: 'work',
                    friction: 'dense_schedule',
                    positiveSignal: 'buffer_helped',
                    energyLoad: 'medium',
                  ),
                  _QaSignalSample(
                    daysAgo: 0,
                    focusDomainId: 'emotional_stability',
                    energyLevel: 2,
                    content: _copy(
                      language,
                      zhHans: '傍晚没有立刻继续工作，先坐了一会儿，心里安定很多。',
                      zhHant: '傍晚沒有立刻繼續工作，先坐了一會兒，心裡安定很多。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '先停一下，也是一种有效的选择。',
                      zhHant: '先停一下，也是一種有效的選擇。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '短暂停顿让情绪和身体重新对齐。',
                      zhHant: '短暫停頓讓情緒和身體重新對齊。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '把这个停顿留成今天的结束信号。',
                      zhHant: '把這個停頓留成今天的結束訊號。',
                    ),
                    scene: 'emotional',
                    friction: 'overextension',
                    positiveSignal: 'pause_helped',
                    energyLoad: 'low',
                  ),
                  _QaSignalSample(
                    daysAgo: 1,
                    focusDomainId: 'emotional_stability',
                    energyLevel: 1,
                    content: _copy(
                      language,
                      zhHans: '开会前已经有点紧，临时增加议题后更容易乱。',
                      zhHant: '開會前已經有點緊，臨時增加議題後更容易亂。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '临时变化叠在已有压力上，难怪会乱。',
                      zhHant: '臨時變化疊在已有壓力上，難怪會亂。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '不确定性会放大会议前的能量消耗。',
                      zhHant: '不確定性會放大會議前的能量消耗。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '会前只写下最需要守住的一件事。',
                      zhHant: '會前只寫下最需要守住的一件事。',
                    ),
                    scene: 'work',
                    friction: 'uncertainty',
                    energyLoad: 'high',
                  ),
                  _QaSignalSample(
                    daysAgo: 1,
                    focusDomainId: 'emotional_stability',
                    energyLevel: 1,
                    content: _copy(
                      language,
                      zhHans: '晚上关掉通知以后，读书半小时比想象中轻松。',
                      zhHant: '晚上關掉通知以後，讀書半小時比想像中輕鬆。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '安静下来后，你的注意力其实还在。',
                      zhHant: '安靜下來後，你的注意力其實還在。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '减少提醒能明显降低注意力切换。',
                      zhHant: '減少提醒能明顯降低注意力切換。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '保留一个不被通知打断的短窗口。',
                      zhHant: '保留一個不被通知打斷的短時段。',
                    ),
                    scene: 'home',
                    friction: 'notifications',
                    positiveSignal: 'quiet_focus',
                    energyLoad: 'low',
                  ),
                  _QaSignalSample(
                    daysAgo: 2,
                    focusDomainId: 'growth_plan',
                    energyLevel: 2,
                    content: _copy(
                      language,
                      zhHans: '把复杂任务拆成第一步之后，没有再一直拖着。',
                      zhHant: '把複雜任務拆成第一步之後，沒有再一直拖著。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '你不是缺动力，而是需要更小的入口。',
                      zhHant: '你不是缺動力，而是需要更小的入口。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '明确第一步能减少启动阻力。',
                      zhHant: '明確第一步能減少啟動阻力。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '下一件复杂任务也只先写第一步。',
                      zhHant: '下一件複雜任務也只先寫第一步。',
                    ),
                    scene: 'work',
                    friction: 'starting',
                    positiveSignal: 'small_start',
                    energyLoad: 'medium',
                  ),
                  _QaSignalSample(
                    daysAgo: 3,
                    focusDomainId: 'emotional_stability',
                    energyLevel: 1,
                    content: _copy(
                      language,
                      zhHans: '一整天都在回复消息，真正重要的事几乎没推进。',
                      zhHant: '一整天都在回覆訊息，真正重要的事幾乎沒推進。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '忙了一天却没有推进感，确实会很挫败。',
                      zhHant: '忙了一天卻沒有推進感，確實會很挫折。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '碎片回复正在挤压需要连续注意力的工作。',
                      zhHant: '零碎回覆正在擠壓需要連續注意力的工作。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '先圈出一个不回复消息的四十分钟。',
                      zhHant: '先圈出一個不回覆訊息的四十分鐘。',
                    ),
                    scene: 'work',
                    friction: 'interruptions',
                    energyLoad: 'high',
                  ),
                  _QaSignalSample(
                    daysAgo: 4,
                    focusDomainId: 'food_sleep',
                    energyLevel: 0,
                    content: _copy(
                      language,
                      zhHans: '午后晒到太阳以后，疲惫感没有继续往下掉。',
                      zhHant: '午後曬到太陽以後，疲憊感沒有繼續往下掉。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '身体收到了一点恢复信号。',
                      zhHant: '身體收到了一點恢復訊號。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '自然光和短暂走动能缓住下午低谷。',
                      zhHant: '自然光和短暫走動能緩住午後低谷。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '疲惫刚出现时就去走一小圈。',
                      zhHant: '疲憊剛出現時就去走一小圈。',
                    ),
                    scene: 'recovery',
                    friction: 'fatigue',
                    positiveSignal: 'sunlight_helped',
                    energyLoad: 'low',
                  ),
                  _QaSignalSample(
                    daysAgo: 5,
                    focusDomainId: 'growth_plan',
                    energyLevel: 0,
                    content: _copy(
                      language,
                      zhHans: '连续两场会议后，连简单决定都觉得很重。',
                      zhHant: '連續兩場會議後，連簡單決定都覺得很重。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '这更像能量见底，不是你变得不会决定。',
                      zhHant: '這更像能量見底，不是你變得不會決定。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '高密度会议后，决策负担会明显升高。',
                      zhHant: '高密度會議後，決策負擔會明顯升高。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '把重要决定移到会议前或恢复之后。',
                      zhHant: '把重要決定移到會議前或恢復之後。',
                    ),
                    scene: 'work',
                    friction: 'decision_fatigue',
                    energyLoad: 'high',
                  ),
                  _QaSignalSample(
                    daysAgo: 6,
                    focusDomainId: 'emotional_stability',
                    energyLevel: 2,
                    content: _copy(
                      language,
                      zhHans: '周末没有排满，反而更愿意主动整理下周。',
                      zhHant: '週末沒有排滿，反而更願意主動整理下週。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '留白没有让你停下，反而让主动性回来。',
                      zhHant: '留白沒有讓你停下，反而讓主動性回來。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '恢复空间会带回计划感。',
                      zhHant: '恢復空間會帶回計畫感。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '下周也保留一个不安排用途的空档。',
                      zhHant: '下週也保留一個不安排用途的空檔。',
                    ),
                    scene: 'planning',
                    friction: 'overplanning',
                    positiveSignal: 'space_helped',
                    energyLoad: 'low',
                  ),
                  _QaSignalSample(
                    daysAgo: 7,
                    focusDomainId: 'growth_plan',
                    energyLevel: 0,
                    content: _copy(
                      language,
                      zhHans: '下午临时切换太多，回家后什么都不想做。',
                      zhHant: '午後臨時切換太多，回家後什麼都不想做。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '回家后的空掉，是白天切换太密集留下的余波。',
                      zhHant: '回家後的空掉，是白天切換太密集留下的餘波。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '工作切换会继续影响晚间恢复。',
                      zhHant: '工作切換會繼續影響晚間恢復。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '下班前留五分钟把未完成事项收起来。',
                      zhHant: '下班前留五分鐘把未完成事項收起來。',
                    ),
                    scene: 'work',
                    friction: 'context_switching',
                    energyLoad: 'high',
                  ),
                  _QaSignalSample(
                    daysAgo: 8,
                    focusDomainId: 'food_sleep',
                    energyLevel: 2,
                    content: _copy(
                      language,
                      zhHans: '午休只拉伸了几分钟，下午肩膀没有那么僵。',
                      zhHant: '午休只伸展了幾分鐘，午後肩膀沒有那麼僵。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '很小的动作也已经产生了可见变化。',
                      zhHant: '很小的動作也已經產生了可見變化。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '低成本恢复动作更容易被真正执行。',
                      zhHant: '低成本恢復動作更容易被真正執行。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '继续保持小，不用急着加量。',
                      zhHant: '繼續保持小，不用急著加量。',
                    ),
                    scene: 'recovery',
                    friction: 'body_tension',
                    positiveSignal: 'stretch_helped',
                    energyLoad: 'low',
                  ),
                  _QaSignalSample(
                    daysAgo: 9,
                    focusDomainId: 'growth_plan',
                    energyLevel: 2,
                    content: _copy(
                      language,
                      zhHans: '早上先做最重要的一件事，后面被打断也没那么焦虑。',
                      zhHant: '早上先做最重要的一件事，後面被打斷也沒那麼焦慮。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '推进感先出现以后，后面的变化更容易承受。',
                      zhHant: '推進感先出現以後，後面的變化更容易承受。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '优先完成核心任务能降低全天的不安。',
                      zhHant: '優先完成核心任務能降低全天的不安。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '明早继续先守住一个核心推进。',
                      zhHant: '明早繼續先守住一個核心推進。',
                    ),
                    scene: 'work',
                    friction: 'interruptions',
                    positiveSignal: 'priority_helped',
                    energyLoad: 'medium',
                  ),
                  _QaSignalSample(
                    daysAgo: 10,
                    focusDomainId: 'food_sleep',
                    energyLevel: 0,
                    content: _copy(
                      language,
                      zhHans: '晚上太晚还在处理消息，睡前一直停不下来。',
                      zhHant: '晚上太晚還在處理訊息，睡前一直停不下來。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '工作没有结束信号，身体也很难切回休息。',
                      zhHant: '工作沒有結束訊號，身體也很難切回休息。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '晚间消息会延迟恢复和入睡。',
                      zhHant: '晚間訊息會延遲恢復和入睡。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '给最后一次查看消息设一个时间点。',
                      zhHant: '給最後一次查看訊息設定一個時間點。',
                    ),
                    scene: 'sleep',
                    friction: 'late_messages',
                    energyLoad: 'high',
                  ),
                  _QaSignalSample(
                    daysAgo: 11,
                    focusDomainId: 'relationship_connection',
                    energyLevel: 2,
                    content: _copy(
                      language,
                      zhHans: '和朋友聊完以后，原本卡着的情绪松开了一点。',
                      zhHant: '和朋友聊完以後，原本卡著的情緒鬆開了一點。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '被理解以后，你不需要一个人顶住全部。',
                      zhHant: '被理解以後，你不需要一個人撐住全部。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '有安全感的连接能帮助情绪恢复。',
                      zhHant: '有安全感的連結能幫助情緒恢復。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '下次卡住时，早点向可信任的人说一句。',
                      zhHant: '下次卡住時，早點向信任的人說一句。',
                    ),
                    scene: 'relationship',
                    friction: 'emotional_load',
                    positiveSignal: 'connection_helped',
                    energyLoad: 'low',
                  ),
                  _QaSignalSample(
                    daysAgo: 12,
                    focusDomainId: 'growth_plan',
                    energyLevel: 0,
                    content: _copy(
                      language,
                      zhHans: '把日程排得太满以后，任何小变化都会让我急。',
                      zhHant: '把行程排得太滿以後，任何小變化都會讓我急。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '不是变化太大，而是已经没有缓冲。',
                      zhHant: '不是變化太大，而是已經沒有緩衝。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '缺少留白会放大临时变化的压力。',
                      zhHant: '缺少留白會放大臨時變化的壓力。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '每半天至少留一个可移动的小空档。',
                      zhHant: '每半天至少留一個可移動的小空檔。',
                    ),
                    scene: 'planning',
                    friction: 'dense_schedule',
                    energyLoad: 'high',
                  ),
                  _QaSignalSample(
                    daysAgo: 13,
                    focusDomainId: 'meaning_value',
                    energyLevel: 2,
                    content: _copy(
                      language,
                      zhHans: '今天只完成了一件事，但那件事真的重要。',
                      zhHant: '今天只完成了一件事，但那件事真的重要。',
                    ),
                    acknowledgement: _copy(
                      language,
                      zhHans: '数量不多，不代表这一天没有价值。',
                      zhHant: '數量不多，不代表這一天沒有價值。',
                    ),
                    observation: _copy(
                      language,
                      zhHans: '清晰的优先级会带来更稳定的满足感。',
                      zhHant: '清晰的優先順序會帶來更穩定的滿足感。',
                    ),
                    tryNext: _copy(
                      language,
                      zhHans: '明天也先选一件值得完成的事。',
                      zhHant: '明天也先選一件值得完成的事。',
                    ),
                    scene: 'planning',
                    friction: 'self_pressure',
                    positiveSignal: 'meaningful_progress',
                    energyLoad: 'medium',
                  ),
                ];

  static const _englishSignalSamples = <_QaSignalSample>[
    _QaSignalSample(
      daysAgo: 0,
      focusDomainId: 'emotional_stability',
      energyLevel: 2,
      content:
          'I switched tasks three times this morning. The tiring part was having to refocus each time.',
      acknowledgement:
          'That back-and-forth can really wear you down. We can leave it here for now.',
      observation: 'Frequent task switching is affecting your energy today.',
      tryNext:
          'Before the next switch, take two minutes to wrap up and breathe.',
      scene: 'work',
      friction: 'context_switching',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 0,
      focusDomainId: 'food_sleep',
      energyLevel: 2,
      content:
          'I took a ten-minute walk after lunch and came back with a much clearer head.',
      acknowledgement: 'You have found a simple, practical way to reset.',
      observation:
          'A short screen break and a little movement help you recover in the afternoon.',
      tryNext:
          'Keep this ten-minute window. It does not need to be more complex.',
      scene: 'recovery',
      friction: 'fatigue',
      positiveSignal: 'short_walk_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 0,
      focusDomainId: 'emotional_stability',
      energyLevel: 2,
      content:
          'I left some space between meetings this afternoon and felt much less rushed.',
      acknowledgement: 'That small gap seems to have given you room to reset.',
      observation: 'With a buffer, meetings do not drain all your energy.',
      tryNext: 'Notice which kind of buffer is easiest to keep.',
      scene: 'work',
      friction: 'dense_schedule',
      positiveSignal: 'buffer_helped',
      energyLoad: 'medium',
    ),
    _QaSignalSample(
      daysAgo: 0,
      focusDomainId: 'emotional_stability',
      energyLevel: 2,
      content:
          'I did not go straight back to work this evening. Sitting quietly for a while helped me feel steadier.',
      acknowledgement: 'Pausing first can be a useful choice too.',
      observation: 'A short pause helped your mind and body settle together.',
      tryNext: 'Let this pause become the signal that your workday is over.',
      scene: 'emotional',
      friction: 'overextension',
      positiveSignal: 'pause_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 1,
      focusDomainId: 'emotional_stability',
      energyLevel: 1,
      content:
          'I was already tense before the meeting, and a last-minute topic made it harder to stay organized.',
      acknowledgement:
          'A sudden change on top of existing pressure can easily throw things off.',
      observation: 'Uncertainty increases the energy cost before meetings.',
      tryNext:
          'Before the meeting, write down the one thing you want to protect.',
      scene: 'work',
      friction: 'uncertainty',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 1,
      focusDomainId: 'emotional_stability',
      energyLevel: 1,
      content:
          'After turning off notifications, reading for half an hour felt easier than expected.',
      acknowledgement:
          'Once things were quiet, your attention was still there.',
      observation: 'Fewer alerts noticeably reduce attention switching.',
      tryNext: 'Keep one short window free from notifications.',
      scene: 'home',
      friction: 'notifications',
      positiveSignal: 'quiet_focus',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 2,
      focusDomainId: 'growth_plan',
      energyLevel: 2,
      content:
          'Once I broke the complex task into a first step, I stopped putting it off.',
      acknowledgement:
          'You were not lacking motivation. You needed a smaller way in.',
      observation: 'A clear first step reduces the friction of starting.',
      tryNext: 'For the next complex task, write down only the first step.',
      scene: 'work',
      friction: 'starting',
      positiveSignal: 'small_start',
      energyLoad: 'medium',
    ),
    _QaSignalSample(
      daysAgo: 3,
      focusDomainId: 'emotional_stability',
      energyLevel: 1,
      content:
          'I spent the whole day replying to messages and barely moved the important work forward.',
      acknowledgement:
          'Being busy all day without a sense of progress can be frustrating.',
      observation:
          'Fragmented replies are crowding out work that needs sustained attention.',
      tryNext: 'Block out forty minutes with no message replies.',
      scene: 'work',
      friction: 'interruptions',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 4,
      focusDomainId: 'food_sleep',
      energyLevel: 0,
      content:
          'After getting some afternoon sunlight, my fatigue stopped getting worse.',
      acknowledgement: 'Your body received a small signal to recover.',
      observation:
          'Natural light and a short walk can soften the afternoon slump.',
      tryNext: 'Take a short walk as soon as the fatigue begins.',
      scene: 'recovery',
      friction: 'fatigue',
      positiveSignal: 'sunlight_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 5,
      focusDomainId: 'growth_plan',
      energyLevel: 0,
      content:
          'After two meetings in a row, even simple decisions felt difficult.',
      acknowledgement:
          'This sounds more like depleted energy than losing your ability to decide.',
      observation:
          'Back-to-back meetings noticeably increase decision fatigue.',
      tryNext: 'Make important decisions before meetings or after a reset.',
      scene: 'work',
      friction: 'decision_fatigue',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 6,
      focusDomainId: 'emotional_stability',
      energyLevel: 2,
      content:
          'I did not fill the whole weekend, and that made me more willing to plan the week ahead.',
      acknowledgement:
          'Leaving space did not stop you. It helped your initiative return.',
      observation: 'Room to recover brings back a sense of direction.',
      tryNext: 'Leave one open block with no assigned purpose next week.',
      scene: 'planning',
      friction: 'overplanning',
      positiveSignal: 'space_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 7,
      focusDomainId: 'growth_plan',
      energyLevel: 0,
      content:
          'There were too many unexpected switches this afternoon, and I wanted to do nothing after getting home.',
      acknowledgement:
          'Feeling empty at home may be the aftereffect of switching too often during the day.',
      observation: 'Workday switching continues to affect evening recovery.',
      tryNext: 'Take five minutes before leaving work to close out loose ends.',
      scene: 'work',
      friction: 'context_switching',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 8,
      focusDomainId: 'food_sleep',
      energyLevel: 2,
      content:
          'I stretched for only a few minutes at lunch, and my shoulders felt less stiff in the afternoon.',
      acknowledgement:
          'A very small action has already made a visible difference.',
      observation:
          'Low-effort recovery actions are easier to follow through on.',
      tryNext: 'Keep it small for now. There is no need to add more yet.',
      scene: 'recovery',
      friction: 'body_tension',
      positiveSignal: 'stretch_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 9,
      focusDomainId: 'growth_plan',
      energyLevel: 2,
      content:
          'I handled the most important task first this morning, so later interruptions felt less stressful.',
      acknowledgement:
          'Once you had a sense of progress, later changes were easier to handle.',
      observation:
          'Finishing a core task first can reduce anxiety for the rest of the day.',
      tryNext: 'Protect one meaningful piece of progress tomorrow morning.',
      scene: 'work',
      friction: 'interruptions',
      positiveSignal: 'priority_helped',
      energyLoad: 'medium',
    ),
    _QaSignalSample(
      daysAgo: 10,
      focusDomainId: 'food_sleep',
      energyLevel: 0,
      content:
          'I was still handling messages late at night and could not wind down before bed.',
      acknowledgement:
          'Without a clear end to work, your body has a hard time switching into rest.',
      observation: 'Late-night messages delay recovery and sleep.',
      tryNext: 'Set a time for your final message check.',
      scene: 'sleep',
      friction: 'late_messages',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 11,
      focusDomainId: 'relationship_connection',
      energyLevel: 2,
      content:
          'After talking with a friend, the feelings I had been carrying loosened a little.',
      acknowledgement:
          'Feeling understood means you do not have to carry everything alone.',
      observation: 'A safe connection can support emotional recovery.',
      tryNext:
          'When you feel stuck again, reach out to someone you trust sooner.',
      scene: 'relationship',
      friction: 'emotional_load',
      positiveSignal: 'connection_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 12,
      focusDomainId: 'growth_plan',
      energyLevel: 0,
      content:
          'When I pack my schedule too tightly, even a small change makes me feel rushed.',
      acknowledgement:
          'The change is not necessarily too big. There may simply be no buffer left.',
      observation:
          'A lack of open space magnifies the stress of sudden changes.',
      tryNext: 'Leave at least one movable gap in each half of the day.',
      scene: 'planning',
      friction: 'dense_schedule',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 13,
      focusDomainId: 'meaning_value',
      energyLevel: 2,
      content:
          'I completed only one thing today, but it was something that truly mattered.',
      acknowledgement:
          'Doing fewer things does not mean the day had less value.',
      observation: 'Clear priorities create a steadier sense of satisfaction.',
      tryNext: 'Tomorrow, choose one thing worth finishing first.',
      scene: 'planning',
      friction: 'self_pressure',
      positiveSignal: 'meaningful_progress',
      energyLoad: 'medium',
    ),
  ];

  static const _japaneseSignalSamples = <_QaSignalSample>[
    _QaSignalSample(
      daysAgo: 0,
      focusDomainId: 'emotional_stability',
      energyLevel: 2,
      content: '午前中に3つのタスクを続けて切り替えた。いちばん疲れたのは、そのたびに集中し直すことだった。',
      acknowledgement: '行き来するような切り替えは確かに消耗します。まずはここに残しておきましょう。',
      observation: 'タスク切り替えの密度が、今日のエネルギーに影響している。',
      tryNext: '次に切り替える前に、締めくくりと呼吸のための2分をとる。',
      scene: 'work',
      friction: 'context_switching',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 0,
      focusDomainId: 'food_sleep',
      energyLevel: 2,
      content: '昼食後に10分歩いたら、戻ってから頭がずっとすっきりした。',
      acknowledgement: 'すでに、自分に合う具体的な回復の入り口を見つけています。',
      observation: '短時間画面から離れて歩くことが、午後の回復に役立っている。',
      tryNext: 'まずはこの10分の時間を保つ。複雑にする必要はない。',
      scene: 'recovery',
      friction: 'fatigue',
      positiveSignal: 'short_walk_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 0,
      focusDomainId: 'emotional_stability',
      energyLevel: 2,
      content: '午後の会議の間に少し余白を入れたら、そこまで急かされずに済んだ。',
      acknowledgement: 'その小さな余白が、きちんとあなたを支えています。',
      observation: '緩衝時間があれば、会議でエネルギーを使い切らずに済む。',
      tryNext: 'どんな余白ならいちばん続けやすいか、引き続き観察する。',
      scene: 'work',
      friction: 'dense_schedule',
      positiveSignal: 'buffer_helped',
      energyLoad: 'medium',
    ),
    _QaSignalSample(
      daysAgo: 0,
      focusDomainId: 'emotional_stability',
      energyLevel: 2,
      content: '夕方すぐに仕事を続けず、まず少し座っていたら、気持ちがずいぶん落ち着いた。',
      acknowledgement: 'まず立ち止まることも、効果のある選択の一つです。',
      observation: '短い停止が、気持ちと身体をもう一度そろえてくれた。',
      tryNext: 'この立ち止まる時間を、今日の終わりの合図にする。',
      scene: 'emotional',
      friction: 'overextension',
      positiveSignal: 'pause_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 1,
      focusDomainId: 'emotional_stability',
      energyLevel: 1,
      content: '会議前から少し緊張していて、急に議題が増えたらさらに混乱しやすくなった。',
      acknowledgement: 'もともとあったプレッシャーに急な変化が重なったので、混乱するのも無理はありません。',
      observation: '不確実さが、会議前のエネルギー消費を大きくしている。',
      tryNext: '会議前に、最低限守りたい1つだけを書き出す。',
      scene: 'work',
      friction: 'uncertainty',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 1,
      focusDomainId: 'emotional_stability',
      energyLevel: 1,
      content: '夜に通知を切ったら、思っていたより楽に30分読書できた。',
      acknowledgement: '静かになれば、あなたの集中力はちゃんと残っています。',
      observation: '通知を減らすと、注意の切り替えが明らかに減る。',
      tryNext: '通知に遮られない短い時間を保つ。',
      scene: 'home',
      friction: 'notifications',
      positiveSignal: 'quiet_focus',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 2,
      focusDomainId: 'growth_plan',
      energyLevel: 2,
      content: '複雑なタスクを最初の一歩に分けたら、ずっと後回しにせずに済んだ。',
      acknowledgement: 'やる気がないのではなく、もっと小さな入り口が必要だったのです。',
      observation: '最初の一歩を明確にすると、始める際の抵抗が小さくなる。',
      tryNext: '次の複雑なタスクでも、まず最初の一歩だけを書く。',
      scene: 'work',
      friction: 'starting',
      positiveSignal: 'small_start',
      energyLoad: 'medium',
    ),
    _QaSignalSample(
      daysAgo: 3,
      focusDomainId: 'emotional_stability',
      energyLevel: 1,
      content: '1日中メッセージの返信に追われて、本当に大切なことはほとんど進まなかった。',
      acknowledgement: '忙しく過ごしたのに進んだ実感がないと、確かにくじけます。',
      observation: '細かい返信が、まとまった注意を必要とする仕事を圧迫している。',
      tryNext: 'メッセージを返さない40分を1つ確保する。',
      scene: 'work',
      friction: 'interruptions',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 4,
      focusDomainId: 'food_sleep',
      energyLevel: 0,
      content: '午後に日光を浴びたら、疲れがそれ以上深くならなかった。',
      acknowledgement: '身体が少しだけ回復の合図を受け取ったようです。',
      observation: '自然光と短い歩行が、午後の落ち込みを和らげている。',
      tryNext: '疲れが出始めたら、すぐに少し歩く。',
      scene: 'recovery',
      friction: 'fatigue',
      positiveSignal: 'sunlight_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 5,
      focusDomainId: 'growth_plan',
      energyLevel: 0,
      content: '会議が2つ続いた後は、簡単な判断さえ重く感じた。',
      acknowledgement: '判断できなくなったのではなく、エネルギーが底をついた状態に近そうです。',
      observation: '会議が密集した後は、意思決定の負担が大きくなる。',
      tryNext: '重要な判断は、会議の前か回復した後に移す。',
      scene: 'work',
      friction: 'decision_fatigue',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 6,
      focusDomainId: 'emotional_stability',
      energyLevel: 2,
      content: '週末の予定を詰め込まなかったら、かえって自分から来週を整えたくなった。',
      acknowledgement: '余白はあなたを止めず、むしろ自主性を取り戻してくれました。',
      observation: '回復の余白があると、計画する感覚が戻ってくる。',
      tryNext: '来週も、用途を決めない空き時間を1つ残す。',
      scene: 'planning',
      friction: 'overplanning',
      positiveSignal: 'space_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 7,
      focusDomainId: 'growth_plan',
      energyLevel: 0,
      content: '午後に急な切り替えが多すぎて、帰宅後は何もする気になれなかった。',
      acknowledgement: '帰宅後の空っぽな感覚は、日中の切り替えが密集した後引きのようです。',
      observation: '仕事の切り替えは、夜の回復にも影響が続く。',
      tryNext: '退勤前に5分とり、未完了のことをいったん閉じる。',
      scene: 'work',
      friction: 'context_switching',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 8,
      focusDomainId: 'food_sleep',
      energyLevel: 2,
      content: '昼休みに数分ストレッチしただけで、午後は肩がそれほどこわばらなかった。',
      acknowledgement: 'ごく小さな行動でも、すでに見える変化が生まれています。',
      observation: '負担の小さい回復行動のほうが、実際に実行しやすい。',
      tryNext: '小さいまま続ける。急いで増やす必要はない。',
      scene: 'recovery',
      friction: 'body_tension',
      positiveSignal: 'stretch_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 9,
      focusDomainId: 'growth_plan',
      energyLevel: 2,
      content: '朝いちばん大切なことを先に終えたら、その後中断されてもそこまで不安にならなかった。',
      acknowledgement: '先に進んだ実感が持てると、その後の変化も受け止めやすくなります。',
      observation: '中心となるタスクを優先して終えると、1日の不安が小さくなる。',
      tryNext: '明日の朝も、まず大切な進捗を1つ守る。',
      scene: 'work',
      friction: 'interruptions',
      positiveSignal: 'priority_helped',
      energyLoad: 'medium',
    ),
    _QaSignalSample(
      daysAgo: 10,
      focusDomainId: 'food_sleep',
      energyLevel: 0,
      content: '夜遅くまでメッセージを処理していたら、寝る前になっても気持ちが止まらなかった。',
      acknowledgement: '仕事の終わりの合図がないと、身体も休息に切り替えにくくなります。',
      observation: '夜のメッセージ対応が、回復と入眠を遅らせている。',
      tryNext: 'メッセージを最後に確認する時刻を決める。',
      scene: 'sleep',
      friction: 'late_messages',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 11,
      focusDomainId: 'relationship_connection',
      energyLevel: 2,
      content: '友人と話し終えたら、つかえていた気持ちが少しほぐれた。',
      acknowledgement: '理解してもらえると、1人ですべてを背負う必要がなくなります。',
      observation: '安心できるつながりが、気持ちの回復を助けている。',
      tryNext: '次に行き詰まったら、信頼できる人に早めに一言伝える。',
      scene: 'relationship',
      friction: 'emotional_load',
      positiveSignal: 'connection_helped',
      energyLoad: 'low',
    ),
    _QaSignalSample(
      daysAgo: 12,
      focusDomainId: 'growth_plan',
      energyLevel: 0,
      content: '予定を詰め込みすぎると、どんな小さな変化でも焦ってしまう。',
      acknowledgement: '変化が大きすぎるのではなく、すでに余白が残っていないのです。',
      observation: '余白のなさが、急な変化のプレッシャーを大きくしている。',
      tryNext: '半日ごとに、動かせる小さな空き時間を少なくとも1つ残す。',
      scene: 'planning',
      friction: 'dense_schedule',
      energyLoad: 'high',
    ),
    _QaSignalSample(
      daysAgo: 13,
      focusDomainId: 'meaning_value',
      energyLevel: 2,
      content: '今日終えられたのは1つだけだったけれど、それは本当に大切なことだった。',
      acknowledgement: '数が少ないことは、その1日に価値がないということではありません。',
      observation: '優先順位が明確だと、より安定した満足感につながる。',
      tryNext: '明日も、終える価値のあることを1つ先に選ぶ。',
      scene: 'planning',
      friction: 'self_pressure',
      positiveSignal: 'meaningful_progress',
      energyLoad: 'medium',
    ),
  ];

  static String _normalizeSeedLanguage(String? language) {
    final requested = language?.trim();
    final normalized = RuntimeLocaleText.normalize(
      requested == null || requested.isEmpty
          ? RuntimeLocaleText.deviceLanguageCode()
          : requested,
    );
    return switch (normalized) {
      'en' => 'en',
      'ja' => 'ja',
      'zh-Hant' => 'zh-Hant',
      _ => 'zh-Hans',
    };
  }

  static String _copy(
    String language, {
    required String zhHans,
    required String zhHant,
    String? en,
    String? ja,
  }) {
    if (language == 'en') {
      if (en == null) {
        throw StateError('Missing English QA showcase copy.');
      }
      return en;
    }
    if (language == 'ja' && ja != null) return ja;
    return language == 'zh-Hant' ? zhHant : zhHans;
  }

  static String _energyState(int energyLevel) => switch (energyLevel) {
        0 => 'draining',
        2 => 'ease',
        _ => 'steady',
      };

  static String _dateKey(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class _QaSignalSample {
  final int daysAgo;
  final String focusDomainId;
  final int energyLevel;
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
    required this.focusDomainId,
    required this.energyLevel,
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
