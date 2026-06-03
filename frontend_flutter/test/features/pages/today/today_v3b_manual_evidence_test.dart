import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/i18n/app_locale_text.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_page.dart';
import 'package:ai_opportunity_radar/features/pages/today/today_view_model.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const evidenceDir = '/private/tmp/signalpath_v3b_evidence';

  setUpAll(() async {
    final dir = Directory(evidenceDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  });

  testWidgets('V3B evidence 01: online SignalCard remains in Today inbox',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_online_001',
          content: '正常联网新增：今天上午把一个小任务收完了。',
          acknowledgement: '保存的 AI 回复：这条已经作为 SignalCard 保存。',
          userConfirmation: 'unconfirmed',
        ),
        _legacySignal(),
      ],
    );

    await _pumpEvidencePage(tester, repo);
    await _writeEvidenceNote(
      '01_online_signalcard_legacy_timeline.txt',
      evidenceDir,
      'TodayPage renders the online SignalCard. Legacy records now live in the separate diary page.',
    );

    expect(find.textContaining('正常联网新增'), findsWidgets);
  });

  testWidgets('V3B evidence 02: backend unreachable local draft',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'draft_unreachable_001',
          content: '断网新增：这条必须先留在本机。',
          acknowledgement: '已先保存在本机，网络恢复后会同步。',
          isLocalDraft: true,
          syncFailed: true,
          migrationStatus: 'local_draft',
        ),
        _legacySignal(),
      ],
    );

    await _pumpEvidencePage(tester, repo);
    await _writeEvidenceNote(
      '02_backend_unreachable_local_draft.txt',
      evidenceDir,
      'TodayPage renders backend-unreachable local draft with retry status.',
    );

    expect(find.textContaining('断网新增'), findsWidgets);
    expect(find.text('Saved on device'), findsWidgets);
    expect(find.text('Sync needs retry'), findsWidgets);
  });

  testWidgets('V3B evidence 03: confirmation and correction written',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_confirm_001',
          content: '确认动作：这条要写入 edited correction。',
          acknowledgement: '旧 ai_reply：使用保存内容，不重新生成。',
          sourceType: 'ai_predicted',
          userConfirmation: 'unconfirmed',
        ),
        _legacySignal(),
      ],
    );

    await _pumpEvidencePage(tester, repo);

    await tester.scrollUntilVisible(
      find.text('Looks right').first,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Looks right').first);
    await _settleEvidenceFrame(tester);
    expect(repo.lastConfirmation, 'accurate');

    await tester.ensureVisible(find.text('Adjust').first);
    await tester.tap(find.text('Adjust').first);
    await _settleEvidenceFrame(tester);
    await tester.enterText(
        find.byType(TextField).last, 'edited correction 写入成功');
    await tester.tap(find.text('Save').last);
    await _settleEvidenceFrame(tester);

    await _writeEvidenceNote(
      '03_confirmation_edited_written.txt',
      evidenceDir,
      'TodayPage writes confirmation and edited correction through repository.',
    );

    expect(repo.lastConfirmation, 'edited');
    expect(repo.lastCorrection['edited_text'], 'edited correction 写入成功');
    expect(find.text('Adjusted'), findsWidgets);
    expect(find.textContaining('旧 ai_reply'), findsWidgets);
  });

  testWidgets('V3B-2B status chips and buttons stay low pressure',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_synced_edited_001',
          content: 'Synced edited: this should not look like a task.',
          acknowledgement: 'Saved AI reply stays below the raw text.',
          sourceType: 'ai_predicted',
          userConfirmation: 'edited',
        ),
        _todaySignal(
          signalCardId: 'draft_retry_001',
          content: 'Draft retry: original text must stay visible.',
          acknowledgement: '',
          sourceType: 'ai_predicted',
          isLocalDraft: true,
          syncFailed: true,
          migrationStatus: 'local_draft',
        ),
      ],
    );

    await _pumpEvidencePage(tester, repo);

    expect(find.text('Synced'), findsWidgets);
    expect(find.text('Adjusted'), findsWidgets);
    expect(find.text('Saved on device'), findsWidgets);
    expect(find.text('Sync needs retry'), findsWidgets);
    expect(find.text('Not checked yet'), findsWidgets);
    expect(find.text('Looks right'), findsWidgets);
    expect(find.text('Not quite'), findsWidgets);
    expect(find.text('Adjust'), findsWidgets);
    expect(find.text('Add context'), findsWidgets);
    expect(
        find.textContaining('AI has not organized this yet'), findsOneWidget);
  });

  testWidgets('V3B-2B Today status copy supports four languages',
      (tester) async {
    final cases = [
      (
        locale: const Locale('en'),
        saved: 'Saved on device',
        retry: 'Sync needs retry',
        imported: 'Imported',
        confirm: 'Looks right',
        adjust: 'Adjust',
      ),
      (
        locale: const Locale('ja'),
        saved: '端末に保存済み',
        retry: '同期は再試行待ち',
        imported: '移行済み',
        confirm: '合っていそう',
        adjust: '調整',
      ),
      (
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        saved: '已保存在本机',
        retry: '同步待重试',
        imported: '旧记录已导入',
        confirm: '是准的',
        adjust: '改一下',
      ),
      (
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
        saved: '已保存在本機',
        retry: '同步待重試',
        imported: '舊記錄已導入',
        confirm: '是準的',
        adjust: '改一下',
      ),
    ];

    for (final item in cases) {
      final repo = MutableTodayRepository(
        signals: [
          _todaySignal(
            signalCardId: 'draft_locale_${item.locale}',
            content: 'Locale draft text',
            acknowledgement: '',
            sourceType: 'ai_predicted',
            isLocalDraft: true,
            syncFailed: true,
            migrationStatus: 'local_draft',
          ),
          _legacySignal(),
        ],
      );

      await _pumpEvidencePage(tester, repo, locale: item.locale);

      expect(find.text(item.saved), findsWidgets);
      expect(find.text(item.retry), findsWidgets);
      expect(find.text(item.confirm), findsWidgets);
      expect(find.text(item.adjust), findsWidgets);

      expect(find.text(item.imported), findsNothing);
    }
  });

  testWidgets('raw text and voice records do not ask for accuracy confirmation',
      (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_raw_text_001',
          content: '天气不错',
          acknowledgement: 'AI 还没整理这条，但你的原文已经保存。',
        ),
        _todaySignal(
          signalCardId: 'sig_voice_001',
          content: '语音转写：今天散步之后轻了一点。',
          acknowledgement: '这条转写已经保存。',
          sourceType: 'voice',
        ),
      ],
    );

    await _pumpEvidencePage(
      tester,
      repo,
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
    );

    expect(find.text('天气不错'), findsWidgets);
    expect(find.text('语音转写：今天散步之后轻了一点。'), findsWidgets);
    expect(find.text('是准的'), findsNothing);
    expect(find.text('不太准'), findsNothing);
    expect(find.text('改一下'), findsNothing);
    expect(find.text('补一点'), findsNothing);
    expect(find.text('还没确认'), findsNothing);
    expect(find.text('已保存在本机'), findsNothing);
  });

  test('AI predicted signal seed follows app language', () async {
    final cases = [
      (
        language: AppLanguage.simplifiedChinese,
        expected: '也许今天有一个信号，和「天气不错」有关。',
      ),
      (
        language: AppLanguage.traditionalChinese,
        expected: '也許今天有一個信號，和「天气不错」有關。',
      ),
      (
        language: AppLanguage.japanese,
        expected: '今日は「天气不错」の周りにシグナルがあるかもしれません。',
      ),
      (
        language: AppLanguage.english,
        expected: 'Maybe today has a signal around 天气不错.',
      ),
    ];

    for (final item in cases) {
      final repo = MutableTodayRepository(
        signals: [
          _todaySignal(
            signalCardId: 'sig_seed_${item.language.name}',
            content: '天气不错',
            acknowledgement: '',
          ),
        ],
      );
      final vm = TodayViewModel(repo);
      await Future<void>.delayed(Duration.zero);

      await vm.createPredictedSignal(language: item.language);

      expect(repo.lastSubmittedContent, item.expected);
      expect(repo.lastSubmittedSourceType, 'ai_predicted');
    }
  });

  testWidgets('简体中文页面点击预判信号后不会显示英文种子', (tester) async {
    final repo = MutableTodayRepository(
      signals: [
        _todaySignal(
          signalCardId: 'sig_seed_ui',
          content: '不想上班',
          acknowledgement: '',
        ),
      ],
    );

    await _pumpEvidencePage(
      tester,
      repo,
      locale: const Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hans',
      ),
    );
    await tester.tap(find.text('预判一个信号'));
    await _settleEvidenceFrame(tester);

    expect(find.text('也许今天有一个信号，和「不想上班」有关。'), findsWidgets);
    expect(find.textContaining('Maybe today has a signal'), findsNothing);
  });
}

Future<void> _pumpEvidencePage(
  WidgetTester tester,
  MutableTodayRepository repo, {
  Locale locale = const Locale('en'),
}) async {
  final meVm = await buildMeViewModel();
  await tester.binding.setSurfaceSize(const Size(390, 1600));
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('v3b-evidence-root'),
      child: buildTestApp(
        child: const TodayPage(),
        providers: [
          ChangeNotifierProvider<TodayViewModel>(
            create: (_) => TodayViewModel(repo),
          ),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
        locale: locale,
      ),
    ),
  );
  await _settleEvidenceFrame(tester);
}

Future<void> _settleEvidenceFrame(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

Future<void> _writeEvidenceNote(
  String filename,
  String evidenceDir,
  String body,
) async {
  final file = File('$evidenceDir/$filename');
  file.writeAsStringSync(body);
}

RecentSignalModel _todaySignal({
  required String signalCardId,
  required String content,
  required String acknowledgement,
  String userConfirmation = 'unconfirmed',
  String sourceType = 'text',
  bool isLocalDraft = false,
  bool syncFailed = false,
  String migrationStatus = 'native',
}) {
  return RecentSignalModel(
    id: signalCardId.replaceFirst('sig_', 'raw_'),
    signalCardId: signalCardId,
    sourceType: sourceType,
    content: content,
    createdAt: DateTime.now(),
    localDate: _todayKey(),
    timezone: 'Asia/Tokyo',
    acknowledgement: acknowledgement,
    emotion: 'neutral',
    intensity: 'low',
    scene: 'daily_life',
    energyLoad: 'neutral',
    userConfirmation: userConfirmation,
    migrationStatus: migrationStatus,
    isLocalDraft: isLocalDraft,
    syncFailed: syncFailed,
  );
}

RecentSignalModel _legacySignal() {
  return RecentSignalModel(
    id: 'raw_legacy_001',
    signalCardId: 'sig_legacy_001',
    content: '旧记录：昨天晚上已经很累，但还是把事情收完了。',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    localDate: _yesterdayKey(),
    timezone: 'Asia/Tokyo',
    acknowledgement: '旧 AI 回复：这条里保存的是当时那种硬撑后的疲惫。',
    emotion: 'negative',
    intensity: 'medium',
    scene: 'work',
    friction: 'overload',
    energyLoad: 'draining',
    userConfirmation: 'unconfirmed',
    includedInSummary: true,
    includedInWeekly: true,
    isLegacy: true,
    migrationStatus: 'migrated',
  );
}

String _todayKey() => _dateKey(DateTime.now());

String _yesterdayKey() =>
    _dateKey(DateTime.now().subtract(const Duration(days: 1)));

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class MutableTodayRepository extends StubTodayRepository {
  List<RecentSignalModel> signals;
  String? lastConfirmation;
  String? lastSubmittedContent;
  String? lastSubmittedSourceType;
  Map<String, dynamic> lastCorrection = const {};

  MutableTodayRepository({required this.signals})
      : super(fetchTodayResult: const {});

  @override
  Future<Map<String, dynamic>> fetchToday() async {
    fetchTodayCallCount += 1;
    return {
      'insight': TodayInsightModel(text: 'Today Summary 使用 SignalCard 列表生成。'),
      'pendingQuestion': null,
      'bestAction': DailyBestActionModel(text: '今天先试试：只补一条真实发生的小事。'),
      'recentSignals': signals,
    };
  }

  @override
  Future<Map<String, dynamic>> submitCapture({
    required String content,
    String? tagHint,
    String sourceType = 'text',
    Map<String, dynamic> rawPayloadJson = const {},
  }) async {
    lastSubmittedContent = content;
    lastSubmittedSourceType = sourceType;
    final signal = _todaySignal(
      signalCardId: 'sig_submitted_${signals.length}',
      content: content,
      acknowledgement: '',
      sourceType: sourceType,
    );
    signals = [signal, ...signals];
    return {
      'acknowledgement': signal.acknowledgement,
      'followup': null,
      'updatedRecentSignals': signals,
      'localSignal': signal,
    };
  }

  @override
  Future<void> confirmSignalCard({
    required String signalCardId,
    required String userConfirmation,
    Map<String, dynamic> userCorrectionJson = const {},
  }) async {
    lastConfirmation = userConfirmation;
    lastCorrection = userCorrectionJson;
    signals = signals
        .map(
          (signal) => signal.signalCardId == signalCardId
              ? RecentSignalModel(
                  id: signal.id,
                  signalCardId: signal.signalCardId,
                  sourceType: signal.sourceType,
                  content: signal.content,
                  createdAt: signal.createdAt,
                  localDate: signal.localDate,
                  timezone: signal.timezone,
                  acknowledgement: signal.acknowledgement,
                  observation: signal.observation,
                  tryNext: signal.tryNext,
                  emotion: signal.emotion,
                  intensity: signal.intensity,
                  scene: signal.scene,
                  friction: signal.friction,
                  positiveSignal: signal.positiveSignal,
                  energyLoad: signal.energyLoad,
                  sceneTags: signal.sceneTags,
                  intentTags: signal.intentTags,
                  userConfirmation: userConfirmation,
                  userCorrectionJson: userCorrectionJson,
                  includedInSummary: signal.includedInSummary,
                  includedInWeekly: signal.includedInWeekly,
                  includedInJourney: signal.includedInJourney,
                  isLegacy: signal.isLegacy,
                  migrationStatus: signal.migrationStatus,
                  isLocalDraft: signal.isLocalDraft,
                  syncFailed: signal.syncFailed,
                )
              : signal,
        )
        .toList();
  }
}
