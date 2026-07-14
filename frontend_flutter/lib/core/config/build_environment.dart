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
