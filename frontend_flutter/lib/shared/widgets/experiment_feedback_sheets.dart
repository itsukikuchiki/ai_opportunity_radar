import 'package:flutter/material.dart';

import '../../core/i18n/app_locale_text.dart';
import '../../core/models/experiment_evaluation_models.dart';
import 'aurora_ui.dart';

/// One append-only feedback event for a short small experiment.
///
/// A completed try carries an immediate effect and effort judgement. A try
/// that was not completed deliberately carries neither, so the app cannot
/// turn a missing attempt into an effectiveness judgement.
class SmallTryAttemptFeedbackDraft {
  final String completionStatus;
  final String? effect;
  final String? difficulty;
  final String? note;

  const SmallTryAttemptFeedbackDraft({
    required this.completionStatus,
    this.effect,
    this.difficulty,
    this.note,
  });

  bool get wasCompleted => completionStatus == 'completed';
}

Future<SmallTryAttemptFeedbackDraft?> showSmallTryAttemptFeedbackSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<SmallTryAttemptFeedbackDraft>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _SmallTryAttemptFeedbackSheet(title: title),
  );
}

class _SmallTryAttemptFeedbackSheet extends StatefulWidget {
  final String title;

  const _SmallTryAttemptFeedbackSheet({required this.title});

  @override
  State<_SmallTryAttemptFeedbackSheet> createState() =>
      _SmallTryAttemptFeedbackSheetState();
}

class _SmallTryAttemptFeedbackSheetState
    extends State<_SmallTryAttemptFeedbackSheet> {
  final _noteController = TextEditingController();
  String? _completionStatus;
  String? _effect;
  String? _difficulty;

  bool get _canSave {
    if (_completionStatus == 'not_completed') return true;
    return _completionStatus == 'completed' &&
        SmallTryEffect.values.contains(_effect) &&
        SmallTryDifficulty.values.contains(_difficulty);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        key: const ValueKey('small-try-feedback-sheet'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCFA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AuroraColors.line,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Record this small experiment',
                  zhHans: '登记这次小实验',
                  zhHant: '登記這次小實驗',
                  ja: '今回の小実験を記録',
                ),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AuroraColors.ink,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 18),
              _SheetLabel(
                text: AppLocaleText.tr(
                  context,
                  en: 'Did you try it?',
                  zhHans: '这次试了吗？',
                  zhHant: '這次試了嗎？',
                  ja: '今回は試しましたか？',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceButton(
                      key: const ValueKey('small-try-completed-choice'),
                      selected: _completionStatus == 'completed',
                      label: AppLocaleText.tr(
                        context,
                        en: 'Tried it',
                        zhHans: '试了',
                        zhHant: '試了',
                        ja: '試した',
                      ),
                      icon: Icons.check_rounded,
                      color: AuroraColors.mint,
                      onPressed: () => setState(() {
                        _completionStatus = 'completed';
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChoiceButton(
                      key: const ValueKey('small-try-not-completed-choice'),
                      selected: _completionStatus == 'not_completed',
                      label: AppLocaleText.tr(
                        context,
                        en: 'Not this time',
                        zhHans: '这次没试',
                        zhHant: '這次沒試',
                        ja: '今回は試さなかった',
                      ),
                      icon: Icons.remove_rounded,
                      color: AuroraColors.orange,
                      onPressed: () => setState(() {
                        _completionStatus = 'not_completed';
                        _effect = null;
                        _difficulty = null;
                      }),
                    ),
                  ),
                ],
              ),
              if (_completionStatus == 'completed') ...[
                const SizedBox(height: 20),
                _SheetLabel(
                  text: AppLocaleText.tr(
                    context,
                    en: 'How did it feel right away?',
                    zhHans: '当下有帮助吗？',
                    zhHant: '當下有幫助嗎？',
                    ja: 'すぐに役立ちましたか？',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FeedbackChip(
                      key: const ValueKey('small-try-effect-helpful'),
                      selected: _effect == SmallTryEffect.helpful,
                      label: AppLocaleText.tr(
                        context,
                        en: 'Helpful',
                        zhHans: '有帮助',
                        zhHant: '有幫助',
                        ja: '役立った',
                      ),
                      onSelected: () =>
                          setState(() => _effect = SmallTryEffect.helpful),
                    ),
                    _FeedbackChip(
                      key: const ValueKey('small-try-effect-somewhat'),
                      selected: _effect == SmallTryEffect.somewhatHelpful,
                      label: AppLocaleText.tr(
                        context,
                        en: 'A little',
                        zhHans: '有一点',
                        zhHant: '有一點',
                        ja: '少し',
                      ),
                      onSelected: () => setState(
                        () => _effect = SmallTryEffect.somewhatHelpful,
                      ),
                    ),
                    _FeedbackChip(
                      key: const ValueKey('small-try-effect-none'),
                      selected: _effect == SmallTryEffect.noEffect,
                      label: AppLocaleText.tr(
                        context,
                        en: 'No difference',
                        zhHans: '没感觉',
                        zhHant: '沒感覺',
                        ja: '変化なし',
                      ),
                      onSelected: () =>
                          setState(() => _effect = SmallTryEffect.noEffect),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SheetLabel(
                  text: AppLocaleText.tr(
                    context,
                    en: 'How much effort did it take?',
                    zhHans: '做起来费力吗？',
                    zhHant: '做起來費力嗎？',
                    ja: '負担はどのくらいでしたか？',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FeedbackChip(
                      key: const ValueKey('small-try-difficulty-easy'),
                      selected: _difficulty == SmallTryDifficulty.easy,
                      label: AppLocaleText.tr(
                        context,
                        en: 'Easy',
                        zhHans: '轻松',
                        zhHant: '輕鬆',
                        ja: '軽い',
                      ),
                      onSelected: () => setState(
                        () => _difficulty = SmallTryDifficulty.easy,
                      ),
                    ),
                    _FeedbackChip(
                      key: const ValueKey('small-try-difficulty-okay'),
                      selected: _difficulty == SmallTryDifficulty.okay,
                      label: AppLocaleText.tr(
                        context,
                        en: 'Okay',
                        zhHans: '还好',
                        zhHant: '還好',
                        ja: '普通',
                      ),
                      onSelected: () => setState(
                        () => _difficulty = SmallTryDifficulty.okay,
                      ),
                    ),
                    _FeedbackChip(
                      key: const ValueKey('small-try-difficulty-hard'),
                      selected: _difficulty == SmallTryDifficulty.difficult,
                      label: AppLocaleText.tr(
                        context,
                        en: 'Took effort',
                        zhHans: '偏费力',
                        zhHant: '偏費力',
                        ja: 'やや重い',
                      ),
                      onSelected: () => setState(
                        () => _difficulty = SmallTryDifficulty.difficult,
                      ),
                    ),
                  ],
                ),
              ],
              if (_completionStatus != null) ...[
                const SizedBox(height: 18),
                TextField(
                  key: const ValueKey('small-try-feedback-note'),
                  controller: _noteController,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 160,
                  decoration: InputDecoration(
                    hintText: AppLocaleText.tr(
                      context,
                      en: 'Add a note (optional)',
                      zhHans: '补一句（可选）',
                      zhHant: '補一句（可選）',
                      ja: 'ひとこと追加（任意）',
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.72),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AuroraColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AuroraColors.line),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('small-try-feedback-save'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AuroraColors.purple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AuroraColors.purple.withValues(alpha: 0.22),
                  ),
                  onPressed: _canSave ? _save : null,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Save this attempt',
                      zhHans: '保存这次尝试',
                      zhHant: '儲存這次嘗試',
                      ja: '今回の記録を保存',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final completionStatus = _completionStatus;
    if (completionStatus == null || !_canSave) return;
    final note = _noteController.text.trim();
    Navigator.of(context).pop(
      SmallTryAttemptFeedbackDraft(
        completionStatus: completionStatus,
        effect: completionStatus == 'completed' ? _effect : null,
        difficulty: completionStatus == 'completed' ? _difficulty : null,
        note: note.isEmpty ? null : note,
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;

  const _SheetLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AuroraColors.ink,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ChoiceButton({
    super.key,
    required this.selected,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor:
            selected ? color.withValues(alpha: 0.12) : Colors.transparent,
        foregroundColor: selected ? color : AuroraColors.ink,
        side: BorderSide(
          color: selected ? color : AuroraColors.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, textAlign: TextAlign.center),
    );
  }
}

class _FeedbackChip extends StatelessWidget {
  final bool selected;
  final String label;
  final VoidCallback onSelected;

  const _FeedbackChip({
    super.key,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      showCheckmark: true,
      label: Text(label),
      onSelected: (_) => onSelected(),
      side: BorderSide(
        color: selected ? AuroraColors.purple : AuroraColors.line,
      ),
      selectedColor: AuroraColors.purple.withValues(alpha: 0.12),
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? AuroraColors.purple : AuroraColors.ink,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
