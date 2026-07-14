import 'package:flutter/material.dart';

import '../../core/i18n/app_locale_text.dart';

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDEBFF),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 34,
                      color: Color(0xFF7267F0),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      key: const ValueKey('initialization-failure-title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (referenceId != null && referenceId!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      label: '$referenceLabel ${referenceId!}',
                      child: Text(
                        '$referenceLabel: ${referenceId!}',
                        key: const ValueKey(
                          'initialization-failure-reference',
                        ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Semantics(
                    button: true,
                    label: retry,
                    child: FilledButton.icon(
                      key: const ValueKey('initialization-retry-action'),
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(160, 48),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(retry),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
