import 'dart:ui' as ui;

import '../../models/memory_models.dart';
import '../../models/monthly_models.dart';
import '../../models/today_models.dart';
import '../../models/weekly_illustration_taxonomy.dart';
import '../../models/weekly_models.dart';
import '../../../shared/utils/l1_attunement_fallback.dart';
import '../api_client.dart';

class AiRepository {
  final ApiClient apiClient;
  final String Function() languageLoader;

  AiRepository(
    this.apiClient, {
    String Function()? languageLoader,
  }) : languageLoader = languageLoader ?? _deviceLanguageCode;

  static String _deviceLanguageCode() {
    final locale = ui.PlatformDispatcher.instance.locale;
    final languageCode = locale.languageCode.toLowerCase();
    final scriptCode = locale.scriptCode?.toLowerCase();
    final countryCode = locale.countryCode?.toUpperCase();
    if (languageCode == 'ja') return 'ja';
    if (languageCode == 'zh') {
      final isTraditional = scriptCode == 'hant' ||
          countryCode == 'TW' ||
          countryCode == 'HK' ||
          countryCode == 'MO';
      return isTraditional ? 'zh-Hant' : 'zh-Hans';
    }
    return 'en';
  }

  Future<AiCaptureReplyResult> generateCaptureReply({
    required String content,
    required List<String> recentAssistantTexts,
    String? language,
    String? focusArea,
    String? responseStyle,
  }) async {
    final style = _normalizeResponseStyle(responseStyle);
    final displayLanguage = _fallbackLanguage(
      content,
      requested: language,
    );

    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/capture-reply',
        {
          'content': content,
          'recent_assistant_texts': recentAssistantTexts,
          'language': language,
          'focus_area': focusArea,
          'response_style': style,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;

      return AiCaptureReplyResult(
        acknowledgement: (data['acknowledgement'] as String?) ??
            _styleText(
              _fallbackAcknowledgement(
                content,
                language: displayLanguage,
              ),
              style,
            ),
        observation: (data['observation'] as String?) ??
            _styleText(
              _fallbackSingleObservation(
                content,
                language: displayLanguage,
              ),
              style,
            ),
        tryNext: (data['try_next'] as String?) ??
            _styleText(
              _fallbackSingleTryNext(
                content,
                language: displayLanguage,
              ),
              style,
            ),
        emotion: (data['emotion'] as String?) ?? _fallbackEmotion(content),
        intensity:
            (data['intensity'] as String?) ?? _fallbackIntensity(content),
        sceneTags: _parseStringList(data['scene_tags']),
        intentTags: _parseStringList(data['intent_tags']),
        followup: data['followup'] == null
            ? null
            : FollowupQuestionModel.fromJson(
                data['followup'] as Map<String, dynamic>,
              ),
      );
    } catch (_) {
      return AiCaptureReplyResult(
        acknowledgement: _styleText(
          _fallbackAcknowledgement(
            content,
            language: displayLanguage,
          ),
          style,
        ),
        observation: _styleText(
          _fallbackSingleObservation(
            content,
            language: displayLanguage,
          ),
          style,
        ),
        tryNext: _styleText(
          _fallbackSingleTryNext(
            content,
            language: displayLanguage,
          ),
          style,
        ),
        emotion: _fallbackEmotion(content),
        intensity: _fallbackIntensity(content),
        sceneTags: _fallbackSceneTags(content),
        intentTags: _fallbackIntentTags(content),
        followup: null,
      );
    }
  }

  Future<AiTodaySummaryResult> generateTodaySummary({
    required DateTime date,
    required List<RecentSignalModel> entries,
    String? focusArea,
    String? responseStyle,
  }) async {
    final style = _normalizeResponseStyle(responseStyle);
    final displayLanguage = _normalizeLanguage(languageLoader());

    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/today-summary',
        {
          'date': _dateKey(date),
          'entry_count': entries.length,
          'entries': entries
              .map(
                (e) => {
                  'id': e.id,
                  'content': e.content,
                  'created_at': e.createdAt?.toUtc().toIso8601String(),
                  'acknowledgement': e.acknowledgement,
                  'observation': e.observation,
                  'try_next': e.tryNext,
                  'emotion': e.emotion,
                  'intensity': e.intensity,
                  'scene_tags': e.sceneTags,
                  'intent_tags': e.intentTags,
                },
              )
              .toList(),
          'focus_area': focusArea,
          'response_style': style,
          'language': displayLanguage,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;

      return AiTodaySummaryResult(
        observation: (data['observation'] as String?) ??
            _styleText(
              _fallbackObservation(entries, displayLanguage),
              style,
            ),
        suggestion: (data['suggestion'] as String?) ??
            _styleText(
              _fallbackSuggestion(entries, displayLanguage),
              style,
            ),
      );
    } catch (_) {
      return AiTodaySummaryResult(
        observation:
            _styleText(_fallbackObservation(entries, displayLanguage), style),
        suggestion:
            _styleText(_fallbackSuggestion(entries, displayLanguage), style),
      );
    }
  }

  Future<WeeklyInsightModel> generateWeeklySummary({
    required String weekStart,
    required String weekEnd,
    required List<Map<String, dynamic>> entries,
    required Map<String, int> dayCounts,
    required List<String> topTokens,
    String? focusArea,
  }) async {
    final displayLanguage = _normalizeLanguage(languageLoader());
    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/weekly-generate',
        {
          'week_start': weekStart,
          'week_end': weekEnd,
          'entry_count': entries.length,
          'entries': entries,
          'day_counts': dayCounts,
          'top_tokens': topTokens,
          'focus_area': focusArea,
          'language': displayLanguage,
          'illustration_taxonomy':
              WeeklyIllustrationTaxonomy.weeklyGeneratePayload,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      return WeeklyInsightModel.fromJson(data);
    } catch (_) {
      return _fallbackWeeklyInsight(
        weekStart: weekStart,
        weekEnd: weekEnd,
        entries: entries,
        dayCounts: dayCounts,
        topTokens: topTokens,
        language: displayLanguage,
      );
    }
  }

  Future<MemorySummaryModel> generateJourneySummary({
    required String snapshotDate,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
    String? focusArea,
  }) async {
    final displayLanguage = _normalizeLanguage(languageLoader());
    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/journey-generate',
        {
          'snapshot_date': snapshotDate,
          'entry_count': entries.length,
          'entries': entries,
          'top_tokens': topTokens,
          'total_days': totalDays,
          'focus_area': focusArea,
          'language': displayLanguage,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      return MemorySummaryModel.fromJson(data);
    } catch (_) {
      return _fallbackJourneySummary(
        entries: entries,
        topTokens: topTokens,
        totalDays: totalDays,
        language: displayLanguage,
      );
    }
  }

  Future<MonthlyReviewModel> generateMonthlyReview({
    required String monthStart,
    required String monthEnd,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
    String? focusArea,
  }) async {
    final displayLanguage = _normalizeLanguage(languageLoader());
    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/monthly-generate',
        {
          'month_start': monthStart,
          'month_end': monthEnd,
          'entry_count': entries.length,
          'entries': entries,
          'top_tokens': topTokens,
          'total_days': totalDays,
          'focus_area': focusArea,
          'language': displayLanguage,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      return MonthlyReviewModel.fromJson(data);
    } catch (_) {
      return _fallbackMonthlyReview(
        monthStart: monthStart,
        monthEnd: monthEnd,
        entries: entries,
        topTokens: topTokens,
        totalDays: totalDays,
        language: displayLanguage,
      );
    }
  }

  Future<LightDialogResponseModel> generateLightDialog({
    required RecentSignalModel signal,
    required List<LightDialogTurnModel> history,
    required String userMessage,
    required String language,
    String? focusArea,
    String? responseStyle,
  }) async {
    final style = _normalizeResponseStyle(responseStyle);

    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/light-dialog',
        {
          'capture_content': signal.content,
          'capture_acknowledgement': signal.acknowledgement,
          'history': history.map((e) => e.toJson()).toList(),
          'user_message': userMessage,
          'language': language,
          'focus_area': focusArea,
          'response_style': style,
        },
      );

      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      return LightDialogResponseModel.fromJson(data);
    } catch (_) {
      return LightDialogResponseModel(
        reply: _styleText(
          _fallbackLightDialogReply(
            signalContent: signal.content,
            userMessage: userMessage,
            language: language,
          ),
          style,
        ),
      );
    }
  }

  String _fallbackLightDialogReply({
    required String signalContent,
    required String userMessage,
    required String language,
  }) {
    final safetyText = '$signalContent $userMessage';
    if (_isImmediateSafetyRisk(safetyText)) {
      return _offlineSafetyAcknowledgement(
        language == 'zh-Hant' || language == 'ja' || language == 'en'
            ? language
            : 'zh-Hans',
      );
    }
    return l1AttunedDialogReply(
      signalContent: signalContent,
      userMessage: userMessage,
      language: language,
    );
  }

  Future<WeeklyReflectModel> generateWeeklyReflect({
    required WeeklyInsightModel weekly,
    String? focusArea,
  }) async {
    final displayLanguage = _normalizeLanguage(languageLoader());
    final attemptFacts = _deepWeeklyAttemptFacts(weekly);
    final sourceSignalCardIds = _weeklySourceSignalCardIds(weekly);
    try {
      final res = await apiClient.postJson(
        '/api/v1/ai/reflect-weekly',
        {
          'week_start': weekly.weekStart,
          'week_end': weekly.weekEnd,
          'key_insight': weekly.keyInsight,
          'patterns': weekly.patterns,
          'frictions': weekly.frictions,
          'best_action': weekly.bestAction,
          'chart_data': weekly.chartData.map((e) => e.toJson()).toList(),
          'focus_area': focusArea,
          'attempt_count': attemptFacts.attemptCount,
          'recorded_attempt_day_count': attemptFacts.recordedDayCount,
          'completed_attempt_day_count': attemptFacts.completedDayCount,
          'signal_attempt_overlap_day_count': attemptFacts.overlapDayCount,
          'dominant_feedback_pattern': attemptFacts.dominantFeedbackPattern,
          'source_signal_card_ids': sourceSignalCardIds,
          'language': displayLanguage,
        },
      );
      final data = (res['data'] as Map<String, dynamic>?) ?? res;
      final generated = WeeklyReflectModel.fromJson(data);
      if (!_weeklyReflectMatchesLanguage(
        generated,
        displayLanguage,
      )) {
        throw const FormatException(
          'Weekly deep analysis did not match the requested language.',
        );
      }
      return generated;
    } catch (_) {
      final sourceTopic = weekly.deriveTopicFocus();
      final topic = WeeklyTopicFocusModel(
        headline: _safeGeneratedSourceText(
          sourceTopic.headline,
          displayLanguage,
          fallback: _localized(
            displayLanguage,
            en: 'This week\'s recurring pattern',
            zhHans: '本周反复出现的模式',
            zhHant: '本週反覆出現的模式',
            ja: '今週繰り返したパターン',
          ),
        ),
        reason: _safeGeneratedSourceText(
          sourceTopic.reason,
          displayLanguage,
          fallback: _localized(
            displayLanguage,
            en: 'One recurring pattern and one source of friction appeared together this week.',
            zhHans: '本周有一个重复模式与一个摩擦点同时出现。',
            zhHant: '本週有一個重複模式與一個摩擦點同時出現。',
            ja: '今週は、繰り返すパターンと一つの摩擦が同時に現れました。',
          ),
        ),
        nextWatch: _safeGeneratedSourceText(
          sourceTopic.nextWatch,
          displayLanguage,
          fallback: _localized(
            displayLanguage,
            en: 'Next week, notice when the same situation returns.',
            zhHans: '下周继续留意同类情况何时再次出现。',
            zhHant: '下週繼續留意同類情況何時再次出現。',
            ja: '来週、同じ状況がいつ再び現れるかに注目します。',
          ),
        ),
      );
      final chartPoints = [...weekly.chartData]..sort(
          (a, b) => a.date.compareTo(b.date),
        );
      WeeklyChartPointModel? peak;
      WeeklyChartPointModel? low;
      if (chartPoints.isNotEmpty) {
        peak = chartPoints.reduce(
          (a, b) => a.signalCount >= b.signalCount ? a : b,
        );
        low = chartPoints.reduce(
          (a, b) => a.moodScore <= b.moodScore ? a : b,
        );
      }
      final peakLabel = _shortDateLabel(peak?.date) ??
          _localized(
            displayLanguage,
            en: 'one day this week',
            zhHans: '这周某一天',
            zhHant: '這週某一天',
            ja: '今週のある日',
          );
      final lowLabel = _shortDateLabel(low?.date) ??
          _localized(
            displayLanguage,
            en: 'a lower point this week',
            zhHans: '这周某个低点',
            zhHant: '這週某個低點',
            ja: '今週の低調な時点',
          );
      return WeeklyReflectModel(
        summary: _localized(
          displayLanguage,
          en: '${topic.reason} The deeper analysis looks for the same tension behind these entries, rather than simply making the account longer.',
          zhHans: '${topic.reason} 深度分析更需要看的，是这些记录背后的同一种拉扯，而不是把内容拉长。',
          zhHant: '${topic.reason} 深度分析更需要看的，是這些記錄背後的同一種拉扯，而不是把內容拉長。',
          ja: '${topic.reason} 深度分析では、記録を長くするのではなく、その背後で繰り返す同じ葛藤を見ます。',
        ),
        rootTension: _localized(
          displayLanguage,
          en: 'The deeper tension is often not one event, but the direction you want to move in meeting a recurring source of friction, forcing you to regain your rhythm each time.',
          zhHans: '更深一层的内在拉扯往往不是单个事件，而是你想推进的方向和反复回来的摩擦点互相顶住，导致每次都要重新找回节奏。',
          zhHant: '更深一層的內在拉扯往往不是單一事件，而是你想推進的方向與反覆出現的摩擦互相牴觸，讓你每次都要重新找回節奏。',
          ja: 'より深い葛藤は一つの出来事ではなく、進みたい方向と繰り返す摩擦がぶつかり、そのたびにリズムを取り戻す必要があることです。',
        ),
        hiddenPattern: _localized(
          displayLanguage,
          en: 'Reading the chart with the text, $peakLabel has denser Signal activity, while $lowLabel looks more like a lower point. The important part is not the worst day, but how accumulated pressure pulls you away.',
          zhHans:
              '把图和文字放在一起看，$peakLabel 是 Signal 更密的节点，$lowLabel 更像状态低点。重点不是哪天最糟，而是压力聚集后你如何被拉走。',
          zhHant:
              '把圖和文字放在一起看，$peakLabel 是 Signal 更密集的節點，$lowLabel 更像狀態低點。重點不是哪天最糟，而是壓力累積後如何把你拉走。',
          ja: '図と文章を合わせて見ると、$peakLabel は Signal がより密で、$lowLabel は状態が低い時点に見えます。大切なのは最悪の日ではなく、圧力が集まった後にどう引っ張られるかです。',
        ),
        nextFocus: _localized(
          displayLanguage,
          en: '${topic.nextWatch} When a similar situation happens again, note whether it occurred at the beginning, middle, or closing stage.',
          zhHans: '${topic.nextWatch} 下次再出现同类场景时，多记一句它发生在开始、推进中段，还是收尾阶段。',
          zhHant: '${topic.nextWatch} 下次再出現同類場景時，多記一句它發生在開始、推進中段，還是收尾階段。',
          ja: '${topic.nextWatch} 同じような場面が再び起きたら、開始時・途中・終盤のどこだったかを一言残してください。',
        ),
        riskNote: _localized(
          displayLanguage,
          en: 'This deeper analysis is meant to narrow what to observe, not to reach a conclusion all at once.',
          zhHans: '这份深度分析适合帮你收窄观察面，不适合一次性下结论。',
          zhHant: '這份深度分析適合幫你收窄觀察範圍，不適合一次下結論。',
          ja: 'この深度分析は観察範囲を絞るためのもので、一度に結論を出すためのものではありません。',
        ),
        keyNodes: [
          topic.headline,
          _localized(
            displayLanguage,
            en: 'Dense Signal point: $peakLabel',
            zhHans: 'Signal 密集点：$peakLabel',
            zhHant: 'Signal 密集點：$peakLabel',
            ja: 'Signal が密な時点：$peakLabel',
          ),
          _localized(
            displayLanguage,
            en: 'Lower point: $lowLabel',
            zhHans: '走势低点：$lowLabel',
            zhHant: '走勢低點：$lowLabel',
            ja: '低調な時点：$lowLabel',
          ),
        ],
        patternLabel: topic.headline,
        frictionLabel: topic.reason,
        impactLabel: attemptFacts.completedDayCount > 0
            ? _localized(
                displayLanguage,
                en: '${attemptFacts.completedDayCount} completed days',
                zhHans: '已有 ${attemptFacts.completedDayCount} 个完成日',
                zhHant: '已有 ${attemptFacts.completedDayCount} 個完成日',
                ja: '${attemptFacts.completedDayCount} 日完了',
              )
            : attemptFacts.recordedDayCount > 0
                ? _localized(
                    displayLanguage,
                    en: '${attemptFacts.recordedDayCount} feedback days',
                    zhHans: '已有 ${attemptFacts.recordedDayCount} 个反馈日',
                    zhHant: '已有 ${attemptFacts.recordedDayCount} 個回饋日',
                    ja: '${attemptFacts.recordedDayCount} 日分のフィードバック',
                  )
                : _localized(
                    displayLanguage,
                    en: 'Experiment feedback is still forming',
                    zhHans: '尝试反馈仍在形成',
                    zhHant: '嘗試回饋仍在形成',
                    ja: '実験のフィードバックはまだ形成中',
                  ),
        relationshipSummary: _localized(
          displayLanguage,
          en: 'This week, the recurring pattern and main friction repeatedly appeared within the same context.',
          zhHans: '本周的重复模式与主要摩擦在同一范围内反复同时出现。',
          zhHant: '本週的重複模式與主要摩擦在同一範圍內反覆同時出現。',
          ja: '今週は、繰り返すパターンと主な摩擦が同じ範囲で何度も同時に現れました。',
        ),
        timingSummary: _localized(
          displayLanguage,
          en: 'Signal activity was denser on $peakLabel, while $lowLabel looked more like a lower point.',
          zhHans: '$peakLabel 的 Signal 更密，$lowLabel 更像状态低点。',
          zhHant: '$peakLabel 的 Signal 更密集，$lowLabel 更像狀態低點。',
          ja: '$peakLabel は Signal がより密で、$lowLabel は状態が低い時点に見えます。',
        ),
        nextQuestion: _localized(
          displayLanguage,
          en: '${topic.nextWatch} Did it happen at the beginning, middle, or closing stage?',
          zhHans: '${topic.nextWatch} 它发生在开始、推进还是收尾？',
          zhHant: '${topic.nextWatch} 它發生在開始、推進還是收尾？',
          ja: '${topic.nextWatch} それは開始時・途中・終盤のどこで起きましたか？',
        ),
        illustrationHint: _weeklyIllustrationHint(weekly),
        sourceSignalCardIds: sourceSignalCardIds,
        scopeNote: _localized(
          displayLanguage,
          en: 'This analysis only describes relationships that repeatedly co-occurred in this week’s Signal. It helps choose what to observe next week and does not imply causality, personality, or a long-term conclusion.',
          zhHans: '这份深度分析只说明本周 Signal 中反复同时出现的关系，用于确定下周观察点，不代表因果、人格判断或长期结论。',
          zhHant: '這份深度分析只說明本週 Signal 中反覆同時出現的關係，用於確定下週觀察點，不代表因果、人格判斷或長期結論。',
          ja: 'この深度分析は、今週の Signal で繰り返し同時に現れた関係だけを示します。来週の観察点を決めるためのもので、因果・人格判断・長期的な結論を意味しません。',
        ),
      );
    }
  }

  bool _weeklyReflectMatchesLanguage(
    WeeklyReflectModel reflect,
    String language,
  ) {
    final normalized = _normalizeLanguage(language);
    if (normalized != 'en' && normalized != 'ja') return true;
    final generatedFields = <String>[
      reflect.summary,
      reflect.rootTension,
      reflect.hiddenPattern,
      reflect.nextFocus,
      reflect.riskNote,
      reflect.patternLabel,
      reflect.frictionLabel,
      reflect.impactLabel,
      reflect.relationshipSummary,
      reflect.timingSummary,
      reflect.nextQuestion,
      reflect.scopeNote,
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);
    final text = <String>[
      ...generatedFields,
      ...reflect.keyNodes,
    ].where((value) => value.trim().isNotEmpty).join(' ');
    final hasHan = RegExp(r'[\u3400-\u9fff]').hasMatch(text);
    final hasKana = RegExp(r'[\u3040-\u30ff]').hasMatch(text);
    if (normalized == 'en') {
      return !hasHan && !hasKana && RegExp(r'[A-Za-z]').hasMatch(text);
    }
    final hasChineseOnlyForms = RegExp(
      r'[这们么还没为个录复续觉验這們麼還沒]',
    ).hasMatch(text);
    return hasKana &&
        !hasChineseOnlyForms &&
        generatedFields
            .every((value) => RegExp(r'[\u3040-\u30ff]').hasMatch(value));
  }

  String _safeGeneratedSourceText(
    String value,
    String language, {
    required String fallback,
  }) {
    final normalized = _normalizeLanguage(language);
    if (normalized == 'en') {
      final hasHan = RegExp(r'[\u3400-\u9fff]').hasMatch(value);
      final hasKana = RegExp(r'[\u3040-\u30ff]').hasMatch(value);
      return !hasHan && !hasKana && RegExp(r'[A-Za-z]').hasMatch(value)
          ? value
          : fallback;
    }
    if (normalized == 'ja') {
      final hasKana = RegExp(r'[\u3040-\u30ff]').hasMatch(value);
      final hasChineseOnlyForms = RegExp(
        r'[这们么还没为录复续觉验与过让里现会开进对应当后這們麼還沒為錄復續覺驗與過讓裡現會開進對應當後]',
      ).hasMatch(value);
      return hasKana && !hasChineseOnlyForms ? value : fallback;
    }
    return value;
  }

  ({
    int attemptCount,
    int recordedDayCount,
    int completedDayCount,
    int overlapDayCount,
    String? dominantFeedbackPattern,
  }) _deepWeeklyAttemptFacts(WeeklyInsightModel weekly) {
    final raw = weekly.opportunitySnapshot?['_feedback_event_summary'];
    final summary = raw is Map
        ? raw.map((key, value) => MapEntry('$key', value))
        : const <String, dynamic>{};
    final rawEvents = summary['events'];
    final events = rawEvents is List
        ? rawEvents
            .whereType<Map>()
            .map((event) => event.map((key, value) => MapEntry('$key', value)))
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final subjectIds = <String>{};
    final feedbackDates = <String>{};
    final completedDates = <String>{};
    for (final event in events) {
      final subjectId = event['subject_id']?.toString().trim() ?? '';
      if (subjectId.isNotEmpty) subjectIds.add(subjectId);
      final date = event['local_date']?.toString().trim() ?? '';
      if (date.isNotEmpty) feedbackDates.add(date);
      final status = event['status']?.toString().trim().toLowerCase() ?? '';
      if (date.isNotEmpty &&
          const {'done', 'completed', 'happened', 'yes', 'helpful'}
              .contains(status)) {
        completedDates.add(date);
      }
    }

    final signalDates = <String>{};
    final rawSignals = weekly.opportunitySnapshot?['_weekly_signal_entries'];
    if (rawSignals is List) {
      for (final item in rawSignals.whereType<Map>()) {
        final date =
            (item['local_date'] ?? item['created_at'])?.toString().trim() ?? '';
        if (date.length >= 10) signalDates.add(date.substring(0, 10));
      }
    }
    final overlap = signalDates.intersection(feedbackDates);
    final review = weekly.actionReview;
    final dominantFeedbackPattern = [
      review.nextAdjustment,
      review.mostHelpfulAction,
      review.hardestAction,
    ].map((value) => value.trim()).firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );
    final summaryTotal = (summary['total_count'] as num?)?.toInt() ?? 0;
    return (
      attemptCount: subjectIds.isNotEmpty
          ? subjectIds.length
          : review.triedActionCount > 0
              ? review.triedActionCount
              : summaryTotal,
      recordedDayCount: feedbackDates.length,
      completedDayCount: completedDates.length,
      overlapDayCount: overlap.length,
      dominantFeedbackPattern:
          dominantFeedbackPattern.isEmpty ? null : dominantFeedbackPattern,
    );
  }

  List<String> _weeklySourceSignalCardIds(WeeklyInsightModel weekly) {
    final raw = weekly.opportunitySnapshot?['_weekly_signal_entries'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((entry) => entry['id']?.toString().trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String? _weeklyIllustrationHint(WeeklyInsightModel weekly) {
    for (final item in [...weekly.patterns, ...weekly.frictions]) {
      if (item is! Map) continue;
      final value = item['illustration_hint']?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  String? _shortDateLabel(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return raw.length >= 10 && raw.contains('-') ? raw.substring(5) : raw;
  }

  String _normalizeResponseStyle(String? value) {
    switch (value) {
      case 'clear':
      case 'direct':
      case 'gentle':
        return value!;
      default:
        return 'gentle';
    }
  }

  String _styleText(String text, String style) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;

    switch (style) {
      case 'direct':
        return trimmed
            .replaceAll('先把', '把')
            .replaceAll('就好', '')
            .replaceAll('先不用', '不用')
            .trim();
      case 'clear':
        return trimmed;
      case 'gentle':
      default:
        return trimmed;
    }
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  String _fallbackAcknowledgement(
    String content, {
    String? language,
  }) {
    final trimmed = content.trim();
    final displayLanguage = _fallbackLanguage(
      content,
      requested: language,
    );
    if (_isImmediateSafetyRisk(content)) {
      return _offlineSafetyAcknowledgement(displayLanguage);
    }
    if (trimmed.isEmpty) {
      return switch (displayLanguage) {
        'ja' => '書いてくれたことを、そのままここに残します。',
        'en' => 'I am keeping what you wrote here as it is.',
        'zh-Hant' => '你寫下的這件事已經留在這裡了。',
        _ => '你写下的这件事已经留在这里了。',
      };
    }

    final topic = _topicHint(content);
    if (topic != null) {
      return _topicAcknowledgement(topic, displayLanguage);
    }
    return l1AttunedAcknowledgement(
      content: content,
      language: displayLanguage,
    );
  }

  String _fallbackSingleObservation(
    String content, {
    String? language,
  }) {
    final displayLanguage = _fallbackLanguage(
      content,
      requested: language,
    );
    final emotion = _fallbackEmotion(content);
    if (displayLanguage != 'zh-Hans') {
      final key = switch (emotion) {
        'positive' || 'mixed' || 'negative' => emotion,
        _ => 'neutral',
      };
      return switch (displayLanguage) {
        'zh-Hant' => {
            'positive': '這條記錄顯示，一些具體的小好事確實能幫你補回狀態。',
            'mixed': '這條裡最值得留意的是拉扯感：有消耗，也有一些片刻把你接住。',
            'negative': '這條裡較明顯的線索是，某個具體場景正在持續消耗你。',
            'neutral': '這更像是一條狀態線索，而不是一股很強的情緒。',
          }[key]!,
        'ja' => {
            'positive': 'この記録から、具体的な小さな出来事が気持ちを少し回復させていることが見えます。',
            'mixed': 'この記録では、消耗する感覚と少し持ち直す感覚の両方が大切な手がかりです。',
            'negative': 'この記録では、ある具体的な場面が継続して負担になっていることが見えます。',
            'neutral': 'これは強い感情というより、今の状態を示す手がかりに近そうです。',
          }[key]!,
        _ => {
            'positive':
                'This entry suggests that a specific small moment helped restore some energy.',
            'mixed':
                'The tension between feeling drained and feeling restored is the clearest clue here.',
            'negative':
                'The clearest clue is that a specific situation is steadily wearing you down.',
            'neutral':
                'This reads more like a clue about your state than a strong emotion.',
          }[key]!,
      };
    }
    final topic = _topicHint(content);
    if (topic != null) {
      return _topicObservation(topic);
    }

    final sceneTags = _fallbackSceneTags(content);

    if (emotion == 'positive') {
      if (sceneTags.contains('achievement')) {
        return '今天比较值得记住的，是你会被“确实有推进”的感觉明显提起来。';
      }
      return '今天更清楚的线索是：一些具体的小好事，确实能给你补回状态。';
    }

    if (emotion == 'mixed') {
      return '这条里最值得记的是那种拉扯感：你会被消耗，也会被一些具体的东西重新接住。';
    }

    if (emotion == 'negative') {
      if (sceneTags.contains('work')) {
        return '今天更明显的不是情绪本身，而是工作里的打断、改动或失控感在反复磨你。';
      }
      if (sceneTags.contains('body')) {
        return '你今天更像是先被身体状态拖住了，情绪只是跟着一起往下。';
      }
      return '今天更明显的不是一句“烦”，而是某个具体场景正在稳定地消耗你。';
    }

    return '你今天更像是在留下一条状态线索，而不是在表达一股很强的情绪。';
  }

  String _fallbackSingleTryNext(
    String content, {
    String? language,
  }) {
    final displayLanguage = _fallbackLanguage(
      content,
      requested: language,
    );
    final emotion = _fallbackEmotion(content);
    if (displayLanguage != 'zh-Hans') {
      final key = switch (emotion) {
        'positive' || 'mixed' || 'negative' => emotion,
        _ => 'neutral',
      };
      return switch (displayLanguage) {
        'zh-Hant' => {
            'positive': '先記下是哪個具體片刻帶來了好一點的感覺，不用寫多。',
            'mixed': '先不用總結整天，只記下是什麼讓你稍微緩了回來。',
            'negative': '先記下最卡你的那個瞬間，其他暫時不用整理。',
            'neutral': '先把這一條留著，看看它之後會不會再出現。',
          }[key]!,
        'ja' => {
            'positive': '少しよい気持ちにつながった具体的な点だけ、短く残しておきましょう。',
            'mixed': '一日全体をまとめず、少し持ち直せたきっかけだけ残してみてください。',
            'negative': 'いちばん引っかかった瞬間だけ残し、ほかは今すぐ整理しなくて大丈夫です。',
            'neutral': 'この記録をいったん残し、また同じことが起きるか見てみましょう。',
          }[key]!,
        _ => {
            'positive':
                'Note the specific detail that helped this moment feel better.',
            'mixed':
                'For now, note only what helped you recover a little later.',
            'negative':
                'Note the moment that felt most difficult; the rest can wait.',
            'neutral': 'Keep this entry and see whether the same clue returns.',
          }[key]!,
      };
    }
    final topic = _topicHint(content);
    if (topic != null) {
      return _topicTryNext(topic);
    }

    final sceneTags = _fallbackSceneTags(content);

    if (emotion == 'positive') {
      if (sceneTags.contains('achievement')) {
        return '先记住这一下具体是因为什么推进感出现的，之后很容易复用。';
      }
      return '先把让你感觉不错的那个具体点记下来，不用写多。';
    }

    if (emotion == 'mixed') {
      return '今天先别急着总结整天，只记住是什么让你后面稍微缓回来一点。';
    }

    if (emotion == 'negative') {
      if (sceneTags.contains('work')) {
        return '下次再出现时，只补一句它发生在什么工作场景里，就已经很有用了。';
      }
      if (sceneTags.contains('body')) {
        return '先不用分析原因，只留意一下这种身体状态是从什么时候开始的。';
      }
      return '先把最卡你的那个瞬间记下来，其他先不用整理。';
    }

    return '先把这一条放着，看看之后它会不会再回来。';
  }

  String _fallbackObservation(
    List<RecentSignalModel> entries,
    String language,
  ) {
    final displayLanguage = _normalizeLanguage(language);
    if (entries.isEmpty) {
      return _localized(
        displayLanguage,
        en: 'There are no entries yet today. Start with one small thing that really happened.',
        zhHans: '今天还没有记录，先留下一件真实发生的小事就好。',
        zhHant: '今天還沒有記錄，先留下一件真實發生的小事就好。',
        ja: '今日はまだ記録がありません。実際に起きた小さなことを一つ残してみましょう。',
      );
    }

    if (entries.length == 1) {
      final first = entries.first;
      return first.observation ??
          _localized(
            displayLanguage,
            en: 'You recorded 1 Signal today. You have started keeping what genuinely stood out.',
            zhHans: '今天记录了 1 条 Signal。你已经开始把今天里真正触动你的事留了下来。',
            zhHant: '今天記錄了 1 條 Signal。你已經開始把今天真正觸動你的事留下來。',
            ja: '今日は Signal を1件記録しました。心に残ったことを残し始めています。',
          );
    }

    final mixedCount = entries.where((e) => e.emotion == 'mixed').length;
    final negativeCount = entries.where((e) => e.emotion == 'negative').length;
    final positiveCount = entries.where((e) => e.emotion == 'positive').length;

    if (mixedCount > 0) {
      return _localized(
        displayLanguage,
        en: 'You recorded ${entries.length} Signal today. Some do not move in one direction; they show a back-and-forth tension.',
        zhHans: '今天记录了 ${entries.length} 条 Signal，几条线索不是单向变化，而是在来回拉扯。',
        zhHant: '今天記錄了 ${entries.length} 條 Signal，幾條線索不是單向變化，而是在來回拉扯。',
        ja: '今日は Signal を${entries.length}件記録しました。いくつかは一方向ではなく、行き来する葛藤を示しています。',
      );
    }
    if (negativeCount >= positiveCount && negativeCount > 0) {
      return _localized(
        displayLanguage,
        en: 'You recorded ${entries.length} Signal today. The clearest theme is that certain situations are repeatedly draining you.',
        zhHans: '今天记录了 ${entries.length} 条 Signal，更明显的是某些场景在反复消耗你。',
        zhHant: '今天記錄了 ${entries.length} 條 Signal，更明顯的是某些場景在反覆消耗你。',
        ja: '今日は Signal を${entries.length}件記録しました。特定の場面が繰り返し負担になっていることが目立ちます。',
      );
    }
    if (positiveCount > 0) {
      return _localized(
        displayLanguage,
        en: 'You recorded ${entries.length} Signal today. Specific moments that help bring you back are beginning to appear.',
        zhHans: '今天记录了 ${entries.length} 条 Signal，里面已经开始出现一些能把你拉回来的具体片段。',
        zhHant: '今天記錄了 ${entries.length} 條 Signal，裡面已開始出現一些能把你拉回來的具體片段。',
        ja: '今日は Signal を${entries.length}件記録しました。少し持ち直す助けになる具体的な場面が見え始めています。',
      );
    }
    return _localized(
      displayLanguage,
      en: 'You recorded ${entries.length} Signal today. Today’s clues are beginning to come together.',
      zhHans: '今天记录了 ${entries.length} 条 Signal。今天的线索已经开始聚起来了。',
      zhHant: '今天記錄了 ${entries.length} 條 Signal。今天的線索已開始聚起來。',
      ja: '今日は Signal を${entries.length}件記録しました。今日の手がかりが少しずつ集まり始めています。',
    );
  }

  String _fallbackSuggestion(
    List<RecentSignalModel> entries,
    String language,
  ) {
    final displayLanguage = _normalizeLanguage(language);
    if (entries.isEmpty) {
      return _localized(
        displayLanguage,
        en: 'For today, note one small thing that made you pause.',
        zhHans: '今天先记下一件让你停顿了一下的小事就好。',
        zhHant: '今天先記下一件讓你停頓了一下的小事就好。',
        ja: '今日は、少し立ち止まった出来事を一つだけ残してみましょう。',
      );
    }

    if (entries.length == 1) {
      final first = entries.first;
      return first.tryNext ??
          _localized(
            displayLanguage,
            en: 'If something similar happens again today, add one more Signal.',
            zhHans: '如果同类事情今天再出现一次，再补记一条 Signal 就可以。',
            zhHant: '如果同類事情今天再出現一次，再補記一條 Signal 就可以。',
            ja: '今日また同じようなことが起きたら、Signal をもう1件残してみてください。',
          );
    }

    final workHeavy = entries.where((e) => e.sceneTags.contains('work')).length;
    final mixedCount = entries.where((e) => e.emotion == 'mixed').length;

    if (mixedCount > 0) {
      return _localized(
        displayLanguage,
        en: 'Notice which situations pull you down and which small moments help bring you back.',
        zhHans: '今天先留意：哪些场景会把你拉低，哪些小事又会把你拉回来。',
        zhHant: '今天先留意：哪些場景會把你拉低，哪些小事又會把你拉回來。',
        ja: '今日は、どんな場面で気持ちが下がり、どんな小さなことで少し戻れるかを見てみましょう。',
      );
    }
    if (workHeavy > 0) {
      return _localized(
        displayLanguage,
        en: 'When a similar work situation happens again, add one sentence about where it occurred.',
        zhHans: '下次再出现同类工作场景时，用一句话补记它发生在什么地方。',
        zhHant: '下次再出現同類工作場景時，用一句話補記它發生在什麼地方。',
        ja: '同じような仕事の場面がまた起きたら、どこで起きたかを一文だけ残してみてください。',
      );
    }
    return _localized(
      displayLanguage,
      en: 'Notice whether any type of event today has happened this way before.',
      zhHans: '接下来先留意：今天有没有哪类事情已经不是第一次这样发生。',
      zhHant: '接下來先留意：今天有沒有哪類事情已經不是第一次這樣發生。',
      ja: '今日は、以前にも同じように起きたことがないかを見てみましょう。',
    );
  }

  String _fallbackEmotion(String content) {
    final text = content.toLowerCase();

    final positiveKeywords = [
      '开心',
      '高兴',
      '喜欢',
      '顺利',
      '放松',
      '舒服',
      '满足',
      '期待',
      '有成就感',
      '轻松',
      '好吃',
      '快乐',
      '愉快',
      '安心',
      '踏实',
      '嬉しい',
      '楽しい',
      'よかった',
      '満足',
      '安心',
      'happy',
      'glad',
      'good',
      'great',
      'relieved',
      'nice',
    ];
    final negativeKeywords = [
      '烦',
      '累',
      '崩',
      '难受',
      '焦虑',
      '生气',
      '压力',
      '不想',
      '麻烦',
      '受不了',
      '被打断',
      '烦躁',
      '委屈',
      '失控',
      '糟糕',
      '痛苦',
      '压抑',
      'しんどい',
      'つらい',
      '疲れた',
      'イライラ',
      '不安',
      '最悪',
      'annoyed',
      'tired',
      'upset',
      'angry',
      'anxious',
      'stressed',
      'frustrated',
    ];
    final mixedMarkers = [
      '但是',
      '但',
      '不过',
      '后来',
      '虽然',
      '又',
      '缓回来',
      '好了一点',
      'けど',
      'でも',
      'そのあと',
      'but',
      'however',
      'though',
      'later',
    ];

    final hasPositive = positiveKeywords.any(text.contains);
    final hasNegative = negativeKeywords.any(text.contains);
    final hasMixedMarker = mixedMarkers.any(text.contains);

    if ((hasPositive && hasNegative) ||
        (hasMixedMarker && (hasPositive || hasNegative))) {
      return 'mixed';
    }
    if (hasNegative) return 'negative';
    if (hasPositive) return 'positive';
    return 'neutral';
  }

  String? _topicHint(String content) {
    final text = content.toLowerCase();
    bool hit(List<String> keywords) => keywords.any(text.contains);

    if (hit(['token', 'tokens', 'トークン']) &&
        hit(['贵', '高', 'expensive', 'cost', '高い'])) {
      return 'cost';
    }
    if (hit(['骑马', '乗馬', '馬', 'horse'])) {
      return 'horse_expectation';
    }
    if (hit([
      '无法预测明天',
      '不能预测明天',
      '预测明天',
      '活在当下',
      '明日',
      '予測',
      'tomorrow',
      'present'
    ])) {
      return 'tomorrow_uncertainty';
    }
    if (hit(['退休', '退職', '引退', 'retire'])) {
      return 'retirement_wish';
    }
    if (hit(['天气不错', '好天气', 'いい天気', 'weather is nice', 'good weather'])) {
      return 'weather_good';
    }
    if (hit(['不想上班', '休息', '休みたい', 'rest'])) {
      return 'rest_wish';
    }
    if (hit(
        ['钱', '贵', '预算', '成本', '花费', '价格', 'お金', 'money', 'budget', 'cost'])) {
      return 'money';
    }
    return null;
  }

  String _topicAcknowledgement(String topic, String language) {
    return switch ((language, topic)) {
      ('ja', 'cost') => 'モデル利用量のコストが高いと感じたことを、そのままここに残します。',
      ('ja', 'horse_expectation') => '乗馬を楽しみにしている気持ちを、ここに残します。',
      ('ja', 'tomorrow_uncertainty') => '明日は予測できず、今を大切にしたいと書いてくれましたね。',
      ('ja', 'retirement_wish') => '早く引退したいという今の気持ちを、まずここに残します。',
      ('ja', 'weather_good') => '今日は天気がいいと感じた、その小さな瞬間を残します。',
      ('ja', 'rest_wish') => '少し止まって休みたいという気持ちを、ここに残します。',
      ('ja', 'money') => 'お金やコスト、予算が気になったことを、ここに残します。',
      ('en', 'cost') =>
        'You wrote that token cost feels high, and I am keeping that concern here.',
      ('en', 'horse_expectation') =>
        'You mentioned looking forward to horse riding, and I am keeping that moment here.',
      ('en', 'tomorrow_uncertainty') =>
        'You wrote that tomorrow cannot be predicted and that you want to stay with the present.',
      ('en', 'retirement_wish') =>
        'You wrote that you want to retire early, and I am keeping that thought here.',
      ('en', 'weather_good') =>
        'You noticed that the weather feels good today, and I am keeping that small moment here.',
      ('en', 'rest_wish') =>
        'You wrote that you want to stop and rest for a while, and I am keeping that feeling here.',
      ('en', 'money') =>
        'You wrote that money, cost, or budget is on your mind, and I am keeping that here.',
      ('zh-Hant', 'cost') => '你寫下了模型用量成本很高，這份在意先留在這裡。',
      ('zh-Hant', 'horse_expectation') => '你提到了騎馬和期待，這個片刻先留在這裡。',
      ('zh-Hant', 'tomorrow_uncertainty') => '你寫下了明天無法預測，也想好好看著當下。',
      ('zh-Hant', 'retirement_wish') => '你寫下了想早點退休，這個念頭先留在這裡。',
      ('zh-Hant', 'weather_good') => '你留意到今天天氣不錯，這個小片刻先記下來了。',
      ('zh-Hant', 'rest_wish') => '你寫下了想停下來休息，這個感受先留在這裡。',
      ('zh-Hant', 'money') => '你寫下了對錢、成本或預算的在意，這一條先留在這裡。',
      (_, 'cost') => '你写下了使用额度成本很高，这份在意先留在这里。',
      (_, 'horse_expectation') => '你提到了骑马和期待，这个片刻先留在这里。',
      (_, 'tomorrow_uncertainty') => '你写下了明天无法预测，也想好好看着当下。',
      (_, 'retirement_wish') => '你写下了想早点退休，这个念头先留在这里。',
      (_, 'weather_good') => '你留意到今天天气不错，这个小片刻先记下来了。',
      (_, 'rest_wish') => '你写下了想停下来休息，这个感受先留在这里。',
      (_, 'money') => '你写下了对钱、成本或预算的在意，这一条先留在这里。',
      ('ja', _) => '書いてくれたことを、そのままここに残します。',
      ('en', _) => 'I am keeping what you wrote here as it is.',
      ('zh-Hant', _) => '這一條已經按你寫下的內容記下來了。',
      _ => '这一条已经按你写下的内容记下来了。',
    };
  }

  String _fallbackLanguage(
    String content, {
    String? requested,
  }) {
    final normalized = requested?.trim().toLowerCase().replaceAll('_', '-');
    if (normalized != null && normalized.isNotEmpty) {
      if (normalized.startsWith('ja')) return 'ja';
      if (normalized.startsWith('en')) return 'en';
      if (const {'zh-hant', 'zh-tw', 'zh-hk', 'zh-mo'}.contains(normalized)) {
        return 'zh-Hant';
      }
      if (normalized.startsWith('zh')) return 'zh-Hans';
    }
    final hasKana = content.runes.any(
      (code) =>
          (code >= 0x3040 && code <= 0x30FF) ||
          (code >= 0x31F0 && code <= 0x31FF),
    );
    if (hasKana) return 'ja';
    if (RegExp(r'[這裡為會覺讓與還說體來時個後點願該辦實復錢預測寫]').hasMatch(content)) {
      return 'zh-Hant';
    }
    final hasCjk = content.runes.any(
      (code) => code >= 0x4E00 && code <= 0x9FFF,
    );
    if (!hasCjk && RegExp(r'[A-Za-z]').hasMatch(content)) return 'en';
    return 'zh-Hans';
  }

  bool _isImmediateSafetyRisk(String content) {
    final normalized = content.trim().toLowerCase();
    return const [
      '想自杀',
      '要自杀',
      '不想活了',
      '结束生命',
      '傷害自己',
      '自殺したい',
      '今すぐ死にたい',
      'kill myself',
      'suicide now',
      'end my life',
      'hurt myself',
      'hurt someone',
    ].any(normalized.contains);
  }

  String _offlineSafetyAcknowledgement(String language) {
    return switch (language) {
      'ja' =>
        '今の言葉をとても心配しています。今すぐ自分や誰かを傷つける可能性があるなら、危険な物から離れ、地域の緊急窓口か、すぐそばに来られる信頼できる人へ連絡してください。',
      'en' =>
        'I am very concerned about what you just said. If you might hurt yourself or someone else right now, move away from anything dangerous and contact local emergency services or a trusted person who can be with you now.',
      'zh-Hant' =>
        '我很在意你剛才這句話。若你現在可能馬上傷害自己或他人，請先離開危險物品，並聯絡當地緊急服務或一位能立刻到你身邊的可信任的人。',
      _ => '我很在意你刚才这句话。若你现在可能马上伤害自己或他人，请先离开危险物品，并联系当地紧急服务或一位能立刻到你身边的可信任的人。',
    };
  }

  String _topicObservation(String topic) {
    switch (topic) {
      case 'cost':
        return '这条更像是成本提醒：当使用额度或智能助手的成本变得显眼，它会影响你对工具是否值得继续用的判断。';
      case 'horse_expectation':
        return '这条的恢复线索很明确：骑马不是普通安排，而是你这周少数真正期待的事情。';
      case 'tomorrow_uncertainty':
        return '这条更像是一种生活视角：明天不可控，所以今天能抓住的当下变得更重要。';
      case 'retirement_wish':
        return '这条不是简单抱怨，它更像是在提示：现在的工作消耗已经让你开始想象彻底离开的生活。';
      case 'weather_good':
        return '这条里的正向线索很小但清楚：外部环境变轻，会让今天更容易松一点。';
      case 'rest_wish':
        return '这条更像是恢复需求浮出来了：你可能不是懒，而是确实想要一点不用继续扛的空间。';
      case 'money':
        return '这条和钱有关，也可能牵着安全感、值不值得、以及资源是否够用的判断。';
      default:
        return '这条可以先作为一个具体线索留下来。';
    }
  }

  String _topicTryNext(String topic) {
    switch (topic) {
      case 'cost':
        return '可以先记一笔：这次让你觉得贵的，是单次花费、持续消耗，还是不确定能不能换来价值。';
      case 'horse_expectation':
        return '可以先补一句：骑马让你期待的到底是身体活动、自由感，还是暂时离开日常压力。';
      case 'tomorrow_uncertainty':
        return '今天不用把明天想清楚，只选一件当下能好好做的小事就够了。';
      case 'retirement_wish':
        return '先不用立刻讨论退休，只补一句：最想离开的到底是工作量、节奏，还是长期没有恢复空间。';
      case 'weather_good':
        return '如果可以，今天留意一下：天气变好后，你更想散步、休息，还是做一点轻松的事。';
      case 'rest_wish':
        return '先给自己一个很小的恢复块：哪怕只是十分钟不输入、不处理、不回应。';
      case 'money':
        return '先记清楚这笔钱让你卡住的点：价格、必要性，还是付出之后的确定感。';
      default:
        return '先看看它之后还会不会再回来。';
    }
  }

  String _fallbackIntensity(String content) {
    final text = content.toLowerCase();

    final strongMarkers = [
      '一直',
      '总是',
      '反复',
      '受不了',
      '崩了',
      '特别',
      '非常',
      '真的',
      '很烦',
      '很累',
      'ずっと',
      'かなり',
      '本当に',
      'めちゃくちゃ',
      'very',
      'really',
      'extremely',
    ];
    final mediumMarkers = [
      '有点',
      '有一些',
      '有一点',
      '有些',
      '稍微',
      'ちょっと',
      '少し',
      'a bit',
      'kind of',
      'somewhat',
    ];

    if (strongMarkers.any(text.contains) ||
        content.contains('!') ||
        content.contains('！')) {
      return 'high';
    }
    if (mediumMarkers.any(text.contains) ||
        _fallbackEmotion(content) != 'neutral') {
      return 'medium';
    }
    return 'low';
  }

  List<String> _fallbackSceneTags(String content) {
    final text = content.toLowerCase();
    final scenes = <String>[];

    bool hit(List<String> keywords) => keywords.any(text.contains);

    if (hit([
      '上班',
      '开会',
      '同事',
      '老板',
      '需求',
      '任务',
      '公司',
      '工作',
      '邮件',
      '会议',
      '職場',
      '仕事',
      '会議',
      'task',
      'work',
      'meeting',
      'manager'
    ])) {
      scenes.add('work');
    }
    if (hit(
        ['通勤', '地铁', '电车', '路上', '回家路上', '出门', '満員電車', 'commute', 'train'])) {
      scenes.add('commute');
    }
    if (hit([
      '朋友',
      '家人',
      '恋人',
      '关系',
      '聊天',
      '人間関係',
      'family',
      'friend',
      'partner'
    ])) {
      scenes.add('relationship');
    }
    if (hit([
      '头疼',
      '困',
      '睡',
      '累',
      '身体',
      '胃',
      '不舒服',
      '健康',
      '体調',
      '眠い',
      'body',
      'health'
    ])) {
      scenes.add('body');
    }
    if (hit([
      '花钱',
      '工资',
      '金钱',
      '消费',
      '买',
      '预算',
      'token',
      '贵',
      '成本',
      '价格',
      'お金',
      '支出',
      'money',
      'budget',
      'cost',
      'spent'
    ])) {
      scenes.add('money');
    }
    if (hit([
      '明天',
      '未来',
      '预测',
      '当下',
      '明日',
      '予測',
      'tomorrow',
      'future',
      'present'
    ])) {
      scenes.add('future');
    }
    if (hit(['骑马', '乗馬', 'horse', 'ride'])) {
      scenes.add('hobby');
    }
    if (hit(
        ['休息', '放松', '睡觉', '午休', '恢复', '发呆', '散步', '休憩', 'rest', 'relax'])) {
      scenes.add('rest');
    }
    if (hit([
      '完成',
      '做完',
      '推进',
      '成果',
      '达成',
      '有进展',
      '進んだ',
      '達成',
      'finished',
      'done'
    ])) {
      scenes.add('achievement');
    }
    if (hit(['怀疑自己', '自我否定', '不够好', '没做好', '担心自己', '自信がない', 'self doubt'])) {
      scenes.add('self_doubt');
    }
    if (hit([
      '被打断',
      '重复',
      '麻烦',
      '卡住',
      '拖延',
      '琐事',
      '不顺',
      'interrupted',
      'blocked',
      'friction'
    ])) {
      scenes.add('daily_friction');
    }
    if (hit(['在家', '回家', '房间', '家里', '家务', '家', '家で', 'home'])) {
      scenes.add('home');
    }
    if (hit([
      '学习',
      '看书',
      '复习',
      '考试',
      '输出',
      '写作',
      '勉強',
      'study',
      'reading',
      'writing'
    ])) {
      scenes.add('study');
    }
    if (hit(
        ['吃饭', '好吃', '逛', '买东西', '天气', '散步', '咖啡', '食べた', 'lunch', 'coffee'])) {
      scenes.add('daily_life');
    }

    if (scenes.isEmpty) {
      return _fallbackEmotion(content) == 'negative'
          ? const ['daily_friction']
          : const ['daily_life'];
    }
    return scenes.take(3).toList();
  }

  List<String> _fallbackIntentTags(String content) {
    final emotion = _fallbackEmotion(content);
    final text = content.toLowerCase();
    final intents = <String>[];

    if (emotion == 'negative') intents.add('vent');
    if (emotion == 'positive') intents.add('celebrate');
    if (emotion == 'mixed') {
      intents.add('vent');
      intents.add('reflection');
    }
    if (intents.isEmpty) intents.add('record');

    if (['为什么', '是不是', '感觉', '好像', '也许', 'maybe', 'wonder', '気がする']
            .any(text.contains) &&
        !intents.contains('reflection')) {
      intents.add('reflection');
    }

    if (['要不要', '决定', '算了', 'whether', 'decide', '決める'].any(text.contains) &&
        !intents.contains('decision')) {
      intents.add('decision');
    }

    return intents.take(3).toList();
  }

  List<String> _parseStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      return trimmed
          .split(',')
          .map((e) => e.replaceAll('"', '').replaceAll("'", '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  WeeklyInsightModel _fallbackWeeklyInsight({
    required String weekStart,
    required String weekEnd,
    required List<Map<String, dynamic>> entries,
    required Map<String, int> dayCounts,
    required List<String> topTokens,
    required String language,
  }) {
    final displayLanguage = _normalizeLanguage(language);
    if (entries.isEmpty) {
      return WeeklyInsightModel(
        weekStart: weekStart,
        weekEnd: weekEnd,
        status: 'insufficient_data',
        keyInsight: null,
        patterns: const [],
        frictions: const [],
        bestAction: null,
        opportunitySnapshot: null,
        feedbackSubmitted: false,
        chartData: const [],
      );
    }

    final contents = _entryContents(entries);
    final topTokenText = _evidenceTopicFromEntries(
      contents: contents,
      topTokens: topTokens,
      fallback: _localized(
        displayLanguage,
        en: 'this week’s entries',
        zhHans: '本周记录',
        zhHant: '本週記錄',
        ja: '今週の記録',
      ),
      language: displayLanguage,
    );
    final peakDay = _resolvePeakDay(dayCounts);
    final confidenceLine = entries.length < 4
        ? _localized(
            displayLanguage,
            en: 'There are only a few Signal so far, so treat this as a temporary observation.',
            zhHans: '基于目前少量 Signal，先把它当成临时观察。',
            zhHant: '基於目前少量 Signal，先把它當成暫時觀察。',
            ja: '今は Signal がまだ少ないため、ひとまず暫定的な観察として扱います。',
          )
        : _localized(
            displayLanguage,
            en: 'There are enough Signal this week to begin looking at how this repeats.',
            zhHans: '这周已经有足够 Signal，可以先看它的重复方式。',
            zhHant: '這週已經有足夠 Signal，可以先看它的重複方式。',
            ja: '今週は十分な Signal があり、繰り返し方を見始められます。',
          );

    return WeeklyInsightModel(
      weekStart: weekStart,
      weekEnd: weekEnd,
      status: 'ready',
      keyInsight: _localized(
        displayLanguage,
        en: '$confidenceLine Start with “$topTokenText”; Signal were denser on $peakDay.',
        zhHans: '$confidenceLine 这周先看“$topTokenText”，$peakDay 的 Signal 更密集。',
        zhHant: '$confidenceLine 這週先看「$topTokenText」，$peakDay 的 Signal 更密集。',
        ja: '$confidenceLine まず「$topTokenText」を見てみましょう。$peakDay は Signal がより密でした。',
      ),
      patterns: [
        {
          'name': _localized(
            displayLanguage,
            en: 'This week’s observation: $topTokenText',
            zhHans: '本周小观察：$topTokenText',
            zhHant: '本週小觀察：$topTokenText',
            ja: '今週の小さな観察：$topTokenText',
          ),
          'summary': _localized(
            displayLanguage,
            en: '$confidenceLine Notice the situations in which it returns.',
            zhHans: '$confidenceLine 先看它在哪些场景里回来。',
            zhHant: '$confidenceLine 先看它在哪些場景裡再次出現。',
            ja: '$confidenceLine どんな場面で再び現れるかを見てみましょう。',
          ),
        },
        {
          'name': _localized(
            displayLanguage,
            en: 'Signal sources',
            zhHans: 'Signal 来源',
            zhHant: 'Signal 來源',
            ja: 'Signal の出所',
          ),
          'summary': _evidenceSummary(
            contents: contents,
            fallback: topTokenText,
            language: displayLanguage,
          ),
        },
      ],
      frictions: [
        {
          'name': _localized(
            displayLanguage,
            en: 'Possible drain this week',
            zhHans: '本周可能的消耗点',
            zhHant: '本週可能的消耗點',
            ja: '今週の負担になった可能性',
          ),
          'summary': _localized(
            displayLanguage,
            en: 'For now, notice the load around “$topTokenText”; this is not yet a conclusion.',
            zhHans: '目前先看“$topTokenText”带来的负担；还不需要当成结论。',
            zhHant: '目前先看「$topTokenText」帶來的負擔；還不需要當成結論。',
            ja: '今は「$topTokenText」に伴う負担を見てください。まだ結論ではありません。',
          ),
        },
      ],
      bestAction: _localized(
        displayLanguage,
        en: 'Try one small step: when a similar situation happens again, add one sentence about the context.',
        zhHans: '这周先试一步：下次再出现同类情况时，用一句话补记它发生在什么场景。',
        zhHant: '這週先試一步：下次再出現同類情況時，用一句話補記它發生在什麼場景。',
        ja: '今週は一歩だけ試しましょう。同じ状況が起きたら、どんな場面だったかを一文残してください。',
      ),
      opportunitySnapshot: {
        'name': _localized(
          displayLanguage,
          en: 'Keep the recurring Signal visible',
          zhHans: '把重复 Signal 固定下来',
          zhHant: '把重複 Signal 固定下來',
          ja: '繰り返す Signal を残す',
        ),
        'summary': _localized(
          displayLanguage,
          en: 'If the same kind of event keeps returning, it may be worth recording in a consistent way.',
          zhHans: '如果某类事情总是回来，它可能值得先被结构化记录。',
          zhHant: '如果某類事情總是再次出現，可能值得用固定方式記錄。',
          ja: '同じ種類の出来事が繰り返すなら、一定の形で記録する価値がありそうです。',
        ),
      },
      feedbackSubmitted: false,
      chartData: const [],
    );
  }

  MemorySummaryModel _fallbackJourneySummary({
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
    required String language,
  }) {
    final displayLanguage = _normalizeLanguage(language);
    final contents = _entryContents(entries);
    final topToken = _evidenceTopicFromEntries(
      contents: contents,
      topTokens: topTokens,
      fallback: _localized(
        displayLanguage,
        en: 'recent entries',
        zhHans: '最近的记录',
        zhHant: '最近的記錄',
        ja: '最近の記録',
      ),
      language: displayLanguage,
    );
    final confidence = entries.length < 6
        ? _localized(
            displayLanguage,
            en: 'This is still an early life trajectory',
            zhHans: '还只是早期生活轨迹',
            zhHant: '還只是早期生活軌跡',
            ja: 'まだ初期の生活軌跡です',
          )
        : _localized(
            displayLanguage,
            en: 'Longer-term clues are beginning to appear',
            zhHans: '已经开始有长期线索',
            zhHant: '已經開始有長期線索',
            ja: '長期的な手がかりが見え始めています',
          );

    return MemorySummaryModel(
      patterns: [
        JourneySignalItemModel(
          name: _localized(
            displayLanguage,
            en: 'An emerging life path',
            zhHans: '正在形成的生活路径',
            zhHant: '正在形成的生活路徑',
            ja: '形成されつつある生活の道筋',
          ),
          summary: _localized(
            displayLanguage,
            en: '$confidence. The clearest theme is “$topToken”. Notice whether it is occasional or slowly becoming a recurring structure.',
            zhHans: '$confidence：目前最清楚的是“$topToken”。先看它是偶尔出现，还是慢慢变成重复结构。',
            zhHant: '$confidence：目前最清楚的是「$topToken」。先看它是偶爾出現，還是慢慢變成重複結構。',
            ja: '$confidence。今もっとも明確なのは「$topToken」です。時々起きるだけなのか、繰り返す構造になりつつあるのかを見てみましょう。',
          ),
          signalLevel: totalDays >= 3 ? 'repeated_pattern' : 'weak_signal',
        ),
      ],
      frictions: [
        JourneySignalItemModel(
          name: _localized(
            displayLanguage,
            en: 'Possible longer-term drain',
            zhHans: '可能的长期消耗',
            zhHant: '可能的長期消耗',
            ja: '長期的な負担の可能性',
          ),
          summary: _localized(
            displayLanguage,
            en: 'If “$topToken” keeps appearing, it may be a source of drain worth reviewing later. For now, keep observing lightly.',
            zhHans: '如果“$topToken”继续出现，它可能是后面要回看的消耗来源；现在先保持小观察。',
            zhHant: '如果「$topToken」繼續出現，它可能是之後值得回看的消耗來源；現在先保持輕量觀察。',
            ja: '「$topToken」が続くなら、後で振り返るべき負担源かもしれません。今は軽く観察を続けましょう。',
          ),
          signalLevel: totalDays >= 4 ? 'stable_mode' : 'repeated_pattern',
        ),
      ],
      desires: [
        JourneySignalItemModel(
          name: _localized(
            displayLanguage,
            en: 'A direction still emerging',
            zhHans: '还在浮现的方向',
            zhHant: '仍在浮現的方向',
            ja: 'まだ浮かびつつある方向',
          ),
          summary: _localized(
            displayLanguage,
            en: 'The entries now span $totalDays days, and some longer-term priorities are slowly becoming visible.',
            zhHans: '记录已经跨越 $totalDays 天，一些真正长期在意的方向正在慢慢浮现。',
            zhHant: '記錄已跨越 $totalDays 天，一些真正長期在意的方向正在慢慢浮現。',
            ja: '記録は$totalDays日間にわたり、長期的に大切にしたい方向が少しずつ見え始めています。',
          ),
          signalLevel: totalDays >= 2 ? 'repeated_pattern' : 'weak_signal',
        ),
      ],
      experiments: [
        JourneySignalItemModel(
          name: _localized(
            displayLanguage,
            en: 'What is beginning to help',
            zhHans: '开始有帮助的东西',
            zhHant: '開始有幫助的做法',
            ja: '役立ち始めていること',
          ),
          summary: _localized(
            displayLanguage,
            en: 'Continuing to record will make it easier to see which approaches are not helpful by chance, but are becoming reliably useful.',
            zhHans: '继续记录下去，会更容易看见什么做法不是偶然有效，而是在慢慢变得有帮助。',
            zhHant: '繼續記錄下去，會更容易看見哪些做法不是偶然有效，而是在慢慢變得有幫助。',
            ja: '記録を続けると、偶然ではなく徐々に役立つようになっている方法が見えやすくなります。',
          ),
          signalLevel: totalDays >= 2 ? 'repeated_pattern' : 'weak_signal',
        ),
      ],
    );
  }

  List<String> _entryContents(List<Map<String, dynamic>> entries) {
    return entries
        .map((e) => (e['content'] ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _evidenceTopicFromEntries({
    required List<String> contents,
    required List<String> topTokens,
    required String fallback,
    required String language,
  }) {
    final joined = contents.join(' ');
    final topic = _topicHint(joined);
    switch (topic) {
      case 'cost':
        return _localized(
          language,
          en: 'usage cost',
          zhHans: '使用额度成本',
          zhHant: '使用額度成本',
          ja: '利用コスト',
        );
      case 'horse_expectation':
        return _localized(
          language,
          en: 'anticipation and restoration from horse riding',
          zhHans: '骑马带来的期待和恢复',
          zhHant: '騎馬帶來的期待與恢復',
          ja: '乗馬への期待と回復',
        );
      case 'tomorrow_uncertainty':
        return _localized(
          language,
          en: 'uncertainty about tomorrow and staying present',
          zhHans: '明天不可控与活在当下',
          zhHant: '明天不可控與活在當下',
          ja: '明日の不確実さと今を大切にすること',
        );
      case 'retirement_wish':
        return _localized(
          language,
          en: 'wanting to step away from work strain',
          zhHans: '想离开工作消耗',
          zhHant: '想離開工作消耗',
          ja: '仕事の消耗から離れたい気持ち',
        );
      case 'weather_good':
        return _localized(
          language,
          en: 'feeling lighter with good weather',
          zhHans: '天气带来的轻一点的状态',
          zhHant: '天氣帶來的輕鬆狀態',
          ja: '天気による軽い状態',
        );
      case 'rest_wish':
        return _localized(
          language,
          en: 'wanting to stop and rest',
          zhHans: '想停下来休息',
          zhHant: '想停下來休息',
          ja: '立ち止まって休みたい気持ち',
        );
      case 'money':
        return _localized(
          language,
          en: 'money and cost pressure',
          zhHans: '钱和成本压力',
          zhHant: '金錢與成本壓力',
          ja: 'お金とコストの負担',
        );
      default:
        return topTokens.isEmpty
            ? fallback
            : _readableToken(topTokens.first, language: language);
    }
  }

  String _evidenceSummary({
    required List<String> contents,
    required String fallback,
    required String language,
  }) {
    final samples = contents.take(2).toList();
    if (samples.isEmpty) {
      return _localized(
        language,
        en: 'There are still few Signal. Keep “$fallback” as something to observe.',
        zhHans: '目前 Signal 还少，先把“$fallback”作为待观察线索。',
        zhHant: '目前 Signal 還少，先把「$fallback」作為待觀察線索。',
        ja: 'まだ Signal が少ないため、「$fallback」を観察する手がかりとして残します。',
      );
    }
    if (samples.length == 1) {
      return _localized(
        language,
        en: 'This currently comes mainly from one entry: “${_truncateEvidence(samples.first)}”. Avoid over-interpreting it yet.',
        zhHans: '目前主要来自一条记录：“${_truncateEvidence(samples.first)}”。先不要过度判断。',
        zhHant: '目前主要來自一條記錄：「${_truncateEvidence(samples.first)}」。先不要過度判斷。',
        ja: '今のところ主に1件の記録「${_truncateEvidence(samples.first)}」に基づいています。まだ解釈しすぎないでください。',
      );
    }
    return _localized(
      language,
      en: 'This currently comes mainly from “${_truncateEvidence(samples[0], 18)}” and “${_truncateEvidence(samples[1], 18)}”. Notice whether they recur.',
      zhHans:
          '目前主要来自这些记录：“${_truncateEvidence(samples[0], 18)}”和“${_truncateEvidence(samples[1], 18)}”。先看它们是否还会重复。',
      zhHant:
          '目前主要來自這些記錄：「${_truncateEvidence(samples[0], 18)}」和「${_truncateEvidence(samples[1], 18)}」。先看它們是否還會重複。',
      ja: '今のところ主に「${_truncateEvidence(samples[0], 18)}」と「${_truncateEvidence(samples[1], 18)}」から見えています。繰り返すかを見てみましょう。',
    );
  }

  String _truncateEvidence(String value, [int maxLength = 28]) {
    final trimmed = value.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength)}…';
  }

  MonthlyReviewModel _fallbackMonthlyReview({
    required String monthStart,
    required String monthEnd,
    required List<Map<String, dynamic>> entries,
    required List<String> topTokens,
    required int totalDays,
    required String language,
  }) {
    final displayLanguage = _normalizeLanguage(language);
    final topToken = topTokens.isEmpty
        ? _localized(
            displayLanguage,
            en: 'this month’s entries',
            zhHans: '这个月的记录',
            zhHant: '這個月的記錄',
            ja: '今月の記録',
          )
        : _readableToken(topTokens.first, language: displayLanguage);
    final repeated = topTokens
        .take(3)
        .map((token) => _readableToken(token, language: displayLanguage))
        .toList();
    final week1Count = entries.isEmpty ? 0 : entries.length;

    return MonthlyReviewModel(
      monthStart: monthStart,
      monthEnd: monthEnd,
      status: entries.isEmpty ? 'insufficient_data' : 'ready',
      monthlySummary: _localized(
        displayLanguage,
        en: 'This month’s entries repeatedly returned to “$topToken”, suggesting it is more than a one-off fluctuation.',
        zhHans: '这个月的记录反复围绕“$topToken”回来，说明它已经不是偶发的小波动。',
        zhHant: '這個月的記錄反覆圍繞「$topToken」出現，顯示它已不只是偶發波動。',
        ja: '今月の記録は「$topToken」を繰り返し示しており、一時的な揺れだけではなさそうです。',
      ),
      repeatedThemes: repeated.isEmpty
          ? [
              _localized(
                displayLanguage,
                en: 'Recurring themes are beginning to appear this month.',
                zhHans: '这个月已经开始出现重复主题。',
                zhHant: '這個月已開始出現重複主題。',
                ja: '今月は繰り返すテーマが見え始めています。',
              ),
            ]
          : repeated
              .map(
                (e) => _localized(
                  displayLanguage,
                  en: '“$e” appeared repeatedly.',
                  zhHans: '“$e” 反复出现。',
                  zhHant: '「$e」反覆出現。',
                  ja: '「$e」が繰り返し現れました。',
                ),
              )
              .toList(),
      improvingSignals: [
        _localized(
          displayLanguage,
          en: 'Some ways of recovering are gradually becoming more consistent.',
          zhHans: '有些恢复方式正在慢慢变得更稳定。',
          zhHant: '有些恢復方式正在慢慢變得更穩定。',
          ja: '回復につながる方法の一部が少しずつ安定してきています。',
        ),
      ],
      unresolvedPoints: [
        _localized(
          displayLanguage,
          en: 'High-drain situations have not yet been separated clearly enough to understand.',
          zhHans: '高消耗场景还没有真正被拆开看清。',
          zhHant: '高消耗場景還沒有真正被拆開看清。',
          ja: '負担の大きい場面は、まだ十分に分けて捉えられていません。',
        ),
      ],
      nextMonthWatch: _localized(
        displayLanguage,
        en: 'Next month, notice which types of situations most often trigger the first sign of strain.',
        zhHans: '下个月先继续看，哪一类场景最容易触发第一下消耗。',
        zhHant: '下個月先繼續看，哪一類場景最容易觸發最初的消耗。',
        ja: '来月は、どの場面が最初の消耗を起こしやすいかを見てみましょう。',
      ),
      weeklyBridges: [
        MonthlyBridgeWeekModel(
          label: _localized(
            displayLanguage,
            en: 'Week 1',
            zhHans: '第 1 周',
            zhHant: '第 1 週',
            ja: '第1週',
          ),
          summary: _localized(
            displayLanguage,
            en: '$week1Count entries contributed to this month’s main observation.',
            zhHans: '$week1Count 条记录落在这个月的主要观察里。',
            zhHant: '$week1Count 條記錄納入這個月的主要觀察。',
            ja: '$week1Count件の記録が今月の主な観察につながりました。',
          ),
        ),
      ],
    );
  }

  String _resolvePeakDay(Map<String, int> dayCounts) {
    if (dayCounts.isEmpty) return '这周';
    return dayCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _readableToken(
    String token, {
    String? language,
  }) {
    final normalized = token
        .replaceAll(RegExp(r'^[\[\("“]+|[\]\)"”]+$'), '')
        .replaceAll('_', ' ')
        .trim()
        .toLowerCase();
    const zhHansLabels = {
      'planning': '安排',
      'work': '工作',
      'relationship': '关系',
      'relations': '关系',
      'boundary': '边界',
      'boundaries': '边界',
      'recovery': '恢复',
      'rest': '休息',
      'sleep': '睡眠',
      'body': '身体',
      'energy': '能量',
      'attention': '注意力',
      'switching': '切换',
      'schedule': '日程',
      'schedule density': '安排密度',
      'care load': '照顾负荷',
      'limited buffer': '缓冲不足',
      'buffer': '缓冲',
      'weather': '天气',
      'commute': '通勤',
      'home': '家里',
      'daily friction': '日常摩擦',
      'daily life': '日常生活',
    };
    final zhHans = zhHansLabels[normalized];
    if (zhHans == null) return token.trim();
    final displayLanguage = _normalizeLanguage(language ?? languageLoader());
    const enLabels = {
      'planning': 'planning',
      'work': 'work',
      'relationship': 'relationships',
      'relations': 'relationships',
      'boundary': 'boundaries',
      'boundaries': 'boundaries',
      'recovery': 'recovery',
      'rest': 'rest',
      'sleep': 'sleep',
      'body': 'body',
      'energy': 'energy',
      'attention': 'attention',
      'switching': 'switching',
      'schedule': 'schedule',
      'schedule density': 'schedule density',
      'care load': 'care load',
      'limited buffer': 'limited buffer',
      'buffer': 'buffer',
      'weather': 'weather',
      'commute': 'commute',
      'home': 'home',
      'daily friction': 'daily friction',
      'daily life': 'daily life',
    };
    const jaLabels = {
      'planning': '予定',
      'work': '仕事',
      'relationship': '人間関係',
      'relations': '人間関係',
      'boundary': '境界',
      'boundaries': '境界',
      'recovery': '回復',
      'rest': '休息',
      'sleep': '睡眠',
      'body': '身体',
      'energy': 'エネルギー',
      'attention': '注意力',
      'switching': '切り替え',
      'schedule': '予定',
      'schedule density': '予定の密度',
      'care load': 'ケアの負担',
      'limited buffer': '余白不足',
      'buffer': '余白',
      'weather': '天気',
      'commute': '通勤',
      'home': '家',
      'daily friction': '日常の摩擦',
      'daily life': '日常生活',
    };
    const zhHantLabels = {
      'planning': '安排',
      'work': '工作',
      'relationship': '關係',
      'relations': '關係',
      'boundary': '界線',
      'boundaries': '界線',
      'recovery': '恢復',
      'rest': '休息',
      'sleep': '睡眠',
      'body': '身體',
      'energy': '精力',
      'attention': '注意力',
      'switching': '切換',
      'schedule': '日程',
      'schedule density': '安排密度',
      'care load': '照顧負荷',
      'limited buffer': '緩衝不足',
      'buffer': '緩衝',
      'weather': '天氣',
      'commute': '通勤',
      'home': '家裡',
      'daily friction': '日常摩擦',
      'daily life': '日常生活',
    };
    return switch (displayLanguage) {
      'en' => enLabels[normalized] ?? token.trim(),
      'ja' => jaLabels[normalized] ?? token.trim(),
      'zh-Hant' => zhHantLabels[normalized] ?? token.trim(),
      _ => zhHans,
    };
  }

  String _normalizeLanguage(String? language) {
    final normalized = language?.trim().toLowerCase().replaceAll('_', '-');
    if (normalized == null || normalized.isEmpty) return 'en';
    if (normalized.startsWith('ja')) return 'ja';
    if (normalized.startsWith('en')) return 'en';
    if (const {'zh-hant', 'zh-tw', 'zh-hk', 'zh-mo'}.contains(normalized)) {
      return 'zh-Hant';
    }
    if (normalized.startsWith('zh')) return 'zh-Hans';
    return 'en';
  }

  String _localized(
    String language, {
    required String en,
    required String zhHans,
    required String zhHant,
    required String ja,
  }) {
    return switch (_normalizeLanguage(language)) {
      'zh-Hans' => zhHans,
      'zh-Hant' => zhHant,
      'ja' => ja,
      _ => en,
    };
  }
}
