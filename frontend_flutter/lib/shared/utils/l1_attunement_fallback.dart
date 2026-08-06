String l1AttunedAcknowledgement({
  required String content,
  required String language,
}) {
  final normalizedLanguage = _normalizeLanguage(language);
  final text = content.trim();
  final kind = _attunementKind(text);

  return switch ((normalizedLanguage, kind)) {
    ('zh-Hant', 'overload') => '一下子有這麼多事壓過來，確實很容易讓人喘不過氣。',
    ('zh-Hant', 'fatigue') => '聽起來你現在真的很累，這份疲憊值得被好好看見。',
    ('zh-Hant', 'distress') => '聽起來這一刻真的不好受，這份感受值得被認真對待。',
    ('zh-Hant', 'uncertain') => '現在不知道從哪裡開始，這種卡住的感覺確實不好受。',
    ('zh-Hant', 'positive') => '聽得出來，今天這份開心很真切，也值得好好留住。',
    ('ja', 'overload') => 'いろいろなことが一度に重なると、息をつく余裕もなくなるほど苦しくなりますよね。',
    ('ja', 'fatigue') => '今、本当に疲れているのですね。その疲れはきちんと受け止めたいです。',
    ('ja', 'distress') => '今この瞬間が本当につらいのですね。その気持ちを軽く扱わずに受け止めます。',
    ('ja', 'uncertain') => '今はどこから手をつければよいかわからず、立ち止まってしまう感覚なのですね。',
    ('ja', 'positive') => '今日の嬉しさがまっすぐ伝わってきます。大切に残しておきたい瞬間ですね。',
    ('en', 'overload') =>
      'Having so many things land at once can feel genuinely overwhelming.',
    ('en', 'fatigue') =>
      'You sound genuinely tired, and that exhaustion deserves to be noticed.',
    ('en', 'distress') =>
      'This moment sounds genuinely hard, and I do not want to brush that feeling aside.',
    ('en', 'uncertain') =>
      'Not knowing where to begin can leave you feeling genuinely stuck.',
    ('en', 'positive') =>
      'The happiness in this moment comes through clearly, and it is worth holding onto.',
    ('zh-Hans', 'overload') => '一下子有这么多事压过来，确实很容易让人喘不过气。',
    ('zh-Hans', 'fatigue') => '听起来你现在真的很累，这份疲惫值得被好好看见。',
    ('zh-Hans', 'distress') => '听起来这一刻真的不好受，这份感受值得被认真对待。',
    ('zh-Hans', 'uncertain') => '现在不知道从哪里开始，这种卡住的感觉确实不好受。',
    ('zh-Hans', 'positive') => '听得出来，今天这份开心很真切，也值得好好留住。',
    ('zh-Hant', _) =>
      '我聽見你在說「${_compactStatement(text, normalizedLanguage)}」，這件事先按你感受到的樣子留在這裡。',
    ('ja', _) =>
      '「${_compactStatement(text, normalizedLanguage)}」と感じていることを、そのまま受け止めます。',
    ('en', _) =>
      'I hear you saying “${_compactStatement(text, normalizedLanguage)},” and I am staying with it as you experienced it.',
    _ =>
      '我听见你在说“${_compactStatement(text, normalizedLanguage)}”，这件事先按你感受到的样子留在这里。',
  };
}

String l1AttunedDialogReply({
  required String signalContent,
  required String userMessage,
  required String language,
}) {
  final normalizedLanguage = _normalizeLanguage(language);
  if (l1IsRepairTurn(userMessage)) {
    final sourceKind = _attunementKind(signalContent);
    return switch ((normalizedLanguage, sourceKind)) {
      ('zh-Hant', 'overload') => '你說得對，剛才那句沒有接住你一下子被很多事壓著的感受。',
      ('ja', 'overload') => 'その通りです。さっきの言葉は、いろいろなことに押されている苦しさを受け止められていませんでした。',
      ('en', 'overload') =>
        'You are right; my last reply did not meet the feeling of having so many things pressing on you.',
      ('zh-Hans', 'overload') => '你说得对，刚才那句没有接住你一下子被很多事压着的感受。',
      ('zh-Hant', _) => '你說得對，剛才那句太像在處理一條記錄，沒有接住你當時的感受。',
      ('ja', _) => 'その通りです。さっきの言葉は記録を処理するようで、あなたの気持ちを受け止められていませんでした。',
      ('en', _) =>
        'You are right; my last reply sounded like it was processing a record instead of meeting what you were feeling.',
      _ => '你说得对，刚才那句太像在处理一条记录，没有接住你当时的感受。',
    };
  }

  final acknowledgement = l1AttunedAcknowledgement(
    content: userMessage,
    language: normalizedLanguage,
  );
  if (!l1IsExplicitAdviceRequest(userMessage)) {
    return acknowledgement;
  }

  final advice = _lightAdvice(
    signalContent: signalContent,
    language: normalizedLanguage,
  );
  return '$acknowledgement $advice';
}

bool l1IsExplicitAdviceRequest(String text) {
  final normalized = text.trim().toLowerCase();
  return const [
    '怎么办',
    '怎麼辦',
    '怎么做',
    '怎麼做',
    '该怎么',
    '該怎麼',
    '该做什么',
    '該做什麼',
    '如何',
    'what should',
    'what can i do',
    'what do i do',
    'how should',
    'how do i',
    'どうしたら',
    'どうすれば',
    '何をすれば',
    'どうすべき',
  ].any(normalized.contains);
}

bool l1IsRepairTurn(String text) {
  final normalized = text.trim().toLowerCase();
  return const [
    '太无情',
    '太無情',
    '太冷',
    '冷漠',
    '沒接住',
    '没接住',
    '没理解',
    '沒理解',
    '像机器人',
    '像機器人',
    '敷衍',
    '冷たい',
    'よそよそしい',
    '分かってくれない',
    'わかってくれない',
    '気持ちをわかって',
    'heartless',
    'uncaring',
    'too cold',
    'felt cold',
    'did not hear me',
    "didn't hear me",
    'did not understand me',
    "didn't understand me",
    'like a robot',
  ].any(normalized.contains);
}

String _lightAdvice({
  required String signalContent,
  required String language,
}) {
  final kind = _attunementKind(signalContent);
  return switch ((language, kind)) {
    ('zh-Hant', 'overload') => '如果願意，先只挑出眼前最壓著你的那一件，其他事情暫時不用一起處理。',
    ('ja', 'overload') => 'よければ、今いちばん重くのしかかっている一つだけを選び、ほかは一度に扱わなくても大丈夫です。',
    ('en', 'overload') =>
      'If you want, choose only the one thing pressing on you most and leave the rest out of this moment.',
    ('zh-Hans', 'overload') => '如果愿意，先只挑出眼前最压着你的那一件，其他事情暂时不用一起处理。',
    ('zh-Hant', _) => '如果願意，只選一個現在負擔最小、能讓自己稍微穩一點的動作就夠了。',
    ('ja', _) => 'よければ、今いちばん負担が少なく、少し落ち着けることを一つだけ選んでみてください。',
    ('en', _) =>
      'If you want, choose just one low-pressure step that might help you feel a little steadier.',
    _ => '如果愿意，只选一个现在负担最小、能让自己稍微稳一点的动作就够了。',
  };
}

String _attunementKind(String content) {
  final text = content.trim().toLowerCase();
  if (_containsAny(text, const [
    '事情太多',
    '太多了',
    '一堆事',
    '忙不过来',
    '忙不完',
    '压得喘不过气',
    '没停下来',
    '没有停下来',
    '一直没停',
    '没休息',
    '工作太多',
    '事情太雜',
    '忙不過來',
    '多すぎ',
    'やることが多',
    '止まれなかった',
    '休めなかった',
    'too much',
    'too many',
    'overwhelmed',
    'overwhelming',
    'never stopped',
    'no break',
    'without a break',
    'got a break',
    'get a break',
  ])) {
    return 'overload';
  }
  if (_containsAny(text, const [
    '好累',
    '很累',
    '累了',
    '疲惫',
    '疲憊',
    '精疲力尽',
    '精疲力盡',
    '撑不住',
    '撐不住',
    '疲れた',
    'しんどい',
    'へとへと',
    'tired',
    'exhausted',
    'worn out',
  ])) {
    return 'fatigue';
  }
  if (_containsAny(text, const [
    '怎么办',
    '怎麼辦',
    '怎么做',
    '怎麼做',
    '不知道',
    '没办法',
    '沒辦法',
    'どうしたら',
    'わからない',
    'what should',
    'what can i do',
    "don't know",
    'stuck',
  ])) {
    return 'uncertain';
  }
  if (_containsAny(text, const [
    '开心',
    '開心',
    '高兴',
    '高興',
    '快乐',
    '快樂',
    '很舒服',
    '轻松',
    '輕鬆',
    '嬉しい',
    '楽しい',
    '幸せ',
    'happy',
    'glad',
    'delighted',
    'relieved',
  ])) {
    return 'positive';
  }
  if (_containsAny(text, const [
    '难受',
    '難受',
    '烦',
    '煩',
    '焦虑',
    '焦慮',
    '压力',
    '壓力',
    '委屈',
    '崩溃',
    '崩潰',
    '孤独',
    '孤獨',
    'つらい',
    'イライラ',
    '不安',
    '苦しい',
    'upset',
    'anxious',
    'stressed',
    'frustrated',
    'hurt',
    'lonely',
  ])) {
    return 'distress';
  }
  return 'general';
}

String _normalizeLanguage(String language) {
  final normalized = language.trim().toLowerCase().replaceAll('_', '-');
  if (normalized.startsWith('ja')) return 'ja';
  if (normalized.startsWith('en')) return 'en';
  if (normalized == 'zh-hant' ||
      normalized == 'zh-tw' ||
      normalized == 'zh-hk' ||
      normalized == 'zh-mo') {
    return 'zh-Hant';
  }
  return 'zh-Hans';
}

String _compactStatement(String content, String language) {
  var compact = content
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[?？!！]+$'), '')
      .trim();
  if (compact.isEmpty) {
    return switch (language) {
      'zh-Hant' => '這一刻的感受',
      'ja' => '今この瞬間の気持ち',
      'en' => 'what you are feeling right now',
      _ => '这一刻的感受',
    };
  }
  if (compact.length > 56) compact = '${compact.substring(0, 55)}…';
  return compact;
}

bool _containsAny(String text, List<String> tokens) {
  return tokens.any((token) => text.contains(token.toLowerCase()));
}
