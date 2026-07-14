import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/repositories/signal_library_repository.dart';
import 'package:ai_opportunity_radar/core/eligibility/signal_eligibility_service.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_database.dart';

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

    expect(patterns, hasLength(greaterThanOrEqualTo(8)));
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

    expect(patterns, hasLength(greaterThanOrEqualTo(8)));
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

    expect(traditional, hasLength(greaterThanOrEqualTo(8)));
    expect(japanese, hasLength(greaterThanOrEqualTo(8)));
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

  test('unknown library language falls back to English curated patterns',
      () async {
    final repository = _buildRepository(dbPath);

    final patterns = await repository.listCuratedPatterns(language: 'fr');

    expect(patterns, isNotEmpty);
    expect(patterns.every((pattern) => pattern.language == 'en'), isTrue);
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
    expect(signal.rawPayloadJson['canonical_pattern_id'], pattern.id);
    expect(signal.rawPayloadJson['reference_type'], 'curated_signal_card');
    expect(signal.rawPayloadJson['generation_rule_version'],
        'signal_library_reference_v1');
    expect(signal.rawPayloadJson['match_status'], 'accurate');
    expect(signal.rawPayloadJson['added_to_timeline'], isTrue);
    expect(
        signal.rawPayloadJson.keys,
        unorderedEquals([
          'library_pattern_id',
          'title',
          'abstract_pattern',
          'common_scenes',
          'common_frictions',
          'energy_load_hint',
          'possible_positive_signal',
          'language',
          'canonical_pattern_id',
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

    final inaccurate = await repository.respondToPattern(
      pattern: pattern,
      status: 'inaccurate',
      addToTimeline: true,
    );
    expect(inaccurate, isNull);

    actions = await db.query(
      'signal_library_actions',
      where: 'pattern_id = ?',
      whereArgs: [pattern.id],
    );
    expect(actions, isEmpty);
    expect(
      await db.query(
        'signal_cards',
        where: 'source_type = ?',
        whereArgs: ['library_saved'],
      ),
      isEmpty,
    );
  });

  test('same pattern and day upserts instead of duplicating timeline cards',
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
    expect(cards.single['raw_text'], '改成我的情况后再写入。');
    expect(cards.single['user_confirmation'], 'partial');
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
