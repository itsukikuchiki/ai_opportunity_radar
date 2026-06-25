import 'package:flutter_test/flutter_test.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/ai_repository.dart';

void main() {
  test('capture reply fallback stays grounded in specific user text', () async {
    final repository = AiRepository(_FailingApiClient());
    final examples = <String, List<String>>{
      'token好贵': ['token', '成本', '贵'],
      '每周只有骑马是值得期待的': ['骑马', '期待', '恢复'],
      '我们永远无法预测明天会发生什么，但可以好好活在当下': ['明天', '当下'],
      '好想早日退休': ['退休', '工作', '离开'],
      '明天可以去骑马好开心': ['骑马', '开心', '期待'],
    };

    for (final entry in examples.entries) {
      final result = await repository.generateCaptureReply(
        content: entry.key,
        recentAssistantTexts: const [],
      );
      final combined = [
        result.acknowledgement,
        result.observation,
        result.tryNext,
      ].join();

      expect(
        entry.value.any(combined.contains),
        true,
        reason: 'Reply should reference "${entry.key}" but was: $combined',
      );
      expect(combined, isNot(contains('这种小瞬间其实也很有信息量')));
      expect(combined, isNot(contains('先不用急着解释清楚')));
    }
  });
}

class _FailingApiClient extends ApiClient {
  _FailingApiClient() : super(baseUrl: 'http://127.0.0.1:1', userId: 'test');

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    throw Exception('offline');
  }
}
