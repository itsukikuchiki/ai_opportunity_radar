import 'package:flutter/material.dart';

import '../../core/i18n/app_locale_text.dart';
import 'aurora_ui.dart';

class EditableTimelineDecision {
  final bool addToTimeline;
  final String text;

  const EditableTimelineDecision({
    required this.addToTimeline,
    required this.text,
  });
}

Future<EditableTimelineDecision?> showEditableTimelineDecisionDialog(
  BuildContext context, {
  required String initialText,
  required String keyPrefix,
  bool saveAsTodaySignal = false,
}) {
  return showDialog<EditableTimelineDecision>(
    context: context,
    builder: (_) => _EditableTimelineDecisionDialog(
      initialText: initialText,
      keyPrefix: keyPrefix,
      saveAsTodaySignal: saveAsTodaySignal,
    ),
  );
}

class _EditableTimelineDecisionDialog extends StatefulWidget {
  final String initialText;
  final String keyPrefix;
  final bool saveAsTodaySignal;

  const _EditableTimelineDecisionDialog({
    required this.initialText,
    required this.keyPrefix,
    required this.saveAsTodaySignal,
  });

  @override
  State<_EditableTimelineDecisionDialog> createState() =>
      _EditableTimelineDecisionDialogState();
}

class _EditableTimelineDecisionDialogState
    extends State<_EditableTimelineDecisionDialog> {
  late final TextEditingController _controller;
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_committed) return;
    setState(() => _committed = true);
    Navigator.of(context).pop();
  }

  void _complete({required bool addToTimeline}) {
    final text = _controller.text.trim();
    if (_committed || text.isEmpty) return;
    setState(() => _committed = true);
    Navigator.of(context).pop(
      EditableTimelineDecision(
        addToTimeline: addToTimeline,
        text: text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canConfirm = !_committed && _controller.text.trim().isNotEmpty;
    return AuroraDialog(
      key: ValueKey('${widget.keyPrefix}-aurora-dialog'),
      title: Text(
        AppLocaleText.tr(
          context,
          en: widget.saveAsTodaySignal
              ? 'Save as today’s signal?'
              : 'Add this to your timeline?',
          zhHans: widget.saveAsTodaySignal ? '保存为今天的信号吗？' : '要记入时间线吗？',
          zhHant: widget.saveAsTodaySignal ? '儲存為今天的信號嗎？' : '要記入時間線嗎？',
          ja: widget.saveAsTodaySignal ? '今日のシグナルとして保存しますか？' : 'タイムラインに記録しますか？',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: widget.saveAsTodaySignal
                  ? 'Edit the wording so it reflects what is true for you. Nothing is written until you save.'
                  : 'You can edit the wording first, then choose whether it becomes a timeline entry.',
              zhHans: widget.saveAsTodaySignal
                  ? '先改成符合你实际情况的说法。只有点击保存后，才会生成信号卡并进入时间线。'
                  : '你可以先修改这句话，再决定是否把它作为一条真实记录放进时间线。',
              zhHant: widget.saveAsTodaySignal
                  ? '先改成符合你實際情況的說法。只有點擊儲存後，才會生成信號卡並進入時間線。'
                  : '你可以先修改這句話，再決定是否把它作為一條真實記錄放進時間線。',
              ja: widget.saveAsTodaySignal
                  ? '自分の実感に合う言葉に編集できます。保存するまでシグナルカードやタイムラインには記録されません。'
                  : '言葉を編集してから、実際の記録としてタイムラインに残すか選べます。',
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: ValueKey('${widget.keyPrefix}-timeline-input'),
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            maxLength: 160,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.72),
              labelText: AppLocaleText.tr(
                context,
                en: widget.saveAsTodaySignal
                    ? 'Signal content'
                    : 'Timeline text',
                zhHans: widget.saveAsTodaySignal ? '信号内容' : '时间线内容',
                zhHant: widget.saveAsTodaySignal ? '信號內容' : '時間線內容',
                ja: widget.saveAsTodaySignal ? 'シグナルの内容' : 'タイムラインの内容',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AuroraColors.line.withValues(alpha: 0.84),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: ValueKey('${widget.keyPrefix}-dialog-cancel'),
          onPressed: _committed ? null : _cancel,
          child: Text(
            AppLocaleText.tr(
              context,
              en: 'Cancel',
              zhHans: '取消',
              zhHant: '取消',
              ja: 'キャンセル',
            ),
          ),
        ),
        if (!widget.saveAsTodaySignal)
          TextButton(
            key: ValueKey('${widget.keyPrefix}-do-not-add'),
            onPressed:
                canConfirm ? () => _complete(addToTimeline: false) : null,
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Do not add',
                zhHans: '不加入时间线',
                zhHant: '不加入時間線',
                ja: 'タイムラインに追加しない',
              ),
            ),
          ),
        FilledButton(
          key: ValueKey('${widget.keyPrefix}-add-timeline'),
          onPressed: canConfirm ? () => _complete(addToTimeline: true) : null,
          child: Text(
            AppLocaleText.tr(
              context,
              en: widget.saveAsTodaySignal
                  ? 'Save as today’s signal'
                  : 'Add to timeline',
              zhHans: widget.saveAsTodaySignal ? '保存为今天的信号' : '记入时间线',
              zhHant: widget.saveAsTodaySignal ? '儲存為今天的信號' : '記入時間線',
              ja: widget.saveAsTodaySignal ? '今日のシグナルに保存' : 'タイムラインに記録',
            ),
          ),
        ),
      ],
    );
  }
}
