import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/today_models.dart';

class TodayDialogPage extends StatefulWidget {
  final String captureId;

  const TodayDialogPage({
    super.key,
    required this.captureId,
  });

  @override
  State<TodayDialogPage> createState() => _TodayDialogPageState();
}

class _TodayDialogPageState extends State<TodayDialogPage> {
  final TextEditingController _controller = TextEditingController();
  final List<LightDialogTurnModel> _turns = [];
  List<String> _suggestedPrompts = const [];
  RecentSignalModel? _signal;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<AppDependencies>().todayRepository;
    final signal = await repo.getCaptureById(widget.captureId);
    if (!mounted) return;

    setState(() {
      _signal = signal;
      _isLoading = false;
      _error = signal == null ? 'not_found' : null;
      if (signal != null && (signal.acknowledgement ?? '').trim().isNotEmpty) {
        _turns.add(
          LightDialogTurnModel(
            role: 'assistant',
            text: signal.acknowledgement!.trim(),
          ),
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final signal = _signal;
    final text = (preset ?? _controller.text).trim();
    if (signal == null || text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
      _error = null;
      _turns.add(LightDialogTurnModel(role: 'user', text: text));
      _controller.clear();
    });

    try {
      final result = await context.read<AppDependencies>().todayRepository.continueLightDialog(
            signal: signal,
            history: List<LightDialogTurnModel>.from(_turns),
            userMessage: text,
          );

      if (!mounted) return;
      setState(() {
        _turns.add(LightDialogTurnModel(role: 'assistant', text: result.reply));
        _suggestedPrompts = result.suggestedPrompts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'send_failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signal = _signal;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocaleText.tr(
            context,
            en: 'Talk through this entry',
            zhHans: '围绕这条继续想一想',
            zhHant: '圍繞這條繼續想一想',
            ja: 'この記録をもう少し整理する',
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : signal == null
              ? Center(
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'This entry could not be found.',
                      zhHans: '没找到这条记录。',
                      zhHant: '沒找到這條記錄。',
                      ja: 'この記録は見つかりませんでした。',
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'Original entry',
                                  zhHans: '原记录',
                                  zhHant: '原記錄',
                                  ja: '元の記録',
                                ),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(signal.content),
                              if ((signal.observation ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  signal.observation!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _turns.length + (_error == null ? 0 : 1),
                        itemBuilder: (context, index) {
                          if (_error != null && index == _turns.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'This reply did not go through. You can try again.',
                                  zhHans: '这次没有顺利回复，你可以再试一次。',
                                  zhHant: '這次沒有順利回覆，你可以再試一次。',
                                  ja: '今回はうまく返せませんでした。もう一度試せます。',
                                ),
                              ),
                            );
                          }
                          final turn = _turns[index];
                          final isAssistant = turn.role == 'assistant';
                          return Align(
                            alignment: isAssistant
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 320),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isAssistant
                                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                                    : Theme.of(context).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(turn.text),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_suggestedPrompts.isNotEmpty)
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, index) {
                            final prompt = _suggestedPrompts[index];
                            return ActionChip(
                              label: Text(prompt),
                              onPressed: _isSending ? null : () => _send(prompt),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemCount: _suggestedPrompts.length,
                        ),
                      ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: AppLocaleText.tr(
                                    context,
                                    en: 'Say a little more about this...',
                                    zhHans: '围绕这条，再补一点……',
                                    zhHant: '圍繞這條，再補一點……',
                                    ja: 'この記録について、もう少しだけ…',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _isSending ? null : _send,
                              child: _isSending
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(
                                      AppLocaleText.tr(
                                        context,
                                        en: 'Send',
                                        zhHans: '发送',
                                        zhHant: '發送',
                                        ja: '送信',
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
