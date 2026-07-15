import 'package:flutter/material.dart';

import '../../core/i18n/app_locale_text.dart';
import '../../shared/widgets/aurora_ui.dart';

class InitializationFailurePage extends StatelessWidget {
  final String? referenceId;
  final Future<void> Function() onRetry;

  const InitializationFailurePage({
    super.key,
    required this.referenceId,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final title = AppLocaleText.tr(
      context,
      en: 'Signal Path could not finish starting',
      zhHans: 'Signal Path 暂时无法完成启动',
      zhHant: 'Signal Path 暫時無法完成啟動',
      ja: 'Signal Path を起動できませんでした',
    );
    final body = AppLocaleText.tr(
      context,
      en: 'Your data was not changed. Try again. If this keeps happening, share the reference code with support.',
      zhHans: '你的数据没有被修改。请重试；如果仍然发生，可以把参考编号提供给支持人员。',
      zhHant: '你的資料沒有被修改。請重試；如果仍然發生，可以把參考編號提供給支援人員。',
      ja: 'データは変更されていません。もう一度お試しください。繰り返し発生する場合は、参照番号をサポートにお知らせください。',
    );
    final retry = AppLocaleText.tr(
      context,
      en: 'Try again',
      zhHans: '重试',
      zhHant: '重試',
      ja: 'もう一度試す',
    );
    final referenceLabel = AppLocaleText.tr(
      context,
      en: 'Reference code',
      zhHans: '参考编号',
      zhHant: '參考編號',
      ja: '参照番号',
    );

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 700;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: AuroraCard(
                            key: const ValueKey(
                              'initialization-failure-surface',
                            ),
                            padding: EdgeInsets.fromLTRB(
                              compact ? 20 : 26,
                              compact ? 22 : 30,
                              compact ? 20 : 26,
                              compact ? 22 : 28,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ExcludeSemantics(
                                  child: SizedBox.square(
                                    dimension: compact ? 106 : 122,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        AuroraHeroEmblem(
                                          size: compact ? 106 : 122,
                                          opacity: 0.90,
                                        ),
                                        const Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: AuroraSectionIcon(
                                            icon: Icons.refresh_rounded,
                                            color: AuroraColors.purple,
                                            size: 36,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: compact ? 14 : 20),
                                Semantics(
                                  header: true,
                                  child: AuroraHeroTitle(
                                    key: const ValueKey(
                                      'initialization-failure-title',
                                    ),
                                    text: title,
                                    fontSize: compact ? 25 : 28,
                                    maxLines: 4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  body,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: AuroraColors.muted,
                                        height: 1.48,
                                      ),
                                ),
                                if (referenceId != null &&
                                    referenceId!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Semantics(
                                    label: '$referenceLabel ${referenceId!}',
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.56),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: AuroraColors.line
                                              .withValues(alpha: 0.72),
                                        ),
                                      ),
                                      child: Text(
                                        '$referenceLabel: ${referenceId!}',
                                        key: const ValueKey(
                                          'initialization-failure-reference',
                                        ),
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                          color: AuroraColors.ink
                                              .withValues(alpha: 0.70),
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                Semantics(
                                  button: true,
                                  label: retry,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      key: const ValueKey(
                                        'initialization-retry-action',
                                      ),
                                      onPressed: onRetry,
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(48),
                                      ),
                                      icon: const Icon(Icons.refresh_rounded),
                                      label: Text(retry),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const AuroraSafeTopMask(extraHeight: 0),
        ],
      ),
    );
  }
}
