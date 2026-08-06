import 'package:flutter/foundation.dart';

enum SignalPathBuildProfile {
  internal,
  releaseLike,
  staging,
  productionLike,
}

class BuildEnvironment {
  static const String rawProfile = String.fromEnvironment(
    'SIGNALPATH_BUILD_PROFILE',
    defaultValue: 'production-like',
  );

  static const bool enableDebugTools = bool.fromEnvironment(
    'SIGNALPATH_ENABLE_DEBUG_TOOLS',
    defaultValue: false,
  );

  static const bool enablePipelineLogs = bool.fromEnvironment(
    'SIGNALPATH_ENABLE_PIPELINE_LOGS',
    defaultValue: false,
  );

  /// Enables the isolated TestFlight showcase dataset and Pro preview.
  ///
  /// This must only be supplied to an explicitly labelled QA archive. Normal
  /// debug, staging, release-like and production-like builds all keep the
  /// value false, so no simulated data or entitlement behavior can leak into
  /// a production candidate by default.
  static const bool qaShowcaseData = bool.fromEnvironment(
    'SIGNALPATH_QA_SHOWCASE_DATA',
    defaultValue: false,
  );

  /// Optional deterministic locale for the isolated QA showcase dataset.
  ///
  /// Leave empty to follow the device locale. Localized simulator packages
  /// pass their language explicitly so persisted fixture copy cannot drift
  /// from the UI language.
  static const String qaShowcaseLanguage = String.fromEnvironment(
    'SIGNALPATH_QA_SHOWCASE_LANGUAGE',
    defaultValue: '',
  );

  /// Optional local date-time anchor for deterministic showcase screenshots.
  ///
  /// The value intentionally has no production default. Invalid explicit
  /// values fail initialization instead of silently seeding a different week.
  static const String rawQaShowcaseNow = String.fromEnvironment(
    'SIGNALPATH_QA_SHOWCASE_NOW',
    defaultValue: '',
  );

  static DateTime? get qaShowcaseNow {
    final value = rawQaShowcaseNow.trim();
    if (value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException(
        'Invalid SIGNALPATH_QA_SHOWCASE_NOW date-time',
        value,
      );
    }
    return parsed;
  }

  /// Current local clock for deterministic QA pages.
  ///
  /// Normal builds always use the real system clock. Only an explicitly
  /// enabled showcase build may substitute the fixed screenshot timestamp.
  static DateTime get effectiveNow =>
      qaShowcaseData ? (qaShowcaseNow ?? DateTime.now()) : DateTime.now();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static SignalPathBuildProfile get profile {
    switch (rawProfile) {
      case 'internal':
        return SignalPathBuildProfile.internal;
      case 'release-like':
        return SignalPathBuildProfile.releaseLike;
      case 'staging':
        return SignalPathBuildProfile.staging;
      case 'production-like':
      default:
        return SignalPathBuildProfile.productionLike;
    }
  }

  static bool get debugToolsVisible {
    return kDebugMode ||
        enableDebugTools ||
        profile == SignalPathBuildProfile.internal;
  }

  static bool get isReleaseLike {
    return profile == SignalPathBuildProfile.releaseLike ||
        profile == SignalPathBuildProfile.productionLike;
  }
}
