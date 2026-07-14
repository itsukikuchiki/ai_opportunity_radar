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
}) {
  return showDialog<EditableTimelineDecision>(
    context: context,
    builder: (_) => _EditableTimelineDecisionDialog(
      initialText: initialText,
      keyPrefix: keyPrefix,
    ),
  );
}

class _EditableTimelineDecisionDialog extends StatefulWidget {
  final String initialText;
  final String keyPrefix;

  const _EditableTimelineDecisionDialog({
    required this.initialText,
    required this.keyPrefix,
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
    return AlertDialog(
      title: Text(
        AppLocaleText.tr(
          context,
          en: 'Add this to your timeline?',
          zhHans: '要记入时间线吗？',
          zhHant: '要記入時間線嗎？',
          ja: 'タイムラインに記録しますか？',
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocaleText.tr(
                context,
                en: 'You can edit the wording first, then choose whether it becomes a timeline entry.',
                zhHans: '你可以先修改这句话，再决定是否把它作为一条真实记录放进时间线。',
                zhHant: '你可以先修改這句話，再決定是否把它作為一條真實記錄放進時間線。',
                ja: '言葉を編集してから、実際の記録としてタイムラインに残すか選べます。',
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
                labelText: AppLocaleText.tr(
                  context,
                  en: 'Timeline text',
                  zhHans: '时间线内容',
                  zhHant: '時間線內容',
                  ja: 'タイムラインの内容',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
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
        TextButton(
          key: ValueKey('${widget.keyPrefix}-do-not-add'),
          onPressed: canConfirm ? () => _complete(addToTimeline: false) : null,
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
              en: 'Add to timeline',
              zhHans: '记入时间线',
              zhHant: '記入時間線',
              ja: 'タイムラインに記録',
            ),
          ),
        ),
      ],
    );
  }
}
