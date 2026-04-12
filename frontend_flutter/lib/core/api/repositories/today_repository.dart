import 'package:shared_preferences/shared_preferences.dart';

import '../../local/local_capture_repository.dart';
import '../../local/local_daily_snapshot_repository.dart';
import '../../models/today_models.dart';
import 'ai_repository.dart';

typedef FocusAreaLoader = Future<String?> Function();

class TodayRepository {
  final LocalCaptureRepository localCaptureRepository;
  final LocalDailySnapshotRepository localDailySnapshotRepository;
  final AiRepository aiRepository;
  final FocusAreaLoader? focusAreaLoader;

  TodayRepository({
    required this.localCaptureRepository,
    required this.localDailySnapshotRepository,
    required this.aiRepository,
    this.focusAreaLoader,
  });

  Future<Map<String, dynamic>> fetchToday() async {
    final todaySignals = await localCaptureRepository.listTodaySignals();
    final snapshot = await localDailySnapshotRepository.getByDate(DateTime.now());

    final sourceHash = localDailySnapshotRepository.buildSourceHash(todaySignals);

    if (todaySignals.isNotEmpty &&
        (snapshot == null || snapshot.sourceHash != sourceHash)) {
      await _regenerateTodaySummary(todaySignals);
    }

    final latestSnapshot =
        await localDailySnapshotRepository.getByDate(DateTime.now());

    return {
      'insight': TodayInsightModel(
        text: latestSnapshot?.observationText ??
            _defaultObservation(todaySignals.length),
      ),
      'pendingQuestion': null,
      'bestAction': DailyBestActionModel(
        text: latestSnapshot?.suggestionText ??
            _defaultSuggestion(todaySignals.length),
      ),
      'recentSignals': todaySignals,
    };
  }

  Future<Map<String, dynamic>> submitCapture({
    required String content,
    String? tagHint,
  }) async {
    final inserted = await localCaptureRepository.insertCapture(
      content: content,
      tagHint: tagHint,
    );

    final focusArea = await _readFocusArea();
    final recentAssistantTexts =
        await localCaptureRepository.listRecentAcknowledgements(limit: 10);

    String acknowledgement;
    FollowupQuestionModel? followup;

    try {
      final aiReply = await aiRepository.generateCaptureReply(
        content: content,
        recentAssistantTexts: recentAssistantTexts,
        focusArea: focusArea,
      );
      acknowledgement = aiReply.acknowledgement;
      followup = aiReply.followup;
    } catch (_) {
      acknowledgement = _defaultAcknowledgement(content);
      followup = null;
    }

    if (inserted.id != null) {
      await localCaptureRepository.updateAcknowledgement(
        captureId: inserted.id!,
        acknowledgement: acknowledgement,
      );
    }

    final refreshedTodaySignals =
        await localCaptureRepository.listTodaySignals();

    await _regenerateTodaySummary(refreshedTodaySignals);

    return {
      'acknowledgement': acknowledgement,
      'followup': followup,
      'updatedRecentSignals': refreshedTodaySignals,
      'localSignal': RecentSignalModel(
        id: inserted.id,
        content: inserted.content,
        createdAt: inserted.createdAt,
        acknowledgement: acknowledgement,
      ),
    };
  }

  Future<void> submitFollowup({
    required String followupId,
    required String answerValue,
  }) async {
    // Phase 1 先不做后续问题回写；保留接口，避免页面层大改。
  }

  Future<void> _regenerateTodaySummary(List<RecentSignalModel> todaySignals) async {
    final focusArea = await _readFocusArea();

    String observationText;
    String suggestionText;

    try {
      final result = await aiRepository.generateTodaySummary(
        date: DateTime.now(),
        entries: todaySignals,
        focusArea: focusArea,
      );
      observationText = result.observation;
      suggestionText = result.suggestion;
    } catch (_) {
      observationText = _defaultObservation(todaySignals.length);
      suggestionText = _defaultSuggestion(todaySignals.length);
    }

    final sourceHash =
        localDailySnapshotRepository.buildSourceHash(todaySignals);

    await localDailySnapshotRepository.upsert(
      date: DateTime.now(),
      entryCount: todaySignals.length,
      observationText: observationText,
      suggestionText: suggestionText,
      sourceHash: sourceHash,
    );
  }

  Future<String?> _readFocusArea() async {
    if (focusAreaLoader != null) {
      return focusAreaLoader!();
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('repeat_area_preference') ??
        prefs.getString('selected_repeat_area');
  }

  String _defaultAcknowledgement(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return '先把这一条留在这里。';
    }
    return '我看到了这条记录：$trimmed。先把它放在今天里。';
  }

  String _defaultObservation(int count) {
    if (count <= 0) {
      return '今天还没有记录，先留下一件真实发生的小事就好。';
    }
    if (count == 1) {
      return '今天记录了 1 条。你已经开始把今天里真实发生的事留了下来。';
    }
    return '今天记录了 $count 条。今天的线索已经开始慢慢聚起来了。';
  }

  String _defaultSuggestion(int count) {
    if (count <= 0) {
      return '今天先记下一件让你停顿了一下的小事就好。';
    }
    if (count == 1) {
      return '如果同类事情今天再出现一次，再补记一条就可以。';
    }
    return '接下来先留意：今天有没有哪类事情已经不是第一次这样发生。';
  }
}
