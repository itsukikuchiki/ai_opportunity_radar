import 'package:ai_opportunity_radar/shared/widgets/aurora_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('main-page scroll padding reserves the floating nav once',
      (tester) async {
    double? scaffoldInjectedBottom;
    EdgeInsets? scrollPadding;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          bottomNavigationBar: const SizedBox(height: 80),
          body: Builder(
            builder: (context) {
              scaffoldInjectedBottom = MediaQuery.paddingOf(context).bottom;
              scrollPadding = AuroraMainPageSpec.scrollPadding(context);
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(scaffoldInjectedBottom, 80);
    expect(
      scrollPadding,
      const EdgeInsets.fromLTRB(18, 14, 18, 96),
    );
  });

  testWidgets(
    'four hero patterns share accessible premium decorative rendering',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              SizedBox(
                key: ValueKey('signal-slot'),
                width: 240,
                height: 90,
                child: AuroraSignalHeroPattern(opacity: 0.51),
              ),
              SizedBox(
                key: ValueKey('review-slot'),
                width: 240,
                height: 90,
                child: AuroraReviewHeroPattern(opacity: 0.62),
              ),
              SizedBox(
                key: ValueKey('experiment-slot'),
                width: 240,
                height: 90,
                child: AuroraExperimentHeroPattern(opacity: 0.73),
              ),
              SizedBox(
                key: ValueKey('journey-slot'),
                width: 240,
                height: 90,
                child: AuroraJourneyHeroPattern(opacity: 0.84),
              ),
            ],
          ),
        ),
      );

      final patterns = <Type, double>{
        AuroraSignalHeroPattern: 0.51,
        AuroraReviewHeroPattern: 0.62,
        AuroraExperimentHeroPattern: 0.73,
        AuroraJourneyHeroPattern: 0.84,
      };
      for (final entry in patterns.entries) {
        final pattern = find.byType(entry.key);
        expect(pattern, findsOneWidget);
        expect(
          find.descendant(
            of: pattern,
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: pattern, matching: find.byType(Image)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: pattern, matching: find.byType(CustomPaint)),
          findsNothing,
        );
        final opacity = tester.widget<Opacity>(
          find.descendant(of: pattern, matching: find.byType(Opacity)),
        );
        expect(opacity.opacity, entry.value);
      }
    },
  );

  testWidgets('experiment art keeps configurable alignment and fit',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 260,
          height: 160,
          child: AuroraExperimentHeroPattern(
            alignment: Alignment.topRight,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );

    final pattern = tester.widget<AuroraExperimentHeroPattern>(
      find.byType(AuroraExperimentHeroPattern),
    );
    expect(pattern.alignment, Alignment.topRight);
    expect(pattern.fit, BoxFit.contain);
  });

  testWidgets('each hero pattern loads its canonical raster asset',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            SizedBox(
              width: 220,
              height: 80,
              child: AuroraSignalHeroPattern(),
            ),
            SizedBox(
              width: 220,
              height: 80,
              child: AuroraReviewHeroPattern(),
            ),
            SizedBox(
              width: 220,
              height: 80,
              child: AuroraExperimentHeroPattern(),
            ),
            SizedBox(
              width: 220,
              height: 80,
              child: AuroraJourneyHeroPattern(),
            ),
          ],
        ),
      ),
    );

    final paths = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as AssetImage).assetName)
        .toSet();
    expect(
      paths,
      containsAll(<String>{
        'assets/hero_art/today-signal-points-v1.png',
        'assets/hero_art/weekly-review-network-v1.png',
        'assets/experiment/life-experiment-branching-v2.png',
        'assets/hero_art/journey-ring-path-v1.png',
      }),
    );
  });
}
