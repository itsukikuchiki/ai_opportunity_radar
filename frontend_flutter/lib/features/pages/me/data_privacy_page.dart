import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_router.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/navigation/app_back_navigation.dart';
import '../../../shared/widgets/aurora_ui.dart';

typedef DataPrivacyExternalLauncher = Future<bool> Function(Uri uri);

Future<bool> _openDataPrivacyExternalUri(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Explains where Signal Path data is held and which controls own it.
///
/// This page is intentionally explanatory. Destructive data controls stay on
/// Me, where they can require an explicit confirmation and current account
/// context.
class DataPrivacyPage extends StatelessWidget {
  static final Uri privacyPolicyUri = Uri.parse(
    'https://itsukikuchiki.github.io/signalpath-support/',
  );

  final DataPrivacyExternalLauncher openExternal;

  const DataPrivacyPage({
    super.key,
    this.openExternal = _openDataPrivacyExternalUri,
  });

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    var opened = false;
    try {
      opened = await openExternal(privacyPolicyUri);
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocaleText.tr(
            context,
            en: 'Could not open the privacy policy right now.',
            zhHans: '暂时无法打开隐私政策。',
            zhHant: '暫時無法開啟隱私政策。',
            ja: 'プライバシーポリシーを開けませんでした。',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: ListView(
                key: const ValueKey('data-privacy-scroll'),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AuroraIconButton(
                      key: const ValueKey('data-privacy-back'),
                      icon: Icons.arrow_back_rounded,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => context.popOrGo(AppRoutes.me),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _DataPrivacyHeader(),
                  const SizedBox(height: 14),
                  const _StorageMapCard(),
                  const SizedBox(height: 12),
                  const _DataRemovalCard(),
                  const SizedBox(height: 12),
                  const _HealthControlCard(),
                  const SizedBox(height: 12),
                  _PrivacyPolicyCard(
                    onOpen: () => _openPrivacyPolicy(context),
                  ),
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

class _DataPrivacyHeader extends StatelessWidget {
  const _DataPrivacyHeader();

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
                icon: Icons.shield_outlined,
                color: AuroraColors.purple,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Data and privacy',
                      zhHans: '数据与隐私',
                      zhHant: '資料與隱私',
                      ja: 'データとプライバシー',
                    ),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AuroraColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppLocaleText.tr(
              context,
              en: 'Signal Path is device-first. Until you use a Signal Path account, your personal content is treated as local to this device. This page does not offer export or promise cloud backup.',
              zhHans:
                  'Signal Path 采用本机优先。在使用 Signal Path 账户前，个人内容按仅保存在本机处理。本页面不提供导出，也不承诺云端备份。',
              zhHant:
                  'Signal Path 採用裝置優先。在使用 Signal Path 帳戶前，個人內容按僅儲存在本機處理。本頁面不提供匯出，也不承諾雲端備份。',
              ja: 'Signal Path は端末優先です。Signal Path アカウントを利用するまでは、個人コンテンツはこの端末内のデータとして扱われます。この画面は書き出しやクラウドバックアップを提供・保証しません。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AuroraColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageMapCard extends StatelessWidget {
  const _StorageMapCard();

  @override
  Widget build(BuildContext context) {
    return _DataPrivacySection(
      title: AppLocaleText.tr(
        context,
        en: 'Where your data is managed',
        zhHans: '数据由哪里管理',
        zhHant: '資料由哪裡管理',
        ja: 'データの管理場所',
      ),
      children: [
        _DataPrivacyInfoRow(
          icon: Icons.phone_iphone_rounded,
          color: AuroraColors.blue,
          title: AppLocaleText.tr(
            context,
            en: 'On this device',
            zhHans: '本机',
            zhHant: '本機',
            ja: 'この端末',
          ),
          body: AppLocaleText.tr(
            context,
            en: 'Your avatar, abstract Health summary and accepted Signal reminder rules stay local.',
            zhHans: '头像、健康数据的抽象摘要，以及已采纳的 Signal 记录提醒规则保存在本机。',
            zhHant: '頭像、健康資料的抽象摘要，以及已採納的 Signal 記錄提醒規則儲存在本機。',
            ja: 'アバター、ヘルスケアの抽象サマリー、承認した Signal 記録リマインダーは端末内に保存されます。',
          ),
        ),
        _DataPrivacyInfoRow(
          icon: Icons.workspace_premium_outlined,
          color: AuroraColors.gold,
          title: 'App Store / StoreKit',
          body: AppLocaleText.tr(
            context,
            en: 'Apple owns purchase records and verified Pro entitlement. Signal Path reads that entitlement; it does not own the subscription.',
            zhHans: '购买记录与已验证的 Pro 权益由 Apple 管理。Signal Path 读取权益，但不管理订阅本身。',
            zhHant: '購買記錄與已驗證的 Pro 權益由 Apple 管理。Signal Path 讀取權益，但不管理訂閱本身。',
            ja: '購入履歴と確認済みの Pro 権利は Apple が管理します。Signal Path は権利を読み取りますが、サブスクリプション自体は管理しません。',
          ),
        ),
        _DataPrivacyInfoRow(
          icon: Icons.cloud_outlined,
          color: AuroraColors.mint,
          title: AppLocaleText.tr(
            context,
            en: 'Signal Path service',
            zhHans: 'Signal Path 服务',
            zhHant: 'Signal Path 服務',
            ja: 'Signal Path サービス',
          ),
          body: AppLocaleText.tr(
            context,
            en: 'The service keeps the usage ledger needed to show Pro analysis usage and reset periods.',
            zhHans: '服务端保存展示 Pro 分析用量与重置周期所需的用量账本。',
            zhHant: '服務端儲存顯示 Pro 分析用量與重設週期所需的用量帳本。',
            ja: 'Pro 分析の利用量とリセット周期を表示するための利用台帳はサービス側で管理されます。',
          ),
          showDivider: false,
        ),
      ],
    );
  }
}

class _DataRemovalCard extends StatelessWidget {
  const _DataRemovalCard();

  @override
  Widget build(BuildContext context) {
    return _DataPrivacySection(
      title: AppLocaleText.tr(
        context,
        en: 'Clearing data and subscriptions',
        zhHans: '清除数据与订阅',
        zhHant: '清除資料與訂閱',
        ja: 'データ消去とサブスクリプション',
      ),
      children: [
        _DataPrivacyInfoRow(
          icon: Icons.delete_sweep_outlined,
          color: AuroraColors.orange,
          title: AppLocaleText.tr(
            context,
            en: 'Signal Path data',
            zhHans: 'Signal Path 数据',
            zhHant: 'Signal Path 資料',
            ja: 'Signal Path のデータ',
          ),
          body: AppLocaleText.tr(
            context,
            en: 'Clearing data on this device removes local Signal Path content and preferences. If you have a Signal Path account, account deletion also requests removal of its service data.',
            zhHans:
                '清除本机数据会删除本机的 Signal Path 内容与偏好。如果已有 Signal Path 账户，删除账户还会请求删除对应的服务端数据。',
            zhHant:
                '清除本機資料會刪除本機的 Signal Path 內容與偏好。如果已有 Signal Path 帳戶，刪除帳戶還會請求刪除對應的服務端資料。',
            ja: 'この端末のデータを消去すると、端末内の Signal Path コンテンツと設定が削除されます。Signal Path アカウントがある場合、アカウント削除では対応するサービスデータの削除も要求します。',
          ),
        ),
        _DataPrivacyInfoRow(
          key: const ValueKey('data-privacy-subscription-boundary'),
          icon: Icons.autorenew_rounded,
          color: AuroraColors.purple,
          title: AppLocaleText.tr(
            context,
            en: 'App Store subscription',
            zhHans: 'App Store 订阅',
            zhHant: 'App Store 訂閱',
            ja: 'App Store サブスクリプション',
          ),
          body: AppLocaleText.tr(
            context,
            en: 'Clearing local data or deleting a Signal Path account does not cancel your subscription. Manage or cancel it in your App Store account.',
            zhHans: '清除本机数据或删除 Signal Path 账户不会取消订阅。请在 App Store 账户中管理或取消订阅。',
            zhHant: '清除本機資料或刪除 Signal Path 帳戶不會取消訂閱。請在 App Store 帳戶中管理或取消訂閱。',
            ja: '端末データや Signal Path アカウントを削除してもサブスクリプションは解約されません。App Store アカウントで管理・解約してください。',
          ),
          showDivider: false,
        ),
      ],
    );
  }
}

class _HealthControlCard extends StatelessWidget {
  const _HealthControlCard();

  @override
  Widget build(BuildContext context) {
    return _DataPrivacySection(
      title: AppLocaleText.tr(
        context,
        en: 'Health data has two separate controls',
        zhHans: '健康数据有两种不同控制',
        zhHant: '健康資料有兩種不同控制',
        ja: 'ヘルスケアデータには2つの別々の操作があります',
      ),
      children: [
        _DataPrivacyInfoRow(
          key: const ValueKey('data-privacy-clear-health-summary'),
          icon: Icons.cleaning_services_outlined,
          color: AuroraColors.mint,
          title: AppLocaleText.tr(
            context,
            en: 'Clear the saved abstract summary',
            zhHans: '清除已保存的抽象摘要',
            zhHant: '清除已儲存的抽象摘要',
            ja: '保存済みの抽象サマリーを消去',
          ),
          body: AppLocaleText.tr(
            context,
            en: 'This removes Signal Path’s saved recovery hints. It does not change the iOS Health permission.',
            zhHans: '这会删除 Signal Path 已保存的恢复提示，但不会更改 iOS 健康数据权限。',
            zhHant: '這會刪除 Signal Path 已儲存的恢復提示，但不會更改 iOS 健康資料權限。',
            ja: 'Signal Path に保存された回復ヒントを削除しますが、iOS のヘルスケア権限は変更しません。',
          ),
        ),
        _DataPrivacyInfoRow(
          key: const ValueKey('data-privacy-revoke-health-access'),
          icon: Icons.settings_outlined,
          color: AuroraColors.blue,
          title: AppLocaleText.tr(
            context,
            en: 'Revoke access in iOS Settings',
            zhHans: '在 iOS 设置中撤销访问权限',
            zhHant: '在 iOS 設定中撤銷取用權限',
            ja: 'iOS 設定でアクセスを取り消す',
          ),
          body: AppLocaleText.tr(
            context,
            en: 'This stops future Health reads. Previously saved abstract hints remain until you clear them in Signal Path.',
            zhHans: '这会停止今后的健康数据读取。此前保存的抽象提示仍会保留，直到你在 Signal Path 中清除。',
            zhHant: '這會停止今後的健康資料讀取。此前儲存的抽象提示仍會保留，直到你在 Signal Path 中清除。',
            ja: '今後のヘルスケア読み取りを停止します。以前保存された抽象ヒントは、Signal Path で消去するまで残ります。',
          ),
          showDivider: false,
        ),
      ],
    );
  }
}

class _PrivacyPolicyCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _PrivacyPolicyCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuroraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleText.tr(
              context,
              en: 'Read the full policy',
              zhHans: '查看完整政策',
              zhHant: '查看完整政策',
              ja: 'ポリシー全文を確認',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              color: AuroraColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocaleText.tr(
              context,
              en: 'The external privacy policy contains the current legal details.',
              zhHans: '外部隐私政策页面提供当前完整的法律说明。',
              zhHant: '外部隱私政策頁面提供目前完整的法律說明。',
              ja: '外部のプライバシーポリシーで最新の法的詳細を確認できます。',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AuroraColors.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: AuroraPillButton(
              key: const ValueKey('data-privacy-policy-button'),
              icon: Icons.open_in_new_rounded,
              label: AppLocaleText.tr(
                context,
                en: 'Open Privacy Policy',
                zhHans: '打开隐私政策',
                zhHant: '開啟隱私政策',
                ja: 'プライバシーポリシーを開く',
              ),
              filled: true,
              onPressed: onOpen,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataPrivacySection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DataPrivacySection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AuroraColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _DataPrivacyInfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool showDivider;

  const _DataPrivacyInfoRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuroraSoftIconCircle(icon: icon, color: color, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AuroraColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AuroraColors.muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: AuroraColors.line.withValues(alpha: 0.72),
          ),
      ],
    );
  }
}
