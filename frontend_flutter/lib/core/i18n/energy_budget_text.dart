import 'package:flutter/material.dart';

import '../preferences/focus_domains.dart';
import 'app_locale_text.dart';

/// Presentation-only localization for Energy Budget taxonomy values.
///
/// Signal Cards deliberately keep their stable machine keys (for example
/// `context_switching` and `small_start`). Generated copy may quote those keys
/// or embed a snake_case key directly, so this helper converts them only at
/// render time and never mutates stored signals or analysis inputs. Ordinary
/// unquoted English prose is intentionally left untouched.
class EnergyBudgetText {
  const EnergyBudgetText._();

  static String localizeCopy(BuildContext context, String copy) {
    final trimmed = copy.trim();
    if (trimmed.isEmpty) return copy;

    final normalized = _normalizeMachineToken(trimmed);
    final exactFocusDomain = FocusDomains.optionFor(normalized);
    if (exactFocusDomain != null) return exactFocusDomain.label(context);

    final exact = _labels[normalized] ?? _labels[trimmed.toLowerCase()];
    if (exact != null) return _resolve(context, exact);

    var result = _localizeKnownPhrases(context, copy);
    for (final entry in _labels.entries) {
      final localized = _resolve(context, entry.value);
      for (final alias in _quotedAliases(entry.key)) {
        for (final quotes in _quotePairs) {
          result = result.replaceAll(
            RegExp(
              '${RegExp.escape(quotes.$1)}${RegExp.escape(alias)}'
              '${RegExp.escape(quotes.$2)}',
              caseSensitive: false,
            ),
            '${quotes.$1}$localized${quotes.$2}',
          );
        }
      }
      if (_isMachineShaped(entry.key) ||
          _alwaysReplaceInternalTokens.contains(entry.key)) {
        result = result.replaceAll(
          RegExp(
            '\\b${RegExp.escape(entry.key)}\\b',
            caseSensitive: false,
          ),
          localized,
        );
      }
    }
    for (final option in FocusDomains.options) {
      final localized = option.label(context);
      for (final alias in _quotedAliases(option.id)) {
        for (final quotes in _quotePairs) {
          result = result.replaceAll(
            RegExp(
              '${RegExp.escape(quotes.$1)}${RegExp.escape(alias)}'
              '${RegExp.escape(quotes.$2)}',
              caseSensitive: false,
            ),
            '${quotes.$1}$localized${quotes.$2}',
          );
        }
      }
      result = result.replaceAll(
        RegExp(
          '\\b${RegExp.escape(option.id)}\\b',
          caseSensitive: false,
        ),
        localized,
      );
    }
    return _replaceUnknownMachineKeys(context, result);
  }

  static String _normalizeMachineToken(String value) =>
      value.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

  static bool _isMachineShaped(String value) =>
      value.contains('_') || value.contains('-');

  static Set<String> _quotedAliases(String value) => {
        value,
        if (value.contains('_')) value.replaceAll('_', ' '),
        if (value.contains('_')) value.replaceAll('_', '-'),
      };

  static const _alwaysReplaceInternalTokens = <String>{
    'draining',
    'steady',
    'ease',
    'restoring',
    'resourced',
    'communication',
    'scheduling',
    'execution',
    'coordination',
    'vent',
    'celebrate',
    'reflection',
    'unknown',
    'other',
    'positive',
    'negative',
    'neutral',
    'mixed',
    'clear',
    'unclear',
    'helpful',
    'completed',
  };

  static String _replaceUnknownMachineKeys(
    BuildContext context,
    String value,
  ) {
    return value.replaceAllMapped(
      RegExp(r'\b[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)+\b'),
      (match) {
        final token = match.group(0) ?? '';
        if (token.toLowerCase() == 'signal_path') return 'Signal Path';
        return switch (AppLocaleText.resolve(context)) {
          AppLanguage.simplifiedChinese => '其他线索',
          AppLanguage.traditionalChinese => '其他線索',
          AppLanguage.japanese => 'その他の手がかり',
          AppLanguage.english => token.replaceAll('_', ' '),
        };
      },
    );
  }

  static String _localizeKnownPhrases(BuildContext context, String value) {
    var result = value;
    for (final entry in _phrases.entries) {
      result = result.replaceAll(
        RegExp(RegExp.escape(entry.key), caseSensitive: false),
        _resolve(context, entry.value),
      );
    }
    return result;
  }

  static String _resolve(BuildContext context, _LocalizedTaxonomyLabel label) {
    return AppLocaleText.tr(
      context,
      en: label.en,
      zhHans: label.zhHans,
      zhHant: label.zhHant,
      ja: label.ja,
    );
  }

  static const _quotePairs = <(String, String)>[
    ('“', '”'),
    ('"', '"'),
    ("'", "'"),
    ('「', '」'),
    ('『', '』'),
  ];

  static const _phrases = <String, _LocalizedTaxonomyLabel>{
    'Sleep recovery signals may be a little light.': _LocalizedTaxonomyLabel(
      'Sleep recovery signals may be a little light.',
      '睡眠带来的恢复可能有些不足。',
      '睡眠帶來的恢復可能有些不足。',
      '睡眠による回復が少し弱いかもしれません。',
    ),
    'Sleep recovery signals look relatively steady.': _LocalizedTaxonomyLabel(
      'Sleep recovery signals look relatively steady.',
      '睡眠带来的恢复相对平稳。',
      '睡眠帶來的恢復相對平穩。',
      '睡眠による回復は比較的安定しています。',
    ),
    'Movement recovery signals may be quieter in this period.':
        _LocalizedTaxonomyLabel(
      'Movement recovery signals may be quieter in this period.',
      '这段时间，活动带来的恢复线索较少。',
      '這段時間，活動帶來的恢復線索較少。',
      'この期間は、活動による回復の手がかりが少なめです。',
    ),
    'Movement may be offering some recovery support.': _LocalizedTaxonomyLabel(
      'Movement may be offering some recovery support.',
      '活动可能正在帮助恢复。',
      '活動可能正在幫助恢復。',
      '活動が回復を支えている可能性があります。',
    ),
    'Workout load may ask for a little more recovery room.':
        _LocalizedTaxonomyLabel(
      'Workout load may ask for a little more recovery room.',
      '近期运动负担较高，可能需要多留一点恢复空间。',
      '近期運動負擔較高，可能需要多留一點恢復空間。',
      '最近の運動負荷を考えると、回復の余白を少し増やせそうです。',
    ),
    'Workout load does not look like the main pressure signal.':
        _LocalizedTaxonomyLabel(
      'Workout load does not look like the main pressure signal.',
      '运动负担目前不像主要压力来源。',
      '運動負擔目前不像主要壓力來源。',
      '運動負荷は今のところ主な負担ではなさそうです。',
    ),
    'Recovery signals may be a little weak in this stretch.':
        _LocalizedTaxonomyLabel(
      'Recovery signals may be a little weak in this stretch.',
      '这段时间的恢复线索可能偏弱。',
      '這段時間的恢復線索可能偏弱。',
      'この期間は回復の手がかりが少し弱いかもしれません。',
    ),
    'Recovery signals may be a little weak.': _LocalizedTaxonomyLabel(
      'Recovery signals may be a little weak.',
      '近期的恢复线索可能偏弱。',
      '近期的恢復線索可能偏弱。',
      '最近は回復の手がかりが少し弱いかもしれません。',
    ),
    'This period may be a good place to leave some recovery space.':
        _LocalizedTaxonomyLabel(
      'This period may be a good place to leave some recovery space.',
      '这段时间可以多留一点恢复空间。',
      '這段時間可以多留一點恢復空間。',
      'この期間は回復の余白を少し残せそうです。',
    ),
    'Recovery signals look relatively stable in this stretch.':
        _LocalizedTaxonomyLabel(
      'Recovery signals look relatively stable in this stretch.',
      '这段时间的恢复线索相对平稳。',
      '這段時間的恢復線索相對平穩。',
      'この期間の回復の手がかりは比較的安定しています。',
    ),
    'Health hints are only gentle recovery context. Your Signal Cards stay at the center.':
        _LocalizedTaxonomyLabel(
      'Health hints are only gentle recovery context. Your Signal Cards stay at the center.',
      '健康线索只提供辅助恢复信息，仍以你记录的信号卡为主。',
      '健康線索只提供輔助恢復資訊，仍以你記錄的信號卡為主。',
      '健康の手がかりは回復の補助情報であり、中心は自分で記録したシグナルカードです。',
    ),
    'Health access is optional. Energy Budget can keep using your internal Signal Card observations.':
        _LocalizedTaxonomyLabel(
      'Health access is optional. Energy Budget can keep using your internal Signal Card observations.',
      '健康权限是可选的；能量预算仍会使用你在应用内记录的信号卡。',
      '健康權限是選用的；能量預算仍會使用你在應用程式內記錄的信號卡。',
      '健康アクセスは任意です。エネルギー予算は引き続きアプリ内のシグナルカードを使います。',
    ),
    'Health recovery hints can add gentle context, while your Signal Cards stay at the center.':
        _LocalizedTaxonomyLabel(
      'Health recovery hints can add gentle context, while your Signal Cards stay at the center.',
      '健康恢复线索只提供温和的辅助信息，仍以你记录的信号卡为主。',
      '健康恢復線索只提供溫和的輔助資訊，仍以你記錄的信號卡為主。',
      '健康の回復に関する手がかりは補助情報であり、中心は自分で記録したシグナルカードです。',
    ),
    'Health recovery hints are unavailable right now. Energy Budget can still use your internal Signal Card observations.':
        _LocalizedTaxonomyLabel(
      'Health recovery hints are unavailable right now. Energy Budget can still use your internal Signal Card observations.',
      '健康恢复线索暂时不可用；能量预算仍会使用你在应用内记录的信号卡。',
      '健康恢復線索暫時無法使用；能量預算仍會使用你在應用程式內記錄的信號卡。',
      '健康の回復に関する手がかりは現在利用できません。エネルギー配分は引き続きアプリ内のシグナルカードを使います。',
    ),
    'You can keep Health access off. Energy Budget still works from your own Signal Card observations.':
        _LocalizedTaxonomyLabel(
      'You can keep Health access off. Energy Budget still works from your own Signal Card observations.',
      '你可以不启用健康权限；能量预算仍会使用你自己的信号卡。',
      '你可以不啟用健康權限；能量預算仍會使用你自己的信號卡。',
      '健康アクセスは無効のままで構いません。エネルギー配分は自分で記録したシグナルカードから引き続き利用できます。',
    ),
    'Health access is optional. Energy Budget works from internal Signal Card observations first.':
        _LocalizedTaxonomyLabel(
      'Health access is optional. Energy Budget works from internal Signal Card observations first.',
      '健康权限是可选的；能量预算会优先使用应用内的信号卡。',
      '健康權限是選用的；能量預算會優先使用應用程式內的信號卡。',
      '健康アクセスは任意です。エネルギー配分はまずアプリ内のシグナルカードを使います。',
    ),
    'Calendar hints are only gentle context. Your Signal Cards stay at the center.':
        _LocalizedTaxonomyLabel(
      'Calendar hints are only gentle context. Your Signal Cards stay at the center.',
      '日程线索只提供温和的辅助信息，仍以你记录的信号卡为主。',
      '日程線索只提供溫和的輔助資訊，仍以你記錄的信號卡為主。',
      'カレンダーの手がかりは補助情報であり、中心は自分で記録したシグナルカードです。',
    ),
    'Calendar access is optional. Energy Budget can keep using your internal Signal Card observations.':
        _LocalizedTaxonomyLabel(
      'Calendar access is optional. Energy Budget can keep using your internal Signal Card observations.',
      '日程权限是可选的；能量预算仍会使用你在应用内记录的信号卡。',
      '日程權限是選用的；能量預算仍會使用你在應用程式內記錄的信號卡。',
      'カレンダーへのアクセスは任意です。エネルギー配分は引き続きアプリ内のシグナルカードを使います。',
    ),
  };

  static const _labels = <String, _LocalizedTaxonomyLabel>{
    // Scenes.
    'work': _LocalizedTaxonomyLabel('work', '工作', '工作', '仕事'),
    'home': _LocalizedTaxonomyLabel('home', '居家', '居家', '家庭'),
    'planning': _LocalizedTaxonomyLabel('planning', '计划安排', '計畫安排', '計画'),
    'recovery': _LocalizedTaxonomyLabel('recovery', '恢复', '恢復', '回復'),
    'relationship':
        _LocalizedTaxonomyLabel('relationships', '关系', '關係', '人間関係'),
    'emotional': _LocalizedTaxonomyLabel('emotions', '情绪', '情緒', '感情'),
    'sleep': _LocalizedTaxonomyLabel('sleep', '睡眠', '睡眠', '睡眠'),
    'daily_life': _LocalizedTaxonomyLabel('daily life', '日常生活', '日常生活', '日常生活'),
    'commute': _LocalizedTaxonomyLabel('commute', '通勤', '通勤', '移動'),
    'household': _LocalizedTaxonomyLabel('household', '家务', '家務', '家事'),
    'schedule': _LocalizedTaxonomyLabel('schedule', '安排', '安排', '予定'),
    'arrangement': _LocalizedTaxonomyLabel('schedule', '安排', '安排', '予定'),
    'emotion': _LocalizedTaxonomyLabel('emotion', '情绪', '情緒', '感情'),
    'mood': _LocalizedTaxonomyLabel('mood', '情绪', '情緒', '気分'),
    'body': _LocalizedTaxonomyLabel('body', '身体', '身體', '身体'),
    'money': _LocalizedTaxonomyLabel('money', '金钱', '金錢', 'お金'),
    'future': _LocalizedTaxonomyLabel('future', '未来', '未來', '未来'),
    'hobby': _LocalizedTaxonomyLabel('hobby', '兴趣', '興趣', '趣味'),
    'rest': _LocalizedTaxonomyLabel('rest', '休息', '休息', '休息'),
    'achievement': _LocalizedTaxonomyLabel('achievement', '成就', '成就', '達成'),
    'self_doubt':
        _LocalizedTaxonomyLabel('self-doubt', '自我怀疑', '自我懷疑', '自信の揺らぎ'),
    'daily_friction':
        _LocalizedTaxonomyLabel('daily friction', '日常摩擦', '日常摩擦', '日常の摩擦'),
    'study': _LocalizedTaxonomyLabel('study', '学习', '學習', '学習'),

    // Frictions.
    'context_switching': _LocalizedTaxonomyLabel(
      'frequent context switching',
      '频繁切换',
      '頻繁切換',
      '頻繁な切り替え',
    ),
    'context_switch':
        _LocalizedTaxonomyLabel('context switching', '情境切换', '情境切換', '文脈の切り替え'),
    'task_switching':
        _LocalizedTaxonomyLabel('task switching', '任务切换', '任務切換', 'タスク切り替え'),
    'current_switching': _LocalizedTaxonomyLabel(
      'current switching load',
      '当前切换负荷',
      '目前切換負荷',
      '現在の切り替え負荷',
    ),
    'meeting_switch': _LocalizedTaxonomyLabel(
        'meeting transitions', '会议切换', '會議切換', '会議の切り替え'),
    'message_switch': _LocalizedTaxonomyLabel(
        'message switching', '消息切换', '訊息切換', 'メッセージの切り替え'),
    'starting':
        _LocalizedTaxonomyLabel('starting friction', '启动阻力', '啟動阻力', '開始時の負担'),
    'fatigue': _LocalizedTaxonomyLabel('fatigue', '疲惫', '疲憊', '疲れ'),
    'dense_schedule':
        _LocalizedTaxonomyLabel('dense schedule', '安排过密', '安排過密', '予定の詰まり'),
    'overextension':
        _LocalizedTaxonomyLabel('overextension', '持续透支', '持續透支', '無理のしすぎ'),
    'uncertainty':
        _LocalizedTaxonomyLabel('uncertainty', '不确定感', '不確定感', '不確かさ'),
    'notifications': _LocalizedTaxonomyLabel(
        'notification interruptions', '通知打断', '通知打斷', '通知による中断'),
    'interruptions': _LocalizedTaxonomyLabel(
        'frequent interruptions', '频繁打断', '頻繁打斷', '頻繁な中断'),
    'overplanning':
        _LocalizedTaxonomyLabel('overplanning', '安排过满', '安排過滿', '予定の詰め込み'),
    'decision_fatigue':
        _LocalizedTaxonomyLabel('decision fatigue', '决策疲劳', '決策疲勞', '決断疲れ'),
    'late_messages':
        _LocalizedTaxonomyLabel('late messages', '晚间消息', '晚間訊息', '夜遅いメッセージ'),
    'body_tension':
        _LocalizedTaxonomyLabel('body tension', '身体紧绷', '身體緊繃', '身体のこわばり'),
    'emotional_load':
        _LocalizedTaxonomyLabel('emotional load', '情绪负荷', '情緒負荷', '感情の負荷'),
    'self_pressure':
        _LocalizedTaxonomyLabel('self-pressure', '自我压力', '自我壓力', '自分へのプレッシャー'),
    'boundary':
        _LocalizedTaxonomyLabel('boundary pressure', '边界压力', '界線壓力', '境界線の負担'),
    'meeting': _LocalizedTaxonomyLabel('meeting load', '会议负荷', '會議負荷', '会議の負荷'),
    'meeting_load':
        _LocalizedTaxonomyLabel('meeting load', '会议负荷', '會議負荷', '会議の負荷'),
    'overload': _LocalizedTaxonomyLabel('overload', '过载', '過載', '過負荷'),
    'historical_overload':
        _LocalizedTaxonomyLabel('ongoing overload', '持续过载', '持續過載', '続く過負荷'),
    'relationship_message': _LocalizedTaxonomyLabel(
      'relationship-message pressure',
      '关系消息压力',
      '關係訊息壓力',
      '人間関係のメッセージ負担',
    ),
    'schedule_overload':
        _LocalizedTaxonomyLabel('schedule overload', '日程过载', '日程過載', '予定の過負荷'),
    'schedule_pressure':
        _LocalizedTaxonomyLabel('schedule pressure', '日程压力', '日程壓力', '予定の圧迫'),

    // Classification and report enums. These stable storage keys can be
    // embedded in generated copy; they must never leak into localized UI.
    'work_tasks': _LocalizedTaxonomyLabel('work', '工作', '工作', '仕事'),
    'emotion_stress':
        _LocalizedTaxonomyLabel('emotional stress', '情绪压力', '情緒壓力', '感情の負担'),
    'relationships':
        _LocalizedTaxonomyLabel('relationships', '关系', '關係', '人間関係'),
    'time_rhythm':
        _LocalizedTaxonomyLabel('daily rhythm', '生活节奏', '生活節奏', '生活リズム'),
    'health_body':
        _LocalizedTaxonomyLabel('body and health', '身体健康', '身體健康', '身体と健康'),
    'money_spending':
        _LocalizedTaxonomyLabel('money and spending', '金钱消费', '金錢消費', 'お金と支出'),
    'learning_growth_expression': _LocalizedTaxonomyLabel(
      'learning, growth and expression',
      '学习成长与表达',
      '學習成長與表達',
      '学び・成長・表現',
    ),
    'information_gathering': _LocalizedTaxonomyLabel(
        'information gathering', '信息整理', '資訊整理', '情報整理'),
    'decision_making':
        _LocalizedTaxonomyLabel('decision making', '决策比较', '決策比較', '意思決定'),
    'communication':
        _LocalizedTaxonomyLabel('communication', '沟通协作', '溝通協作', 'コミュニケーション'),
    'scheduling':
        _LocalizedTaxonomyLabel('scheduling', '日程安排', '日程安排', 'スケジュール調整'),
    'information': _LocalizedTaxonomyLabel(
        'scattered information', '信息分散', '資訊分散', '情報の分散'),
    'time': _LocalizedTaxonomyLabel('time pressure', '时间压力', '時間壓力', '時間の負担'),
    'decision':
        _LocalizedTaxonomyLabel('decision load', '决策负担', '決策負擔', '意思決定の負担'),
    'execution':
        _LocalizedTaxonomyLabel('execution friction', '执行阻力', '執行阻力', '実行の負担'),
    'coordination':
        _LocalizedTaxonomyLabel('coordination load', '协作确认', '協作確認', '調整の負担'),
    'vent': _LocalizedTaxonomyLabel('venting', '倾诉', '傾訴', '気持ちの吐き出し'),
    'celebrate':
        _LocalizedTaxonomyLabel('celebration', '开心记录', '開心記錄', 'うれしい記録'),
    'reflection': _LocalizedTaxonomyLabel('reflection', '自我观察', '自我觀察', '振り返り'),
    'record': _LocalizedTaxonomyLabel('record', '记录', '記錄', '記録'),
    'voice_signal':
        _LocalizedTaxonomyLabel('voice signal', '语音信号', '語音信號', '音声シグナル'),
    'status_signal':
        _LocalizedTaxonomyLabel('status signal', '状态信号', '狀態信號', '状態シグナル'),
    'quick_status':
        _LocalizedTaxonomyLabel('quick status', '即时状态', '即時狀態', '今の状態'),
    'ai_predicted':
        _LocalizedTaxonomyLabel('AI prediction', '智能预判', '智能預判', '人工知能による予測'),
    'ai_prediction':
        _LocalizedTaxonomyLabel('AI prediction', '智能预判', '智能預判', '人工知能による予測'),
    'signal_card':
        _LocalizedTaxonomyLabel('Signal Card', '信号卡', '信號卡', 'シグナルカード'),
    'signalcard':
        _LocalizedTaxonomyLabel('Signal Card', '信号卡', '信號卡', 'シグナルカード'),
    'signal_path': _LocalizedTaxonomyLabel(
        'Signal Path', 'Signal Path', 'Signal Path', 'Signal Path'),
    'unknown': _LocalizedTaxonomyLabel('uncategorized', '未分类', '未分類', '未分類'),
    'other': _LocalizedTaxonomyLabel('other', '其他', '其他', 'その他'),
    'positive': _LocalizedTaxonomyLabel('positive', '正向', '正向', '前向き'),
    'negative': _LocalizedTaxonomyLabel('negative', '负向', '負向', '否定的'),
    'neutral': _LocalizedTaxonomyLabel('neutral', '平稳', '平穩', '中立'),
    'mixed': _LocalizedTaxonomyLabel('mixed', '复杂交织', '複雜交織', '混在'),
    'clear': _LocalizedTaxonomyLabel('clear', '明确', '明確', '明確'),
    'unclear': _LocalizedTaxonomyLabel('unclear', '尚不明确', '尚不明確', 'まだ不明確'),
    'helpful': _LocalizedTaxonomyLabel('helpful', '有帮助', '有幫助', '役に立った'),
    'not_helpful':
        _LocalizedTaxonomyLabel('not helpful', '没有帮助', '沒有幫助', '役に立たなかった'),
    'completed': _LocalizedTaxonomyLabel('completed', '已完成', '已完成', '完了'),
    'not_completed':
        _LocalizedTaxonomyLabel('not completed', '未完成', '未完成', '未完了'),
    'not_occurred':
        _LocalizedTaxonomyLabel('not completed', '未完成', '未完成', '未完了'),
    'not_happened':
        _LocalizedTaxonomyLabel('not completed', '未完成', '未完成', '未完了'),
    'not_done': _LocalizedTaxonomyLabel('not completed', '未完成', '未完成', '未完了'),
    'not_suitable_today':
        _LocalizedTaxonomyLabel('not completed', '未完成', '未完成', '未完了'),

    // Five-state energy projection and planning intensity.
    'draining': _LocalizedTaxonomyLabel('draining', '偏耗力', '偏耗力', 'やや消耗'),
    'steady': _LocalizedTaxonomyLabel('steady', '平稳', '平穩', '安定'),
    'ease': _LocalizedTaxonomyLabel('ease', '有余力', '有餘力', '余力あり'),
    'restoring': _LocalizedTaxonomyLabel('restoring', '恢复', '恢復', '回復'),
    'resourced': _LocalizedTaxonomyLabel('resourced', '有余力', '有餘力', '余力あり'),
    'boundary_buffer': _LocalizedTaxonomyLabel(
      'boundaries and room',
      '边界与余地',
      '界線與餘地',
      '境界と余白',
    ),
    'very_low': _LocalizedTaxonomyLabel(
      'very low',
      '很低',
      '很低',
      'とても低い',
    ),
    'low': _LocalizedTaxonomyLabel('low', '较低', '較低', '低め'),
    'medium': _LocalizedTaxonomyLabel('medium', '适中', '適中', '中程度'),
    'high': _LocalizedTaxonomyLabel('high', '充足', '充足', '高め'),
    'very_light': _LocalizedTaxonomyLabel('very light', '极轻量', '極輕量', 'ごく軽め'),
    'light': _LocalizedTaxonomyLabel('light', '轻量', '輕量', '軽め'),
    'moderate': _LocalizedTaxonomyLabel('moderate', '适量', '適量', '適量'),

    // Positive and recovery signals.
    'short_walk_helped': _LocalizedTaxonomyLabel(
      'a short walk helped',
      '短暂走动有帮助',
      '短暫走動有幫助',
      '短い散歩が役立った',
    ),
    'buffer_helped': _LocalizedTaxonomyLabel(
        'buffer time helped', '留出缓冲有帮助', '留出緩衝有幫助', '余白が役立った'),
    'pause_helped': _LocalizedTaxonomyLabel(
        'a short pause helped', '短暂停顿有帮助', '短暫停頓有幫助', '短い休止が役立った'),
    'quiet_focus':
        _LocalizedTaxonomyLabel('quiet focus', '安静专注', '安靜專注', '静かな集中'),
    'small_start':
        _LocalizedTaxonomyLabel('a small start', '小步启动', '小步啟動', '小さく始める'),
    'space_helped': _LocalizedTaxonomyLabel(
        'open space helped', '留白有帮助', '留白有幫助', '余白が役立った'),
    'sunlight_helped':
        _LocalizedTaxonomyLabel('sunlight helped', '日照有帮助', '日照有幫助', '日光が役立った'),
    'priority_helped': _LocalizedTaxonomyLabel(
      'prioritizing helped',
      '优先推进有帮助',
      '優先推進有幫助',
      '優先順位づけが役立った',
    ),
    'stretch_helped': _LocalizedTaxonomyLabel(
        'stretching helped', '拉伸有帮助', '伸展有幫助', 'ストレッチが役立った'),
    'connection_helped': _LocalizedTaxonomyLabel(
      'connection helped',
      '连接与支持有帮助',
      '連結與支持有幫助',
      '人とのつながりが役立った',
    ),
    'meaningful_progress': _LocalizedTaxonomyLabel(
      'meaningful progress',
      '有意义的推进',
      '有意義的推進',
      '意味のある前進',
    ),
    'quiet_evening':
        _LocalizedTaxonomyLabel('a quiet evening', '安静的夜晚', '安靜的夜晚', '静かな夜'),
    'walk': _LocalizedTaxonomyLabel('a walk', '散步', '散步', '散歩'),
  };
}

class _LocalizedTaxonomyLabel {
  final String en;
  final String zhHans;
  final String zhHant;
  final String ja;

  const _LocalizedTaxonomyLabel(
    this.en,
    this.zhHans,
    this.zhHant,
    this.ja,
  );
}
