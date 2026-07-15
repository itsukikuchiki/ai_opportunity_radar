import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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

  static final Uri _privacyPolicyUri = Uri.parse(
    'https://itsukikuchiki.github.io/signalpath-support/',
  );
  static final Uri _supportUri = Uri.parse(
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
                key: const ValueKey('me-scroll-view'),
                padding: AuroraMainPageSpec.scrollPadding(context),
                children: [
                  _MeHeroHeader(vm: vm),
                  const SizedBox(height: AuroraMainPageSpec.heroGap),
                  if (vm.loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _LifeDirectionCard(
                      vm: vm,
                      onEdit: vm.saving
                          ? null
                          : () => _showProfileSheet(context, vm),
                    ),
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                    _FocusDomainsCard(
                      selectedIds: vm.selectedFocusDomainIds,
                      onTap: vm.saving
                          ? null
                          : () => _showFocusAreaSheet(context, vm),
                    ),
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  ],
                  _PremiumStatusCard(purchase: purchase, vm: vm),
                  if (vm.usageLoading ||
                      vm.usageLoadFailed ||
                      !vm.usageMatchesLocalEntitlement(
                        purchase?.isPremium ?? false,
                      )) ...[
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                    _UsageSyncCard(
                      vm: vm,
                      localPremium: purchase?.isPremium ?? false,
                    ),
                  ] else if (vm.usageQuotas.isNotEmpty) ...[
                    const SizedBox(height: AuroraMainPageSpec.sectionGap),
                    _MonthlyUsageCard(
                      quotas: vm.usageQuotas.values.toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  _MePreferenceSection(
                    selectedResponseStyle: vm.selectedResponseStyle,
                    onOpenSelfReview: () => context.push(AppRoutes.selfReview),
                    onOpenResponseStyle: vm.saving
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
                  const SizedBox(height: AuroraMainPageSpec.sectionGap),
                  _MeDataSection(
                    onOpenAdvancedSignals: () =>
                        context.push(AppRoutes.advancedSignals),
                    onOpenPrivacy: () => _openPrivacyPolicy(context),
                    onOpenSupport: () => _openSupport(context),
                    onDeleteData: vm.deletingData
                        ? null
                        : () => _confirmDeleteData(context, vm),
                    hasCloudAccount: vm.hasCloudAccount,
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
        direction: vm.lifeDirection ?? '',
      ),
    );
    if (draft == null) return;
    final success = await vm.updateProfile(
      displayName: draft.displayName,
      direction: draft.direction,
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

  Future<void> _showFocusAreaSheet(BuildContext context, MeViewModel vm) async {
    final selected = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => _FocusAreaSettingsPage(
          currentValues: vm.selectedFocusDomainIds,
        ),
      ),
    );

    if (selected == null) return;

    final success = await vm.updateFocusDomains(selected);
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

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    try {
      final opened = await launchUrl(
        _privacyPolicyUri,
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
            en: 'Could not open the privacy page.',
            zhHans: '暂时无法打开隐私页面。',
            zhHant: '暫時無法打開隱私頁面。',
            ja: 'プライバシーページを開けませんでした。',
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
            zhHans: '此操作无法撤销。StoreKit 购买权益仍由 Apple 单独管理。',
            zhHant: '此操作無法撤銷。StoreKit 購買權益仍由 Apple 單獨管理。',
            ja: 'この操作は取り消せません。StoreKit の購入権利は Apple が別途管理します。',
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

  const _MeHeroHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const ValueKey('me-hero-header'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.textScalerOf(context).scale(14) > 20
            ? double.infinity
            : 170,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -14,
            top: -30,
            child: IgnorePointer(
              child: AuroraHeroEmblem(
                size: MediaQuery.sizeOf(context).width <
                        AuroraMainPageSpec.compactBreakpoint
                    ? 116
                    : 138,
                opacity: 0.62,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 92),
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF5487F4),
                      Color(0xFF806AF4),
                      Color(0xFF9A63E8),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Me',
                      zhHans: '我的',
                      zhHant: '我的',
                      ja: '私',
                    ),
                    key: const ValueKey('me-hero-title'),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontSize: AuroraMainPageSpec.responsiveHeroTitleSize(
                              context),
                          fontWeight: FontWeight.w700,
                          height: 1,
                          letterSpacing: -0.25,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 54),
                child: _MeProfileIntro(vm: vm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeProfileIntro extends StatelessWidget {
  final MeViewModel vm;

  const _MeProfileIntro({required this.vm});

  @override
  Widget build(BuildContext context) {
    final photoPath = vm.profilePhotoPath;
    return Row(
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
              Text(
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF071D5E),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
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
                maxLines: 2,
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
              zhHans: '照片太大了，请选择 2 MB 以下的图片。',
              zhHant: '照片太大了，請選擇 2 MB 以下的圖片。',
              ja: '写真が大きすぎます。2MB 未満の画像を選んでください。',
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

class _LifeDirectionCard extends StatelessWidget {
  final MeViewModel vm;
  final VoidCallback? onEdit;

  const _LifeDirectionCard({required this.vm, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('me-life-direction-card'),
      constraints: const BoxConstraints(minHeight: 158),
      decoration: _meCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Opacity(
                opacity: 0.82,
                child: Image.asset(
                  'assets/me/me-direction-landscape.png',
                  width: 190,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.98),
                    Colors.white.withValues(alpha: 0.84),
                    Colors.white.withValues(alpha: 0.24),
                  ],
                  stops: const [0, 0.58, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF071D5E),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AuroraColors.purple.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        vm.lifeDirection == null
                            ? AppLocaleText.tr(
                                context,
                                en: 'Not set',
                                zhHans: '未设置',
                                zhHant: '未設定',
                                ja: '未設定',
                              )
                            : AppLocaleText.tr(
                                context,
                                en: 'Active',
                                zhHans: '进行中',
                                zhHant: '進行中',
                                ja: '進行中',
                              ),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AuroraColors.purple,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  vm.lifeDirection ??
                      AppLocaleText.tr(
                        context,
                        en: 'No life direction has been set yet.',
                        zhHans: '还没有设置人生方向。',
                        zhHant: '還沒有設定人生方向。',
                        ja: '人生の方向はまだ設定されていません。',
                      ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF071D5E),
                        fontSize: AuroraMainPageSpec.bodySize,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      vm.lifeDirectionCreatedAt == null
                          ? Icons.edit_outlined
                          : Icons.calendar_month_outlined,
                      color: const Color(0xFF7F8CB7),
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        vm.lifeDirectionCreatedAt == null
                            ? AppLocaleText.tr(
                                context,
                                en: 'Tap to add your own words',
                                zhHans: '用自己的话写下来',
                                zhHant: '用自己的話寫下來',
                                ja: '自分の言葉で追加',
                              )
                            : MaterialLocalizations.of(context).formatFullDate(
                                vm.lifeDirectionCreatedAt!.toLocal(),
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF7F8CB7),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocaleText.tr(
                        context,
                        en: 'Edit',
                        zhHans: '编辑',
                        zhHant: '編輯',
                        ja: '編集',
                      ),
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 19),
                      color: AuroraColors.purple,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusDomainsCard extends StatelessWidget {
  final List<String> selectedIds;
  final VoidCallback? onTap;

  const _FocusDomainsCard({
    required this.selectedIds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = FocusDomains.normalizeIds(selectedIds);
    final visibleIds = normalized.take(3).toList();
    final hiddenCount = normalized.length - visibleIds.length;

    return Container(
      decoration: _meCardDecoration(),
      padding: AuroraMainPageSpec.comfortableCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _MeRoundedIcon(
                icon: Icons.tune_rounded,
                color: AuroraColors.purple,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'My focus areas',
                        zhHans: '我的关注重点',
                        zhHant: '我的關注重點',
                        ja: '私の注目領域',
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: const Color(0xFF071D5E),
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppLocaleText.tr(
                        context,
                        en: 'These areas guide AI ranking; they never hide other records. Without an account, they stay on this device.',
                        zhHans: '这些领域只影响 AI 的优先理解，不会隐藏其他记录。未登录账户时仅保存在本机。',
                        zhHant: '這些領域只影響 AI 的優先理解，不會隱藏其他記錄。未登入帳戶時只保存在本機。',
                        ja: 'これらは AI の優先順位だけに影響し、他の記録を隠しません。アカウント未設定時はこの端末だけに保存されます。',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF6E7FA9),
                            fontSize: AuroraMainPageSpec.bodySize,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  foregroundColor: AuroraColors.purple,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      normalized.isEmpty
                          ? AppLocaleText.tr(
                              context,
                              en: 'Set',
                              zhHans: '去设置',
                              zhHant: '去設定',
                              ja: '設定',
                            )
                          : AppLocaleText.tr(
                              context,
                              en: 'Edit',
                              zhHans: '调整',
                              zhHant: '調整',
                              ja: '調整',
                            ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AuroraColors.purple,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (normalized.isEmpty)
            Text(
              AppLocaleText.tr(
                context,
                en: 'No focus areas selected yet.',
                zhHans: '还没有选择关注重点',
                zhHant: '還沒有選擇關注重點',
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
  final VoidCallback onOpenAdvancedSignals;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenSupport;
  final VoidCallback? onDeleteData;
  final bool hasCloudAccount;

  const _MeDataSection({
    required this.onOpenAdvancedSignals,
    required this.onOpenPrivacy,
    required this.onOpenSupport,
    required this.onDeleteData,
    required this.hasCloudAccount,
  });

  @override
  Widget build(BuildContext context) {
    return _MeListCard(
      title: AppLocaleText.tr(
        context,
        en: 'Data and privacy',
        zhHans: '数据与隐私',
        zhHant: '資料與隱私',
        ja: 'データとプライバシー',
      ),
      rows: [
        _MeListRowData(
          icon: Icons.monitor_heart_outlined,
          iconColor: const Color(0xFF59BFA5),
          title: AppLocaleText.tr(
            context,
            en: 'Advanced signals',
            zhHans: '高级信号',
            zhHant: '進階信號',
            ja: '高度なシグナル',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Manage abstract energy and recovery hints',
            zhHans: '管理能量与恢复的抽象提示',
            zhHant: '管理能量與恢復的抽象提示',
            ja: 'エネルギーと回復の抽象ヒントを管理',
          ),
          onTap: onOpenAdvancedSignals,
        ),
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
            en: 'Restore-purchase help and contact information',
            zhHans: '恢复购买帮助与联系方式',
            zhHant: '恢復購買協助與聯絡方式',
            ja: '購入復元のヘルプと連絡先',
          ),
          onTap: onOpenSupport,
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

class _MePreferenceSection extends StatelessWidget {
  final String? selectedResponseStyle;
  final VoidCallback onOpenSelfReview;
  final VoidCallback? onOpenResponseStyle;

  const _MePreferenceSection({
    required this.selectedResponseStyle,
    required this.onOpenSelfReview,
    required this.onOpenResponseStyle,
  });

  @override
  Widget build(BuildContext context) {
    return _MeListCard(
      title: AppLocaleText.tr(
        context,
        en: 'Reflection and AI',
        zhHans: '复盘与 AI',
        zhHant: '復盤與 AI',
        ja: '振り返りと AI',
      ),
      rows: [
        _MeListRowData(
          icon: Icons.auto_stories_outlined,
          iconColor: const Color(0xFF5E8DF5),
          title: AppLocaleText.tr(
            context,
            en: 'Structured self-review',
            zhHans: '结构化自我复盘',
            zhHant: '結構化自我復盤',
            ja: '構造化セルフレビュー',
          ),
          subtitle: AppLocaleText.tr(
            context,
            en: 'Turn signals into an evidence-based reflection',
            zhHans: '把信号整理成有证据的回看',
            zhHant: '把信號整理成有證據的回看',
            ja: 'シグナルを根拠のある振り返りに整理',
          ),
          onTap: onOpenSelfReview,
        ),
        _MeListRowData(
          icon: Icons.auto_awesome_rounded,
          iconColor: AuroraColors.purple,
          title: AppLocaleText.tr(
            context,
            en: 'AI response style',
            zhHans: 'AI 回应风格',
            zhHant: 'AI 回應風格',
            ja: 'AI の返答スタイル',
          ),
          subtitle: _responseStyleLabel(context, selectedResponseStyle),
          onTap: onOpenResponseStyle,
        ),
      ],
    );
  }
}

String _responseStyleLabel(BuildContext context, String? value) {
  return switch (value) {
    'clear' => AppLocaleText.tr(
        context,
        en: 'Clear · structured and to the point',
        zhHans: '清晰 · 更有结构，更快到重点',
        zhHant: '清晰 · 更有結構，更快到重點',
        ja: 'クリア · 整理されていて要点が早い',
      ),
    'direct' => AppLocaleText.tr(
        context,
        en: 'Direct · shorter and sharper',
        zhHans: '直接 · 更短，更直接',
        zhHant: '直接 · 更短，更直接',
        ja: '率直 · 短く率直',
      ),
    _ => AppLocaleText.tr(
        context,
        en: 'Gentle · softer and companion-like',
        zhHans: '温和 · 更柔和、更像陪伴',
        zhHant: '溫和 · 更柔和、更像陪伴',
        ja: 'やわらかめ · やさしく寄り添う',
      ),
  };
}

class _MeDebugSection extends StatelessWidget {
  const _MeDebugSection();

  @override
  Widget build(BuildContext context) {
    return _MeListCard(
      title: 'Developer',
      rows: [
        _MeListRowData(
          icon: Icons.account_tree_rounded,
          iconColor: AuroraColors.purple,
          title: 'Trace / Debug',
          subtitle: 'Inspect Signal -> Weekly / Journey / Experiment',
          onTap: () => context.push(AppRoutes.debugTrace),
        ),
      ],
    );
  }
}

class _MeListCard extends StatelessWidget {
  final String title;
  final List<_MeListRowData> rows;

  const _MeListCard({
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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

class _PremiumStatusCard extends StatelessWidget {
  final PurchaseController? purchase;
  final MeViewModel vm;

  const _PremiumStatusCard({
    required this.purchase,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = purchase?.isPremium ?? false;
    final loading = purchase?.loading ?? false;
    final verificationPending =
        purchase?.entitlementReconciliationPending ?? false;
    final reflectQuota = vm.usageQuotas['l3_reflect_weekly'];

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showPremiumPaywall(context, source: 'Pro'),
      child: Container(
        decoration: _meCardDecoration(accent: const Color(0xFF9B78F8)),
        padding: AuroraMainPageSpec.comfortableCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                                zhHans: '正在确认 Pro 状态',
                                zhHant: '正在確認 Pro 狀態',
                                ja: 'Pro 状態を確認中',
                              )
                            : isPremium
                                ? AppLocaleText.tr(
                                    context,
                                    en: 'Signal Path Pro',
                                    zhHans: 'Signal Path Pro',
                                    zhHant: 'Signal Path Pro',
                                    ja: 'Signal Path Pro',
                                  )
                                : AppLocaleText.tr(
                                    context,
                                    en: 'Upgrade to Pro',
                                    zhHans: '升级到 Pro',
                                    zhHant: '升級到 Pro',
                                    ja: 'Pro にアップグレード',
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
                                    en: 'Unlock deeper weekly, journey and self-review insights',
                                    zhHans: '解锁每周、旅程与自我复盘的深度洞察',
                                    zhHant: '解鎖每週、旅程與自我復盤的深度洞察',
                                    ja: '週・旅程・セルフレビューの深い洞察を解放',
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
                  Text(
                    isPremium
                        ? 'PRO'
                        : AppLocaleText.tr(
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
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AuroraColors.purple,
                    size: 21,
                  ),
                ],
              ],
            ),
            if (!loading && !isPremium && reflectQuota != null)
              _ReflectQuotaSummary(quota: reflectQuota),
          ],
        ),
      ),
    );
  }
}

class _ReflectQuotaSummary extends StatelessWidget {
  final UsageQuotaViewData quota;

  const _ReflectQuotaSummary({required this.quota});

  @override
  Widget build(BuildContext context) {
    final limit = quota.limit;
    final progress = limit == null || limit <= 0
        ? null
        : (quota.used / limit).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.68),
                valueColor: const AlwaysStoppedAnimation(AuroraColors.purple),
              ),
            ),
            const SizedBox(height: 7),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'L3 Reflect quota',
                    zhHans: '深度分析额度',
                    zhHant: 'L3 深度反思額度',
                    ja: 'L3 Reflect 枠',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF7F8CB7),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                quota.displayValue,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AuroraColors.purple,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsageSyncCard extends StatelessWidget {
  final MeViewModel vm;
  final bool localPremium;

  const _UsageSyncCard({required this.vm, required this.localPremium});

  @override
  Widget build(BuildContext context) {
    final mismatch = !vm.usageMatchesLocalEntitlement(localPremium);
    return Container(
      key: const ValueKey('me-usage-sync-state'),
      decoration: _meCardDecoration(accent: const Color(0xFF76A9F8)),
      padding: AuroraMainPageSpec.comfortableCardPadding,
      child: Row(
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
                              zhHans: 'Pro 已解锁，用量正在对账',
                              zhHant: 'Pro 已解鎖，用量正在對帳',
                              ja: 'Pro は解除済み、利用状況を照合中',
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
      ),
    );
  }
}

class _MonthlyUsageCard extends StatelessWidget {
  final List<UsageQuotaViewData> quotas;

  const _MonthlyUsageCard({required this.quotas});

  @override
  Widget build(BuildContext context) {
    final visibleQuotas = quotas
        .where((quota) => quota.featureKey.trim().isNotEmpty)
        .take(4)
        .toList(growable: false);
    if (visibleQuotas.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: _meCardDecoration(),
      padding: AuroraMainPageSpec.comfortableCardPadding,
      child: Column(
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
          for (var index = 0; index < visibleQuotas.length; index++) ...[
            _MonthlyUsageRow(quota: visibleQuotas[index]),
            if (index < visibleQuotas.length - 1)
              Divider(
                height: 18,
                color: const Color(0xFFE2E5F3).withValues(alpha: 0.72),
              ),
          ],
        ],
      ),
    );
  }
}

class _MonthlyUsageRow extends StatelessWidget {
  final UsageQuotaViewData quota;

  const _MonthlyUsageRow({required this.quota});

  @override
  Widget build(BuildContext context) {
    final limit = quota.limit;
    final progress =
        limit == null || limit <= 0 ? null : (quota.used / limit).clamp(0, 1);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _usageFeatureLabel(context, quota.featureKey),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF071D5E),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: progress.toDouble(),
                    backgroundColor:
                        AuroraColors.purple.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation(
                      AuroraColors.purple,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 14),
        Text(
          quota.displayValue,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AuroraColors.purple,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
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
        zhHans: '判断 AI',
        zhHant: '判斷 AI',
        ja: '判断 AI',
      ),
    'l3_reflect_weekly' => AppLocaleText.tr(
        context,
        en: 'Weekly Reflect',
        zhHans: '每周复盘深度分析',
        zhHant: 'Weekly 深度反思',
        ja: 'Weekly Reflect',
      ),
    'l3_reflect_journey' => AppLocaleText.tr(
        context,
        en: 'Journey Reflect',
        zhHans: '旅程深度分析',
        zhHant: 'Journey 深度反思',
        ja: 'Journey Reflect',
      ),
    _ => featureKey.replaceAll('_', ' '),
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
  final String direction;

  const _ProfileDraft({required this.displayName, required this.direction});
}

class _ProfileEditSheet extends StatefulWidget {
  final String displayName;
  final String direction;

  const _ProfileEditSheet({
    required this.displayName,
    required this.direction,
  });

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _directionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.displayName);
    _directionController = TextEditingController(text: widget.direction);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _directionController.dispose();
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
                  en: 'Your profile',
                  zhHans: '你的资料',
                  zhHant: '你的資料',
                  ja: 'プロフィール',
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
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('me-life-direction-field'),
                controller: _directionController,
                maxLength: 180,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: AppLocaleText.tr(
                    context,
                    en: 'Life direction (optional)',
                    zhHans: '人生方向（可选）',
                    zhHant: '人生方向（可選）',
                    ja: '人生の方向（任意）',
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _ProfileDraft(
                      displayName: _nameController.text,
                      direction: _directionController.text,
                    ),
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

class _FocusAreaSettingsPage extends StatelessWidget {
  final List<String> currentValues;

  const _FocusAreaSettingsPage({
    required this.currentValues,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = FocusDomains.normalizeIds(currentValues);

    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: true,
              child: StatefulBuilder(
                builder: (context, setPageState) {
                  final selected = initial.toSet();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton.filled(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.86),
                            foregroundColor: const Color(0xFF071D5E),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Change focus areas',
                            zhHans: '修改关注重点',
                            zhHant: '修改關注重點',
                            ja: '注目領域を変更する',
                          ),
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: const Color(0xFF071D5E),
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Choose the life areas you want AI to notice first. You can pick more than one.',
                            zhHans: '选择你希望 AI 优先留意的生活领域，可以多选。',
                            zhHant: '選擇你希望 AI 優先留意的生活領域，可以多選。',
                            ja: 'AIに先に見てほしい生活領域を選べます。複数選択できます。',
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF60749E),
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final textScale =
                                  MediaQuery.textScalerOf(context).scale(14) /
                                      14;
                              final columns =
                                  constraints.maxWidth < 330 || textScale > 1.35
                                      ? 2
                                      : 3;
                              return GridView.builder(
                                itemCount: FocusDomains.options.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  mainAxisExtent: textScale > 1.35 ? 104 : 88,
                                ),
                                itemBuilder: (context, index) {
                                  final option = FocusDomains.options[index];
                                  final isSelected =
                                      selected.contains(option.id);
                                  return Semantics(
                                    button: true,
                                    selected: isSelected,
                                    label: option.label(context),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () {
                                        setPageState(() {
                                          if (isSelected) {
                                            initial.remove(option.id);
                                          } else {
                                            initial.add(option.id);
                                          }
                                        });
                                      },
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
                                          borderRadius:
                                              BorderRadius.circular(16),
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
                                                        : const Color(
                                                            0xFF7F8CB7),
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
                                                      fontWeight:
                                                          FontWeight.w700,
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
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(initial),
                            child: Text(
                              AppLocaleText.tr(
                                context,
                                en: 'Save focus areas',
                                zhHans: '保存关注重点',
                                zhHant: '保存關注重點',
                                ja: '注目領域を保存',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const AuroraSafeTopMask(),
        ],
      ),
    );
  }
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
        zhHans: '请选择 2 MB 以下的图片。',
        zhHant: '請選擇 2 MB 以下的圖片。',
        ja: '2MB 未満の写真を選んでください。',
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
