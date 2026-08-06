import '../../backup/cloud_backup_sync_service.dart';
import '../../local/local_capture_repository.dart';
import '../../local/local_database.dart';
import '../../models/signal_library_models.dart';
import '../../models/today_models.dart';

class SignalLibraryRepository {
  final LocalDatabase localDatabase;
  final CloudBackupSyncService? cloudBackupSyncService;

  SignalLibraryRepository(
    this.localDatabase, {
    this.cloudBackupSyncService,
  });

  Future<List<LibraryPatternModel>> listCuratedPatterns({
    String language = 'en',
  }) async {
    final normalized = _normalizeLanguage(language);
    final localized = _officialCuratedPatterns
        .where((pattern) => pattern.language == normalized)
        .toList(growable: false);
    if (localized.isNotEmpty) return localized;

    return _officialCuratedPatterns
        .where((pattern) => pattern.language == 'en')
        .toList(growable: false);
  }

  Future<RecentSignalModel?> respondToPattern({
    required LibraryPatternModel pattern,
    required String status,
    String? userText,
    bool addToTimeline = false,
  }) async {
    final normalizedStatus = status.trim().toLowerCase();
    if (!const {'accurate', 'partial', 'inaccurate'}
        .contains(normalizedStatus)) {
      throw ArgumentError.value(status, 'status', 'unsupported_match_status');
    }
    final referenceText = pattern.abstractPattern.trim();
    final editedText = userText?.trim();
    final effectiveText =
        editedText?.isNotEmpty == true ? editedText! : referenceText;
    final shouldAdd = normalizedStatus != 'inaccurate' &&
        addToTimeline &&
        effectiveText.isNotEmpty;

    // A reference that is not added to the timeline is a zero-write action.
    // Match choices are not persisted as a separate feedback object.
    if (!shouldAdd) return null;

    final now = DateTime.now();
    final correction = effectiveText == referenceText
        ? const <String, dynamic>{}
        : <String, dynamic>{'edited_text': effectiveText};
    final signal =
        await LocalCaptureRepository(localDatabase).insertConfirmedSignalCard(
      signalCardId: _timelineSignalId(pattern.id, now),
      content: effectiveText,
      sourceType: 'library_saved',
      language: pattern.language,
      scene: pattern.commonScenes.isEmpty ? null : pattern.commonScenes.first,
      friction: pattern.commonFrictions.isEmpty
          ? null
          : pattern.commonFrictions.first,
      positiveSignal: pattern.possiblePositiveSignal,
      energyLoad: pattern.energyLoadHint,
      sceneTags: pattern.commonScenes,
      intentTags: pattern.commonFrictions,
      userConfirmation: normalizedStatus,
      userCorrectionJson: correction,
      rawPayloadJson: {
        ...pattern.toPayloadJson(),
        'reference_type': 'curated_signal_card',
        'generation_rule_version': 'signal_library_reference_v1',
        'match_status': normalizedStatus,
        'added_to_timeline': true,
        if (correction.isNotEmpty) 'user_adjustment_text': effectiveText,
      },
      includedInSummary: false,
      includedInWeekly: false,
      includedInJourney: false,
    );
    cloudBackupSyncService?.markDataChanged();
    return signal;
  }

  String _timelineSignalId(String patternId, DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return 'library_${_safeId(_canonicalPatternId(patternId))}_${local.year}$month$day';
  }

  String _safeId(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

  String _canonicalPatternId(String value) {
    return value.replaceFirst(RegExp(r'_(zh_hans|zh_hant|ja)$'), '');
  }

  String _normalizeLanguage(String language) {
    final trimmed = language.trim();
    if (trimmed.isEmpty) return 'en';
    final lower = trimmed.toLowerCase();
    if (lower == 'zh-hans' || lower == 'zh_hans' || lower == 'zh-cn') {
      return 'zh-Hans';
    }
    if (lower == 'zh-hant' ||
        lower == 'zh_hant' ||
        lower == 'zh-tw' ||
        lower == 'zh-hk') {
      return 'zh-Hant';
    }
    if (lower == 'ja' || lower == 'ja-jp') return 'ja';
    return 'en';
  }
}

final _curatedSeedDate = DateTime.utc(2026, 5, 29);

final List<LibraryPatternModel> _officialCuratedPatterns = [
  LibraryPatternModel(
    id: 'over_scheduled_weeks',
    focusDomainId: 'growth_plan',
    title: 'Over-scheduled weeks',
    abstractPattern:
        'Some people encounter a similar structure when the week has many fixed commitments and very little space between them.',
    commonScenes: const ['work', 'planning', 'care load'],
    commonFrictions: const ['schedule density', 'limited buffer'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: 'a small pocket of open time',
    language: 'en',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'recovery_debt',
    focusDomainId: 'food_sleep',
    title: 'Recovery debt',
    abstractPattern:
        'Some people notice that rest starts feeling like something to catch up on after several demanding days.',
    commonScenes: const ['body', 'rest', 'work'],
    commonFrictions: const ['recovery debt', 'low recovery space'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: 'early rest signals',
    language: 'en',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'attention_switching_fatigue',
    focusDomainId: 'growth_plan',
    title: 'Attention switching fatigue',
    abstractPattern:
        'Some people feel more worn down by frequent switching than by any single task.',
    commonScenes: const ['work', 'messages', 'attention'],
    commonFrictions: const ['context switching', 'interruptions'],
    energyLoadHint: 'high-switching',
    possiblePositiveSignal: 'quiet focus',
    language: 'en',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'unclear_expectation_relationship_friction',
    focusDomainId: 'relationship_connection',
    title: 'Unclear expectation friction',
    abstractPattern:
        'Some people encounter a similar structure when expectations stay implicit and energy goes into guessing what is wanted.',
    commonScenes: const ['relationship', 'work', 'communication'],
    commonFrictions: const ['unclear expectation', 'emotional guessing'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: 'clearer wording',
    language: 'en',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'late_night_compensation_behavior',
    focusDomainId: 'food_sleep',
    title: 'Late-night compensation',
    abstractPattern:
        'Some people notice late-night time becoming a way to reclaim freedom after a compressed day.',
    commonScenes: const ['rest', 'attention', 'personal time'],
    commonFrictions: const ['low daytime freedom', 'delayed recovery'],
    energyLoadHint: 'buffer',
    possiblePositiveSignal: 'need for personal space',
    language: 'en',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'weak_positive_signals',
    focusDomainId: 'emotional_stability',
    title: 'Small moments of emotional steadiness',
    abstractPattern:
        'Some people have small settling moments that are easy to miss because they do not look dramatic.',
    commonScenes: const ['emotion', 'calm', 'recovery'],
    commonFrictions: const ['subtle steadiness is easy to overlook'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: 'small ease',
    language: 'en',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'boundary_fatigue',
    focusDomainId: 'self_boundary',
    title: 'Boundary fatigue',
    abstractPattern:
        'Some people feel tired not from one request, but from many small boundary decisions close together.',
    commonScenes: const ['messages', 'relationship', 'work'],
    commonFrictions: const ['boundary load', 'many small decisions'],
    energyLoadHint: 'boundary',
    possiblePositiveSignal: 'protected space',
    language: 'en',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'small_freedom_connection_creative_energy',
    focusDomainId: 'creative_expression',
    title: 'Small creative moments',
    abstractPattern:
        'Some people regain focus and energy after writing, drawing, or making one small thing without trying to perfect it.',
    commonScenes: const ['creativity', 'expression', 'making'],
    commonFrictions: const ['waiting for perfect output', 'overthinking'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: 'a small act of expression',
    language: 'en',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'over_scheduled_weeks_zh_hans',
    focusDomainId: 'growth_plan',
    title: '安排过密的一周',
    abstractPattern: '有些时候，一周里固定安排很多，中间却几乎没有可以缓一缓的空隙。',
    commonScenes: const ['工作', '安排', '照顾负担'],
    commonFrictions: const ['日程密度', '缓冲不足'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: '一小段可自由安排的时间',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'recovery_debt_zh_hans',
    focusDomainId: 'food_sleep',
    title: '恢复感欠账',
    abstractPattern: '我不是不想休息，而是不知道怎么从忙碌里降速。',
    commonScenes: const ['身体', '休息', '工作'],
    commonFrictions: const ['恢复感欠账', '恢复空间太少'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: '早一点出现的休息信号',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'attention_switching_fatigue_zh_hans',
    focusDomainId: 'growth_plan',
    title: '频繁切换后的疲惫',
    abstractPattern: '有些时候，真正耗力的不是某一件事，而是注意力频繁来回切换。',
    commonScenes: const ['工作', '消息', '注意力'],
    commonFrictions: const ['来回切换', '被打断'],
    energyLoadHint: 'high-switching',
    possiblePositiveSignal: '安静专注的片刻',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'unclear_expectation_relationship_friction_zh_hans',
    focusDomainId: 'relationship_connection',
    title: '期待不清带来的关系摩擦',
    abstractPattern: '有些时候，期待没有被说清楚，能量就会花在猜测对方到底想要什么。',
    commonScenes: const ['关系', '工作', '沟通'],
    commonFrictions: const ['期待不清', '情绪猜测'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: '更清楚的一句话',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'late_night_compensation_behavior_zh_hans',
    focusDomainId: 'food_sleep',
    title: '深夜补偿感',
    abstractPattern: '最近晚上明明很累，却总是拖着不去睡。',
    commonScenes: const ['休息', '注意力', '个人时间'],
    commonFrictions: const ['白天自由感少', '恢复被推迟'],
    energyLoadHint: 'buffer',
    possiblePositiveSignal: '需要一点属于自己的空间',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'weak_positive_signals_zh_hans',
    focusDomainId: 'emotional_stability',
    title: '很小的情绪稳定信号',
    abstractPattern: '有些让情绪慢慢稳定下来的片刻很小，所以很容易被忽略。',
    commonScenes: const ['情绪', '安定', '恢复'],
    commonFrictions: const ['细微的稳定感容易被忽略'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '一点点轻松',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'boundary_fatigue_zh_hans',
    focusDomainId: 'self_boundary',
    title: '边界疲惫',
    abstractPattern: '今天很多事都在推着我走，我几乎没有留给自己的时间。',
    commonScenes: const ['消息', '关系', '工作'],
    commonFrictions: const ['边界负担', '很多小决定'],
    energyLoadHint: 'boundary',
    possiblePositiveSignal: '被保护的一点空间',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'small_freedom_connection_creative_energy_zh_hans',
    focusDomainId: 'creative_expression',
    title: '一点创作带来的能量',
    abstractPattern: '随手写、画或做出一点东西时，我会重新找回专注和活力。',
    commonScenes: const ['创作', '表达', '动手制作'],
    commonFrictions: const ['等待完美', '想得太多'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '一点真实表达',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'over_scheduled_weeks_zh_hant',
    focusDomainId: 'growth_plan',
    title: '安排過密的一週',
    abstractPattern: '有些時候，一週裡固定安排很多，中間卻幾乎沒有可以緩一緩的空隙。',
    commonScenes: const ['工作', '安排', '照顧負擔'],
    commonFrictions: const ['日程密度', '緩衝不足'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: '一小段可自由安排的時間',
    language: 'zh-Hant',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'recovery_debt_zh_hant',
    focusDomainId: 'food_sleep',
    title: '恢復感欠帳',
    abstractPattern: '有些時候，連續幾天都在消耗之後，休息會開始像一件需要補上的事。',
    commonScenes: const ['身體', '休息', '工作'],
    commonFrictions: const ['恢復感欠帳', '恢復空間太少'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: '早一點出現的休息信號',
    language: 'zh-Hant',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'attention_switching_fatigue_zh_hant',
    focusDomainId: 'growth_plan',
    title: '頻繁切換後的疲憊',
    abstractPattern: '有些時候，真正耗力的不是某一件事，而是注意力頻繁來回切換。',
    commonScenes: const ['工作', '訊息', '注意力'],
    commonFrictions: const ['來回切換', '被打斷'],
    energyLoadHint: 'high-switching',
    possiblePositiveSignal: '安靜專注的片刻',
    language: 'zh-Hant',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'unclear_expectation_relationship_friction_zh_hant',
    focusDomainId: 'relationship_connection',
    title: '期待不清帶來的關係摩擦',
    abstractPattern: '有些時候，期待沒有被說清楚，能量就會花在猜測對方到底想要什麼。',
    commonScenes: const ['關係', '工作', '溝通'],
    commonFrictions: const ['期待不清', '情緒猜測'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: '更清楚的一句話',
    language: 'zh-Hant',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'late_night_compensation_behavior_zh_hant',
    focusDomainId: 'food_sleep',
    title: '深夜補償感',
    abstractPattern: '有些時候，深夜會變成把白天失去的自由感補回來的一段時間。',
    commonScenes: const ['休息', '注意力', '個人時間'],
    commonFrictions: const ['白天自由感少', '恢復被推遲'],
    energyLoadHint: 'buffer',
    possiblePositiveSignal: '需要一點屬於自己的空間',
    language: 'zh-Hant',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'weak_positive_signals_zh_hant',
    focusDomainId: 'emotional_stability',
    title: '很小的情緒穩定信號',
    abstractPattern: '有些讓情緒慢慢穩定下來的片刻很小，所以很容易被忽略。',
    commonScenes: const ['情緒', '安定', '恢復'],
    commonFrictions: const ['細微的穩定感容易被忽略'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '一點點輕鬆',
    language: 'zh-Hant',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'boundary_fatigue_zh_hant',
    focusDomainId: 'self_boundary',
    title: '邊界疲憊',
    abstractPattern: '有些疲憊不是來自某一個請求，而是連續很多個小邊界決定擠在一起。',
    commonScenes: const ['訊息', '關係', '工作'],
    commonFrictions: const ['邊界負擔', '很多小決定'],
    energyLoadHint: 'boundary',
    possiblePositiveSignal: '被保護的一點空間',
    language: 'zh-Hant',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'small_freedom_connection_creative_energy_zh_hant',
    focusDomainId: 'creative_expression',
    title: '一點創作帶來的能量',
    abstractPattern: '隨手寫、畫或做出一點東西時，我會重新找回專注和活力。',
    commonScenes: const ['創作', '表達', '動手製作'],
    commonFrictions: const ['等待完美', '想得太多'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '一點真實表達',
    language: 'zh-Hant',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'over_scheduled_weeks_ja',
    focusDomainId: 'growth_plan',
    title: '予定が詰まりすぎる週',
    abstractPattern: '固定された予定が多く、その間に少し息をつく余白がほとんどない週があります。',
    commonScenes: const ['仕事', '予定', 'ケア負担'],
    commonFrictions: const ['予定の密度', 'バッファ不足'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: '少し自由に使える時間',
    language: 'ja',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'recovery_debt_ja',
    focusDomainId: 'food_sleep',
    title: '回復の借り',
    abstractPattern: '負荷の高い日が続くと、休むこと自体が「取り戻すもの」のように感じられることがあります。',
    commonScenes: const ['身体', '休息', '仕事'],
    commonFrictions: const ['回復の借り', '回復スペース不足'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: '早めに出ている休息のシグナル',
    language: 'ja',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'attention_switching_fatigue_ja',
    focusDomainId: 'growth_plan',
    title: '注意の切り替え疲れ',
    abstractPattern: 'ひとつのタスクよりも、注意を何度も切り替えることのほうが消耗につながる場合があります。',
    commonScenes: const ['仕事', 'メッセージ', '注意'],
    commonFrictions: const ['文脈の切り替え', '割り込み'],
    energyLoadHint: 'high-switching',
    possiblePositiveSignal: '静かに集中できる時間',
    language: 'ja',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'unclear_expectation_relationship_friction_ja',
    focusDomainId: 'relationship_connection',
    title: '期待が曖昧な摩擦',
    abstractPattern: '期待が言葉になっていないと、相手が何を望んでいるのかを推測することにエネルギーを使う場合があります。',
    commonScenes: const ['関係', '仕事', 'コミュニケーション'],
    commonFrictions: const ['期待が曖昧', '感情の推測'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: '少し明確な言葉',
    language: 'ja',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'late_night_compensation_behavior_ja',
    focusDomainId: 'food_sleep',
    title: '夜更けの埋め合わせ',
    abstractPattern: '圧縮された一日のあと、夜の時間が自由を取り戻すための場所になることがあります。',
    commonScenes: const ['休息', '注意', '自分の時間'],
    commonFrictions: const ['日中の自由感が少ない', '回復が後ろにずれる'],
    energyLoadHint: 'buffer',
    possiblePositiveSignal: '自分のための少しの空間',
    language: 'ja',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'weak_positive_signals_ja',
    focusDomainId: 'emotional_stability',
    title: '小さな感情安定のシグナル',
    abstractPattern: '気持ちが少しずつ落ち着く瞬間は小さいため、見落とされやすいことがあります。',
    commonScenes: const ['感情', '安定', '回復'],
    commonFrictions: const ['小さな安定を見落としやすい'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '少し楽になる感覚',
    language: 'ja',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'boundary_fatigue_ja',
    focusDomainId: 'self_boundary',
    title: '境界の疲れ',
    abstractPattern: 'ひとつの依頼ではなく、小さな境界判断が続くことで疲れる場合があります。',
    commonScenes: const ['メッセージ', '関係', '仕事'],
    commonFrictions: const ['境界の負荷', '多くの小さな判断'],
    energyLoadHint: 'boundary',
    possiblePositiveSignal: '守られた空間',
    language: 'ja',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'small_freedom_connection_creative_energy_ja',
    focusDomainId: 'creative_expression',
    title: '小さな創作がくれるエネルギー',
    abstractPattern: '気軽に書いたり、描いたり、小さく作ったりすると、集中と活力が戻ることがあります。',
    commonScenes: const ['創作', '表現', 'ものづくり'],
    commonFrictions: const ['完璧を待つ', '考えすぎ'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '小さな自己表現',
    language: 'ja',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  ..._supplementalCuratedPatterns,
];

class _LocalizedLibraryPatternCopy {
  final String title;
  final String abstractPattern;

  const _LocalizedLibraryPatternCopy({
    required this.title,
    required this.abstractPattern,
  });
}

class _SupplementalLibraryPatternSeed {
  final String id;
  final String focusDomainId;
  final String energyLoadHint;
  final Map<String, _LocalizedLibraryPatternCopy> copies;

  const _SupplementalLibraryPatternSeed({
    required this.id,
    required this.focusDomainId,
    required this.energyLoadHint,
    required this.copies,
  });

  LibraryPatternModel build(String language) {
    final copy = copies[language]!;
    final suffix = switch (language) {
      'zh-Hans' => '_zh_hans',
      'zh-Hant' => '_zh_hant',
      'ja' => '_ja',
      _ => '',
    };
    return LibraryPatternModel(
      id: '$id$suffix',
      focusDomainId: focusDomainId,
      title: copy.title,
      abstractPattern: copy.abstractPattern,
      commonScenes: [_domainLabel(focusDomainId, language)],
      commonFrictions: [copy.title],
      energyLoadHint: energyLoadHint,
      possiblePositiveSignal: _domainPositiveSignal(
        focusDomainId,
        language,
      ),
      language: language,
      createdAt: _curatedSeedDate,
      updatedAt: _curatedSeedDate,
    );
  }
}

final List<LibraryPatternModel> _supplementalCuratedPatterns = [
  for (final seed in _supplementalPatternSeeds)
    for (final language in const ['en', 'zh-Hans', 'zh-Hant', 'ja'])
      seed.build(language),
];

const List<_SupplementalLibraryPatternSeed> _supplementalPatternSeeds = [
  _SupplementalLibraryPatternSeed(
    id: 'tension_without_a_big_event',
    focusDomainId: 'emotional_stability',
    energyLoadHint: 'high-drain',
    copies: {
      'en': _LocalizedLibraryPatternCopy(
        title: 'Tension without a big event',
        abstractPattern:
            'Some people stay tense even when nothing major happened, and find it hard to fully settle.',
      ),
      'zh-Hans': _LocalizedLibraryPatternCopy(
        title: '没有大事却一直紧绷',
        abstractPattern: '明明没有发生大事，却一直有些紧绷，很难真正放松。',
      ),
      'zh-Hant': _LocalizedLibraryPatternCopy(
        title: '沒有大事卻一直緊繃',
        abstractPattern: '明明沒有發生大事，卻一直有些緊繃，很難真正放鬆。',
      ),
      'ja': _LocalizedLibraryPatternCopy(
        title: '大きな出来事がなくても残る緊張',
        abstractPattern: '大きな出来事がなくても、ずっと緊張が残り、なかなか力を抜けないことがあります。',
      ),
    },
  ),
  _SupplementalLibraryPatternSeed(
    id: 'being_heard_before_advice',
    focusDomainId: 'relationship_connection',
    energyLoadHint: 'recovery',
    copies: {
      'en': _LocalizedLibraryPatternCopy(
        title: 'Being heard before advice',
        abstractPattern:
            'Some people settle more when they are first understood than when advice arrives immediately.',
      ),
      'zh-Hans': _LocalizedLibraryPatternCopy(
        title: '先被听见再得到建议',
        abstractPattern: '说起难受时，比起马上得到建议，我更需要先被认真听见。',
      ),
      'zh-Hant': _LocalizedLibraryPatternCopy(
        title: '先被聽見再得到建議',
        abstractPattern: '說起難受時，比起馬上得到建議，我更需要先被認真聽見。',
      ),
      'ja': _LocalizedLibraryPatternCopy(
        title: '助言より先に聴いてもらう',
        abstractPattern: 'つらさを話すとき、すぐに助言されるより、まずきちんと聴いてもらうことで落ち着くことがあります。',
      ),
    },
  ),
  _SupplementalLibraryPatternSeed(
    id: 'busy_without_a_clear_why',
    focusDomainId: 'meaning_value',
    energyLoadHint: 'low-meaning',
    copies: {
      'en': _LocalizedLibraryPatternCopy(
        title: 'Busy without a clear why',
        abstractPattern:
            'Some people finish many tasks yet still feel empty when they cannot tell why those tasks matter.',
      ),
      'zh-Hans': _LocalizedLibraryPatternCopy(
        title: '忙碌却说不清为什么重要',
        abstractPattern: '忙了一整天，却说不清这些事为什么重要，心里容易有些空。',
      ),
      'zh-Hant': _LocalizedLibraryPatternCopy(
        title: '忙碌卻說不清為什麼重要',
        abstractPattern: '忙了一整天，卻說不清這些事為什麼重要，心裡容易有些空。',
      ),
      'ja': _LocalizedLibraryPatternCopy(
        title: '忙しいのに意味が見えない',
        abstractPattern: '多くのことを終えても、なぜ大切なのか分からないと、心に空白が残ることがあります。',
      ),
    },
  ),
  _SupplementalLibraryPatternSeed(
    id: 'contribution_seen_restores_motivation',
    focusDomainId: 'meaning_value',
    energyLoadHint: 'recovery',
    copies: {
      'en': _LocalizedLibraryPatternCopy(
        title: 'Motivation when contribution is seen',
        abstractPattern:
            'Some people feel more motivated when their effort genuinely helps someone or is acknowledged.',
      ),
      'zh-Hans': _LocalizedLibraryPatternCopy(
        title: '付出被看见时更有动力',
        abstractPattern: '当做的事真的帮到别人或被看见时，我会更有动力。',
      ),
      'zh-Hant': _LocalizedLibraryPatternCopy(
        title: '付出被看見時更有動力',
        abstractPattern: '當做的事真的幫到別人或被看見時，我會更有動力。',
      ),
      'ja': _LocalizedLibraryPatternCopy(
        title: '貢献が見えると戻る意欲',
        abstractPattern: '自分のしたことが誰かの役に立ったり、きちんと受け取られたりすると、意欲が戻ることがあります。',
      ),
    },
  ),
  _SupplementalLibraryPatternSeed(
    id: 'agreeing_before_checking_capacity',
    focusDomainId: 'self_boundary',
    energyLoadHint: 'boundary',
    copies: {
      'en': _LocalizedLibraryPatternCopy(
        title: 'Agreeing before checking capacity',
        abstractPattern:
            'Some people say yes first and only later notice that the request exceeded their available energy.',
      ),
      'zh-Hans': _LocalizedLibraryPatternCopy(
        title: '先答应再发现精力不够',
        abstractPattern: '别人一开口我就先答应，事后才发现已经超出自己的精力。',
      ),
      'zh-Hant': _LocalizedLibraryPatternCopy(
        title: '先答應再發現精力不夠',
        abstractPattern: '別人一開口我就先答應，事後才發現已經超出自己的精力。',
      ),
      'ja': _LocalizedLibraryPatternCopy(
        title: '余力を確かめる前に引き受ける',
        abstractPattern: '頼まれると先に引き受け、あとから自分の余力を超えていたと気づくことがあります。',
      ),
    },
  ),
  _SupplementalLibraryPatternSeed(
    id: 'input_without_expression',
    focusDomainId: 'creative_expression',
    energyLoadHint: 'high-input',
    copies: {
      'en': _LocalizedLibraryPatternCopy(
        title: 'Too much input, too little expression',
        abstractPattern:
            'Some people feel mentally crowded and lose touch with their own voice after taking in a lot without expressing anything.',
      ),
      'zh-Hans': _LocalizedLibraryPatternCopy(
        title: '输入很多却很少表达',
        abstractPattern: '连续输入很多、很少输出时，脑子会变得很满，自己的声音也越来越模糊。',
      ),
      'zh-Hant': _LocalizedLibraryPatternCopy(
        title: '輸入很多卻很少表達',
        abstractPattern: '連續輸入很多、很少輸出時，腦子會變得很滿，自己的聲音也越來越模糊。',
      ),
      'ja': _LocalizedLibraryPatternCopy(
        title: '入力が多く表現が少ない',
        abstractPattern: '取り入れるものが多く、何も表現しない時間が続くと、頭がいっぱいになり、自分の声が薄れることがあります。',
      ),
    },
  ),
  _SupplementalLibraryPatternSeed(
    id: 'clutter_keeps_attention_open',
    focusDomainId: 'living_environment',
    energyLoadHint: 'high-friction',
    copies: {
      'en': _LocalizedLibraryPatternCopy(
        title: 'Clutter keeps attention occupied',
        abstractPattern:
            'Some people feel as if many unfinished tasks stay open in their mind when their desk or room is cluttered.',
      ),
      'zh-Hans': _LocalizedLibraryPatternCopy(
        title: '杂乱让注意力一直挂着',
        abstractPattern: '桌面或房间很乱时，大脑也像一直挂着许多没完成的事。',
      ),
      'zh-Hant': _LocalizedLibraryPatternCopy(
        title: '雜亂讓注意力一直掛著',
        abstractPattern: '桌面或房間很亂時，大腦也像一直掛著許多沒完成的事。',
      ),
      'ja': _LocalizedLibraryPatternCopy(
        title: '散らかりが注意を占め続ける',
        abstractPattern: '机や部屋が散らかっていると、未完了のことが頭の中にいくつも残り続けるように感じることがあります。',
      ),
    },
  ),
  _SupplementalLibraryPatternSeed(
    id: 'unclear_spending_background_stress',
    focusDomainId: 'living_environment',
    energyLoadHint: 'background-stress',
    copies: {
      'en': _LocalizedLibraryPatternCopy(
        title: 'Unclear spending in the background',
        abstractPattern:
            'Some people keep returning to worry when bills or spending are unclear, even while doing other things.',
      ),
      'zh-Hans': _LocalizedLibraryPatternCopy(
        title: '支出不清带来的后台担心',
        abstractPattern: '账单和支出不清楚时，心里会反复担心，很难真正放松。',
      ),
      'zh-Hant': _LocalizedLibraryPatternCopy(
        title: '支出不清帶來的背景擔心',
        abstractPattern: '帳單和支出不清楚時，心裡會反覆擔心，很難真正放鬆。',
      ),
      'ja': _LocalizedLibraryPatternCopy(
        title: '支出が曖昧なまま残る心配',
        abstractPattern: '請求や支出が分からないままだと、ほかのことをしていても心配が何度も戻ってくることがあります。',
      ),
    },
  ),
  _SupplementalLibraryPatternSeed(
    id: 'enjoyment_always_comes_last',
    focusDomainId: 'interests_hobbies',
    energyLoadHint: 'low-joy',
    copies: {
      'en': _LocalizedLibraryPatternCopy(
        title: 'Enjoyment always comes last',
        abstractPattern:
            'Some people notice that the things they genuinely enjoy keep being pushed aside when a week contains only obligations.',
      ),
      'zh-Hans': _LocalizedLibraryPatternCopy(
        title: '真正喜欢的事总被推到最后',
        abstractPattern: '一周里只做必须做的事时，真正喜欢的事总被推到最后。',
      ),
      'zh-Hant': _LocalizedLibraryPatternCopy(
        title: '真正喜歡的事總被推到最後',
        abstractPattern: '一週裡只做必須做的事時，真正喜歡的事總被推到最後。',
      ),
      'ja': _LocalizedLibraryPatternCopy(
        title: '好きなことがいつも最後になる',
        abstractPattern: '一週間が義務だけで埋まると、本当に好きなことがいつも後回しになることがあります。',
      ),
    },
  ),
  _SupplementalLibraryPatternSeed(
    id: 'vitality_after_movement_or_nature',
    focusDomainId: 'interests_hobbies',
    energyLoadHint: 'recovery',
    copies: {
      'en': _LocalizedLibraryPatternCopy(
        title: 'Vitality after movement or nature',
        abstractPattern:
            'Some people feel noticeably more alive after going outside, moving their body, or spending time in nature.',
      ),
      'zh-Hans': _LocalizedLibraryPatternCopy(
        title: '运动或自然带来的生命力',
        abstractPattern: '去户外、运动或接触自然后，我会明显感觉更有生命力。',
      ),
      'zh-Hant': _LocalizedLibraryPatternCopy(
        title: '運動或自然帶來的生命力',
        abstractPattern: '去戶外、運動或接觸自然後，我會明顯感覺更有生命力。',
      ),
      'ja': _LocalizedLibraryPatternCopy(
        title: '運動や自然のあとに戻る生命力',
        abstractPattern: '外に出たり、体を動かしたり、自然に触れたりすると、はっきり活力が戻ることがあります。',
      ),
    },
  ),
];

String _domainLabel(String domainId, String language) {
  return _domainLabels[language]?[domainId] ??
      _domainLabels['en']![domainId] ??
      domainId;
}

String _domainPositiveSignal(String domainId, String language) {
  return _domainPositiveSignals[language]?[domainId] ??
      _domainPositiveSignals['en']![domainId] ??
      domainId;
}

const Map<String, Map<String, String>> _domainLabels = {
  'en': {
    'emotional_stability': 'emotional stability',
    'relationship_connection': 'relationship connection',
    'meaning_value': 'meaning and value',
    'self_boundary': 'self boundary',
    'growth_plan': 'growth plan',
    'creative_expression': 'creative expression',
    'food_sleep': 'food and sleep',
    'living_environment': 'living environment',
    'interests_hobbies': 'interests and hobbies',
  },
  'zh-Hans': {
    'emotional_stability': '情绪安定',
    'relationship_connection': '关系连接',
    'meaning_value': '价值意义',
    'self_boundary': '自我边界',
    'growth_plan': '成长计划',
    'creative_expression': '创造表达',
    'food_sleep': '饮食睡眠',
    'living_environment': '生活环境',
    'interests_hobbies': '兴趣爱好',
  },
  'zh-Hant': {
    'emotional_stability': '情緒安定',
    'relationship_connection': '關係連結',
    'meaning_value': '價值意義',
    'self_boundary': '自我邊界',
    'growth_plan': '成長計劃',
    'creative_expression': '創造表達',
    'food_sleep': '飲食睡眠',
    'living_environment': '生活環境',
    'interests_hobbies': '興趣愛好',
  },
  'ja': {
    'emotional_stability': '感情の安定',
    'relationship_connection': '関係のつながり',
    'meaning_value': '価値と意味',
    'self_boundary': '自分の境界',
    'growth_plan': '成長計画',
    'creative_expression': '創造と表現',
    'food_sleep': '食事と睡眠',
    'living_environment': '生活環境',
    'interests_hobbies': '興味と趣味',
  },
};

const Map<String, Map<String, String>> _domainPositiveSignals = {
  'en': {
    'emotional_stability': 'a little more steadiness',
    'relationship_connection': 'a clearer connection',
    'meaning_value': 'a sense of meaning',
    'self_boundary': 'protected personal space',
    'growth_plan': 'a clear next step',
    'creative_expression': 'a small act of expression',
    'food_sleep': 'basic physical recovery',
    'living_environment': 'more practical support',
    'interests_hobbies': 'a little more vitality',
  },
  'zh-Hans': {
    'emotional_stability': '一点更稳定的感觉',
    'relationship_connection': '更清楚的连接',
    'meaning_value': '更明确的意义感',
    'self_boundary': '被保护的个人空间',
    'growth_plan': '一个清楚的下一步',
    'creative_expression': '一点真实表达',
    'food_sleep': '身体基础恢复',
    'living_environment': '更稳的现实支撑',
    'interests_hobbies': '一点生命力',
  },
  'zh-Hant': {
    'emotional_stability': '一點更穩定的感覺',
    'relationship_connection': '更清楚的連結',
    'meaning_value': '更明確的意義感',
    'self_boundary': '被保護的個人空間',
    'growth_plan': '一個清楚的下一步',
    'creative_expression': '一點真實表達',
    'food_sleep': '身體基礎恢復',
    'living_environment': '更穩的現實支撐',
    'interests_hobbies': '一點生命力',
  },
  'ja': {
    'emotional_stability': '少し安定した感覚',
    'relationship_connection': 'より明確なつながり',
    'meaning_value': 'はっきりした意味の感覚',
    'self_boundary': '守られた自分の空間',
    'growth_plan': '明確な次の一歩',
    'creative_expression': '小さな自己表現',
    'food_sleep': '身体の基本的な回復',
    'living_environment': 'より安定した現実の支え',
    'interests_hobbies': '少しの生命力',
  },
};
