String? sanitizeUserVisibleAiText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (_blockedUserVisibleAiPhrases.any(lower.contains)) return null;
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
