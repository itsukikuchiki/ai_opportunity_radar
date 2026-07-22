String? sanitizeUserVisibleAiText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (_blockedUserVisibleAiPhrases.any(lower.contains)) return null;
  return text;
}

/// Timeline acknowledgements are L1 Attune snapshots. Older app versions
/// could persist advice or a follow-up question in this field; keep that raw
/// value for audit/backup, but never surface it as today's one-line reply.
String? sanitizeTimelineAcknowledgement(String? value) {
  final text = sanitizeUserVisibleAiText(value);
  if (text == null) return null;
  final lower = text.toLowerCase();
  if (text.contains('?') || text.contains('？')) return null;
  if (_blockedTimelineAdvicePhrases.any(lower.contains)) return null;
  return text;
}

const _blockedUserVisibleAiPhrases = [
  '保存在本机',
  '保存在这台',
  '保存在這台',
  '保存在这台设备',
  '保存在這台設備',
  '本机保存',
  '本機保存',
  '网络恢复',
  '網路恢復',
  '同步完成',
  '等同步',
  '同步',
  '不会丢',
  '不會丟',
  '已私密',
  '观察里',
  '觀察裡',
  '重复输入',
  'saved on this device',
  'saved locally',
  'saved privately',
  'network recovers',
  'sync complete',
  'sync',
  'retry',
  '端末に保存',
  '同期',
];

const _blockedTimelineAdvicePhrases = [
  '建议',
  '建議',
  '你可以',
  '可以先',
  '可以试',
  '可以試',
  '试试看',
  '試試看',
  '试试',
  '試試',
  '不妨',
  '下一步',
  '应该做',
  '應該做',
  '如果愿意',
  '如果願意',
  '继续说',
  '繼續說',
  '告诉我',
  '告訴我',
  '先把动作',
  '先把動作',
  '先做一个',
  '先做一個',
  '先选一个',
  '先選一個',
  'you should',
  'you can ',
  'try to ',
  'try this',
  'consider ',
  'if you want',
  'next step',
  'tell me',
  'say more',
  'why don\'t',
  'よければ',
  'してみ',
  'しましょう',
  'してください',
  'どうですか',
  '話して',
  '教えて',
  '次に',
];
