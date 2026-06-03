import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../local/local_database.dart';
import '../../models/signal_library_models.dart';
import '../../models/today_models.dart';

class SignalLibraryRepository {
  final LocalDatabase localDatabase;
  final Uuid _uuid;

  SignalLibraryRepository(
    this.localDatabase, {
    Uuid uuid = const Uuid(),
  }) : _uuid = uuid;

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

  Future<void> recordPrivateAction({
    required String patternId,
    required String action,
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'signal_library_actions',
      {
        'id': 'sla_${_uuid.v4().replaceAll('-', '').substring(0, 12)}',
        'pattern_id': patternId,
        'action': action,
        'is_private': 1,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<RecentSignalModel> saveToMyObservation({
    required LibraryPatternModel pattern,
    String timezone = 'local',
  }) async {
    final db = await localDatabase.database;
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final signalCardId =
        'library_${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
    final payload = pattern.toPayloadJson();

    await db.insert(
      'signal_cards',
      {
        'id': signalCardId,
        'signal_card_id': signalCardId,
        'raw_memory_id': null,
        'capture_id': null,
        'source_type': 'library_saved',
        'raw_text': '',
        'created_at': nowUtc.toIso8601String(),
        'local_date': _dateKey(now),
        'timezone': timezone == 'local' ? now.timeZoneName : timezone,
        'language': pattern.language,
        'ai_reply': _savedObservationReply(pattern.language),
        'observation': pattern.gentleReflection,
        'try_next': pattern.suggestedSmallExperiment,
        'emotion': null,
        'intensity': null,
        'scene':
            pattern.commonScenes.isEmpty ? null : pattern.commonScenes.first,
        'friction': pattern.commonFrictions.isEmpty
            ? null
            : pattern.commonFrictions.first,
        'positive_signal': pattern.possiblePositiveSignal,
        'energy_load': pattern.energyLoadHint,
        'linked_life_chain_stage': '[]',
        'raw_payload_json': jsonEncode(payload),
        'scene_tags_json': jsonEncode(pattern.commonScenes),
        'intent_tags_json': jsonEncode(pattern.commonFrictions),
        'user_confirmation': 'unconfirmed',
        'user_correction_json': '{}',
        'included_in_summary': 0,
        'included_in_weekly': 0,
        'included_in_journey': 0,
        'linked_experiment_id': null,
        'privacy_level': 'private',
        'is_legacy': 0,
        'migration_status': 'native',
        'is_local_draft': 0,
        'sync_failed': 0,
        'sync_status': 'synced',
        'last_error': null,
        'updated_at': nowUtc.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await recordPrivateAction(
      patternId: pattern.id,
      action: 'save_to_my_observation',
    );

    final rows = await db.query(
      'signal_cards',
      where: 'id = ?',
      whereArgs: [signalCardId],
      limit: 1,
    );
    return RecentSignalModel.fromJson(rows.first);
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
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

  String _savedObservationReply(String language) {
    switch (_normalizeLanguage(language)) {
      case 'zh-Hans':
        return '已私密放进你的观察里。你也可以补充一点自己的情况。';
      case 'zh-Hant':
        return '已私密放進你的觀察裡。你也可以補充一點自己的情況。';
      case 'ja':
        return '自分の観察に非公開で保存しました。必要なときに自分の状況を少し足せます。';
      default:
        return 'Saved privately into your observations. You can add a little of your own context when it feels useful.';
    }
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
    gentleReflection:
        'This may be less about doing more and more about where the week has no soft edges.',
    suggestedSmallExperiment:
        'Try leaving one small buffer before or after the densest part of the week.',
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
    gentleReflection:
        'The signal may be pointing to a need for recovery before the week becomes too full.',
    suggestedSmallExperiment:
        'Try choosing one low-effort recovery block before the tiredness becomes loud.',
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
    gentleReflection:
        'The drain may come from repeated transitions rather than from the task itself.',
    suggestedSmallExperiment:
        'Try grouping one small set of messages or tasks instead of touching them throughout the day.',
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
    gentleReflection:
        'The friction may be about unclear expectations rather than anyone being wrong.',
    suggestedSmallExperiment:
        'Try asking for one concrete next step or boundary in a low-stakes way.',
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
    gentleReflection:
        'This may be a signal that the day needs a little more owned time earlier.',
    suggestedSmallExperiment:
        'Try placing one small personal-choice moment before the day fully closes.',
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
    gentleReflection:
        'A quiet positive signal can still be useful evidence about what helps.',
    suggestedSmallExperiment:
        'Try noticing one small moment that gave even a little ease, without turning it into a task.',
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
    gentleReflection:
        'The useful signal may be where repeated small yes-or-no decisions are using energy.',
    suggestedSmallExperiment:
        'Try pre-deciding one small boundary so it does not need to be renegotiated each time.',
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
    gentleReflection:
        'This kind of signal can point to what gives energy back without needing a major life change.',
    suggestedSmallExperiment:
        'Try protecting one small choice, connection, or creative moment this week.',
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
    gentleReflection: '这也许不是需要做得更多，而是这一周哪里少了一点柔软的边界。',
    suggestedSmallExperiment: '可以试着在最密的一段前后，留一个很小的 buffer。',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'recovery_debt_zh_hans',
    title: '恢复感欠账',
    abstractPattern: '有些时候，连续几天都在消耗之后，休息会开始像一件需要补上的事。',
    commonScenes: const ['身体', '休息', '工作'],
    commonFrictions: const ['恢复感欠账', '恢复空间太少'],
    energyLoadHint: 'high-drain',
    possiblePositiveSignal: '早一点出现的休息信号',
    gentleReflection: '这个信号也许在提醒你，在一周变得太满之前，先给恢复留一点位置。',
    suggestedSmallExperiment: '可以先选一个很低成本的恢复块，不等疲惫变得很大声。',
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
    gentleReflection: '消耗也许来自一次次转换，而不一定来自任务本身。',
    suggestedSmallExperiment: '可以试着把一小组消息或任务集中处理，而不是整天反复碰它们。',
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
    gentleReflection: '摩擦也许来自期待不清，而不一定是谁做错了。',
    suggestedSmallExperiment: '可以在低压力的时刻，先问一个具体的下一步或边界。',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'late_night_compensation_behavior_zh_hans',
    title: '深夜补偿感',
    abstractPattern: '有些时候，深夜会变成把白天失去的自由感补回来的一段时间。',
    commonScenes: const ['休息', '注意力', '个人时间'],
    commonFrictions: const ['白天自由感少', '恢复被推迟'],
    energyLoadHint: 'buffer',
    possiblePositiveSignal: '需要一点属于自己的空间',
    gentleReflection: '这也许是在提醒你，白天更早一点的位置也需要一点自己的时间。',
    suggestedSmallExperiment: '可以在一天完全结束前，先放进一个很小的自主选择时刻。',
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
    gentleReflection: '安静的正向信号，也可以成为“什么对你有帮助”的证据。',
    suggestedSmallExperiment: '可以只是注意一个让你轻一点的小时刻，不把它变成任务。',
    language: 'zh-Hans',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
  LibraryPatternModel(
    id: 'boundary_fatigue_zh_hans',
    title: '边界疲惫',
    abstractPattern: '有些疲惫不是来自某一个请求，而是连续很多个小边界决定挤在一起。',
    commonScenes: const ['消息', '关系', '工作'],
    commonFrictions: const ['边界负担', '很多小决定'],
    energyLoadHint: 'boundary',
    possiblePositiveSignal: '被保护的一点空间',
    gentleReflection: '有用的信号也许在于：哪些反复出现的“要不要”正在消耗你。',
    suggestedSmallExperiment: '可以先预设一个很小的边界，让它不用每次都重新谈一次。',
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
    gentleReflection: '这种信号也许在指向：什么能在不大改生活的情况下，把一点能量还给你。',
    suggestedSmallExperiment: '可以试着保护一个很小的选择、连接或创作时刻。',
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
    gentleReflection: '這也許不是需要做得更多，而是這一週哪裡少了一點柔軟的邊界。',
    suggestedSmallExperiment: '可以試著在最密的一段前後，留一個很小的 buffer。',
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
    gentleReflection: '這個信號也許在提醒你，在一週變得太滿之前，先給恢復留一點位置。',
    suggestedSmallExperiment: '可以先選一個很低成本的恢復塊，不等疲憊變得很大聲。',
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
    gentleReflection: '消耗也許來自一次次轉換，而不一定來自任務本身。',
    suggestedSmallExperiment: '可以試著把一小組訊息或任務集中處理，而不是整天反覆碰它們。',
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
    gentleReflection: '摩擦也許來自期待不清，而不一定是誰做錯了。',
    suggestedSmallExperiment: '可以在低壓力的時刻，先問一個具體的下一步或邊界。',
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
    gentleReflection: '這也許是在提醒你，白天更早一點的位置也需要一點自己的時間。',
    suggestedSmallExperiment: '可以在一天完全結束前，先放進一個很小的自主選擇時刻。',
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
    gentleReflection: '安靜的正向信號，也可以成為「什麼對你有幫助」的證據。',
    suggestedSmallExperiment: '可以只是注意一個讓你輕一點的小時刻，不把它變成任務。',
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
    gentleReflection: '有用的信號也許在於：哪些反覆出現的「要不要」正在消耗你。',
    suggestedSmallExperiment: '可以先預設一個很小的邊界，讓它不用每次都重新談一次。',
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
    gentleReflection: '這種信號也許在指向：什麼能在不大改生活的情況下，把一點能量還給你。',
    suggestedSmallExperiment: '可以試著保護一個很小的選擇、連結或創作時刻。',
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
    gentleReflection: 'もっと頑張ることよりも、週のどこに柔らかい余白がないかを見てもよさそうです。',
    suggestedSmallExperiment: 'いちばん密な時間の前後に、小さなバッファをひとつ置いてみてもよさそうです。',
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
    gentleReflection: '週がいっぱいになる前に、回復の場所を少し残す必要があるというシグナルかもしれません。',
    suggestedSmallExperiment: '疲れが大きくなる前に、低コストの回復ブロックをひとつ選んでみてもよさそうです。',
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
    gentleReflection: '消耗はタスクそのものより、何度も移動することから来ているかもしれません。',
    suggestedSmallExperiment:
        '一日中少しずつ触る代わりに、小さなメッセージやタスクのまとまりを一度に扱ってみてもよさそうです。',
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
    gentleReflection: '摩擦は、誰かが間違っていることよりも、期待が曖昧なことから来ているかもしれません。',
    suggestedSmallExperiment: '負荷の低い場面で、具体的な次の一歩や境界をひとつ尋ねてみてもよさそうです。',
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
    gentleReflection: '一日が終わる前に、もう少し早い時間にも自分の時間が必要だというシグナルかもしれません。',
    suggestedSmallExperiment: '一日が完全に閉じる前に、小さな「自分で選ぶ」瞬間を置いてみてもよさそうです。',
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
    gentleReflection: '静かなポジティブシグナルも、何が助けになるかを見る手がかりになります。',
    suggestedSmallExperiment: 'タスクにせず、少し楽になった小さな瞬間をひとつ気づくだけでもよさそうです。',
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
    gentleReflection: '何度も出てくる小さな「はい／いいえ」が、エネルギーを使っている場所かもしれません。',
    suggestedSmallExperiment: '毎回交渉しなくてよいように、小さな境界をひとつ先に決めてみてもよさそうです。',
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
    gentleReflection: '大きく生活を変えなくても、少しエネルギーを戻してくれるものを指しているシグナルかもしれません。',
    suggestedSmallExperiment: '小さな選択、つながり、創作の時間をひとつ守ってみてもよさそうです。',
    language: 'ja',
    createdAt: _curatedSeedDate,
    updatedAt: _curatedSeedDate,
  ),
];
