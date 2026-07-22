import 'dart:convert';

class FollowupQuestionModel {
  final String id;
  final String question;
  final List<FollowupOptionModel> options;

  FollowupQuestionModel({
    required this.id,
    required this.question,
    required this.options,
  });

  factory FollowupQuestionModel.fromJson(Map<String, dynamic> json) {
    return FollowupQuestionModel(
      id: json['id'] as String,
      question: json['question'] as String,
      options: ((json['options'] as List?) ?? [])
          .map((e) => FollowupOptionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FollowupOptionModel {
  final String label;
  final String value;

  FollowupOptionModel({
    required this.label,
    required this.value,
  });

  factory FollowupOptionModel.fromJson(Map<String, dynamic> json) {
    return FollowupOptionModel(
      label: json['label'] as String,
      value: json['value'] as String,
    );
  }
}

class TodayInsightModel {
  final String text;

  TodayInsightModel({required this.text});
}

class DailyBestActionModel {
  final String text;

  DailyBestActionModel({required this.text});
}

class RecentSignalModel {
  final String? id;
  final String? signalCardId;
  final String? clientId;
  final String? serverId;
  final String sourceType;
  final String content;
  final DateTime? createdAt;
  final String? localDate;
  final String? timezone;
  final String? acknowledgement;
  final String? observation;
  final String? tryNext;
  final String? emotion;
  final String? intensity;
  final String? scene;
  final String? friction;
  final String? positiveSignal;
  final String? energyLoad;
  final String? energyState;
  final List<String> linkedLifeChainStages;
  final Map<String, dynamic> rawPayloadJson;
  final List<String> sceneTags;
  final List<String> intentTags;
  final String userConfirmation;
  final Map<String, dynamic> userCorrectionJson;
  final bool includedInSummary;
  final bool includedInWeekly;
  final bool includedInJourney;
  final String privacyLevel;
  final bool isLegacy;
  final String migrationStatus;
  final bool isLocalDraft;
  final bool syncFailed;

  RecentSignalModel({
    this.id,
    this.signalCardId,
    this.clientId,
    this.serverId,
    this.sourceType = 'text',
    required this.content,
    this.createdAt,
    this.localDate,
    this.timezone,
    this.acknowledgement,
    this.observation,
    this.tryNext,
    this.emotion,
    this.intensity,
    this.scene,
    this.friction,
    this.positiveSignal,
    this.energyLoad,
    this.energyState,
    this.linkedLifeChainStages = const [],
    this.rawPayloadJson = const {},
    this.sceneTags = const [],
    this.intentTags = const [],
    this.userConfirmation = 'unconfirmed',
    this.userCorrectionJson = const {},
    this.includedInSummary = false,
    this.includedInWeekly = false,
    this.includedInJourney = false,
    this.privacyLevel = 'private',
    this.isLegacy = false,
    this.migrationStatus = 'native',
    this.isLocalDraft = false,
    this.syncFailed = false,
  });

  factory RecentSignalModel.fromJson(Map<String, dynamic> json) {
    return RecentSignalModel(
      id: json['id'] as String?,
      signalCardId: (json['signal_card_id'] as String?) ??
          (json['signalCardId'] as String?),
      clientId: (json['client_id'] as String?) ?? (json['clientId'] as String?),
      serverId: (json['server_id'] as String?) ?? (json['serverId'] as String?),
      sourceType: (json['source_type'] as String?) ??
          (json['sourceType'] as String?) ??
          'text',
      content: (json['raw_text'] as String?) ??
          (json['content'] as String?) ??
          (json['summary'] as String?) ??
          '',
      createdAt: _parseDateTime(
        json['created_at'] ??
            json['createdAt'] ??
            json['timestamp'] ??
            json['captured_at'],
      ),
      localDate:
          (json['local_date'] as String?) ?? (json['localDate'] as String?),
      timezone: json['timezone'] as String?,
      acknowledgement: (json['acknowledgement'] as String?) ??
          (json['ai_reply'] as String?) ??
          (json['ai_acknowledgement'] as String?) ??
          (json['response'] as String?),
      observation: (json['observation'] as String?) ??
          (json['observation_text'] as String?) ??
          (json['ai_observation'] as String?),
      tryNext: (json['try_next'] as String?) ??
          (json['tryNext'] as String?) ??
          (json['try_text'] as String?) ??
          (json['ai_try_next'] as String?),
      emotion: (json['emotion'] as String?) ?? (json['ai_emotion'] as String?),
      intensity:
          (json['intensity'] as String?) ?? (json['ai_intensity'] as String?),
      scene: json['scene'] as String?,
      friction: json['friction'] as String?,
      positiveSignal: (json['positive_signal'] as String?) ??
          (json['positiveSignal'] as String?),
      energyLoad:
          (json['energy_load'] as String?) ?? (json['energyLoad'] as String?),
      energyState:
          (json['energy_state'] as String?) ?? (json['energyState'] as String?),
      linkedLifeChainStages: _parseStringList(
        json['linked_life_chain_stage'] ?? json['linkedLifeChainStage'],
      ),
      rawPayloadJson: _parseMap(
        json['raw_payload_json'] ?? json['rawPayloadJson'],
      ),
      sceneTags: _parseStringList(
        json['scene_tags'] ?? json['ai_scene_tags_json'] ?? json['scene'],
      ),
      intentTags: _parseStringList(
        json['intent_tags'] ?? json['ai_intent_tags_json'],
      ),
      userConfirmation: (json['user_confirmation'] as String?) ?? 'unconfirmed',
      userCorrectionJson: _parseMap(
        json['user_correction_json'] ?? json['userCorrectionJson'],
      ),
      includedInSummary: _parseBool(json['included_in_summary']),
      includedInWeekly: _parseBool(json['included_in_weekly']),
      includedInJourney: _parseBool(json['included_in_journey']),
      privacyLevel: (json['privacy_level'] as String?) ??
          (json['privacyLevel'] as String?) ??
          'private',
      isLegacy: _parseBool(json['is_legacy']),
      migrationStatus: (json['migration_status'] as String?) ?? 'native',
      isLocalDraft: _parseBool(json['is_local_draft'] ?? json['isLocalDraft']),
      syncFailed: _parseBool(json['sync_failed'] ?? json['syncFailed']),
    );
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      final value = raw.trim();
      final parsed = DateTime.tryParse(value);
      if (parsed == null) return null;
      if (parsed.isUtc) return parsed;

      // SignalCard created_at is an absolute server timestamp. Some database
      // drivers return UTC values without a trailing Z/offset; interpreting
      // those as device-local time shifts the timeline by the local offset.
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      );
    }
    return null;
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];

      if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
        return trimmed
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      final body = trimmed.substring(1, trimmed.length - 1).trim();
      if (body.isEmpty) return const [];

      return body
          .split(',')
          .map((e) => e.replaceAll('"', '').replaceAll("'", '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static Map<String, dynamic> _parseMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {}
    }
    return const {};
  }

  static bool _parseBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is int) return raw != 0;
    if (raw is String) {
      final value = raw.toLowerCase().trim();
      return value == 'true' || value == '1' || value == 'yes';
    }
    return false;
  }

  String dedupeKey() {
    return '${signalCardId ?? id ?? ''}|${content.trim().toLowerCase()}';
  }

  bool get isLibrarySaved => sourceType == 'library_saved';

  bool get isAiPredicted => sourceType == 'ai_predicted';

  bool get hasUserConfirmedLibrarySaved {
    if (!isLibrarySaved) return true;
    if (_isExplicitlyConfirmed) return true;
    if (userConfirmation != 'edited' && userConfirmation != 'supplemented') {
      return false;
    }
    return _hasPersonalContext;
  }

  bool get _hasPersonalContext {
    final edited = userCorrectionJson['edited_text']?.toString().trim();
    final supplement = userCorrectionJson['supplement_text']?.toString().trim();
    return (edited != null && edited.isNotEmpty) ||
        (supplement != null && supplement.isNotEmpty);
  }

  bool get hasUserConfirmedAiPrediction {
    if (!isAiPredicted) return true;
    if (_isExplicitlyConfirmed) return true;
    if (userConfirmation == 'edited' || userConfirmation == 'supplemented') {
      return _hasPersonalContext;
    }
    return false;
  }

  bool get _isExplicitlyConfirmed {
    final value = userConfirmation.trim().toLowerCase();
    return value == 'confirmed' || value == 'accurate' || value == 'partial';
  }

  String? get libraryPatternTitle {
    final title = rawPayloadJson['title']?.toString().trim();
    return title == null || title.isEmpty ? null : title;
  }

  String? get libraryAbstractPattern {
    final pattern = rawPayloadJson['abstract_pattern']?.toString().trim();
    return pattern == null || pattern.isEmpty ? null : pattern;
  }

  String localDateKey() {
    final existing = localDate?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    final local = createdAt?.toLocal();
    if (local == null) return '';
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class DailySnapshotModel {
  final String date;
  final int entryCount;
  final String? observationText;
  final String? suggestionText;
  final String? sourceHash;
  final DateTime? generatedAt;

  DailySnapshotModel({
    required this.date,
    required this.entryCount,
    required this.observationText,
    required this.suggestionText,
    required this.sourceHash,
    required this.generatedAt,
  });

  factory DailySnapshotModel.fromDb(Map<String, Object?> row) {
    return DailySnapshotModel(
      date: (row['date'] as String?) ?? '',
      entryCount: (row['entry_count'] as int?) ?? 0,
      observationText: row['observation_text'] as String?,
      suggestionText: row['suggestion_text'] as String?,
      sourceHash: row['source_hash'] as String?,
      generatedAt: DateTime.tryParse((row['generated_at'] as String?) ?? ''),
    );
  }
}

class AiCaptureReplyResult {
  final String acknowledgement;
  final String observation;
  final String tryNext;
  final String emotion;
  final String intensity;
  final List<String> sceneTags;
  final List<String> intentTags;
  final FollowupQuestionModel? followup;

  AiCaptureReplyResult({
    required this.acknowledgement,
    this.observation = '',
    this.tryNext = '',
    this.emotion = 'neutral',
    this.intensity = 'low',
    this.sceneTags = const [],
    this.intentTags = const [],
    required this.followup,
  });
}

class AiTodaySummaryResult {
  final String observation;
  final String suggestion;

  AiTodaySummaryResult({
    required this.observation,
    required this.suggestion,
  });
}

class LightDialogTurnModel {
  final String role;
  final String text;

  const LightDialogTurnModel({
    required this.role,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
      };
}

class LightDialogResponseModel {
  final String reply;
  final List<String> suggestedPrompts;

  const LightDialogResponseModel({
    required this.reply,
    this.suggestedPrompts = const [],
  });

  factory LightDialogResponseModel.fromJson(Map<String, dynamic> json) {
    return LightDialogResponseModel(
      reply: (json['reply'] as String?) ?? '',
      suggestedPrompts: ((json['suggested_prompts'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.trim().isNotEmpty)
          .toList(),
    );
  }
}
