import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ai_opportunity_radar/core/api/repositories/signal_library_repository.dart';
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

    expect(zhHans.acknowledgement, contains('已先保存在本机'));
    expect(zhHant.acknowledgement, contains('已先保存在本機'));
    expect(japanese.acknowledgement, contains('端末に保存'));
    expect(fallback.acknowledgement, startsWith('Saved on this device'));
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
            pattern.gentleReflection,
            pattern.suggestedSmallExperiment,
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

  test('save to my observation creates private library_saved SignalCard',
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

    final signal = await repository.saveToMyObservation(pattern: pattern);

    expect(signal.sourceType, 'library_saved');
    expect(signal.privacyLevel, 'private');
    expect(signal.userConfirmation, 'unconfirmed');
    expect(signal.isLocalDraft, isFalse);
    expect(signal.syncFailed, isFalse);
    expect(signal.rawPayloadJson['library_pattern_id'], pattern.id);
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
          'gentle_reflection',
          'suggested_small_experiment',
          'language',
        ]));
    expect(signal.content, isEmpty);

    final db = await localDatabase.database;
    final rows = await db.query(
      'signal_cards',
      where: 'id = ?',
      whereArgs: [signal.signalCardId],
    );
    expect(rows, hasLength(1));
    expect(rows.single['source_type'], 'library_saved');
    expect(rows.single['privacy_level'], 'private');
    expect(rows.single['user_confirmation'], 'unconfirmed');
    expect(rows.single['raw_payload_json'].toString(),
        contains('"library_pattern_id":"${pattern.id}"'));
    expect(
      rows.single['raw_text'].toString(),
      isEmpty,
    );
    expect(
      rows.single['raw_payload_json'].toString(),
      isNot(contains('PRIVATE RAW TEXT SHOULD NOT LEAK')),
    );
    expect(rows.single['included_in_summary'], 0);
    expect(rows.single['included_in_weekly'], 0);
    expect(rows.single['included_in_journey'], 0);
  });

  test('save to my observation localizes saved AI reply for Chinese patterns',
      () async {
    final localDatabase = LocalDatabase(
      dbPathOverride: dbPath,
      databaseFactoryOverride: databaseFactoryFfi,
    );
    final repository = SignalLibraryRepository(localDatabase);
    final pattern =
        (await repository.listCuratedPatterns(language: 'zh-Hans')).first;

    final signal = await repository.saveToMyObservation(pattern: pattern);

    expect(signal.acknowledgement, contains('已私密放进你的观察里'));
    expect(signal.acknowledgement, isNot(contains('Saved privately')));
  });

  test('library actions are stored locally as private interactions only',
      () async {
    final localDatabase = LocalDatabase(
      dbPathOverride: dbPath,
      databaseFactoryOverride: databaseFactoryFfi,
    );
    final repository = SignalLibraryRepository(localDatabase);
    final pattern = (await repository.listCuratedPatterns()).first;

    await repository.recordPrivateAction(
      patternId: pattern.id,
      action: 'i_also_have_this',
    );
    await repository.recordPrivateAction(
      patternId: pattern.id,
      action: 'not_for_me',
    );
    await repository.saveToMyObservation(pattern: pattern);

    final db = await localDatabase.database;
    final rows = await db.query(
      'signal_library_actions',
      where: 'pattern_id = ?',
      whereArgs: [pattern.id],
    );

    expect(rows, hasLength(3));
    expect(rows.every((row) => row['is_private'] == 1), isTrue);
    expect(rows.map((row) => row['action']), contains('i_also_have_this'));
    expect(rows.map((row) => row['action']), contains('not_for_me'));
    expect(
      rows.map((row) => row['action']),
      contains('save_to_my_observation'),
    );

    final publicTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND lower(name) LIKE '%public%'",
    );
    expect(publicTables, isEmpty);

    final savedCards = await db.query(
      'signal_cards',
      where: 'source_type = ?',
      whereArgs: ['library_saved'],
    );
    expect(savedCards, hasLength(1));
    expect(savedCards.single['privacy_level'], 'private');
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
