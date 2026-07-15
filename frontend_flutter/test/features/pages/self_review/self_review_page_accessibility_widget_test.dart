import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ai_opportunity_radar/core/api/api_client.dart';
import 'package:ai_opportunity_radar/core/api/repositories/self_review_repository.dart';
import 'package:ai_opportunity_radar/core/local/local_capture_repository.dart';
import 'package:ai_opportunity_radar/core/models/self_review_models.dart';
import 'package:ai_opportunity_radar/features/pages/me/me_view_model.dart';
import 'package:ai_opportunity_radar/features/pages/self_review/self_review_page.dart';
import 'package:ai_opportunity_radar/features/pages/self_review/self_review_view_model.dart';
import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';

import '../../../helpers/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'SelfReview follows Aurora hierarchy at 390x844 and 1.3x text scale',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    final meVm = await buildMeViewModel();
    final reviewVm = SelfReviewViewModel(
      _StubSelfReviewRepository(
        const SelfReviewModel(
          status: 'ready',
          reviewedDays: 7,
          repeatedBlockers: ['Switching too often makes recovery harder.'],
          mainDrains: ['Decision load stays high late in the day.'],
          helpingPatterns: ['A short buffer before the next task helps.'],
          closingNote: 'Keep the next adjustment small and observable.',
        ),
      ),
    );
    addTearDown(reviewVm.dispose);
    addTearDown(meVm.dispose);

    await tester.pumpWidget(
      buildTestApp(
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.3),
          ),
          child: SelfReviewPage(),
        ),
        providers: [
          ChangeNotifierProvider<SelfReviewViewModel>.value(value: reviewVm),
          ChangeNotifierProvider<MeViewModel>.value(value: meVm),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuroraHeroTitle), findsOneWidget);
    expect(find.byType(AuroraHeroEmblem), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('self-review-back'))),
      const Size(44, 44),
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('self-review-heading-semantics')),
      ),
      matchesSemantics(
        label: 'Why is recovery difficult at night?',
        isHeader: true,
      ),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

class _StubSelfReviewRepository extends SelfReviewRepository {
  final SelfReviewModel model;

  _StubSelfReviewRepository(this.model)
      : super(
          localCaptureRepository: LocalCaptureRepository(createDummyDatabase()),
          apiClient: ApiClient(
            baseUrl: 'https://example.invalid',
            userId: 'self-review-widget-test',
          ),
        );

  @override
  Future<SelfReviewModel> fetchSelfReview() async => model;
}
