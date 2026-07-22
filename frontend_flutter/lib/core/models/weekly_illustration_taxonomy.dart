class WeeklyIllustrationTaxonomy {
  const WeeklyIllustrationTaxonomy._();

  static const focusAreas = [
    '情绪安定',
    '关系连接',
    '价值意义',
    '自我边界',
    '成长计划',
    '创造表达',
    '饮食睡眠',
    '生活环境',
    '兴趣爱好',
  ];

  static const behaviorPatterns = [
    '任务堆积，开始变困难',
    '会议密集，注意力被切碎',
    '临时变化打断原本节奏',
    '休息时间被任务挤掉',
    '想休息，但停下来后反而空转',
    '晚上刷手机变多',
    '早上启动困难',
    '中午以后精力明显下降',
    '情绪被日程密度带着走',
    '焦虑提前出现，还没开始就紧张',
    '做完事后更累，不是更轻松',
    '计划越大，越容易不开始',
    '目标太多，注意力分散',
    '创作被工作挤掉',
    '不敢拒绝，自己的时间被挤占',
    '过度迎合后感到疲惫',
    '想表达，但说不清',
    '独处不足，恢复变慢',
    '生活环境混乱，心情也乱',
    '关系对话后反复内耗',
    '金钱或现实压力牵动安全感',
    '身体信号先出现，才意识到累',
    '小实验有效，节奏开始稳定',
    '兴趣活动带来恢复感',
  ];

  static const reviewPatterns = [
    '做到了',
    '没做到',
    '不想做',
    '今天不适合',
    '有帮助',
    '一般',
    '没帮助',
    '想调整',
    '太难了',
    '太复杂了',
    '太像任务打卡',
    '时间太长',
    '10 分钟以内更容易发生',
    '身体类小实验更有效',
    '写一句观察更有效',
    '散步类行动更有效',
    '放下手机类行动有效',
    '整理环境类行动有效',
    '关系表达类行动有效',
    '目标拆小类行动有效',
    '早上更容易做到',
    '晚上更容易做到',
    '周末更容易做到',
    '连续发生几天',
    '中断后重新开始',
    '部分发生',
    '只是观察也有帮助',
    '被安排打断',
    '被情绪打断',
    '下周继续 / 停止 / 改小',
  ];

  static const weeklyGeneratePayload = {
    'field_name': 'illustration_hint',
    'usage':
        'When generating weekly patterns, frictions, opportunity snapshots, or review guidance, choose one exact value from these lists as illustration_hint.',
    'focus_areas': focusAreas,
    'behavior_patterns': behaviorPatterns,
    'review_patterns': reviewPatterns,
  };
}
