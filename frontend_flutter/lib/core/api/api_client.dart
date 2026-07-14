import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config/build_environment.dart';
import '../diagnostics/privacy_safe_logger.dart';

typedef RequestIdFactory = String Function();

class ApiException implements Exception {
  final String method;
  final String path;
  final int statusCode;
  final String? code;
  final String message;
  final String requestId;

  ApiException({
    required this.method,
    required this.path,
    required this.statusCode,
    required this.message,
    required this.requestId,
    this.code,
  });

  @override
  String toString() {
    final prefix = code == null ? '' : '[$code] ';
    return 'Request failed ($statusCode): ${prefix}request_id=$requestId';
  }
}

class ApiClient {
  final String baseUrl;
  final String userId;
  final http.Client _httpClient;
  final RequestIdFactory _requestIdFactory;
  final PrivacySafeLogger _logger;

  ApiClient({
    String? baseUrl,
    required this.userId,
    http.Client? httpClient,
    RequestIdFactory? requestIdFactory,
    PrivacySafeLogger? logger,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl(),
        _httpClient = httpClient ?? http.Client(),
        _requestIdFactory = requestIdFactory ?? const Uuid().v4,
        _logger = logger ?? PrivacySafeLogger.instance;

  static String _defaultBaseUrl() {
    const fromEnv = BuildEnvironment.apiBaseUrl;
    if (fromEnv.isNotEmpty) return fromEnv;

    return 'https://aiopportunityradar-production.up.railway.app';
  }

  String createRequestId() => _requestIdFactory();

  Map<String, String> requestHeaders({
    String? requestId,
    Map<String, String> additional = const {},
  }) {
    return {
      ...additional,
      'Content-Type': 'application/json',
      'X-User-Id': userId,
      'X-Request-Id': requestId ?? createRequestId(),
    };
  }

  Future<Map<String, dynamic>> getJson(String path) => getJsonWithHeaders(path);

  Future<Map<String, dynamic>> getJsonWithHeaders(
    String path, {
    Map<String, String> additionalHeaders = const {},
  }) {
    return _execute(
      method: 'GET',
      path: path,
      additionalHeaders: additionalHeaders,
      send: (headers) => _httpClient.get(
        Uri.parse('$baseUrl$path'),
        headers: headers,
      ),
    );
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) =>
      postJsonWithHeaders(path, body);

  Future<Map<String, dynamic>> postJsonWithHeaders(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> additionalHeaders = const {},
  }) {
    return _execute(
      method: 'POST',
      path: path,
      additionalHeaders: additionalHeaders,
      send: (headers) => _httpClient.post(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body,
  ) =>
      patchJsonWithHeaders(path, body);

  Future<Map<String, dynamic>> patchJsonWithHeaders(
    String path,
    Map<String, dynamic> body, {
    Map<String, String> additionalHeaders = const {},
  }) {
    return _execute(
      method: 'PATCH',
      path: path,
      additionalHeaders: additionalHeaders,
      send: (headers) => _httpClient.patch(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? body,
  }) =>
      deleteJsonWithHeaders(path, body: body);

  Future<Map<String, dynamic>> deleteJsonWithHeaders(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String> additionalHeaders = const {},
  }) {
    return _execute(
      method: 'DELETE',
      path: path,
      additionalHeaders: additionalHeaders,
      send: (headers) => _httpClient.delete(
        Uri.parse('$baseUrl$path'),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> _execute({
    required String method,
    required String path,
    required Map<String, String> additionalHeaders,
    required Future<http.Response> Function(Map<String, String> headers) send,
  }) async {
    final requestId = createRequestId();
    try {
      final response = await send(requestHeaders(
        requestId: requestId,
        additional: additionalHeaders,
      ));
      _throwIfFailed(method, path, requestId, response);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (error, stackTrace) {
      _logger.capture(
        error,
        stackTrace,
        operation: 'api_request',
        requestId: requestId,
      );
      rethrow;
    }
  }

  void _throwIfFailed(
    String method,
    String path,
    String requestId,
    http.Response response,
  ) {
    if (response.statusCode < 400) return;
    String? code;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is Map<String, dynamic>) {
          code = _safeResponseCode(detail['code']);
        }
      }
    } catch (_) {
      // A non-JSON response is intentionally not copied into the exception.
    }
    throw ApiException(
      method: method,
      path: path,
      statusCode: response.statusCode,
      code: code,
      message: 'The service could not complete this request.',
      requestId: requestId,
    );
  }

  void close() => _httpClient.close();

  static String? _safeResponseCode(Object? value) {
    final candidate = value?.toString().trim();
    if (candidate == null || candidate.isEmpty || candidate.length > 64) {
      return null;
    }
    return RegExp(r'^[A-Za-z0-9_.:-]+$').hasMatch(candidate) ? candidate : null;
  }
}
