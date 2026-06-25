import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/purchases/purchase_controller.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../paywall/paywall_sheet.dart';
import '../../../shared/widgets/section_header.dart';
import 'me_view_model.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  static final Uri _privacyPolicyUri = Uri.parse(
    'https://itsukikuchiki.github.io/signalpath-support/',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.watch<MeViewModel>();
    final purchase = context.watch<PurchaseController?>();

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 172),
                children: [
                  AuroraCard(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.88),
                        const Color(0xFFF6F2FF),
                        const Color(0xFFFFFBF7),
                      ],
                    ),
                    child: Row(
                      children: [
                        const AuroraBrandMark(size: 78),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'Welcome back',
                                  zhHans: '欢迎回来',
                                  zhHant: '歡迎回來',
                                  ja: 'おかえりなさい',
                                ),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 27,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'Organize life signals into a calmer order.',
                                  zhHans: '把生活的信号，慢慢整理成秩序。',
                                  zhHant: '把生活的信號，慢慢整理成秩序。',
                                  ja: '生活のシグナルを、少しずつ整えていきます。',
                                ),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AuroraColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AuroraColors.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionHeader(
                    title: AppLocaleText.tr(
                      context,
                      en: 'My usage style',
                      zhHans: '我的使用方式',
                      zhHant: '我的使用方式',
                      ja: '自分の使い方',
                    ),
                    subtitle: AppLocaleText.tr(
                      context,
                      en: 'These settings are not fixed forever. You can adjust them later anytime.',
                      zhHans: '这些设置不会把你固定住，之后随时都可以调整。',
                      zhHant: '這些設定不會把你固定住，之後隨時都可以調整。',
                      ja: 'これらの設定は固定ではなく、あとからいつでも変えられます。',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (vm.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _MeGroupedCard(
                      title: AppLocaleText.tr(
                        context,
                        en: 'My usage style',
                        zhHans: '我的使用方式',
                        zhHant: '我的使用方式',
                        ja: '自分の使い方',
                      ),
                      icon: Icons.auto_awesome_motion_rounded,
                      iconColor: AuroraColors.purple,
                      rows: [
                        _MeGroupedRowData(
                          icon: Icons.track_changes_rounded,
                          iconColor: AuroraColors.purple,
                          title: AppLocaleText.tr(
                            context,
                            en: 'Focus area',
                            zhHans: '关注方向',
                            zhHant: '關注方向',
                            ja: '注目方向',
                          ),
                          onTap: vm.saving
                              ? null
                              : () => _showFocusAreaSheet(context, vm),
                        ),
                        _MeGroupedRowData(
                          icon: Icons.language_rounded,
                          iconColor: AuroraColors.blue,
                          title: AppLocaleText.tr(
                            context,
                            en: 'Language',
                            zhHans: '语言',
                            zhHant: '語言',
                            ja: '言語',
                          ),
                        ),
                        _MeGroupedRowData(
                          icon: Icons.auto_awesome_rounded,
                          iconColor: AuroraColors.purple,
                          title: AppLocaleText.tr(
                            context,
                            en: 'AI response style',
                            zhHans: 'AI 回应风格',
                            zhHant: 'AI 回應風格',
                            ja: 'AI の返答スタイル',
                          ),
                          onTap: vm.saving
                              ? null
                              : () {
                                  if (purchase?.isPremium ?? false) {
                                    _showResponseStyleSheet(context, vm);
                                  } else {
                                    showPremiumPaywall(
                                      context,
                                      source: AppLocaleText.tr(
                                        context,
                                        en: 'AI response style',
                                        zhHans: 'AI 回应风格',
                                        zhHant: 'AI 回應風格',
                                        ja: 'AI の返答スタイル',
                                      ),
                                    );
                                  }
                                },
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  _MeDataSection(
                    onOpenJournal: () => context.go(AppRoutes.journal),
                    onOpenAdvancedSignals: () =>
                        context.go(AppRoutes.advancedSignals),
                    onDeleteAccount: () => _confirmDeleteAccount(context, vm),
                    onOpenPrivacy: _openPrivacyPolicy,
                  ),
                  const SizedBox(height: 12),
                  _CloudBackupCard(vm: vm),
                  const SizedBox(height: 24),
                  _PremiumStatusCard(purchase: purchase, vm: vm),
                  const SizedBox(height: 24),
                  const _MeHelpSection(),
                  if (vm.errorMessage != null &&
                      vm.errorMessage!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          vm.errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
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

  Future<void> _showFocusAreaSheet(BuildContext context, MeViewModel vm) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return _FocusAreaPickerSheet(
          currentValue: vm.selectedRepeatArea,
        );
      },
    );

    if (selected == null || selected == vm.selectedRepeatArea) return;

    final success = await vm.updateRepeatArea(selected);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? AppLocaleText.tr(
                  context,
                  en: 'Focus area updated.',
                  zhHans: '关注方向已更新。',
                  zhHant: '關注方向已更新。',
                  ja: '注目方向を更新しました。',
                )
              : AppLocaleText.tr(
                  context,
                  en: 'Failed to update focus area.',
                  zhHans: '更新关注方向失败。',
                  zhHant: '更新關注方向失敗。',
                  ja: '注目方向の更新に失敗しました。',
                ),
        ),
      ),
    );
  }

  Future<void> _showResponseStyleSheet(
      BuildContext context, MeViewModel vm) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) =>
          _ResponseStylePickerSheet(currentValue: vm.selectedResponseStyle),
    );

    if (selected == null || selected == vm.selectedResponseStyle) return;

    final success = await vm.updateResponseStyle(selected);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? AppLocaleText.tr(
                  context,
                  en: 'AI response style updated.',
                  zhHans: 'AI 回应风格已更新。',
                  zhHant: 'AI 回應風格已更新。',
                  ja: 'AI の返答スタイルを更新しました。',
                )
              : AppLocaleText.tr(
                  context,
                  en: 'Failed to update AI response style.',
                  zhHans: '更新 AI 回应风格失败。',
                  zhHant: '更新 AI 回應風格失敗。',
                  ja: 'AI の返答スタイル更新に失敗しました。',
                ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    MeViewModel vm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            AppLocaleText.tr(
              context,
              en: 'Delete account and all data?',
              zhHans: '删除账户和所有数据？',
              zhHant: '刪除帳戶和所有資料？',
              ja: 'アカウントとすべてのデータを削除しますか？',
            ),
          ),
          content: Text(
            AppLocaleText.tr(
              context,
              en: 'This deletes local records, cloud backup snapshots, and the Apple-linked Signal Path account. Pro purchases remain managed by the App Store and can be restored separately.',
              zhHans:
                  '这会删除本机记录、云备份快照，以及与 Apple 登录关联的 Signal Path 账户。Pro 购买仍由 App Store 管理，可单独恢复。',
              zhHant:
                  '這會刪除本機記錄、雲端備份快照，以及與 Apple 登入關聯的 Signal Path 帳戶。Pro 購買仍由 App Store 管理，可另外恢復。',
              ja: '端末内の記録、クラウドバックアップ、Apple ログインに紐づく Signal Path アカウントを削除します。Pro 購入は App Store 側で管理され、別途復元できます。',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
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
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB94A48),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Delete',
                  zhHans: '删除',
                  zhHant: '刪除',
                  ja: '削除',
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    final ok = await vm.deleteAccountAndAllData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_CloudBackupCard._cloudMessageText(
        context,
        vm.cloudMessage,
        ok: ok,
      ))),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(_privacyPolicyUri, mode: LaunchMode.externalApplication);
  }
}

class _CloudBackupCard extends StatelessWidget {
  final MeViewModel vm;

  const _CloudBackupCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final signedIn = vm.cloudSignedIn;
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.cloud_done_outlined,
                color: AuroraColors.blue,
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
                        en: 'Apple sign-in and record backup',
                        zhHans: 'Apple 登录与记录备份',
                        zhHant: 'Apple 登入與記錄備份',
                        ja: 'Apple ログインと記録バックアップ',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      signedIn
                          ? AppLocaleText.tr(
                              context,
                              en: 'Signed in. Records can be restored on a new device.',
                              zhHans: '已登录。换手机时可以恢复之前的记录。',
                              zhHant: '已登入。換手機時可以恢復之前的記錄。',
                              ja: 'ログイン済み。新しい端末で記録を復元できます。',
                            )
                          : AppLocaleText.tr(
                              context,
                              en: 'Local-first stays on. Apple sign-in only adds a private backup snapshot.',
                              zhHans: '本地优先不变。Apple 登录只用于保存一份私人备份快照。',
                              zhHant: '本地優先不變。Apple 登入只用於保存一份私人備份快照。',
                              ja: 'ローカル優先のまま、Apple ログインで個人用バックアップを追加します。',
                            ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AuroraColors.muted,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((vm.latestBackupVersion ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Latest backup: ${vm.latestBackupVersion}',
                zhHans: '最近备份：${vm.latestBackupVersion}',
                zhHant: '最近備份：${vm.latestBackupVersion}',
                ja: '最新バックアップ：${vm.latestBackupVersion}',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                  ),
            ),
          ],
          if ((vm.cloudMessage ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _cloudMessageText(context, vm.cloudMessage!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.blue,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          if (vm.cloudLoading)
            const LinearProgressIndicator(minHeight: 3)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AuroraPillButton(
                  filled: !signedIn,
                  icon: Icons.apple,
                  label: signedIn
                      ? AppLocaleText.tr(
                          context,
                          en: 'Backup now',
                          zhHans: '立即备份',
                          zhHant: '立即備份',
                          ja: '今すぐバックアップ',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'Sign in with Apple',
                          zhHans: '使用 Apple 登录',
                          zhHant: '使用 Apple 登入',
                          ja: 'Apple でログイン',
                        ),
                  onPressed: () async {
                    final ok = signedIn
                        ? await vm.uploadCloudBackupNow()
                        : await vm.signInWithAppleAndBackupNow();
                    if (!context.mounted) return;
                    _showCloudSnack(context, ok, vm.cloudMessage);
                  },
                ),
                AuroraPillButton(
                  icon: Icons.restore_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Restore records',
                    zhHans: '恢复记录',
                    zhHant: '恢復記錄',
                    ja: '記録を復元',
                  ),
                  onPressed: signedIn
                      ? () async {
                          final ok = await vm.restoreLatestCloudBackup();
                          if (!context.mounted) return;
                          _showCloudSnack(context, ok, vm.cloudMessage);
                        }
                      : null,
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            AppLocaleText.tr(
              context,
              en: 'This restores records only. Pro purchase restore remains in the Pro sheet.',
              zhHans: '这里恢复的是记录。Pro 购买恢复仍在 Pro 订阅页。',
              zhHant: '這裡恢復的是記錄。Pro 購買恢復仍在 Pro 訂閱頁。',
              ja: 'ここで復元するのは記録だけです。Pro 購入の復元は Pro 画面にあります。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AuroraColors.muted,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }

  static void _showCloudSnack(
    BuildContext context,
    bool ok,
    String? message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_cloudMessageText(context, message, ok: ok))),
    );
  }

  static String _cloudMessageText(
    BuildContext context,
    String? raw, {
    bool? ok,
  }) {
    switch (raw) {
      case 'cloud_backup_uploaded':
        return AppLocaleText.tr(
          context,
          en: 'Backup saved.',
          zhHans: '备份已保存。',
          zhHant: '備份已保存。',
          ja: 'バックアップを保存しました。',
        );
      case 'cloud_backup_restored':
        return AppLocaleText.tr(
          context,
          en: 'Records restored. Reopen pages to refresh the view.',
          zhHans: '记录已恢复。重新打开页面后会刷新显示。',
          zhHant: '記錄已恢復。重新打開頁面後會刷新顯示。',
          ja: '記録を復元しました。ページを開き直すと反映されます。',
        );
      case 'cloud_backup_empty':
        return AppLocaleText.tr(
          context,
          en: 'No backup found yet.',
          zhHans: '还没有找到可恢复的备份。',
          zhHant: '還沒有找到可恢復的備份。',
          ja: '復元できるバックアップはまだありません。',
        );
      case 'cloud_backup_sign_in_required':
        return AppLocaleText.tr(
          context,
          en: 'Sign in with Apple first.',
          zhHans: '请先使用 Apple 登录。',
          zhHant: '請先使用 Apple 登入。',
          ja: '先に Apple でログインしてください。',
        );
      case 'cloud_backup_unavailable':
        return AppLocaleText.tr(
          context,
          en: 'Cloud backup is not available in this build.',
          zhHans: '这个版本暂时无法使用云备份。',
          zhHant: '這個版本暫時無法使用雲備份。',
          ja: 'このビルドではクラウドバックアップを利用できません。',
        );
      case 'account_deleted':
        return AppLocaleText.tr(
          context,
          en: 'Account and local records deleted. Reopen the app to start fresh.',
          zhHans: '账户和本机记录已删除。重新打开 App 后会从新状态开始。',
          zhHant: '帳戶和本機記錄已刪除。重新打開 App 後會從新狀態開始。',
          ja: 'アカウントと端末内の記録を削除しました。アプリを開き直すと新しい状態で始まります。',
        );
      case 'account_delete_unavailable':
        return AppLocaleText.tr(
          context,
          en: 'Account deletion is not available in this build.',
          zhHans: '这个版本暂时无法删除账户。',
          zhHant: '這個版本暫時無法刪除帳戶。',
          ja: 'このビルドではアカウント削除を利用できません。',
        );
      default:
        if (ok == true) {
          return AppLocaleText.tr(
            context,
            en: 'Done.',
            zhHans: '已完成。',
            zhHant: '已完成。',
            ja: '完了しました。',
          );
        }
        return AppLocaleText.tr(
          context,
          en: 'Cloud backup could not finish. Your local records are still safe.',
          zhHans: '云备份没有完成，但本机记录仍然安全。',
          zhHant: '雲備份沒有完成，但本機記錄仍然安全。',
          ja: 'クラウドバックアップは完了しませんでしたが、端末内の記録は安全です。',
        );
    }
  }
}

class _MeDataSection extends StatelessWidget {
  final VoidCallback onOpenJournal;
  final VoidCallback onOpenAdvancedSignals;
  final VoidCallback onDeleteAccount;
  final VoidCallback onOpenPrivacy;

  const _MeDataSection({
    required this.onOpenJournal,
    required this.onOpenAdvancedSignals,
    required this.onDeleteAccount,
    required this.onOpenPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return _MeGroupedCard(
      title: AppLocaleText.tr(
        context,
        en: 'My data',
        zhHans: '我的数据',
        zhHant: '我的資料',
        ja: '自分のデータ',
      ),
      icon: Icons.lock_outline_rounded,
      iconColor: AuroraColors.purple,
      rows: [
        _MeGroupedRowData(
          icon: Icons.menu_book_rounded,
          iconColor: AuroraColors.mint,
          title: AppLocaleText.tr(
            context,
            en: 'Journal and reviews',
            zhHans: '手帐与回顾',
            zhHant: '手帳與回顧',
            ja: '手帳と振り返り',
          ),
          onTap: onOpenJournal,
        ),
        _MeGroupedRowData(
          icon: Icons.verified_user_outlined,
          iconColor: AuroraColors.orange,
          title: AppLocaleText.tr(
            context,
            en: 'Advanced signal settings',
            zhHans: '高级线索设置',
            zhHant: '進階線索設定',
            ja: '高度なシグナル設定',
          ),
          onTap: onOpenAdvancedSignals,
        ),
        _MeGroupedRowData(
          icon: Icons.privacy_tip_outlined,
          iconColor: AuroraColors.blue,
          title: AppLocaleText.tr(
            context,
            en: 'Privacy notes',
            zhHans: '隐私说明',
            zhHant: '隱私說明',
            ja: 'プライバシー',
          ),
          onTap: onOpenPrivacy,
        ),
        _MeGroupedRowData(
          icon: Icons.download_rounded,
          iconColor: AuroraColors.purple,
          title: AppLocaleText.tr(
            context,
            en: 'Export data',
            zhHans: '导出数据',
            zhHant: '匯出資料',
            ja: 'データを書き出す',
          ),
        ),
        _MeGroupedRowData(
          icon: Icons.delete_outline_rounded,
          iconColor: const Color(0xFFB94A48),
          title: AppLocaleText.tr(
            context,
            en: 'Delete account and all data',
            zhHans: '删除账户和所有数据',
            zhHant: '刪除帳戶和所有資料',
            ja: 'アカウントとすべてのデータを削除',
          ),
          onTap: onDeleteAccount,
        ),
      ],
    );
  }
}

class _MeHelpSection extends StatelessWidget {
  const _MeHelpSection();

  @override
  Widget build(BuildContext context) {
    return _MeGroupedCard(
      title: AppLocaleText.tr(
        context,
        en: 'Help and notes',
        zhHans: '帮助与说明',
        zhHant: '幫助與說明',
        ja: 'ヘルプと説明',
      ),
      icon: Icons.help_outline_rounded,
      iconColor: AuroraColors.purple,
      rows: [
        _MeGroupedRowData(
          icon: Icons.auto_stories_outlined,
          iconColor: AuroraColors.purple,
          title: AppLocaleText.tr(
            context,
            en: 'How Signal Path works',
            zhHans: 'Signal Path 如何工作',
            zhHant: 'Signal Path 如何運作',
            ja: 'Signal Path のしくみ',
          ),
        ),
        const _MeGroupedRowData(
          icon: Icons.chat_bubble_outline_rounded,
          iconColor: AuroraColors.mint,
          title: 'FAQ',
        ),
        _MeGroupedRowData(
          icon: Icons.headset_mic_outlined,
          iconColor: AuroraColors.orange,
          title: AppLocaleText.tr(
            context,
            en: 'Contact support',
            zhHans: '联系支持',
            zhHant: '聯絡支援',
            ja: 'サポートに連絡',
          ),
        ),
      ],
    );
  }
}

class _MeGroupedCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<_MeGroupedRowData> rows;

  const _MeGroupedCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
            ),
            child: Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  _MeGroupedRow(data: rows[index]),
                  if (index < rows.length - 1)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: AuroraColors.line.withValues(alpha: 0.70),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeGroupedRowData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onTap;

  const _MeGroupedRowData({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.onTap,
  });
}

class _MeGroupedRow extends StatelessWidget {
  final _MeGroupedRowData data;

  const _MeGroupedRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: data.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Row(
          children: [
            AuroraSoftIconCircle(
              icon: data.icon,
              color: data.iconColor,
              size: 34,
              iconSize: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AuroraColors.muted),
          ],
        ),
      ),
    );
  }
}

class _PremiumStatusCard extends StatelessWidget {
  final PurchaseController? purchase;
  final MeViewModel vm;

  const _PremiumStatusCard({
    required this.purchase,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPremium = purchase?.isPremium ?? false;

    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFF0EAFF).withValues(alpha: 0.94),
          Colors.white.withValues(alpha: 0.92),
          const Color(0xFFFFFBF5).withValues(alpha: 0.80),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AuroraSoftIconCircle(
                icon: isPremium
                    ? Icons.workspace_premium
                    : Icons.workspace_premium_outlined,
                color: AuroraColors.purple,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isPremium
                      ? AppLocaleText.tr(
                          context,
                          en: 'Pro is active',
                          zhHans: 'Pro 已开通',
                          zhHant: 'Pro 已開通',
                          ja: 'Pro が有効です',
                        )
                      : AppLocaleText.tr(
                          context,
                          en: 'Signal Path Pro',
                          zhHans: 'Signal Path Pro',
                          zhHant: 'Signal Path Pro',
                          ja: 'Signal Path Pro',
                        ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
              const AuroraCrystalIllustration(width: 92, height: 72),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuotaTile(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Deep Weekly',
                    zhHans: '本月 Deep Weekly',
                    zhHant: '本月 Deep Weekly',
                    ja: '今月 Deep Weekly',
                  ),
                  value: _quotaValue(
                    context,
                    'deep_weekly',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuotaTile(
                  label: AppLocaleText.tr(
                    context,
                    en: 'Deep analysis',
                    zhHans: '本月深度分析',
                    zhHant: '本月深度分析',
                    ja: '今月の深い分析',
                  ),
                  value: _quotaValue(
                    context,
                    'gpt55_deep_upgrade',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPremium
                ? AppLocaleText.tr(
                    context,
                    en: 'Deeper weekly reads, Life Journey, journal view, self-review, and response style switching are available.',
                    zhHans: '更深的本周回看、生活地图、手帐视图、自我梳理和回应风格都已可用。',
                    zhHant: '更深的本週回看、生活地圖、手帳視圖、自我梳理和回應風格都已可用。',
                    ja: 'より深い Weekly、生活の旅路、手帳ビュー、Self-Review、返答スタイルが使えます。',
                  )
                : AppLocaleText.tr(
                    context,
                    en: 'Unlock deeper weekly reads, Life Journey, and a calmer way to look back.',
                    zhHans: '解锁更深的本周回看、生活地图和更安静的长期回顾。',
                    zhHant: '解鎖更深的本週回看、生活地圖和更安靜的長期回顧。',
                    ja: 'より深い Weekly、生活の旅路、静かな振り返りを開きます。',
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AuroraColors.muted,
              height: 1.35,
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: AuroraPillButton(
                onPressed: () => showPremiumPaywall(context, source: 'Pro'),
                filled: true,
                icon: Icons.auto_awesome_rounded,
                label: AppLocaleText.tr(
                  context,
                  en: 'Upgrade',
                  zhHans: '升级',
                  zhHant: '升級',
                  ja: 'Upgrade',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _quotaValue(BuildContext context, String featureKey) {
    final quota = vm.usageQuotas[featureKey];
    if (quota != null) return quota.displayValue;
    if (vm.usageLoading) {
      return AppLocaleText.tr(
        context,
        en: 'Syncing',
        zhHans: '同步中',
        zhHant: '同步中',
        ja: '同期中',
      );
    }
    return AppLocaleText.tr(
      context,
      en: 'Not synced',
      zhHans: '未同步',
      zhHant: '未同步',
      ja: '未同期',
    );
  }
}

class _QuotaTile extends StatelessWidget {
  final String label;
  final String value;

  const _QuotaTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AuroraColors.muted,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _FocusAreaPickerSheet extends StatelessWidget {
  final String? currentValue;

  const _FocusAreaPickerSheet({
    required this.currentValue,
  });

  @override
  Widget build(BuildContext context) {
    final options = <_FocusAreaOption>[
      _FocusAreaOption(
        value: 'work_tasks',
        title: AppLocaleText.tr(context,
            en: 'Work and tasks',
            zhHans: '工作与任务',
            zhHant: '工作與任務',
            ja: '仕事とタスク'),
        subtitle: AppLocaleText.tr(context,
            en: 'Progress, priorities, collaboration, communication, and repeated workflows',
            zhHans: '推进事情、安排优先级、合作沟通、反复消耗你的流程',
            zhHant: '推進事情、安排優先級、合作溝通、反覆消耗你的流程',
            ja: '物事の進め方、優先順位、協働や連絡、繰り返し消耗する流れ'),
      ),
      _FocusAreaOption(
        value: 'emotion_stress',
        title: AppLocaleText.tr(context,
            en: 'Emotions and stress',
            zhHans: '情绪与压力',
            zhHant: '情緒與壓力',
            ja: '感情とストレス'),
        subtitle: AppLocaleText.tr(context,
            en: 'Frustration, hurt, joy, tension, and lingering feelings',
            zhHans: '烦躁、委屈、开心、紧绷，或者总放不下的时刻',
            zhHant: '煩躁、委屈、開心、緊繃，或者總放不下的時刻',
            ja: 'イライラ、しんどさ、うれしさ、張りつめた感じ、引きずる瞬間'),
      ),
      _FocusAreaOption(
        value: 'relationships',
        title: AppLocaleText.tr(context,
            en: 'Relationships and interaction',
            zhHans: '关系与相处',
            zhHant: '關係與相處',
            ja: '人間関係と付き合い方'),
        subtitle: AppLocaleText.tr(context,
            en: 'Family, friends, coworkers, partners, friction, and what matters to you',
            zhHans: '家人、朋友、同事、伴侣之间的互动、摩擦和在意',
            zhHant: '家人、朋友、同事、伴侶之間的互動、摩擦和在意',
            ja: '家族、友人、同僚、パートナーとのやり取り、摩擦、気になること'),
      ),
      _FocusAreaOption(
        value: 'time_rhythm',
        title: AppLocaleText.tr(context,
            en: 'Time and daily rhythm',
            zhHans: '时间与生活节奏',
            zhHant: '時間與生活節奏',
            ja: '時間と生活リズム'),
        subtitle: AppLocaleText.tr(context,
            en: 'Commutes, routines, procrastination, rest, and interruptions',
            zhHans: '通勤、作息、拖延、休息不够，或者一天总被打断的地方',
            zhHant: '通勤、作息、拖延、休息不夠，或者一天總被打斷的地方',
            ja: '通勤、生活リズム、先延ばし、休めなさ、中断される場面'),
      ),
      _FocusAreaOption(
        value: 'health_body',
        title: AppLocaleText.tr(context,
            en: 'Health and physical state',
            zhHans: '健康与身体状态',
            zhHant: '健康與身體狀態',
            ja: '健康と身体の状態'),
        subtitle: AppLocaleText.tr(context,
            en: 'Fatigue, sleep, food, exercise, recovery, and body signals',
            zhHans: '疲惫、睡眠、饮食、运动、恢复感，或者身体给你的提醒',
            zhHant: '疲憊、睡眠、飲食、運動、恢復感，或者身體給你的提醒',
            ja: '疲れ、睡眠、食事、運動、回復感、身体からのシグナル'),
      ),
      _FocusAreaOption(
        value: 'money_spending',
        title: AppLocaleText.tr(context,
            en: 'Money and spending',
            zhHans: '金钱与消费',
            zhHant: '金錢與消費',
            ja: 'お金と消費'),
        subtitle: AppLocaleText.tr(context,
            en: 'Spending, habits, pressure, budgeting, and hesitant purchases',
            zhHans: '花销、消费习惯、金钱压力、预算安排，或者总让你犹豫的支出',
            zhHant: '花銷、消費習慣、金錢壓力、預算安排，或者總讓你猶豫的支出',
            ja: '支出、買い方の癖、お金のプレッシャー、予算、迷いやすい出費'),
      ),
      _FocusAreaOption(
        value: 'learning_growth_expression',
        title: AppLocaleText.tr(context,
            en: 'Learning, growth, and expression',
            zhHans: '学习、成长与表达',
            zhHant: '學習、成長與表達',
            ja: '学び・成長・表現'),
        subtitle: AppLocaleText.tr(context,
            en: 'Things you want to learn, express clearly, improve, or keep moving forward',
            zhHans: '想学的东西、想写清楚的内容、想变好的部分，或者一直在努力推进的方向',
            zhHant: '想學的東西、想寫清楚的內容、想變好的部分，或者一直在努力推進的方向',
            ja: '学びたいこと、言葉にしたいこと、伸ばしたい部分、少しずつ進めたい方向'),
      ),
      _FocusAreaOption(
        value: 'open',
        title: AppLocaleText.tr(context,
            en: 'Keep it open for now',
            zhHans: '先不限定，想到什么记什么',
            zhHant: '先不限定，想到什麼記什麼',
            ja: 'まだ決めず、思いついたことから記録する'),
        subtitle: AppLocaleText.tr(context,
            en: 'Capture what really happens first, and sort the direction out later',
            zhHans: '先把真实发生的事情留下来，之后再慢慢看它更接近哪些方向',
            zhHant: '先把真實發生的事情留下來，之後再慢慢看它更接近哪些方向',
            ja: 'まずは実際に起きたことを残して、方向はあとから少しずつ見ていく'),
      ),
    ];

    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocaleText.tr(
                context,
                en: 'Change focus area',
                zhHans: '修改关注方向',
                zhHant: '修改關注方向',
                ja: '注目方向を変更する',
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Pick the one that feels closest to where you want the system to start noticing first.',
                zhHans: '选一个现在最接近你、也最希望系统先开始留意的方向。',
                zhHant: '選一個現在最接近你、也最希望系統先開始留意的方向。',
                ja: '今の自分に近く、システムにまず見てほしい方向を一つ選んでください。',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = options[index];
                  final selected = option.value == currentValue;

                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).pop(option.value),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.65)
                            : theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.55),
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(option.subtitle),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusAreaOption {
  final String value;
  final String title;
  final String subtitle;

  const _FocusAreaOption({
    required this.value,
    required this.title,
    required this.subtitle,
  });
}

class _ResponseStylePickerSheet extends StatelessWidget {
  final String? currentValue;

  const _ResponseStylePickerSheet({
    required this.currentValue,
  });

  @override
  Widget build(BuildContext context) {
    final options = <_ResponseStyleOption>[
      _ResponseStyleOption(
        value: 'gentle',
        title: AppLocaleText.tr(context,
            en: 'Gentle', zhHans: '温和', zhHant: '溫和', ja: 'やわらかめ'),
        subtitle: AppLocaleText.tr(context,
            en: 'Softer and more companion-like',
            zhHans: '更柔和、更像陪伴',
            zhHant: '更柔和、更像陪伴',
            ja: 'やわらかく寄り添う感じ'),
      ),
      _ResponseStyleOption(
        value: 'clear',
        title: AppLocaleText.tr(context,
            en: 'Clear', zhHans: '清晰', zhHant: '清晰', ja: 'クリア'),
        subtitle: AppLocaleText.tr(context,
            en: 'More structured and to the point',
            zhHans: '更有结构，更快到重点',
            zhHant: '更有結構，更快到重點',
            ja: '整理されていて要点が早い'),
      ),
      _ResponseStyleOption(
        value: 'direct',
        title: AppLocaleText.tr(context,
            en: 'Direct', zhHans: '直接', zhHant: '直接', ja: '率直'),
        subtitle: AppLocaleText.tr(context,
            en: 'Shorter and sharper',
            zhHans: '更短，更直接',
            zhHant: '更短，更直接',
            ja: '短く率直'),
      ),
    ];

    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option.value == currentValue;
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            title: Text(option.title),
            subtitle: Text(option.subtitle),
            trailing: selected ? const Icon(Icons.check_circle) : null,
            onTap: () => Navigator.of(context).pop(option.value),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: options.length,
      ),
    );
  }
}

class _ResponseStyleOption {
  final String value;
  final String title;
  final String subtitle;

  const _ResponseStyleOption({
    required this.value,
    required this.title,
    required this.subtitle,
  });
}
