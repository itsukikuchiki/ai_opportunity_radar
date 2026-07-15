import 'package:flutter/material.dart';

import 'app_locale_text.dart';

/// Presentation-only localization for Energy Budget taxonomy values.
///
/// Signal Cards deliberately keep their stable machine keys (for example
/// `context_switching` and `small_start`). Energy Budget copy may quote those
/// keys, so this helper converts only exact taxonomy tokens at render time and
/// never mutates the stored signal or the analysis inputs.
class EnergyBudgetText {
  const EnergyBudgetText._();

  static String localizeCopy(BuildContext context, String copy) {
    final trimmed = copy.trim();
    if (trimmed.isEmpty) return copy;

    final exact = _labels[trimmed.toLowerCase()];
    if (exact != null) return _resolve(context, exact);

    var result = copy;
    for (final entry in _labels.entries) {
      final localized = _resolve(context, entry.value);
      for (final quotes in _quotePairs) {
        result = result.replaceAll(
          '${quotes.$1}${entry.key}${quotes.$2}',
          '${quotes.$1}$localized${quotes.$2}',
        );
      }
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
