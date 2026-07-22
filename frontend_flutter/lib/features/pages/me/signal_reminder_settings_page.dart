import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/navigation/app_back_navigation.dart';
import '../../../core/notifications/signal_reminder_repository.dart';
import '../../../core/notifications/signal_reminder_rule.dart';
import '../../../shared/widgets/aurora_ui.dart';

/// Manages only reminders the user has already confirmed elsewhere.
///
/// Reminder rules are local notification preferences. Reading, editing,
/// enabling, disabling, or deleting one never writes a Signal Card.
class SignalReminderSettingsPage extends StatefulWidget {
  final SignalReminderRepository? repository;

  const SignalReminderSettingsPage({
    super.key,
    this.repository,
  });

  @override
  State<SignalReminderSettingsPage> createState() =>
      _SignalReminderSettingsPageState();
}

class _SignalReminderSettingsPageState
    extends State<SignalReminderSettingsPage> {
  SignalReminderRepository? _repository;
  List<SignalReminderRule> _rules = const [];
  final Set<String> _busyRuleIds = <String>{};
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final repository = widget.repository ??
          SignalReminderRepository(
            preferences: await SharedPreferences.getInstance(),
          );
      final rules = await repository.loadRules();
      if (!mounted) return;
      setState(() {
        _repository = repository;
        _rules = rules;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _setEnabled(SignalReminderRule rule, bool enabled) async {
    final repository = _repository;
    if (repository == null || _busyRuleIds.contains(rule.id)) return;
    _setBusy(rule.id, true);
    try {
      if (!enabled) {
        await repository.disable(rule.id);
        await _reloadRules();
        if (mounted) {
          _showMessage(
            AppLocaleText.tr(
              context,
              en: 'Reminder turned off.',
              zhHans: '提醒已关闭。',
              zhHant: '提醒已關閉。',
              ja: 'リマインダーをオフにしました。',
            ),
          );
        }
        return;
      }

      final result = await repository.saveConfirmed(
        rule.copyWith(
          enabled: true,
          localeTag: Localizations.localeOf(context).toLanguageTag(),
        ),
      );
      await _reloadRules();
      if (!mounted) return;
      _showMessage(_saveMessage(result.status));
    } catch (_) {
      if (mounted) _showMessage(_genericFailureMessage());
    } finally {
      _setBusy(rule.id, false);
    }
  }

  Future<void> _edit(SignalReminderRule rule) async {
    final repository = _repository;
    if (repository == null || _busyRuleIds.contains(rule.id)) return;

    SignalReminderRule draft = rule;
    if (rule.cadence == SignalReminderCadence.once) {
      final today = DateUtils.dateOnly(DateTime.now());
      final current = rule.localDate == null || rule.localDate!.isBefore(today)
          ? today
          : rule.localDate!;
      final date = await showDatePicker(
        context: context,
        initialDate: current,
        firstDate: today,
        lastDate: today.add(const Duration(days: 366)),
        helpText: AppLocaleText.tr(
          context,
          en: 'Choose the reminder date',
          zhHans: '选择提醒日期',
          zhHant: '選擇提醒日期',
          ja: 'リマインダーの日付を選択',
        ),
      );
      if (!mounted || date == null) return;
      draft = draft.copyWith(localDate: date);
    } else {
      final weekdays = await _chooseWeekdays(rule.weekdays);
      if (!mounted || weekdays == null) return;
      draft = draft.copyWith(weekdays: weekdays);
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: rule.hour, minute: rule.minute),
      helpText: AppLocaleText.tr(
        context,
        en: 'Choose the reminder time',
        zhHans: '选择提醒时间',
        zhHant: '選擇提醒時間',
        ja: 'リマインダーの時刻を選択',
      ),
    );
    if (!mounted || time == null) return;

    _setBusy(rule.id, true);
    try {
      final result = await repository.saveConfirmed(
        draft.copyWith(
          hour: time.hour,
          minute: time.minute,
          localeTag: Localizations.localeOf(context).toLanguageTag(),
        ),
      );
      await _reloadRules();
      if (!mounted) return;
      _showMessage(_saveMessage(result.status));
    } catch (_) {
      if (mounted) _showMessage(_genericFailureMessage());
    } finally {
      _setBusy(rule.id, false);
    }
  }

  Future<Set<int>?> _chooseWeekdays(Set<int> initial) async {
    final selected = Set<int>.from(initial);
    return showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => AuroraDialog(
          title: Text(
            AppLocaleText.tr(
              dialogContext,
              en: 'Repeat on',
              zhHans: '重复日期',
              zhHant: '重複日期',
              ja: '繰り返す曜日',
            ),
          ),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var weekday = DateTime.monday;
                  weekday <= DateTime.sunday;
                  weekday += 1)
                FilterChip(
                  key: ValueKey('signal-reminder-weekday-$weekday'),
                  label: Text(_weekdayShort(dialogContext, weekday)),
                  selected: selected.contains(weekday),
                  onSelected: (value) {
                    updateDialog(() {
                      if (value) {
                        selected.add(weekday);
                      } else if (selected.length > 1) {
                        selected.remove(weekday);
                      }
                    });
                  },
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                AppLocaleText.tr(
                  dialogContext,
                  en: 'Cancel',
                  zhHans: '取消',
                  zhHant: '取消',
                  ja: 'キャンセル',
                ),
              ),
            ),
            FilledButton(
              key: const ValueKey('signal-reminder-weekdays-save'),
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: Text(
                AppLocaleText.tr(
                  dialogContext,
                  en: 'Continue',
                  zhHans: '继续',
                  zhHant: '繼續',
                  ja: '次へ',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(SignalReminderRule rule) async {
    final repository = _repository;
    if (repository == null || _busyRuleIds.contains(rule.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AuroraDialog(
        title: Text(
          AppLocaleText.tr(
            dialogContext,
            en: 'Delete this reminder?',
            zhHans: '删除这条提醒？',
            zhHant: '刪除這則提醒？',
            ja: 'このリマインダーを削除しますか？',
          ),
        ),
        content: Text(
          AppLocaleText.tr(
            dialogContext,
            en: 'This removes only the local reminder rule. Your Signals and reports will not change.',
            zhHans: '只会删除本机提醒规则，不会更改你的 Signal 或报告。',
            zhHant: '只會刪除本機提醒規則，不會更改你的 Signal 或報告。',
            ja: '端末内のリマインダー設定だけを削除します。Signal やレポートは変わりません。',
          ),
          style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                color: AuroraColors.muted,
                height: 1.45,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              AppLocaleText.tr(
                dialogContext,
                en: 'Cancel',
                zhHans: '取消',
                zhHant: '取消',
                ja: 'キャンセル',
              ),
            ),
          ),
          FilledButton(
            key: const ValueKey('signal-reminder-confirm-delete'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              AppLocaleText.tr(
                dialogContext,
                en: 'Delete',
                zhHans: '删除',
                zhHant: '刪除',
                ja: '削除',
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    _setBusy(rule.id, true);
    try {
      await repository.delete(rule.id);
      await _reloadRules();
      if (mounted) {
        _showMessage(
          AppLocaleText.tr(
            context,
            en: 'Reminder deleted.',
            zhHans: '提醒已删除。',
            zhHant: '提醒已刪除。',
            ja: 'リマインダーを削除しました。',
          ),
        );
      }
    } catch (_) {
      if (mounted) _showMessage(_genericFailureMessage());
    } finally {
      _setBusy(rule.id, false);
    }
  }

  Future<void> _reloadRules() async {
    final repository = _repository;
    if (repository == null) return;
    final rules = await repository.loadRules();
    if (!mounted) return;
    setState(() => _rules = rules);
  }

  void _setBusy(String id, bool busy) {
    if (!mounted) return;
    setState(() {
      if (busy) {
        _busyRuleIds.add(id);
      } else {
        _busyRuleIds.remove(id);
      }
    });
  }

  void _showMessage(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _saveMessage(SignalReminderSaveStatus status) {
    switch (status) {
      case SignalReminderSaveStatus.scheduled:
        return AppLocaleText.tr(
          context,
          en: 'Reminder saved.',
          zhHans: '提醒已保存。',
          zhHant: '提醒已儲存。',
          ja: 'リマインダーを保存しました。',
        );
      case SignalReminderSaveStatus.permissionDenied:
        return AppLocaleText.tr(
          context,
          en: 'Notifications are off in system Settings, so this reminder remains disabled.',
          zhHans: '系统通知权限未开启，这条提醒仍保持关闭。',
          zhHant: '系統通知權限未開啟，這則提醒仍保持關閉。',
          ja: 'システムの通知がオフのため、このリマインダーは無効のままです。',
        );
      case SignalReminderSaveStatus.unavailable:
        return AppLocaleText.tr(
          context,
          en: 'Local reminders are unavailable on this device.',
          zhHans: '此设备暂不支持本机提醒。',
          zhHant: '此裝置暫不支援本機提醒。',
          ja: 'この端末ではローカル通知を利用できません。',
        );
      case SignalReminderSaveStatus.disabled:
        return AppLocaleText.tr(
          context,
          en: 'Reminder turned off.',
          zhHans: '提醒已关闭。',
          zhHant: '提醒已關閉。',
          ja: 'リマインダーをオフにしました。',
        );
      case SignalReminderSaveStatus.schedulingFailed:
        return _genericFailureMessage();
    }
  }

  String _genericFailureMessage() => AppLocaleText.tr(
        context,
        en: 'The reminder could not be updated. Please try again.',
        zhHans: '提醒暂时无法更新，请重试。',
        zhHant: '提醒暫時無法更新，請重試。',
        ja: 'リマインダーを更新できませんでした。もう一度お試しください。',
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: ListView(
                key: const ValueKey('signal-reminder-settings-scroll'),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AuroraIconButton(
                      key: const ValueKey('signal-reminder-settings-back'),
                      icon: Icons.arrow_back_rounded,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => context.popOrGo(AppRoutes.me),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HeaderCard(ruleCount: _rules.length),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_loadFailed)
                    _LoadFailureCard(onRetry: _load)
                  else if (_rules.isEmpty)
                    const _EmptyReminderCard()
                  else
                    for (final rule in _rules) ...[
                      _ReminderRuleCard(
                        rule: rule,
                        busy: _busyRuleIds.contains(rule.id),
                        onEnabledChanged: (enabled) =>
                            _setEnabled(rule, enabled),
                        onEdit: () => _edit(rule),
                        onDelete: () => _delete(rule),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
          const AuroraSafeTopMask(),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int ruleCount;

  const _HeaderCard({required this.ruleCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuroraCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuroraSectionIcon(
                icon: Icons.notifications_none_rounded,
                color: AuroraColors.purple,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Signal reminders',
                        zhHans: 'Signal 记录提醒',
                        zhHant: 'Signal 記錄提醒',
                        ja: 'Signal 記録リマインダー',
                      ),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: '$ruleCount saved locally',
                        zhHans: '$ruleCount 条保存在本机',
                        zhHant: '$ruleCount 則儲存在本機',
                        ja: '端末内に $ruleCount 件保存',
                      ),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AuroraColors.purple,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Manage reminders you already accepted. A reminder only opens Today; it never records or creates a Signal Card for you.',
              zhHans: '管理你已经确认的提醒。提醒只会打开今天页面，不会替你记录，也不会创建 Signal Card。',
              zhHant: '管理你已經確認的提醒。提醒只會打開今天頁面，不會替你記錄，也不會建立 Signal Card。',
              ja: '確認済みのリマインダーを管理します。通知は「今日」を開くだけで、記録や Signal Card の作成は行いません。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AuroraColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderRuleCard extends StatelessWidget {
  final SignalReminderRule rule;
  final bool busy;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReminderRuleCard({
    required this.rule,
    required this.busy,
    required this.onEnabledChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuroraCard(
      key: ValueKey('signal-reminder-rule-${rule.id}'),
      padding: const EdgeInsets.fromLTRB(16, 15, 12, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuroraSoftIconCircle(
                icon: rule.cadence == SignalReminderCadence.weekly
                    ? Icons.repeat_rounded
                    : Icons.event_available_rounded,
                color: rule.enabled ? AuroraColors.mint : AuroraColors.muted,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ruleTitle(context, rule),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _ruleSchedule(context, rule),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  key: ValueKey('signal-reminder-toggle-${rule.id}'),
                  value: rule.enabled,
                  onChanged: onEnabledChanged,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AuroraChip(
                label: rule.enabled
                    ? AppLocaleText.tr(
                        context,
                        en: 'On',
                        zhHans: '已开启',
                        zhHant: '已開啟',
                        ja: 'オン',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'Off',
                        zhHans: '已关闭',
                        zhHant: '已關閉',
                        ja: 'オフ',
                      ),
                color: rule.enabled ? AuroraColors.mint : AuroraColors.muted,
              ),
              const Spacer(),
              IconButton(
                key: ValueKey('signal-reminder-edit-${rule.id}'),
                tooltip: AppLocaleText.tr(
                  context,
                  en: 'Edit reminder',
                  zhHans: '编辑提醒',
                  zhHant: '編輯提醒',
                  ja: 'リマインダーを編集',
                ),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('signal-reminder-delete-${rule.id}'),
                tooltip: AppLocaleText.tr(
                  context,
                  en: 'Delete reminder',
                  zhHans: '删除提醒',
                  zhHant: '刪除提醒',
                  ja: 'リマインダーを削除',
                ),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyReminderCard extends StatelessWidget {
  const _EmptyReminderCard();

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      key: const ValueKey('signal-reminder-empty'),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        children: [
          const AuroraSoftIconCircle(
            icon: Icons.notifications_off_outlined,
            color: AuroraColors.blue,
            size: 52,
          ),
          const SizedBox(height: 14),
          Text(
            AppLocaleText.tr(
              context,
              en: 'No confirmed reminders yet',
              zhHans: '还没有已确认的提醒',
              zhHant: '還沒有已確認的提醒',
              ja: '確認済みのリマインダーはありません',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 7),
          Text(
            AppLocaleText.tr(
              context,
              en: 'When you accept a Signal reminder suggestion, you can manage it here.',
              zhHans: '采纳 Signal 记录提醒建议后，可以在这里管理。',
              zhHant: '採納 Signal 記錄提醒建議後，可以在這裡管理。',
              ja: 'Signal 記録リマインダーの提案を採用すると、ここで管理できます。',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.42,
                ),
          ),
        ],
      ),
    );
  }
}

class _LoadFailureCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _LoadFailureCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AuroraColors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Reminder settings could not be loaded.',
                zhHans: '暂时无法读取提醒设置。',
                zhHant: '暫時無法讀取提醒設定。',
                ja: 'リマインダー設定を読み込めませんでした。',
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Retry',
                zhHans: '重试',
                zhHant: '重試',
                ja: '再試行',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _ruleTitle(BuildContext context, SignalReminderRule rule) {
  if (rule.cadence == SignalReminderCadence.once) {
    return AppLocaleText.tr(
      context,
      en: 'One-time reminder',
      zhHans: '单次提醒',
      zhHant: '單次提醒',
      ja: '一度だけのリマインダー',
    );
  }
  return AppLocaleText.tr(
    context,
    en: 'Weekly reminder',
    zhHans: '每周提醒',
    zhHant: '每週提醒',
    ja: '毎週のリマインダー',
  );
}

String _ruleSchedule(BuildContext context, SignalReminderRule rule) {
  final time = TimeOfDay(hour: rule.hour, minute: rule.minute).format(context);
  if (rule.cadence == SignalReminderCadence.once) {
    final date = MaterialLocalizations.of(context).formatMediumDate(
      rule.localDate!,
    );
    return '$date · $time';
  }
  final weekdays = rule.weekdays.toList()..sort();
  return '${weekdays.map((day) => _weekdayShort(context, day)).join('、')} · $time';
}

String _weekdayShort(BuildContext context, int weekday) {
  final locale = AppLocaleText.resolve(context);
  const english = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const japanese = ['月', '火', '水', '木', '金', '土', '日'];
  const simplified = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  const traditional = ['週一', '週二', '週三', '週四', '週五', '週六', '週日'];
  final index = weekday - DateTime.monday;
  return switch (locale) {
    AppLanguage.english => english[index],
    AppLanguage.japanese => japanese[index],
    AppLanguage.simplifiedChinese => simplified[index],
    AppLanguage.traditionalChinese => traditional[index],
  };
}
