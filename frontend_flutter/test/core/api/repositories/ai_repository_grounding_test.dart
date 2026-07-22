import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';
import 'package:ai_opportunity_radar/core/models/today_models.dart';
import 'package:ai_opportunity_radar/core/models/weekly_models.dart';

void main() {
  test('capture reply fallback stays grounded in specific user text', () async {
    final repository = AiRepository(_FailingApiClient());
    final examples = <String, List<String>>{
      'token好贵': ['token', '成本', '贵'],
      '每周只有骑马是值得期待的': ['骑马', '期待', '恢复'],
      '我们永远无法预测明天会发生什么，但可以好好活在当下': ['明天', '当下'],
      '好想早日退休': ['退休', '工作', '离开'],
      '明天可以去骑马好开心': ['骑马', '开心', '期待'],
    };

    for (final entry in examples.entries) {
      final result = await repository.generateCaptureReply(
        content: entry.key,
        recentAssistantTexts: const [],
      );
      final combined = [
        result.acknowledgement,
        result.observation,
        result.tryNext,
      ].join();

      expect(
        entry.value.any(combined.contains),
        true,
        reason: 'Reply should reference "${entry.key}" but was: $combined',
      );
      expect(combined, isNot(contains('这种小瞬间其实也很有信息量')));
      expect(combined, isNot(contains('先不用急着解释清楚')));
    }
  });

  test(
      'offline timeline acknowledgement supports app languages without causal attribution',
      () async {
    final repository = AiRepository(_FailingApiClient());
    final cases = <({
      String content,
      String required,
      List<String> forbidden,
    })>[
      (
        content: '好想早日退休',
        required: '退休',
        forbidden: ['工作消耗', '逃离感', '背后', '根因'],
      ),
      (
        content: '好想早點退休',
        required: '退休',
        forbidden: ['工作消耗', '逃離感', '背後', '根因'],
      ),
      (
        content: '今日は少し休みたい',
        required: '休み',
        forbidden: ['身体と心', 'サイン', '原因'],
      ),
      (
        content: 'Money is tight this month',
        required: 'money',
        forbidden: ['value', 'safety', 'worth it', 'root cause'],
      ),
    ];

    for (final testCase in cases) {
      final result = await repository.generateCaptureReply(
        content: testCase.content,
        recentAssistantTexts: const [],
      );
      final acknowledgement = result.acknowledgement.toLowerCase();
      expect(acknowledgement, contains(testCase.required.toLowerCase()));
      for (final forbidden in testCase.forbidden) {
        expect(acknowledgement, isNot(contains(forbidden.toLowerCase())));
      }
      expect(acknowledgement, isNot(contains('?')));
      expect(acknowledgement, isNot(contains('？')));
    }
  });

  test('offline safety acknowledgement remains an explicit exception',
      () async {
    final repository = AiRepository(_FailingApiClient());
    final result = await repository.generateCaptureReply(
      content: '我现在想自杀',
      recentAssistantTexts: const [],
    );

    expect(result.acknowledgement, contains('紧急服务'));
    expect(result.acknowledgement, contains('可信任的人'));
  });

  test('light dialog sends language and keeps current turn out of history',
      () async {
    final client = _RecordingApiClient();
    final repository = AiRepository(client);

    final result = await repository.generateLightDialog(
      signal: RecentSignalModel(
        content: '会議の切り替えが多くて疲れた',
        acknowledgement: '何度も切り替えるのは消耗しますね。',
      ),
      history: const [
        LightDialogTurnModel(role: 'assistant', text: '何度も切り替えるのは消耗しますね。'),
      ],
      userMessage: 'どうしたらいい？',
      language: 'ja',
    );

    expect(result.reply, '受け取りました。');
    expect(client.lastPath, '/api/v1/ai/light-dialog');
    expect(client.lastBody?['language'], 'ja');
    expect(client.lastBody?['user_message'], 'どうしたらいい？');
    expect(client.lastBody?['history'], hasLength(1));
  });

  test('offline light dialog gives one localized reply without prompt options',
      () async {
    final repository = AiRepository(_FailingApiClient());
    final signal = RecentSignalModel(content: '上午连续切了三个任务，很累');

    final zhHans = await repository.generateLightDialog(
      signal: signal,
      history: const [],
      userMessage: '我该怎么做',
      language: 'zh-Hans',
    );
    final english = await repository.generateLightDialog(
      signal: signal,
      history: const [],
      userMessage: 'What should I do?',
      language: 'en',
    );
    final zhHant = await repository.generateLightDialog(
      signal: signal,
      history: const [],
      userMessage: '我該做什麼',
      language: 'zh-Hant',
    );
    final japanese = await repository.generateLightDialog(
      signal: signal,
      history: const [],
      userMessage: '何をすればいい？',
      language: 'ja',
    );
    final alternateEnglish = await repository.generateLightDialog(
      signal: signal,
      history: const [],
      userMessage: 'What do I do?',
      language: 'en',
    );

    expect(zhHans.reply, contains('负担最小'));
    expect(zhHans.reply, isNot(contains('当时最让你停住')));
    expect(zhHans.suggestedPrompts, isEmpty);
    expect(english.reply, contains('low-effort'));
    expect(english.suggestedPrompts, isEmpty);
    expect(zhHant.reply, contains('負擔最小'));
    expect(japanese.reply, contains('負担が少なく'));
    expect(alternateEnglish.reply, contains('low-effort'));
  });

  test('deep weekly sends attempt aggregates and parses chart-ready fields',
      () async {
    final client = _RecordingApiClient();
    final repository = AiRepository(client);
    final result = await repository.generateWeeklyReflect(
      weekly: WeeklyInsightModel(
        weekStart: '2026-07-13',
        weekEnd: '2026-07-19',
        status: 'ready',
        keyInsight: '本周反复出现安排打断。',
        patterns: const [
          {
            'name': '任务堆积',
            'illustration_hint': '任务堆积，开始变困难',
          },
        ],
        frictions: const [
          {'name': '安排打断'},
        ],
        bestAction: '下周只观察一次打断发生的位置。',
        opportunitySnapshot: const {
          '_weekly_signal_entries': [
            {'id': 'signal-1', 'local_date': '2026-07-15'},
            {'id': 'signal-2', 'local_date': '2026-07-17'},
          ],
          '_feedback_event_summary': {
            'total_count': 2,
            'events': [
              {
                'subject_id': 'attempt-1',
                'subject_type': 'micro_action',
                'local_date': '2026-07-15',
                'status': 'completed',
              },
              {
                'subject_id': 'attempt-1',
                'subject_type': 'micro_action',
                'local_date': '2026-07-16',
                'status': 'not_completed',
              },
            ],
          },
          '_weekly_action_review': {
            'tried_action_count': 1,
            'next_adjustment': '下次把尝试缩短到五分钟',
          },
        },
        feedbackSubmitted: false,
        chartData: const [
          WeeklyChartPointModel(
            date: '2026-07-15',
            signalCount: 1,
            moodScore: -0.2,
            frictionScore: 0.6,
            hasPositiveSignal: false,
          ),
        ],
      ),
    );

    expect(client.lastPath, '/api/v1/ai/reflect-weekly');
    expect(client.lastBody?['attempt_count'], 1);
    expect(client.lastBody?['recorded_attempt_day_count'], 2);
    expect(client.lastBody?['completed_attempt_day_count'], 1);
    expect(client.lastBody?['signal_attempt_overlap_day_count'], 1);
    expect(
      client.lastBody?['dominant_feedback_pattern'],
      '下次把尝试缩短到五分钟',
    );
    expect(
        client.lastBody?['source_signal_card_ids'], ['signal-1', 'signal-2']);
    expect(result.patternLabel, '任务堆积');
    expect(result.relationshipSummary, contains('共同出现'));
    expect(result.timingSummary, contains('周三'));
    expect(result.nextQuestion, contains('哪个阶段'));
    expect(result.illustrationHint, '任务堆积，开始变困难');
    expect(result.sourceSignalCardIds, ['signal-1', 'signal-2']);
    expect(result.scopeNote, contains('不代表因果'));
  });
}

class _FailingApiClient extends ApiClient {
  _FailingApiClient() : super(baseUrl: 'http://127.0.0.1:1', userId: 'test');

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    throw Exception('offline');
  }
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(baseUrl: 'http://127.0.0.1:1', userId: 'test');

  String? lastPath;
  Map<String, dynamic>? lastBody;

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    lastPath = path;
    lastBody = body;
    if (path == '/api/v1/ai/reflect-weekly') {
      return {
        'data': {
          'summary': '本周关系已经形成。',
          'root_tension': '想推进时也会被安排拉走。',
          'hidden_pattern': '周三更密集。',
          'next_focus': '下周只验证一次。',
          'risk_note': '不代表长期结论。',
          'key_nodes': ['任务堆积', '安排打断'],
          'pattern_label': '任务堆积',
          'friction_label': '安排打断',
          'impact_label': '已有 1 个完成日',
          'relationship_summary': '任务堆积与安排打断在本周共同出现。',
          'timing_summary': '周三的 Signal 更密。',
          'next_question': '安排发生在任务的哪个阶段？',
          'illustration_hint': '任务堆积，开始变困难',
          'source_signal_card_ids': ['signal-1', 'signal-2'],
          'scope_note': '只说明本周关系，不代表因果。',
        },
      };
    }
    return {
      'data': {
        'reply': '受け取りました。',
        'suggested_prompts': <String>[],
      },
    };
  }
}
