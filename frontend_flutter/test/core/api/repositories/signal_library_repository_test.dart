import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/repositories/signal_library_repository.dart';
import 'package:ai_opportunity_radar/core/eligibility/signal_eligibility_service.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';
import 'package:ai_opportunity_radar/core/models/signal_library_illustration_catalog.dart';
import 'package:ai_opportunity_radar/core/models/signal_library_models.dart';
import 'package:ai_opportunity_radar/core/preferences/focus_domains.dart';

void main() {
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    tempDir =
        await Directory.systemTemp.createTemp('signal_library_repo_test_');
    dbPath = p.join(tempDir.path, 'signal_library_test.db');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('curated library uses official abstract patterns only', () async {
    final repository = _buildRepository(dbPath);

    final patterns = await repository.listCuratedPatterns();

    expect(patterns, hasLength(18));
    expect(
        patterns.map((pattern) => pattern.id),
        containsAll([
          'over_scheduled_weeks',
          'recovery_debt',
          'attention_switching_fatigue',
          'unclear_expectation_relationship_friction',
          'late_night_compensation_behavior',
          'weak_positive_signals',
          'boundary_fatigue',
          'small_freedom_connection_creative_energy',
        ]));
    expect(patterns.every((pattern) => pattern.language == 'en'), isTrue);
  });

  test('Simplified Chinese library uses localized official patterns', () async {
    final repository = _buildRepository(dbPath);

    final patterns = await repository.listCuratedPatterns(language: 'zh-Hans');

    expect(patterns, hasLength(18));
    expect(patterns.every((pattern) => pattern.language == 'zh-Hans'), isTrue);
    expect(patterns.first.title, '安排过密的一周');
    expect(patterns.first.abstractPattern, contains('固定安排很多'));
    expect(patterns.first.abstractPattern, isNot(contains('Some people')));
    expect(
      patterns.map((pattern) => pattern.title),
      isNot(contains('Over-scheduled weeks')),
    );
  });

  test('Traditional Chinese and Japanese libraries use localized patterns',
      () async {
    final repository = _buildRepository(dbPath);

    final traditional =
        await repository.listCuratedPatterns(language: 'zh-Hant');
    final japanese = await repository.listCuratedPatterns(language: 'ja');

    expect(traditional, hasLength(18));
    expect(japanese, hasLength(18));
    expect(
      traditional.every((pattern) => pattern.language == 'zh-Hant'),
      isTrue,
    );
    expect(japanese.every((pattern) => pattern.language == 'ja'), isTrue);
    expect(traditional.first.title, '安排過密的一週');
    expect(japanese.first.title, '予定が詰まりすぎる週');
    expect(traditional.first.abstractPattern, isNot(contains('Some people')));
    expect(japanese.first.abstractPattern, isNot(contains('Some people')));
  });

  test('all curated cards use stable packaged behavior illustrations',
      () async {
    final repository = _buildRepository(dbPath);
    final illustrationKeyByCanonicalId = <String, String>{};

    for (final language in const ['en', 'zh-Hans', 'zh-Hant', 'ja']) {
      final patterns = await repository.listCuratedPatterns(language: language);

      for (final pattern in patterns) {
        final definition =
            SignalLibraryIllustrationCatalog.forPatternId(pattern.id);
        expect(definition, isNotNull, reason: '$language / ${pattern.id}');
        expect(
          definition!.id,
          startsWith('pattern.'),
          reason: 'Signal Library must not reuse review feedback artwork',
        );
        expect(
          File(p.join(Directory.current.path, definition.asset)).existsSync(),
          isTrue,
          reason: definition.asset,
        );

        final previous = illustrationKeyByCanonicalId[pattern.canonicalId];
        if (previous == null) {
          illustrationKeyByCanonicalId[pattern.canonicalId] = definition.id;
        } else {
          expect(
            definition.id,
            previous,
            reason: 'localized variants must share one illustration',
          );
        }
      }
    }

    expect(illustrationKeyByCanonicalId, hasLength(18));
    expect(
      SignalLibraryIllustrationCatalog.forPatternId(
        'tension_without_a_big_event',
      )?.asset,
      'assets/weekly/weekly-pattern-tension-without-big-event.png',
    );
    expect(
      SignalLibraryIllustrationCatalog.forPatternId(
        'being_heard_before_advice',
      )?.asset,
      'assets/weekly/weekly-pattern-being-heard-before-advice.png',
    );
    expect(
      SignalLibraryIllustrationCatalog.forPatternId(
        'contribution_seen_restores_motivation',
      )?.asset,
      'assets/weekly/weekly-pattern-contribution-seen-restores-motivation.png',
    );
  });

  test('unknown library language falls back to English curated patterns',
      () async {
    final repository = _buildRepository(dbPath);

    final patterns = await repository.listCuratedPatterns(language: 'fr');

    expect(patterns, isNotEmpty);
    expect(patterns.every((pattern) => pattern.language == 'en'), isTrue);
  });

  test('every locale has two or three cards for every explicit focus tag',
      () async {
    final repository = _buildRepository(dbPath);
    final domainIds = FocusDomains.options.map((option) => option.id).toSet();
    final catalogs = <String, List<LibraryPatternModel>>{};

    for (final language in const ['en', 'zh-Hans', 'zh-Hant', 'ja']) {
      final patterns = await repository.listCuratedPatterns(language: language);
      catalogs[language] = patterns;

      expect(patterns, hasLength(18), reason: language);
      expect(
        patterns.map((pattern) => pattern.focusDomainId).toSet(),
        domainIds,
        reason: language,
      );
      expect(
        patterns.map((pattern) => pattern.id).toSet(),
        hasLength(patterns.length),
        reason: '$language ids',
      );
      expect(
        patterns.map((pattern) => pattern.abstractPattern).toSet(),
        hasLength(patterns.length),
        reason: '$language content',
      );

      for (final domainId in domainIds) {
        final count = patterns
            .where((pattern) => pattern.focusDomainId == domainId)
            .length;
        expect(
          count,
          allOf(greaterThanOrEqualTo(2), lessThanOrEqualTo(3)),
          reason: '$language / $domainId',
        );
      }
    }

    final englishDomains = {
      for (final pattern in catalogs['en']!)
        _canonicalPatternId(pattern.id): pattern.focusDomainId,
    };
    expect(englishDomains, _expectedDomainByPattern);
    for (final language in const ['zh-Hans', 'zh-Hant', 'ja']) {
      final localizedDomains = {
        for (final pattern in catalogs[language]!)
          _canonicalPatternId(pattern.id): pattern.focusDomainId,
      };
      expect(localizedDomains, englishDomains, reason: language);
    }
  });

  test(
      'local draft fallback follows supported language and defaults to English',
      () async {
    final localDatabase = LocalDatabase(
      dbPathOverride: dbPath,
      databaseFactoryOverride: databaseFactoryFfi,
    );
    final captureRepository = LocalCaptureRepository(localDatabase);

    final zhHans = await captureRepository.insertLocalDraftSignal(
      content: '简体中文草稿',
      language: 'zh-Hans',
    );
    final zhHant = await captureRepository.insertLocalDraftSignal(
      content: '繁體中文草稿',
      language: 'zh-Hant',
    );
    final japanese = await captureRepository.insertLocalDraftSignal(
      content: '日本語の下書き',
      language: 'ja',
    );
    final fallback = await captureRepository.insertLocalDraftSignal(
      content: 'Brouillon',
      language: 'fr',
    );

    expect(zhHans.acknowledgement, contains('生活信号'));
    expect(zhHant.acknowledgement, contains('生活信號'));
    expect(japanese.acknowledgement, contains('生活シグナル'));
    expect(fallback.acknowledgement, startsWith('This is one small signal'));
  });

  test('library cards do not contain raw text, stories, or identifiers',
      () async {
    final repository = _buildRepository(dbPath);
    final patterns = await repository.listCuratedPatterns();

    final joined = patterns
        .map(
          (pattern) => [
            pattern.title,
            pattern.abstractPattern,
            ...pattern.commonScenes,
            ...pattern.commonFrictions,
          ].join(' '),
        )
        .join('\n')
        .toLowerCase();

    const bannedFragments = [
      'private raw text',
      'when i ',
      'i was ',
      'my boss',
      'my child',
      'my company',
      'tokyo',
      'google',
      'apple',
      'wife',
      'husband',
      'mother',
      'father',
      'yesterday at',
      'last friday',
      'you are this kind of person',
      'you have this problem',
    ];

    for (final fragment in bannedFragments) {
      expect(joined, isNot(contains(fragment)), reason: fragment);
    }
    expect(RegExp(r'\b\d{4}-\d{2}-\d{2}\b').hasMatch(joined), isFalse);
    expect(
      RegExp(r'\b(wife|husband|mother|father|son|daughter)\b').hasMatch(joined),
      isFalse,
    );
    expect(
      patterns.every((pattern) =>
          pattern.abstractPattern.startsWith('Some people ') ||
          pattern.abstractPattern.startsWith('Some people encounter ')),
      isTrue,
    );
  });

  test('accurate edited reference creates one private timeline SignalCard',
      () async {
    final localDatabase = LocalDatabase(
      dbPathOverride: dbPath,
      databaseFactoryOverride: databaseFactoryFfi,
    );
    final captureRepository = LocalCaptureRepository(localDatabase);
    await captureRepository.insertLocalDraftSignal(
      content: 'PRIVATE RAW TEXT SHOULD NOT LEAK',
    );

    final repository = SignalLibraryRepository(localDatabase);
    final pattern = (await repository.listCuratedPatterns()).first;

    final signal = await repository.respondToPattern(
      pattern: pattern,
      status: 'accurate',
      userText: 'I need more room between fixed plans.',
      addToTimeline: true,
    );

    expect(signal, isNotNull);
    expect(signal!.sourceType, 'library_saved');
    expect(signal.privacyLevel, 'private');
    expect(signal.userConfirmation, 'accurate');
    expect(signal.isLocalDraft, isFalse);
    expect(signal.syncFailed, isFalse);
    expect(signal.content, 'I need more room between fixed plans.');
    expect(signal.acknowledgement, isNull);
    expect(signal.observation, isNull);
    expect(signal.tryNext, isNull);
    expect(signal.scene, pattern.commonScenes.first);
    expect(signal.friction, pattern.commonFrictions.first);
    expect(signal.energyLoad, pattern.energyLoadHint);
    expect(signal.positiveSignal, pattern.possiblePositiveSignal);
    expect(signal.rawPayloadJson['library_pattern_id'], pattern.id);
    expect(signal.rawPayloadJson['focus_domain_id'], pattern.focusDomainId);
    expect(signal.rawPayloadJson['canonical_pattern_id'], pattern.id);
    expect(
      signal.rawPayloadJson['illustration_key'],
      SignalLibraryIllustrationCatalog.keyForPatternId(pattern.id),
    );
    expect(
      signal.rawPayloadJson['illustration_catalog_version'],
      SignalLibraryIllustrationCatalog.version,
    );
    expect(signal.rawPayloadJson['reference_type'], 'curated_signal_card');
    expect(signal.rawPayloadJson['generation_rule_version'],
        'signal_library_reference_v1');
    expect(signal.rawPayloadJson['match_status'], 'accurate');
    expect(signal.rawPayloadJson['added_to_timeline'], isTrue);
    expect(
        signal.rawPayloadJson.keys,
        unorderedEquals([
          'library_pattern_id',
          'canonical_pattern_id',
          'focus_domain_id',
          'illustration_key',
          'illustration_catalog_version',
          'title',
          'abstract_pattern',
          'common_scenes',
          'common_frictions',
          'energy_load_hint',
          'possible_positive_signal',
          'language',
          'reference_type',
          'generation_rule_version',
          'match_status',
          'added_to_timeline',
          'user_adjustment_text',
        ]));
    expect(
      const SignalEligibilityService().isEligible(
        signal,
        SignalEligibilityStage.weekly,
      ),
      isTrue,
    );

    final db = await localDatabase.database;
    final rows = await db.query(
      'signal_cards',
      where: 'id = ?',
      whereArgs: [signal.signalCardId],
    );
    expect(rows, hasLength(1));
    expect(rows.single['source_type'], 'library_saved');
    expect(rows.single['privacy_level'], 'private');
    expect(rows.single['user_confirmation'], 'accurate');
    expect(rows.single['raw_payload_json'].toString(),
        contains('"library_pattern_id":"${pattern.id}"'));
    expect(rows.single['raw_text'], 'I need more room between fixed plans.');
    expect(rows.single['observation'], isNull);
    expect(rows.single['try_next'], isNull);
    expect(
      rows.single['raw_payload_json'].toString(),
      isNot(contains('PRIVATE RAW TEXT SHOULD NOT LEAK')),
    );
    expect(rows.single['included_in_summary'], 0);
    expect(rows.single['included_in_weekly'], 0);
    expect(rows.single['included_in_journey'], 0);
  });

  test('not-added and inaccurate references are zero-write actions', () async {
    final localDatabase = LocalDatabase(
      dbPathOverride: dbPath,
      databaseFactoryOverride: databaseFactoryFfi,
    );
    final repository = SignalLibraryRepository(localDatabase);
    final pattern = (await repository.listCuratedPatterns()).first;

    final partial = await repository.respondToPattern(
      pattern: pattern,
      status: 'partial',
      userText: 'Only the missing buffer feels familiar.',
      addToTimeline: false,
    );
    expect(partial, isNull);

    final db = await localDatabase.database;
    expect(
      await db.query(
        'signal_cards',
        where: 'source_type = ?',
        whereArgs: ['library_saved'],
      ),
      isEmpty,
    );
    var actions = await db.query(
      'signal_library_actions',
      where: 'pattern_id = ?',
      whereArgs: [pattern.id],
    );
    expect(actions, isEmpty);

    for (var attempt = 1; attempt <= 4; attempt += 1) {
      final inaccurate = await repository.respondToPattern(
        pattern: pattern,
        status: 'inaccurate',
        addToTimeline: true,
      );
      expect(inaccurate, isNull, reason: 'attempt $attempt');

      actions = await db.query(
        'signal_library_actions',
        where: 'pattern_id = ?',
        whereArgs: [pattern.id],
      );
      expect(actions, isEmpty, reason: 'attempt $attempt');
      expect(
        await db.query(
          'signal_cards',
          where: 'source_type = ?',
          whereArgs: ['library_saved'],
        ),
        isEmpty,
        reason: 'attempt $attempt',
      );
    }
  });

  test('same pattern and day replays the immutable card without duplicating',
      () async {
    final localDatabase = LocalDatabase(
      dbPathOverride: dbPath,
      databaseFactoryOverride: databaseFactoryFfi,
    );
    final repository = SignalLibraryRepository(localDatabase);
    final pattern = (await repository.listCuratedPatterns()).first;
    final localizedPattern =
        (await repository.listCuratedPatterns(language: 'zh-Hans')).first;

    await repository.respondToPattern(
      pattern: pattern,
      status: 'accurate',
      addToTimeline: true,
    );
    await repository.respondToPattern(
      pattern: localizedPattern,
      status: 'partial',
      userText: '改成我的情况后再写入。',
      addToTimeline: true,
    );

    final db = await localDatabase.database;
    final cards = await db.query(
      'signal_cards',
      where: 'source_type = ?',
      whereArgs: ['library_saved'],
    );
    final actions = await db.query(
      'signal_library_actions',
      where: 'pattern_id = ?',
      whereArgs: [pattern.id],
    );
    expect(cards, hasLength(1));
    expect(cards.single['raw_text'], pattern.abstractPattern);
    expect(cards.single['user_confirmation'], 'accurate');
    expect(actions, isEmpty);
  });
}

SignalLibraryRepository _buildRepository(String dbPath) {
  return SignalLibraryRepository(
    LocalDatabase(
      dbPathOverride: dbPath,
      databaseFactoryOverride: databaseFactoryFfi,
    ),
  );
}

String _canonicalPatternId(String id) {
  return id.replaceFirst(RegExp(r'_(zh_hans|zh_hant|ja)$'), '');
}

const Map<String, String> _expectedDomainByPattern = {
  'over_scheduled_weeks': 'growth_plan',
  'recovery_debt': 'food_sleep',
  'attention_switching_fatigue': 'growth_plan',
  'unclear_expectation_relationship_friction': 'relationship_connection',
  'late_night_compensation_behavior': 'food_sleep',
  'weak_positive_signals': 'emotional_stability',
  'boundary_fatigue': 'self_boundary',
  'small_freedom_connection_creative_energy': 'creative_expression',
  'tension_without_a_big_event': 'emotional_stability',
  'being_heard_before_advice': 'relationship_connection',
  'busy_without_a_clear_why': 'meaning_value',
  'contribution_seen_restores_motivation': 'meaning_value',
  'agreeing_before_checking_capacity': 'self_boundary',
  'input_without_expression': 'creative_expression',
  'clutter_keeps_attention_open': 'living_environment',
  'unclear_spending_background_stress': 'living_environment',
  'enjoyment_always_comes_last': 'interests_hobbies',
  'vitality_after_movement_or_nature': 'interests_hobbies',
};
