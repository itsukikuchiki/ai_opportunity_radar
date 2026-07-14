import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/weekly_models.dart';
import '../../../shared/widgets/aurora_ui.dart';

class TodayExperimentFeedbackPage extends StatefulWidget {
  final String experimentId;

  const TodayExperimentFeedbackPage({
    super.key,
    required this.experimentId,
  });

  @override
  State<TodayExperimentFeedbackPage> createState() =>
      _TodayExperimentFeedbackPageState();
}

class _TodayExperimentFeedbackPageState
    extends State<TodayExperimentFeedbackPage> {
  final _noteController = TextEditingController();
  String _status = 'tried';
  bool _loading = true;
  bool _saving = false;
  LifeExperimentModel? _experiment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final deps = context.read<AppDependencies>();
    final experiment = await deps.localLifeExperimentRepository.getById(
      widget.experimentId,
    );
    if (!mounted) return;
    setState(() {
      _experiment = experiment;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final experiment = _experiment;
    if (experiment == null || _saving) return;
    setState(() => _saving = true);
    final deps = context.read<AppDependencies>();
    await deps.localLifeExperimentRepository.recordFeedback(
      experimentId: experiment.id,
      localUserId: deps.localUserId,
      completionStatus: _status,
      feedbackText: _noteController.text.trim().isEmpty
          ? _defaultFeedbackText(_status)
          : _noteController.text.trim(),
      feedbackDate: DateTime.now(),
      conditionTags: [_status],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocaleText.tr(
            context,
            en: 'Experiment feedback saved.',
            zhHans: '实验反馈已保存。',
            zhHant: '實驗回饋已保存。',
            ja: '実験のフィードバックを保存しました。',
          ),
        ),
      ),
    );
    context.go(AppRoutes.today);
  }

  String _defaultFeedbackText(String status) {
    switch (status) {
      case 'helpful':
        return 'This helped today.';
      case 'adjusted':
      case 'too_hard':
        return 'This could be adjusted next time.';
      case 'not_today':
        return 'This was not suitable today.';
      default:
        return 'This experiment happened today.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final experiment = _experiment;
    return Scaffold(
      body: AuroraPage(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go(AppRoutes.today),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Experiment feedback',
                        zhHans: '实验反馈',
                        zhHant: '實驗回饋',
                        ja: '実験フィードバック',
                      ),
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AuroraColors.ink,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 18),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (experiment == null)
                AuroraCard(
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'This experiment could not be found.',
                      zhHans: '没有找到这条实验。',
                      zhHant: '沒有找到這條實驗。',
                      ja: 'この実験が見つかりません。',
                    ),
                  ),
                )
              else ...[
                AuroraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        experiment.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AuroraColors.purple,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        experiment.suggestedAction,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AuroraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocaleText.tr(
                          context,
                          en: 'What happened today?',
                          zhHans: '今天发生了什么？',
                          zhHant: '今天發生了什麼？',
                          ja: '今日どうでしたか？',
                        ),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FeedbackChoice(
                            selected: _status == 'tried',
                            label: AppLocaleText.tr(context,
                                en: 'Happened',
                                zhHans: '发生了',
                                zhHant: '發生了',
                                ja: 'できた'),
                            onTap: () => setState(() => _status = 'tried'),
                          ),
                          _FeedbackChoice(
                            selected: _status == 'helpful',
                            label: AppLocaleText.tr(context,
                                en: 'Helpful',
                                zhHans: '有帮助',
                                zhHant: '有幫助',
                                ja: '役立った'),
                            onTap: () => setState(() => _status = 'helpful'),
                          ),
                          _FeedbackChoice(
                            selected:
                                _status == 'adjusted' || _status == 'too_hard',
                            label: AppLocaleText.tr(context,
                                en: 'Want to adjust',
                                zhHans: '想调整',
                                zhHant: '想調整',
                                ja: '調整したい'),
                            onTap: () => setState(() => _status = 'adjusted'),
                          ),
                          _FeedbackChoice(
                            selected: _status == 'not_today',
                            label: AppLocaleText.tr(context,
                                en: 'Not today',
                                zhHans: '今天不适合',
                                zhHant: '今天不適合',
                                ja: '今日は合わない'),
                            onTap: () => setState(() => _status = 'not_today'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _noteController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: AppLocaleText.tr(
                            context,
                            en: 'Add one sentence if you want.',
                            zhHans: '如果愿意，可以补一句。',
                            zhHant: '如果願意，可以補一句。',
                            ja: '必要なら一言足せます。',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AuroraPillButton(
                  filled: true,
                  label: _saving
                      ? AppLocaleText.tr(context,
                          en: 'Saving', zhHans: '保存中', zhHant: '保存中', ja: '保存中')
                      : AppLocaleText.tr(context,
                          en: 'Save feedback',
                          zhHans: '保存反馈',
                          zhHant: '保存回饋',
                          ja: '保存する'),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackChoice extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onTap;

  const _FeedbackChoice({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: AuroraColors.purple.withValues(alpha: 0.16),
    );
  }
}
