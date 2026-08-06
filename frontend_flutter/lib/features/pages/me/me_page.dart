import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/app_locale_text.dart';
import '../../../core/preferences/focus_domains.dart';
import '../../../core/purchases/purchase_controller.dart';
import '../../../core/state/app_bootstrap_state.dart';
import '../../../app/app_router.dart';
import '../../../shared/widgets/aurora_ui.dart';
import '../../paywall/paywall_sheet.dart';
import 'me_view_model.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  static final Uri _supportUri = Uri.parse(
    'https://signalpath-app-preview.itsukikuchiki.chatgpt.site/#guestbook',
  );
  static final Uri _privacyUri = Uri.parse(
    'https://signalpath-app-preview.itsukikuchiki.chatgpt.site/privacy',
  );
  static final Uri _subscriptionManagementUri = Uri.parse(
    'https://apps.apple.com/account/subscriptions',
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
                key: const ValueKey('me-scroll-view'),
                padding: AuroraMainPageSpec.scrollPadding(context),
                children: [
                  _MeHeroHeader(
                    vm: vm,
                    onEdit:
                        vm.saving ? null : () => _showProfileSheet(context, vm),
                  ),
                  const SizedBox(height: AuroraMainPageSpec.heroGap),
                  if (vm.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _FocusDomainsCard(
                      lifeDirection: vm.lifeDirection,
                      createdAt: vm.lifeDirectionCreatedAt,
                      selectedIds: vm.selectedFocusDomainIds,
                      onTap: vm.saving
                          ? null
                          : () => _showLifeDirectionPage(context, vm),
                    ),
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  ],
                  _ProUsageCard(
                    purchase: purchase,
                    vm: vm,
                    onManageSubscription: () =>
                        _openSubscriptionManagement(context),
                  ),
                  const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  _MeSignalsSection(
                    onOpenReminders: () =>
                        context.push(AppRoutes.signalReminders),
                    onOpenAdvancedSignals: () =>
                        context.push(AppRoutes.advancedSignals),
                  ),
                  const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  _MeDataSection(
                    onOpenPrivacy: () => _openPrivacy(context),
                    onDeleteData: vm.deletingData
                        ? null
                        : () => _confirmDeleteData(context, vm),
                    hasCloudAccount: vm.hasCloudAccount,
                  ),
                  const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  _MeHelpSection(
                    onOpenSupport: () => _openSupport(context),
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                    const _MeDebugSection(),
                  ],
                  if (vm.errorMessage != null &&
                      vm.errorMessage!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _meErrorLabel(context, vm.errorMessage!),
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
          const AuroraSafeTopMask(extraHeight: 4),
        ],
      ),
    );
  }

  Future<void> _showProfileSheet(BuildContext context, MeViewModel vm) async {
    final draft = await showModalBottomSheet<_ProfileDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProfileEditSheet(
        displayName: vm.profileDisplayName ?? '',
      ),
    );
    if (draft == null) return;
    final success = await vm.updateProfile(
      displayName: draft.displayName,
      direction: vm.lifeDirection ?? '',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? AppLocaleText.tr(
                  context,
                  en: 'Profile updated.',
                  zhHans: '个人资料已更新。',
                  zhHant: '個人資料已更新。',
                  ja: 'プロフィールを更新しました。',
                )
              : _meErrorLabel(context, vm.errorMessage),
        ),
      ),
    );
  }

  Future<void> _showLifeDirectionPage(
    BuildContext context,
    MeViewModel vm,
  ) async {
    final draft = await Navigator.of(context).push<_LifeDirectionDraft>(
      MaterialPageRoute(
        builder: (_) => _LifeDirectionSettingsPage(
          currentDirection: vm.lifeDirection ?? '',
          currentValues: vm.selectedFocusDomainIds,
        ),
      ),
    );

    if (draft == null) return;

    final profileUpdated = await vm.updateProfile(
      displayName: vm.profileDisplayName ?? '',
      direction: draft.direction,
    );
    final focusUpdated =
        profileUpdated && await vm.updateFocusDomains(draft.focusDomainIds);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          focusUpdated
              ? AppLocaleText.tr(
                  context,
                  en: 'Life direction updated.',
                  zhHans: '人生方向已更新。',
                  zhHant: '人生方向已更新。',
                  ja: '人生の方向を更新しました。',
                )
              : AppLocaleText.tr(
                  context,
                  en: 'Failed to update the life direction.',
                  zhHans: '更新人生方向失败。',
                  zhHant: '更新人生方向失敗。',
                  ja: '人生の方向を更新できませんでした。',
                ),
        ),
      ),
    );
  }

  Future<void> _openSupport(BuildContext context) async {
    try {
      final opened = await launchUrl(
        _supportUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocaleText.tr(
            context,
            en: 'Could not open support right now.',
            zhHans: '暂时无法打开支持页面。',
            zhHant: '暫時無法打開支援頁面。',
            ja: 'サポートページを開けませんでした。',
          ),
        ),
      ),
    );
  }

  Future<void> _openPrivacy(BuildContext context) async {
    try {
      final opened = await launchUrl(
        _privacyUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
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

  Future<void> _openSubscriptionManagement(BuildContext context) async {
    try {
      final opened = await launchUrl(
        _subscriptionManagementUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened || !context.mounted) return;
    } catch (_) {
      if (!context.mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocaleText.tr(
            context,
            en: 'Could not open subscription management.',
            zhHans: '暂时无法打开订阅管理。',
            zhHant: '暫時無法打開訂閱管理。',
            ja: 'サブスクリプション管理を開けませんでした。',
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteData(
    BuildContext context,
    MeViewModel vm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          vm.hasCloudAccount
              ? AppLocaleText.tr(
                  context,
                  en: 'Delete account and all data?',
                  zhHans: '删除账户与所有数据？',
                  zhHant: '刪除帳戶與所有資料？',
                  ja: 'アカウントと全データを削除しますか？',
                )
              : AppLocaleText.tr(
                  context,
                  en: 'Clear all data on this device?',
                  zhHans: '清除本机全部数据？',
                  zhHant: '清除此裝置上的全部資料？',
                  ja: 'この端末の全データを消去しますか？',
                ),
        ),
        content: Text(
          AppLocaleText.tr(
            context,
            en: 'This cannot be undone. StoreKit purchase rights are managed separately by Apple.',
            zhHans: '此操作无法撤销。购买权益仍由苹果单独管理。',
            zhHant: '此操作無法撤銷。購買權益仍由蘋果單獨管理。',
            ja: 'この操作は取り消せません。購入権利はアップルが別途管理します。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              MaterialLocalizations.of(context).cancelButtonLabel,
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
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
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    AppBootstrapState? bootstrap;
    try {
      bootstrap = context.read<AppBootstrapState>();
    } on ProviderNotFoundException {
      bootstrap = null;
    }
    final success = await vm.deleteMyData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? AppLocaleText.tr(
                  context,
                  en: 'Your Signal Path data was deleted.',
                  zhHans: 'Signal Path 数据已删除。',
                  zhHant: 'Signal Path 資料已刪除。',
                  ja: 'Signal Path のデータを削除しました。',
                )
              : _meErrorLabel(context, vm.errorMessage),
        ),
      ),
    );
    if (success && bootstrap != null) {
      await bootstrap.resetAfterDataDeletion();
    }
  }
}

class _MeHeroHeader extends StatelessWidget {
  final MeViewModel vm;
  final VoidCallback? onEdit;

  const _MeHeroHeader({required this.vm, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    return AuroraCard(
      key: const ValueKey('me-hero-header'),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFFFFFBF6).withValues(alpha: 0.94),
          const Color(0xFFF7F1FF).withValues(alpha: 0.86),
          const Color(0xFFEEF5FF).withValues(alpha: 0.80),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(),
          child: Stack(
            children: [
              Positioned(
                key: const ValueKey('me-hero-direction-pattern'),
                right: compact ? -36 : -28,
                top: compact ? -34 : -40,
                width: compact ? 164 : 188,
                height: compact ? 164 : 188,
                child: const IgnorePointer(
                  child: AuroraJourneyHeroPattern(opacity: 0.54),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 16,
                  compact ? 13 : 15,
                  compact ? 14 : 16,
                  compact ? 14 : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: compact ? 76 : 104),
                      child: AuroraHeroTitle(
                        key: const ValueKey('me-hero-title'),
                        text: AppLocaleText.tr(
                          context,
                          en: 'Me',
                          zhHans: '我的',
                          zhHant: '我的',
                          ja: '私',
                        ),
                        fontSize:
                            AuroraMainPageSpec.responsiveHeroTitleSize(context),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _MeProfileIntro(vm: vm, onEdit: onEdit),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeProfileIntro extends StatelessWidget {
  final MeViewModel vm;
  final VoidCallback? onEdit;

  const _MeProfileIntro({required this.vm, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final photoPath = vm.profilePhotoPath;
    return Row(
      key: const ValueKey('me-profile-summary'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: vm.saving ? null : () => _pickAvatar(context, vm),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                key: const ValueKey('me-profile-avatar'),
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AuroraColors.purple.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: photoPath == null || photoPath.trim().isEmpty
                      ? Image.asset(
                          'assets/me/me-avatar-landscape.png',
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(photoPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/me/me-avatar-landscape.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: 2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AuroraColors.purple,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: Text(
                      vm.profileDisplayName == null
                          ? AppLocaleText.tr(
                              context,
                              en: 'Hello',
                              zhHans: '你好',
                              zhHant: '你好',
                              ja: 'こんにちは',
                            )
                          : AppLocaleText.tr(
                              context,
                              en: 'Hello, ${vm.profileDisplayName}',
                              zhHans: '你好，${vm.profileDisplayName}',
                              zhHant: '你好，${vm.profileDisplayName}',
                              ja: 'こんにちは、${vm.profileDisplayName}',
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFF071D5E),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('me-profile-edit-button'),
                    tooltip: AppLocaleText.tr(
                      context,
                      en: 'Edit name',
                      zhHans: '修改用户名',
                      zhHant: '修改使用者名稱',
                      ja: '名前を編集',
                    ),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 17),
                    color: AuroraColors.purple,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.72),
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                vm.lifeDirection ??
                    AppLocaleText.tr(
                      context,
                      en: 'Add a life direction when you are ready.',
                      zhHans: '准备好时，再写下你想靠近的生活。',
                      zhHant: '準備好時，再寫下你想靠近的生活。',
                      ja: '準備ができたら、目指す暮らしを記せます。',
                    ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF60749E),
                      fontSize: AuroraMainPageSpec.heroSubtitleSize,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                key: const ValueKey('me-life-direction'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAvatar(BuildContext context, MeViewModel vm) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 88,
    );
    if (picked == null) return;

    final sourceFile = File(picked.path);
    final size = await sourceFile.length();
    if (!context.mounted) return;
    if (size > MeViewModel.maxProfilePhotoBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocaleText.tr(
              context,
              en: 'Photo is too large. Please choose one under 2 MB.',
              zhHans: '照片太大了，请选择 2 兆字节以下的图片。',
              zhHant: '照片太大了，請選擇 2 兆位元組以下的圖片。',
              ja: '写真が大きすぎます。2メガバイト未満の画像を選んでください。',
            ),
          ),
        ),
      );
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final extension =
        p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
    final target = File(p.join(directory.path, 'me_avatar$extension'));
    await sourceFile.copy(target.path);
    final ok = await vm.updateProfilePhotoPath(
      path: target.path,
      sizeBytes: await target.length(),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? AppLocaleText.tr(
                  context,
                  en: 'Profile photo updated.',
                  zhHans: '头像已更新。',
                  zhHant: '頭像已更新。',
                  ja: 'プロフィール写真を更新しました。',
                )
              : AppLocaleText.tr(
                  context,
                  en: 'Could not update the photo.',
                  zhHans: '无法更新头像。',
                  zhHant: '無法更新頭像。',
                  ja: '写真を更新できませんでした。',
                ),
        ),
      ),
    );
  }
}

class _FocusDomainsCard extends StatelessWidget {
  final String? lifeDirection;
  final DateTime? createdAt;
  final List<String> selectedIds;
  final VoidCallback? onTap;

  const _FocusDomainsCard({
    required this.lifeDirection,
    required this.createdAt,
    required this.selectedIds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = FocusDomains.normalizeIds(selectedIds);
    final visibleIds = normalized.take(3).toList();
    final hiddenCount = normalized.length - visibleIds.length;

    final direction = lifeDirection?.trim();
    return Container(
      key: const ValueKey('me-focus-domains-card'),
      decoration: _meCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -28,
            bottom: -22,
            width: 210,
            height: 150,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.20,
                child: Image.asset(
                  'assets/me/me-avatar-landscape.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.white.withValues(alpha: 0.94),
                  Colors.white.withValues(alpha: 0.82),
                  Colors.white.withValues(alpha: 0.38),
                ],
                stops: const [0, 0.62, 1],
              ),
            ),
          ),
          Padding(
              padding: AuroraMainPageSpec.comfortableCardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'My life direction',
                            zhHans: '我的人生方向',
                            zhHant: '我的人生方向',
                            ja: '私の人生の方向',
                          ),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: const Color(0xFF071D5E),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AuroraColors.purple.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AuroraColors.purple.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'In progress',
                            zhHans: '进行中',
                            zhHant: '進行中',
                            ja: '進行中',
                          ),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AuroraColors.purple,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    direction?.isNotEmpty == true
                        ? direction!
                        : AppLocaleText.tr(
                            context,
                            en: 'Write down the kind of life you want to move toward.',
                            zhHans: '写下你想慢慢靠近的生活。',
                            zhHant: '寫下你想慢慢靠近的生活。',
                            ja: '少しずつ近づきたい暮らしを書きましょう。',
                          ),
                    key: const ValueKey('me-life-direction-summary'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: const Color(0xFF071D5E),
                          fontSize: 16,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: Color(0xFF7F8CB7),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Created ${DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(createdAt!)}',
                            zhHans:
                                '创建于 ${DateFormat('yyyy年M月d日').format(createdAt!)}',
                            zhHant:
                                '建立於 ${DateFormat('yyyy年M月d日').format(createdAt!)}',
                            ja: '${DateFormat('yyyy年M月d日').format(createdAt!)} に作成',
                          ),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF7F8CB7),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useIconOnly = constraints.maxWidth < 280 ||
                          MediaQuery.textScalerOf(context).scale(14) > 16;
                      final label = AppLocaleText.tr(
                        context,
                        en: 'Focus areas',
                        zhHans: '关注领域',
                        zhHant: '關注領域',
                        ja: '注目領域',
                      );
                      return Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: const Color(0xFF60749E),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (useIconOnly)
                            IconButton(
                              key: const ValueKey(
                                'me-life-direction-edit-button',
                              ),
                              tooltip: AppLocaleText.tr(
                                context,
                                en: 'Edit life direction',
                                zhHans: '调整人生方向',
                                zhHant: '調整人生方向',
                                ja: '人生の方向を調整',
                              ),
                              onPressed: onTap,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              color: AuroraColors.purple,
                              style: IconButton.styleFrom(
                                minimumSize: const Size(44, 44),
                              ),
                            )
                          else
                            TextButton.icon(
                              key: const ValueKey(
                                'me-life-direction-edit-button',
                              ),
                              onPressed: onTap,
                              style: TextButton.styleFrom(
                                foregroundColor: AuroraColors.purple,
                                minimumSize: const Size(44, 44),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              label: Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'Edit',
                                  zhHans: '调整',
                                  zhHant: '調整',
                                  ja: '調整',
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  if (normalized.isEmpty)
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'No focus areas selected yet.',
                        zhHans: '还没有选择关注领域',
                        zhHant: '還沒有選擇關注領域',
                        ja: '注目領域はまだ選ばれていません。',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF7F8CB7),
                            fontWeight: FontWeight.w700,
                          ),
                    )
                  else
                    Wrap(
                      spacing: 9,
                      runSpacing: 10,
                      children: [
                        for (final id in visibleIds) _FocusDomainChip(id: id),
                        if (hiddenCount > 0)
                          _FocusDomainMoreChip(totalCount: normalized.length),
                      ],
                    ),
                ],
              )),
        ],
      ),
    );
  }
}

class _FocusDomainChip extends StatelessWidget {
  final String id;

  const _FocusDomainChip({required this.id});

  @override
  Widget build(BuildContext context) {
    final option = FocusDomains.optionFor(id);
    final color = option?.color ?? AuroraColors.purple;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 68,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option?.icon ?? Icons.auto_awesome_rounded,
              size: 17,
              color: color,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                FocusDomains.labelFor(context, id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF071D5E),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusDomainMoreChip extends StatelessWidget {
  final int totalCount;

  const _FocusDomainMoreChip({required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AuroraColors.purple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AuroraColors.purple.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        AppLocaleText.tr(
          context,
          en: 'and $totalCount total',
          zhHans: '等 $totalCount 个',
          zhHant: '等 $totalCount 個',
          ja: '全$totalCount件',
        ),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AuroraColors.purple,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MeDataSection extends StatelessWidget {
  final VoidCallback onOpenPrivacy;
  final VoidCallback? onDeleteData;
  final bool hasCloudAccount;

  const _MeDataSection({
    required this.onOpenPrivacy,
    required this.onDeleteData,
    required this.hasCloudAccount,
  });

  @override
  Widget build(BuildContext context) {
    return _MeListCard(
      cardKey: const ValueKey('me-data-privacy-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Data and privacy',
        zhHans: '数据与隐私',
        zhHant: '資料與隱私',
        ja: 'データとプライバシー',
      ),
      subtitle: hasCloudAccount
          ? AppLocaleText.tr(
              context,
              en: 'Manage your account data and privacy choices.',
              zhHans: '管理账户数据与隐私选择。',
              zhHant: '管理帳戶資料與隱私選擇。',
              ja: 'アカウントデータとプライバシー設定を管理します。',
            )
          : AppLocaleText.tr(
              context,
              en: 'Manage Signal Path data and privacy choices.',
              zhHans: '管理 Signal Path 数据与隐私选择。',
              zhHant: '管理 Signal Path 資料與隱私選擇。',
              ja: 'Signal Path のデータとプライバシー設定を管理します。',
            ),
      rows: [
        _MeListRowData(
          icon: Icons.privacy_tip_outlined,
          iconColor: AuroraColors.purple,
          title: AppLocaleText.tr(
            context,
            en: 'Privacy and security',
            zhHans: '隐私与安全',
            zhHant: '隱私與安全',
            ja: 'プライバシーと安全',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Review how Signal Path handles your data',
            zhHans: '查看 Signal Path 如何处理你的数据',
            zhHant: '查看 Signal Path 如何處理你的資料',
            ja: 'Signal Path のデータ取り扱いを確認',
          ),
          onTap: onOpenPrivacy,
        ),
        _MeListRowData(
          icon: Icons.delete_forever_outlined,
          iconColor: const Color(0xFFD95858),
          title: hasCloudAccount
              ? AppLocaleText.tr(
                  context,
                  en: 'Delete account and all data',
                  zhHans: '删除账户与所有数据',
                  zhHant: '刪除帳戶與所有資料',
                  ja: 'アカウントと全データを削除',
                )
              : AppLocaleText.tr(
                  context,
                  en: 'Clear data on this device',
                  zhHans: '清除本机数据',
                  zhHant: '清除此裝置資料',
                  ja: 'この端末のデータを消去',
                ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Permanently remove Signal Path content and preferences',
            zhHans: '永久删除 Signal Path 内容与偏好',
            zhHant: '永久刪除 Signal Path 內容與偏好',
            ja: 'Signal Path の内容と設定を完全に削除',
          ),
          onTap: onDeleteData,
        ),
      ],
    );
  }
}

class _MeSignalsSection extends StatelessWidget {
  final VoidCallback onOpenReminders;
  final VoidCallback onOpenAdvancedSignals;

  const _MeSignalsSection({
    required this.onOpenReminders,
    required this.onOpenAdvancedSignals,
  });

  @override
  Widget build(BuildContext context) {
    return _MeListCard(
      cardKey: const ValueKey('me-reminders-data-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Reminders and connected data',
        zhHans: '提醒与联动',
        zhHant: '提醒與聯動',
        ja: 'リマインダーと連携',
      ),
      rows: [
        _MeListRowData(
          icon: Icons.notifications_active_outlined,
          iconColor: const Color(0xFF5E8DF5),
          title: AppLocaleText.tr(
            context,
            en: 'Signal reminders',
            zhHans: 'Signal 记录提醒',
            zhHant: 'Signal 記錄提醒',
            ja: 'Signal 記録リマインダー',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Manage reminder suggestions you have accepted',
            zhHans: '管理你已经采纳的记录提醒',
            zhHant: '管理你已經採納的記錄提醒',
            ja: '承認した記録リマインダーを管理',
          ),
          onTap: onOpenReminders,
        ),
        _MeListRowData(
          icon: Icons.monitor_heart_outlined,
          iconColor: const Color(0xFF59BFA5),
          title: AppLocaleText.tr(
            context,
            en: 'Connected data',
            zhHans: '联动',
            zhHant: '聯動',
            ja: '連携',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'See how health data shapes energy, recovery, and suggestions',
            zhHans: '查看健康数据如何影响精力、恢复与建议',
            zhHant: '查看健康資料如何影響精力、恢復與建議',
            ja: '健康データが精力・回復・提案に与える影響を確認',
          ),
          onTap: onOpenAdvancedSignals,
        ),
      ],
    );
  }
}

class _MeHelpSection extends StatelessWidget {
  final VoidCallback onOpenSupport;

  const _MeHelpSection({
    required this.onOpenSupport,
  });

  @override
  Widget build(BuildContext context) {
    return _MeListCard(
      cardKey: const ValueKey('me-help-about-card'),
      title: AppLocaleText.tr(
        context,
        en: 'Help and about',
        zhHans: '帮助与关于',
        zhHant: '幫助與關於',
        ja: 'ヘルプとこのアプリについて',
      ),
      rows: [
        _MeListRowData(
          icon: Icons.support_agent_rounded,
          iconColor: const Color(0xFF5E8DF5),
          title: AppLocaleText.tr(
            context,
            en: 'Help and support',
            zhHans: '帮助与支持',
            zhHant: '幫助與支援',
            ja: 'ヘルプとサポート',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Purchase help, troubleshooting and contact information',
            zhHans: '购买帮助、问题排查与联系方式',
            zhHant: '購買協助、問題排查與聯絡方式',
            ja: '購入、トラブル対応、連絡先',
          ),
          onTap: onOpenSupport,
        ),
      ],
    );
  }
}

class _MeDebugSection extends StatelessWidget {
  const _MeDebugSection();

  @override
  Widget build(BuildContext context) {
    return _MeListCard(
      title: AppLocaleText.tr(
        context,
        en: 'Developer',
        zhHans: '开发者',
        zhHant: '開發者',
        ja: '開発者',
      ),
      rows: [
        _MeListRowData(
          icon: Icons.account_tree_rounded,
          iconColor: AuroraColors.purple,
          title: AppLocaleText.tr(
            context,
            en: 'Trace / Debug',
            zhHans: '追踪 / 调试',
            zhHant: '追蹤 / 調試',
            ja: '追跡 / デバッグ',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Inspect Signal -> Weekly / Journey / Experiment',
            zhHans: '检查 Signal → 每周复盘 / 旅程 / 生活实验',
            zhHant: '檢查 Signal → 每週復盤 / 旅程 / 生活實驗',
            ja: 'Signal → 週次振り返り / 旅程 / 生活実験を確認',
          ),
          onTap: () => context.push(AppRoutes.debugTrace),
        ),
      ],
    );
  }
}

class _MeListCard extends StatelessWidget {
  final Key? cardKey;
  final String title;
  final String? subtitle;
  final List<_MeListRowData> rows;

  const _MeListCard({
    this.cardKey,
    required this.title,
    this.subtitle,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: cardKey,
      decoration: _meCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF071D5E),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7F8CB7),
                      fontSize: AuroraMainPageSpec.supportingSize,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
              ),
            ],
            const SizedBox(height: 4),
            for (var index = 0; index < rows.length; index++) ...[
              _MeListRow(data: rows[index]),
              if (index < rows.length - 1)
                Divider(
                  height: 1,
                  indent: 58,
                  color: const Color(0xFFE2E5F3).withValues(alpha: 0.78),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MeListRowData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MeListRowData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
}

class _MeListRow extends StatelessWidget {
  final _MeListRowData data;

  const _MeListRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: data.onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Row(
          children: [
            _MeRoundedIcon(icon: data.icon, color: data.iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF071D5E),
                          fontSize: AuroraMainPageSpec.bodySize,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7F8CB7),
                          fontSize: AuroraMainPageSpec.supportingSize,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF667DAF),
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProUsageCard extends StatelessWidget {
  final PurchaseController? purchase;
  final MeViewModel vm;
  final VoidCallback onManageSubscription;

  const _ProUsageCard({
    required this.purchase,
    required this.vm,
    required this.onManageSubscription,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = purchase?.isPremium ?? false;
    final loading = purchase?.loading ?? false;
    final verificationPending =
        purchase?.entitlementReconciliationPending ?? false;
    final usageNeedsAttention = vm.usageLoading ||
        vm.usageLoadFailed ||
        !vm.usageMatchesLocalEntitlement(isPremium);
    final visibleQuotas = vm.usageQuotas.values
        .where((quota) => quota.featureKey.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showPremiumPaywall(context, source: 'Pro'),
      child: Container(
        key: const ValueKey('me-pro-usage-card'),
        decoration: _meCardDecoration(accent: const Color(0xFF9B78F8)),
        padding: AuroraMainPageSpec.comfortableCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MeCrownBadge(active: isPremium),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loading
                            ? AppLocaleText.tr(
                                context,
                                en: 'Checking Pro status',
                                zhHans: '正在确认专业版状态',
                                zhHant: '正在確認專業版狀態',
                                ja: 'プロ版の状態を確認中',
                              )
                            : isPremium
                                ? AppLocaleText.tr(
                                    context,
                                    en: 'Pro membership',
                                    zhHans: '专业版会员',
                                    zhHant: '專業版會員',
                                    ja: 'プロ版メンバー',
                                  )
                                : AppLocaleText.tr(
                                    context,
                                    en: 'Upgrade to Pro',
                                    zhHans: '升级到专业版',
                                    zhHant: '升級到專業版',
                                    ja: 'プロ版にアップグレード',
                                  ),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF071D5E),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        loading
                            ? AppLocaleText.tr(
                                context,
                                en: 'Syncing purchase access…',
                                zhHans: '正在同步购买权益…',
                                zhHant: '正在同步購買權益…',
                                ja: '購入権利を同期しています…',
                              )
                            : isPremium
                                ? verificationPending
                                    ? AppLocaleText.tr(
                                        context,
                                        en: 'Unlocked · verification continues in the background',
                                        zhHans: '已解锁 · 后台继续验证',
                                        zhHant: '已解鎖 · 後台繼續驗證',
                                        ja: '解除済み · バックグラウンドで検証中',
                                      )
                                    : AppLocaleText.tr(
                                        context,
                                        en: 'Active · manage or restore purchases',
                                        zhHans: '已启用 · 管理或恢复购买',
                                        zhHant: '已啟用 · 管理或恢復購買',
                                        ja: '有効 · 購入の管理・復元',
                                      )
                                : AppLocaleText.tr(
                                    context,
                                    en: 'Unlock deeper weekly and journey analysis',
                                    zhHans: '解锁每周复盘与旅程的深度分析',
                                    zhHant: '解鎖每週復盤與旅程的深度分析',
                                    ja: '毎週復盤と旅程の深度分析を利用',
                                  ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF6E7FA9),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Benefits',
                        zhHans: '查看权益',
                        zhHant: '查看權益',
                        ja: '特典',
                      ),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AuroraColors.purple,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AuroraColors.purple,
                    size: 21,
                  ),
                ],
              ],
            ),
            if (!usageNeedsAttention && visibleQuotas.isNotEmpty) ...[
              const SizedBox(height: 14),
              _MembershipQuotaSummary(quota: visibleQuotas.first),
            ],
            if (usageNeedsAttention || visibleQuotas.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: const Color(0xFFE2E5F3).withValues(alpha: 0.72),
              ),
              const SizedBox(height: 12),
              if (usageNeedsAttention)
                _UsageSyncInline(vm: vm, localPremium: isPremium)
              else
                _MonthlyUsageInline(quotas: visibleQuotas),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('me-manage-subscription-button'),
                onPressed: onManageSubscription,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'Manage subscription',
                    zhHans: '管理订阅',
                    zhHant: '管理訂閱',
                    ja: 'サブスクリプションを管理',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AuroraColors.purple,
                  minimumSize: const Size.fromHeight(44),
                  side: BorderSide(
                    color: AuroraColors.purple.withValues(alpha: 0.24),
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageSyncInline extends StatelessWidget {
  final MeViewModel vm;
  final bool localPremium;

  const _UsageSyncInline({required this.vm, required this.localPremium});

  @override
  Widget build(BuildContext context) {
    final mismatch = !vm.usageMatchesLocalEntitlement(localPremium);
    return Row(
      key: const ValueKey('me-usage-sync-state'),
      children: [
        if (vm.usageLoading)
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        else
          const _MeRoundedIcon(
            icon: Icons.sync_rounded,
            color: Color(0xFF5E8DF5),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vm.usageLoading
                    ? AppLocaleText.tr(
                        context,
                        en: 'Checking usage',
                        zhHans: '正在核对用量',
                        zhHant: '正在核對用量',
                        ja: '利用状況を確認中',
                      )
                    : mismatch
                        ? AppLocaleText.tr(
                            context,
                            en: 'Pro access is unlocked; usage is reconciling',
                            zhHans: '专业版已解锁，用量正在对账',
                            zhHant: '專業版已解鎖，用量正在對帳',
                            ja: 'プロ版は解除済み、利用状況を照合中',
                          )
                        : AppLocaleText.tr(
                            context,
                            en: 'Usage is temporarily unavailable',
                            zhHans: '用量暂时无法更新',
                            zhHant: '用量暫時無法更新',
                            ja: '利用状況を一時的に更新できません',
                          ),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF071D5E),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Last known values are kept; no zero value is inferred from a network error.',
                  zhHans: '会保留上次已知值，不会把网络错误误显示为 0。',
                  zhHant: '會保留上次已知值，不會把網路錯誤誤顯示為 0。',
                  ja: '前回の値を保持し、通信エラーを 0 として表示しません。',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7F8CB7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        if (!vm.usageLoading)
          IconButton(
            tooltip: AppLocaleText.tr(
              context,
              en: 'Retry',
              zhHans: '重试',
              zhHant: '重試',
              ja: '再試行',
            ),
            onPressed: vm.reloadUsage,
            icon: const Icon(Icons.refresh_rounded),
            color: AuroraColors.purple,
          ),
      ],
    );
  }
}

class _MembershipQuotaSummary extends StatelessWidget {
  final UsageQuotaViewData quota;

  const _MembershipQuotaSummary({required this.quota});

  @override
  Widget build(BuildContext context) {
    final limit = quota.limit;
    final progress =
        limit == null || limit <= 0 ? null : (quota.used / limit).clamp(0, 1);

    return Column(
      key: const ValueKey('me-membership-quota-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppLocaleText.tr(
                  context,
                  en: 'Monthly allowance',
                  zhHans: '本月额度',
                  zhHant: '本月額度',
                  ja: '今月の利用枠',
                ),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF60749E),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Text(
              quota.displayValue,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AuroraColors.purple,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress.toDouble(),
              backgroundColor: AuroraColors.purple.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(AuroraColors.purple),
            ),
          ),
        ],
      ],
    );
  }
}

class _MonthlyUsageInline extends StatelessWidget {
  final List<UsageQuotaViewData> quotas;

  const _MonthlyUsageInline({required this.quotas});

  @override
  Widget build(BuildContext context) {
    final visibleQuotas = quotas
        .where((quota) => quota.featureKey.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);
    if (visibleQuotas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocaleText.tr(
            context,
            en: 'This month',
            zhHans: '本月使用',
            zhHant: '本月使用',
            ja: '今月の利用',
          ),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF071D5E),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final quota in visibleQuotas)
                  SizedBox(
                    width: tileWidth,
                    child: _MonthlyUsageTile(quota: quota),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MonthlyUsageTile extends StatelessWidget {
  final UsageQuotaViewData quota;

  const _MonthlyUsageTile({required this.quota});

  @override
  Widget build(BuildContext context) {
    final color = _usageFeatureColor(quota.featureKey);
    return Container(
      key: ValueKey('me-monthly-usage-${quota.featureKey}'),
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MeRoundedIcon(
            icon: _usageFeatureIcon(quota.featureKey),
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            _usageFeatureLabel(context, quota.featureKey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF60749E),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            quota.displayValue,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF071D5E),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

IconData _usageFeatureIcon(String featureKey) {
  return switch (featureKey) {
    'l1_assist' || 'l1_assist_daily_flow' => Icons.auto_awesome_rounded,
    'l1_attune_dialogue' => Icons.chat_bubble_rounded,
    'l2_reason' || 'l2_reason_pattern_check' => Icons.psychology_alt_rounded,
    'l3_reflect' ||
    'l3_reflect_weekly' ||
    'l3_reflect_journey' =>
      Icons.science_rounded,
    _ => Icons.insights_rounded,
  };
}

Color _usageFeatureColor(String featureKey) {
  return switch (featureKey) {
    'l1_attune_dialogue' => const Color(0xFFE887B9),
    'l2_reason' || 'l2_reason_pattern_check' => const Color(0xFF7B6AF2),
    'l3_reflect' ||
    'l3_reflect_weekly' ||
    'l3_reflect_journey' =>
      const Color(0xFF59BFA5),
    _ => const Color(0xFF5E8DF5),
  };
}

String _usageFeatureLabel(BuildContext context, String featureKey) {
  return switch (featureKey) {
    'l1_assist' || 'l1_assist_daily_flow' => AppLocaleText.tr(
        context,
        en: 'Recording assist',
        zhHans: '记录辅助',
        zhHant: '記錄輔助',
        ja: '記録アシスト',
      ),
    'l1_attune_dialogue' => AppLocaleText.tr(
        context,
        en: 'Attune dialogue',
        zhHans: '轻回应对话',
        zhHant: '輕回應對話',
        ja: '寄り添い対話',
      ),
    'l2_reason' || 'l2_reason_pattern_check' => AppLocaleText.tr(
        context,
        en: 'Reason AI',
        zhHans: '智能助手判断',
        zhHant: '智能助手判斷',
        ja: 'アシスタントの判断',
      ),
    'l3_reflect' => AppLocaleText.tr(
        context,
        en: 'Deep analysis',
        zhHans: '深度分析',
        zhHant: '深度分析',
        ja: '深度分析',
      ),
    'l3_reflect_weekly' => AppLocaleText.tr(
        context,
        en: 'Weekly Reflect',
        zhHans: '每周复盘深度分析',
        zhHant: '每週復盤深度分析',
        ja: '週次振り返り',
      ),
    'l3_reflect_journey' => AppLocaleText.tr(
        context,
        en: 'Journey Reflect',
        zhHans: '旅程深度分析',
        zhHant: '旅程深度分析',
        ja: '旅程の振り返り',
      ),
    _ => AppLocaleText.tr(
        context,
        en: featureKey.replaceAll('_', ' '),
        zhHans: '其他功能',
        zhHant: '其他功能',
        ja: 'その他の機能',
      ),
  };
}

class _MeRoundedIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _MeRoundedIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: RadialGradient(
          center: const Alignment(-0.42, -0.42),
          colors: [
            Colors.white.withValues(alpha: 0.94),
            color.withValues(alpha: 0.17),
            Colors.white.withValues(alpha: 0.60),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _MeCrownBadge extends StatelessWidget {
  final bool active;

  const _MeCrownBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFB490FF),
            Color(0xFF7764F6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AuroraColors.purple.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        active ? Icons.workspace_premium : Icons.workspace_premium_outlined,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

BoxDecoration _meCardDecoration({Color accent = const Color(0xFFBEB7F7)}) {
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.86),
        const Color(0xFFFFF8F4).withValues(alpha: 0.70),
        const Color(0xFFF4F1FF).withValues(alpha: 0.66),
        Color.lerp(accent, const Color(0xFFF1F8FF), 0.78)!
            .withValues(alpha: 0.62),
      ],
      stops: const [0, 0.36, 0.72, 1],
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.86), width: 1),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF7164A8).withValues(alpha: 0.10),
        blurRadius: 30,
        spreadRadius: -14,
        offset: const Offset(0, 15),
      ),
      BoxShadow(
        color: const Color(0xFFFFB17C).withValues(alpha: 0.07),
        blurRadius: 26,
        spreadRadius: -14,
        offset: const Offset(-6, 10),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.90),
        blurRadius: 12,
        spreadRadius: -7,
        offset: const Offset(-4, -4),
      ),
    ],
  );
}

class _ProfileDraft {
  final String displayName;

  const _ProfileDraft({required this.displayName});
}

class _ProfileEditSheet extends StatefulWidget {
  final String displayName;

  const _ProfileEditSheet({
    required this.displayName,
  });

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocaleText.tr(
                  context,
                  en: 'Edit your name',
                  zhHans: '修改用户名',
                  zhHant: '修改使用者名稱',
                  ja: '名前を変更',
                ),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF071D5E),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('me-profile-name-field'),
                controller: _nameController,
                maxLength: 40,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.pop(
                  context,
                  _ProfileDraft(displayName: _nameController.text),
                ),
                decoration: InputDecoration(
                  labelText: AppLocaleText.tr(
                    context,
                    en: 'Name (optional)',
                    zhHans: '称呼（可选）',
                    zhHant: '稱呼（可選）',
                    ja: '名前（任意）',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _ProfileDraft(displayName: _nameController.text),
                  ),
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Save',
                      zhHans: '保存',
                      zhHant: '儲存',
                      ja: '保存',
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
}

class _LifeDirectionDraft {
  final String direction;
  final List<String> focusDomainIds;

  const _LifeDirectionDraft({
    required this.direction,
    required this.focusDomainIds,
  });
}

class _LifeDirectionSettingsPage extends StatefulWidget {
  final String currentDirection;
  final List<String> currentValues;

  const _LifeDirectionSettingsPage({
    required this.currentDirection,
    required this.currentValues,
  });

  @override
  State<_LifeDirectionSettingsPage> createState() =>
      _LifeDirectionSettingsPageState();
}

class _LifeDirectionSettingsPageState
    extends State<_LifeDirectionSettingsPage> {
  late final TextEditingController _directionController;
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _directionController = TextEditingController(text: widget.currentDirection);
    _selected = FocusDomains.normalizeIds(widget.currentValues).toSet();
  }

  @override
  void dispose() {
    _directionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton.filled(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.86),
                        foregroundColor: const Color(0xFF071D5E),
                        minimumSize: const Size(44, 44),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'My life direction',
                        zhHans: '我的人生方向',
                        zhHant: '我的人生方向',
                        ja: '私の人生の方向',
                      ),
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: const Color(0xFF071D5E),
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'Describe the life you want to move toward, then choose the areas you want Signal Path to notice first.',
                        zhHans: '写下你想靠近的生活，再选择希望 Signal Path 优先留意的领域。',
                        zhHant: '寫下你想靠近的生活，再選擇希望 Signal Path 優先留意的領域。',
                        ja: '近づきたい暮らしを書き、Signal Path に優先して見てほしい領域を選びます。',
                      ),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF60749E),
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              key: const ValueKey(
                                'me-life-direction-settings-field',
                              ),
                              controller: _directionController,
                              maxLength: 180,
                              minLines: 3,
                              maxLines: 5,
                              textInputAction: TextInputAction.newline,
                              decoration: InputDecoration(
                                labelText: AppLocaleText.tr(
                                  context,
                                  en: 'Life direction',
                                  zhHans: '人生方向',
                                  zhHant: '人生方向',
                                  ja: '人生の方向',
                                ),
                                hintText: AppLocaleText.tr(
                                  context,
                                  en: 'What kind of life do you want to move toward?',
                                  zhHans: '你想慢慢靠近怎样的生活？',
                                  zhHant: '你想慢慢靠近怎樣的生活？',
                                  ja: 'どんな暮らしに近づきたいですか？',
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Focus areas',
                                zhHans: '关注领域',
                                zhHant: '關注領域',
                                ja: '注目領域',
                              ),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: const Color(0xFF071D5E),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: FocusDomains.options.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                mainAxisExtent: textScale > 1.25 ? 108 : 90,
                              ),
                              itemBuilder: (context, index) {
                                final option = FocusDomains.options[index];
                                final isSelected =
                                    _selected.contains(option.id);
                                return Semantics(
                                  button: true,
                                  selected: isSelected,
                                  label: option.label(context),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => setState(() {
                                      if (isSelected) {
                                        _selected.remove(option.id);
                                      } else {
                                        _selected.add(option.id);
                                      }
                                    }),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? option.color
                                                .withValues(alpha: 0.12)
                                            : Colors.white
                                                .withValues(alpha: 0.62),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? option.color
                                              : Colors.white
                                                  .withValues(alpha: 0.88),
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  option.icon,
                                                  color: isSelected
                                                      ? option.color
                                                      : const Color(0xFF7F8CB7),
                                                  size: 24,
                                                ),
                                                const SizedBox(height: 7),
                                                Text(
                                                  option.label(context),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme.labelLarge
                                                      ?.copyWith(
                                                    color: isSelected
                                                        ? option.color
                                                        : const Color(
                                                            0xFF071D5E),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              top: 1,
                                              right: 1,
                                              child: Icon(
                                                Icons.check_circle_rounded,
                                                color: option.color,
                                                size: 18,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const ValueKey('me-save-life-direction-button'),
                        onPressed: () => Navigator.of(context).pop(
                          _LifeDirectionDraft(
                            direction: _directionController.text.trim(),
                            focusDomainIds: FocusDomains.normalizeIds(
                              _selected.toList(growable: false),
                            ),
                          ),
                        ),
                        child: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Save life direction',
                            zhHans: '保存人生方向',
                            zhHant: '儲存人生方向',
                            ja: '人生の方向を保存',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const AuroraSafeTopMask(),
        ],
      ),
    );
  }
}

String _meErrorLabel(BuildContext context, String? code) {
  return switch (code) {
    'account_delete_failed' => AppLocaleText.tr(
        context,
        en: 'The account could not be deleted. Nothing on this device was cleared; please retry or contact support.',
        zhHans: '账户删除失败，本机数据尚未清除。请重试或联系支持。',
        zhHant: '帳戶刪除失敗，此裝置資料尚未清除。請重試或聯絡支援。',
        ja: 'アカウントを削除できませんでした。端末データは消去されていません。再試行するかサポートへご連絡ください。',
      ),
    'local_delete_failed' => AppLocaleText.tr(
        context,
        en: 'Local data could not be cleared. Please retry.',
        zhHans: '本机数据清除失败，请重试。',
        zhHant: '此裝置資料清除失敗，請重試。',
        ja: '端末データを消去できませんでした。再試行してください。',
      ),
    'profile_photo_too_large' => AppLocaleText.tr(
        context,
        en: 'Please choose a photo under 2 MB.',
        zhHans: '请选择 2 兆字节以下的图片。',
        zhHant: '請選擇 2 兆位元組以下的圖片。',
        ja: '2メガバイト未満の写真を選んでください。',
      ),
    _ => AppLocaleText.tr(
        context,
        en: 'That change could not be saved. Please try again.',
        zhHans: '暂时无法保存，请重试。',
        zhHant: '暫時無法儲存，請重試。',
        ja: '保存できませんでした。再試行してください。',
      ),
  };
}
