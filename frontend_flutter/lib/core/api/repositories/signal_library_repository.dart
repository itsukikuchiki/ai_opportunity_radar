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
    final canonicalPatternId = _canonicalPatternId(pattern.id);
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
        'canonical_pattern_id': canonicalPatternId,
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
    title: 'Weak positive signals',
    abstractPattern:
        'Some people have small restoring moments that are easy to miss because they do not look dramatic.',
    commonScenes: const ['recovery', 'creativity', 'connection'],
    commonFrictions: const ['positive signals are easy to overlook'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: 'small ease',
    language: 'en',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'boundary_fatigue',
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
    title: 'Small freedom, connection, or creative energy',
    abstractPattern:
        'Some people recover through brief moments of choice, connection, or making something small.',
    commonScenes: const ['connection', 'creativity', 'freedom'],
    commonFrictions: const ['low personal agency', 'thin recovery space'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: 'freedom, connection, or creative energy',
    language: 'en',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'over_scheduled_weeks_zh_hans',
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
    title: '很小的正向信号',
    abstractPattern: '有些恢复感很小，不够戏剧化，所以很容易被忽略。',
    commonScenes: const ['恢复', '创作', '连接'],
    commonFrictions: const ['正向信号容易被忽略'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '一点点轻松',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'boundary_fatigue_zh_hans',
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
    title: '小自由、连接感或创作能量',
    abstractPattern: '有些人会从很短的选择、连接，或做出一点小东西的时刻里恢复过来。',
    commonScenes: const ['连接', '创作', '自由感'],
    commonFrictions: const ['自主感偏低', '恢复空间很薄'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '自由感、连接感或创作能量',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'over_scheduled_weeks_zh_hant',
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
    title: '很小的正向信號',
    abstractPattern: '有些恢復感很小，不夠戲劇化，所以很容易被忽略。',
    commonScenes: const ['恢復', '創作', '連結'],
    commonFrictions: const ['正向信號容易被忽略'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '一點點輕鬆',
    language: 'zh-Hant',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'boundary_fatigue_zh_hant',
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
    title: '小自由、連結感或創作能量',
    abstractPattern: '有些人會從很短的選擇、連結，或做出一點小東西的時刻裡恢復過來。',
    commonScenes: const ['連結', '創作', '自由感'],
    commonFrictions: const ['自主感偏低', '恢復空間很薄'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '自由感、連結感或創作能量',
    language: 'zh-Hant',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'over_scheduled_weeks_ja',
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
    title: '小さなポジティブシグナル',
    abstractPattern: '劇的ではない回復の瞬間は、小さいからこそ見落とされやすいことがあります。',
    commonScenes: const ['回復', '創作', 'つながり'],
    commonFrictions: const ['ポジティブなシグナルを見落としやすい'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '少し楽になる感覚',
    language: 'ja',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'boundary_fatigue_ja',
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
    title: '小さな自由、つながり、創作のエネルギー',
    abstractPattern: '短い選択、つながり、何かを少し作る時間から回復する人もいます。',
    commonScenes: const ['つながり', '創作', '自由感'],
    commonFrictions: const ['主体感が少ない', '回復スペースが薄い'],
    energyLoadHint: 'recovery',
    possiblePositiveSignal: '自由感、つながり、創作のエネルギー',
    language: 'ja',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
];
