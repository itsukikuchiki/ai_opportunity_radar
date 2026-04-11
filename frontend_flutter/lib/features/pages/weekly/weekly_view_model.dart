import 'package:flutter/foundation.dart';

import '../../../core/api/repositories/weekly_repository.dart';
import '../../../core/models/weekly_models.dart';
import '../../../shared/states/load_state.dart';

class WeeklyViewModel extends ChangeNotifier {
  final WeeklyRepository repository;

  LoadState loadState = LoadState.initial;
  SubmitState feedbackSubmitState = SubmitState.idle;
  WeeklyInsightModel? weeklyInsight;
  String? errorMessage;

  bool usingMockData = false;

  WeeklyViewModel(this.repository) {
    load();
  }

  Future<void> load() async {
    usingMockData = false;
    loadState = LoadState.loading;
    errorMessage = null;
    feedbackSubmitState = SubmitState.idle;
    notifyListeners();

    try {
      weeklyInsight = await repository.fetchCurrentWeekly();
      loadState = (weeklyInsight?.status == 'insufficient_data' || weeklyInsight?.status == 'not_started')
          ? LoadState.empty
          : LoadState.ready;
    } catch (e) {
      errorMessage = e.toString();
      loadState = LoadState.error;
    }

    notifyListeners();
  }

  Future<void> retry() => load();

  void toggleMockRichState() {
    if (usingMockData) {
      load();
      return;
    }

    usingMockData = true;
    feedbackSubmitState = SubmitState.idle;
    errorMessage = null;

    final language = _resolveLanguage();
    weeklyInsight = _mockWeeklyInsight(language);

    loadState = LoadState.ready;
    notifyListeners();
  }

  Future<void> submitFeedback(String value) async {
    final weekly = weeklyInsight;
    if (weekly == null) return;

    if (usingMockData) {
      feedbackSubmitState = SubmitState.success;
      weeklyInsight = WeeklyInsightModel(
        weekStart: weekly.weekStart,
        weekEnd: weekly.weekEnd,
        status: weekly.status,
        keyInsight: weekly.keyInsight,
        patterns: weekly.patterns,
        frictions: weekly.frictions,
        bestAction: weekly.bestAction,
        opportunitySnapshot: weekly.opportunitySnapshot,
        feedbackSubmitted: true,
      );
      notifyListeners();
      return;
    }

    feedbackSubmitState = SubmitState.submitting;
    errorMessage = null;
    notifyListeners();

    try {
      await repository.submitWeeklyFeedback(
        weekStart: weekly.weekStart,
        feedbackValue: value,
      );

      feedbackSubmitState = SubmitState.success;
      weeklyInsight = WeeklyInsightModel(
        weekStart: weekly.weekStart,
        weekEnd: weekly.weekEnd,
        status: weekly.status,
        keyInsight: weekly.keyInsight,
        patterns: weekly.patterns,
        frictions: weekly.frictions,
        bestAction: weekly.bestAction,
        opportunitySnapshot: weekly.opportunitySnapshot,
        feedbackSubmitted: true,
      );
    } catch (e) {
      feedbackSubmitState = SubmitState.failure;
      errorMessage = e.toString();
    }

    notifyListeners();
  }

  _VmLanguage _resolveLanguage() {
    final locale = PlatformDispatcher.instance.locale;
    final languageCode = locale.languageCode.toLowerCase();
    final scriptCode = locale.scriptCode?.toLowerCase();
    final countryCode = locale.countryCode?.toUpperCase();

    if (languageCode == 'ja') {
      return _VmLanguage.japanese;
    }

    if (languageCode == 'zh') {
      final isTraditional =
          scriptCode == 'hant' ||
          countryCode == 'TW' ||
          countryCode == 'HK' ||
          countryCode == 'MO';
      return isTraditional
          ? _VmLanguage.traditionalChinese
          : _VmLanguage.simplifiedChinese;
    }

    return _VmLanguage.english;
  }

  WeeklyInsightModel _mockWeeklyInsight(_VmLanguage language) {
    switch (language) {
      case _VmLanguage.simplifiedChinese:
        return WeeklyInsightModel(
          weekStart: '2026-03-23',
          weekEnd: '2026-03-29',
          status: 'ready',
          keyInsight:
              '你这周的消耗不只是“事情多”，而是“被打断、重复确认、替别人收尾”这几类摩擦在反复切走心力。',
          patterns: const [
            {
              'name': '重复整理信息',
              'summary': '聊天、会议和零散信息经常需要重新收口，说明信息落点还没有固定下来。'
            },
            {
              'name': '反复确认顺序',
              'summary': '只要计划一变化，你就会花时间重新确认先后顺序和对象。'
            },
            {
              'name': '偶尔也有让你松一点的时刻',
              'summary': '并不全是消耗，有几次记录也显示某些小事确实能让你缓下来一点。'
            },
          ],
          frictions: const [
            {
              'name': '节奏被打断',
              'summary': '问题不只在任务量，而在于开始之后又不断被切走上下文。'
            },
            {
              'name': '替别人收尾',
              'summary': '有些原本不该落到你这里的问题，最后还是变成了你的消耗。'
            },
            {
              'name': '疲惫感在叠加',
              'summary': '小摩擦反复出现后，累的感觉会比事情本身更先压上来。'
            },
          ],
          bestAction: '本周先只试一步：把最常重复确认的一类事情，固定成一个最小模板。',
          opportunitySnapshot: const {
            'name': '确认流程模板化',
            'summary': '如果你总在重新确认顺序和对象，这类动作很适合先做成固定模板。'
          },
          feedbackSubmitted: false,
        );
      case _VmLanguage.traditionalChinese:
        return WeeklyInsightModel(
          weekStart: '2026-03-23',
          weekEnd: '2026-03-29',
          status: 'ready',
          keyInsight:
              '你這週的消耗不只是「事情多」，而是「被打斷、重複確認、替別人收尾」這幾類摩擦在反覆切走心力。',
          patterns: const [
            {
              'name': '重複整理資訊',
              'summary': '聊天、會議和零散資訊經常需要重新收口，說明資訊落點還沒有固定下來。'
            },
            {
              'name': '反覆確認順序',
              'summary': '只要計畫一變化，你就會花時間重新確認先後順序和對象。'
            },
            {
              'name': '偶爾也有讓你鬆一點的時刻',
              'summary': '並不全是消耗，有幾次記錄也顯示某些小事確實能讓你緩下來一點。'
            },
          ],
          frictions: const [
            {
              'name': '節奏被打斷',
              'summary': '問題不只在任務量，而在於開始之後又不斷被切走上下文。'
            },
            {
              'name': '替別人收尾',
              'summary': '有些原本不該落到你這裡的問題，最後還是變成了你的消耗。'
            },
            {
              'name': '疲憊感在疊加',
              'summary': '小摩擦反覆出現後，累的感覺會比事情本身更先壓上來。'
            },
          ],
          bestAction: '本週先只試一步：把最常重複確認的一類事情，固定成一個最小模板。',
          opportunitySnapshot: const {
            'name': '確認流程模板化',
            'summary': '如果你總在重新確認順序和對象，這類動作很適合先做成固定模板。'
          },
          feedbackSubmitted: false,
        );
      case _VmLanguage.japanese:
        return WeeklyInsightModel(
          weekStart: '2026-03-23',
          weekEnd: '2026-03-29',
          status: 'ready',
          keyInsight:
              '今週の消耗は単に「やることが多い」だけではなく、「中断されること・確認し直すこと・人の後始末をすること」が繰り返し心力を削っていた点にあります。',
          patterns: const [
            {
              'name': '情報を整理し直している',
              'summary': 'チャットや会議、ばらけた情報を何度もまとめ直していて、情報の着地点がまだ固定されていません。'
            },
            {
              'name': '順番を何度も確認し直している',
              'summary': '予定が少し変わるたびに、順番や相手をもう一度確認する時間が発生しています。'
            },
            {
              'name': '少し楽になる瞬間もある',
              'summary': '消耗ばかりではなく、少し気持ちがゆるむ小さな瞬間もいくつかありました。'
            },
          ],
          frictions: const [
            {
              'name': 'リズムが中断される',
              'summary': '問題は作業量だけでなく、始めたあとに何度も文脈が切られていることです。'
            },
            {
              'name': '人の後始末をしている',
              'summary': '本来は自分の役割ではないことが、結局こちらの消耗になっていました。'
            },
            {
              'name': '疲れが積み上がっている',
              'summary': '小さな摩擦が続いたあと、作業そのものより先に疲れが前面に出ています。'
            },
          ],
          bestAction: '今週はまず一歩だけ。いちばん繰り返し確認している種類のことを、小さなテンプレートにしてみてください。',
          opportunitySnapshot: const {
            'name': '確認フローのテンプレート化',
            'summary': '順番や相手を何度も確認しているなら、その流れはテンプレート化の候補です。'
          },
          feedbackSubmitted: false,
        );
      case _VmLanguage.english:
        return WeeklyInsightModel(
          weekStart: '2026-03-23',
          weekEnd: '2026-03-29',
          status: 'ready',
          keyInsight:
              'The drain this week was not only “too much to do,” but repeated interruption, re-confirmation, and cleanup that should not have landed on you.',
          patterns: const [
            {
              'name': 'Re-organizing information',
              'summary': 'Chats, meetings, and scattered notes kept needing another pass, which suggests information still is not landing in one stable place.'
            },
            {
              'name': 'Re-confirming order and ownership',
              'summary': 'As soon as plans shifted, extra time went into confirming sequence and who was doing what.'
            },
            {
              'name': 'A few moments did make things lighter',
              'summary': 'Not all signals were draining. A few entries suggest some small things genuinely helped you loosen up.'
            },
          ],
          frictions: const [
            {
              'name': 'Interrupted rhythm',
              'summary': 'The issue was not only workload, but how often your context got cut after you had already started.'
            },
            {
              'name': 'Cleaning up after others',
              'summary': 'Some issues that should not have landed with you still turned into your cost.'
            },
            {
              'name': 'Fatigue stacking up',
              'summary': 'After repeated small frictions, tiredness started arriving before the task itself was even the main problem.'
            },
          ],
          bestAction:
              'Try just one step this week: turn the one thing you keep re-confirming into a very small template.',
          opportunitySnapshot: const {
            'name': 'Template the confirmation flow',
            'summary': 'If sequence and ownership keep getting re-confirmed, that flow is a strong candidate for templating first.'
          },
          feedbackSubmitted: false,
        );
    }
  }
}

enum _VmLanguage {
  english,
  simplifiedChinese,
  traditionalChinese,
  japanese,
}
