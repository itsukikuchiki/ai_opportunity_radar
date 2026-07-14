import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

typedef PrivacySafeLogSink = void Function(PrivacySafeLogRecord record);
typedef DiagnosticIdFactory = String Function();

class PrivacySafeLogRecord {
  final String eventId;
  final String operation;
  final String errorType;
  final String fingerprint;
  final String? requestId;
  final bool fatal;
  final DateTime occurredAt;

  const PrivacySafeLogRecord({
    required this.eventId,
    required this.operation,
    required this.errorType,
    required this.fingerprint,
    required this.requestId,
    required this.fatal,
    required this.occurredAt,
  });

  Map<String, Object?> toSafeFields() => {
        'event_id': eventId,
        'operation': operation,
        'error_type': errorType,
        'fingerprint': fingerprint,
        if (requestId != null) 'request_id': requestId,
        'fatal': fatal,
        'occurred_at': occurredAt.toUtc().toIso8601String(),
      };

  String toSafeLine() => toSafeFields()
      .entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' ');
}

/// Records only diagnostic metadata. Exception messages, HTTP bodies, user
/// text, local file paths, and stack traces are intentionally never retained.
class PrivacySafeLogger {
  static final PrivacySafeLogger instance = PrivacySafeLogger();

  final PrivacySafeLogSink _sink;
  final DiagnosticIdFactory _idFactory;
  final DateTime Function() _clock;
  final int maxBufferedRecords;
  final List<PrivacySafeLogRecord> _records = [];

  PrivacySafeLogger({
    PrivacySafeLogSink? sink,
    DiagnosticIdFactory? idFactory,
    DateTime Function()? clock,
    this.maxBufferedRecords = 100,
  })  : _sink = sink ?? _developerSink,
        _idFactory = idFactory ?? const Uuid().v4,
        _clock = clock ?? DateTime.now;

  List<PrivacySafeLogRecord> get records => List.unmodifiable(_records);

  PrivacySafeLogRecord capture(
    Object error,
    StackTrace stackTrace, {
    required String operation,
    String? requestId,
    bool fatal = false,
  }) {
    final record = PrivacySafeLogRecord(
      eventId: _safeToken(_idFactory(), fallback: 'event'),
      operation: _safeToken(operation, fallback: 'unknown_operation'),
      errorType: _safeToken(error.runtimeType.toString(), fallback: 'Error'),
      fingerprint: _fingerprint(error.runtimeType.toString(), stackTrace),
      requestId: requestId == null
          ? null
          : _safeToken(requestId, fallback: 'unknown_request'),
      fatal: fatal,
      occurredAt: _clock(),
    );
    _records.add(record);
    if (_records.length > maxBufferedRecords) {
      _records.removeRange(0, _records.length - maxBufferedRecords);
    }
    _sink(record);
    return record;
  }

  void installFlutterHandlers() {
    FlutterError.onError = (details) {
      capture(
        details.exception,
        details.stack ?? StackTrace.current,
        operation: 'flutter_framework',
        fatal: false,
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      capture(
        error,
        stackTrace,
        operation: 'platform_dispatcher',
        fatal: true,
      );
      return true;
    };

    ErrorWidget.builder = (details) {
      capture(
        details.exception,
        details.stack ?? StackTrace.current,
        operation: 'widget_build',
        fatal: false,
      );
      return const _PrivacySafeFrameworkErrorWidget();
    };
  }

  static void _developerSink(PrivacySafeLogRecord record) {
    developer.log(record.toSafeLine(), name: 'SignalPath');
  }

  static String _safeToken(String value, {required String fallback}) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (normalized.isEmpty) return fallback;
    return normalized.length <= 96 ? normalized : normalized.substring(0, 96);
  }

  static String _fingerprint(String errorType, StackTrace stackTrace) {
    final firstFrame = stackTrace
        .toString()
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => 'no_stack');
    final source = '$errorType|$firstFrame';
    var hash = 0x811C9DC5;
    for (final unit in source.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class _PrivacySafeFrameworkErrorWidget extends StatelessWidget {
  const _PrivacySafeFrameworkErrorWidget();

  @override
  Widget build(BuildContext context) {
    final locale = PlatformDispatcher.instance.locale;
    final message = switch (locale.languageCode.toLowerCase()) {
      'ja' => 'この内容を表示できません。',
      'zh' when _isTraditional(locale) => '暫時無法顯示這項內容。',
      'zh' => '暂时无法显示这项内容。',
      _ => 'This content is temporarily unavailable.',
    };
    return ColoredBox(
      color: const Color(0xFFFFFCFA),
      child: Center(
        child: Semantics(
          label: message,
          child: Text(
            message,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
  }

  static bool _isTraditional(Locale locale) {
    final script = locale.scriptCode?.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    return script == 'hant' ||
        country == 'TW' ||
        country == 'HK' ||
        country == 'MO';
  }
}
