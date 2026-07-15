import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/local/external_energy_hint_store.dart';
import '../../../core/models/advanced_energy_boundary_models.dart';
import '../../../core/models/health_recovery_signal_models.dart';
import '../../../core/platform/external_energy_platform_service.dart';
import '../../../shared/widgets/aurora_ui.dart';

enum _HealthNotice {
  loadUnavailable,
  permissionDenied,
  readFailed,
  noData,
  cleared,
  saveFailed,
}

class AdvancedSignalSettingsPage extends StatefulWidget {
  final ExternalEnergyPlatformService service;
  final ExternalEnergyHintStore? hintStore;

  const AdvancedSignalSettingsPage({
    super.key,
    this.service = const ExternalEnergyPlatformService(),
    this.hintStore,
  });

  @override
  State<AdvancedSignalSettingsPage> createState() =>
      _AdvancedSignalSettingsPageState();
}

class _AdvancedSignalSettingsPageState
    extends State<AdvancedSignalSettingsPage> {
  ExternalEnergyPermissionStatus _health =
      ExternalEnergyPermissionStatus.notRequested;
  bool _loading = true;
  bool _requestingHealth = false;
  bool _clearingHealth = false;
  Map<String, String> _healthHints = const {};
  _HealthNotice? _notice;

  ExternalEnergyPlatformService get _service => widget.service;

  ExternalEnergyHintStore? get _hintStore {
    return widget.hintStore ??
        Provider.of<AppDependencies?>(context, listen: false)
            ?.energyBudgetRepository
            .externalEnergyHintStore;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _notice = null;
      });
    }
    try {
      final persistedHints =
          _hintStore?.loadHealthSummary().toAbstractMetadata() ??
              const <String, String>{};
      final health = await _service.healthPermissionStatus();
      if (!mounted) return;
      setState(() {
        _health = health;
        _healthHints = persistedHints;
        _notice = health == ExternalEnergyPermissionStatus.unavailable
            ? _HealthNotice.loadUnavailable
            : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _health = ExternalEnergyPermissionStatus.unavailable;
        _notice = _HealthNotice.loadUnavailable;
        _loading = false;
      });
    }
  }

  Future<void> _requestHealth() async {
    if (_requestingHealth || _clearingHealth) return;
    final store = _hintStore;
    setState(() {
      _requestingHealth = true;
      _notice = null;
    });
    try {
      final result = await _service.requestHealthHints();
      var nextHints = _healthHints;
      if (result.permissionStatus == ExternalEnergyPermissionStatus.denied ||
          result.permissionStatus == ExternalEnergyPermissionStatus.revoked) {
        await store?.clearHealthHints();
        nextHints = const {};
      } else if (result.permissionStatus ==
              ExternalEnergyPermissionStatus.authorized &&
          result.abstractHints.isNotEmpty) {
        await store?.saveHealthHints(result.abstractHints);
        nextHints = result.abstractHints;
      }
      if (!mounted) return;
      setState(() {
        _health = result.permissionStatus;
        _healthHints = nextHints;
        _notice = _noticeFor(result);
        _requestingHealth = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice = _HealthNotice.saveFailed;
        _requestingHealth = false;
      });
    }
  }

  Future<void> _clearHealthHints() async {
    if (_requestingHealth || _clearingHealth) return;
    final store = _hintStore;
    setState(() {
      _clearingHealth = true;
      _notice = null;
    });
    try {
      await store?.clearHealthHints();
      if (!mounted) return;
      setState(() {
        _healthHints = const {};
        _notice = _HealthNotice.cleared;
        _clearingHealth = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notice = _HealthNotice.saveFailed;
        _clearingHealth = false;
      });
    }
  }

  _HealthNotice? _noticeFor(HealthRecoverySignalResult result) {
    switch (result.status) {
      case 'healthkit_recovery_signal_ready':
        return null;
      case 'no_health_data_internal_only':
        return _HealthNotice.noData;
      case 'healthkit_read_failed_internal_only':
        return _HealthNotice.readFailed;
      case 'healthkit_consent_denied_internal_only':
      case 'permission_not_requested_internal_only':
        return _HealthNotice.permissionDenied;
      case 'healthkit_unavailable_internal_only':
      default:
        return _HealthNotice.loadUnavailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          AuroraPage(
            child: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
                children: [
                  _GlassBackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 14),
                  AuroraCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AuroraSectionIcon(
                              icon: Icons.monitor_heart_outlined,
                              color: AuroraColors.mint,
                              size: 42,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppLocaleText.tr(
                                  context,
                                  en: 'Advanced signal settings',
                                  zhHans: '高级线索设置',
                                  zhHant: '進階線索設定',
                                  ja: '高度なシグナル設定',
                                ),
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: AuroraColors.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Health data is optional. It only adds abstract recovery signals for Energy Budget; raw details are not shown, uploaded, or sent to Signal Library.',
                            zhHans:
                                '健康数据是可选项，只会为能量预算增加抽象恢复信号；健康明细不会展示、上传，也不会进入信号库。',
                            zhHant:
                                '健康資料是可選項，只會為能量預算增加抽象恢復信號；健康明細不會展示、上傳，也不會進入信號庫。',
                            ja: 'ヘルスケアデータは任意です。エネルギー予算の抽象的な回復シグナルだけに使い、詳細は表示・アップロード・シグナルライブラリ利用しません。',
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AuroraColors.muted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    _PermissionCard(
                      icon: Icons.favorite_rounded,
                      color: AuroraColors.mint,
                      title: AppLocaleText.tr(
                        context,
                        en: 'Health recovery signals',
                        zhHans: '健康恢复线索',
                        zhHant: '健康恢復線索',
                        ja: 'ヘルスケア回復シグナル',
                      ),
                      status: _statusLabel(
                        context,
                        _health,
                        hasActiveHints: _healthHints.isNotEmpty,
                      ),
                      body: AppLocaleText.tr(
                        context,
                        en: 'Only abstract sleep, movement, and workout recovery hints are used. This is not a score or diagnosis.',
                        zhHans: '只使用睡眠、活动、运动的抽象恢复线索。这不是评分，也不是诊断。',
                        zhHant: '只使用睡眠、活動、運動的抽象恢復線索。這不是評分，也不是診斷。',
                        ja: '睡眠、動き、運動の抽象的な回復ヒントだけを使います。点数や診断ではありません。',
                      ),
                      loading: _requestingHealth,
                      clearing: _clearingHealth,
                      hints: _healthHints,
                      primaryLabel: _healthHints.isEmpty
                          ? AppLocaleText.tr(
                              context,
                              en: 'Enable optional hints',
                              zhHans: '开启可选线索',
                              zhHant: '開啟可選線索',
                              ja: '任意のヒントをオンにする',
                            )
                          : AppLocaleText.tr(
                              context,
                              en: 'Refresh hints',
                              zhHans: '刷新恢复线索',
                              zhHant: '重新整理恢復線索',
                              ja: '回復ヒントを更新',
                            ),
                      onPressed: _requestHealth,
                      onClear: _healthHints.isEmpty ? null : _clearHealthHints,
                    ),
                    if (_notice != null) ...[
                      const SizedBox(height: 12),
                      _HealthNoticeCard(
                        notice: _notice!,
                        onRetry: _notice == _HealthNotice.loadUnavailable
                            ? _load
                            : null,
                      ),
                    ],
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

  String _statusLabel(
    BuildContext context,
    ExternalEnergyPermissionStatus status, {
    required bool hasActiveHints,
  }) {
    if (hasActiveHints) {
      return AppLocaleText.tr(
        context,
        en: 'In use',
        zhHans: '使用中',
        zhHant: '使用中',
        ja: '使用中',
      );
    }
    switch (status) {
      case ExternalEnergyPermissionStatus.authorized:
        return AppLocaleText.tr(
          context,
          en: 'No hints saved',
          zhHans: '未保存线索',
          zhHant: '未儲存線索',
          ja: '保存済みヒントなし',
        );
      case ExternalEnergyPermissionStatus.denied:
      case ExternalEnergyPermissionStatus.revoked:
        return AppLocaleText.tr(
          context,
          en: 'Off',
          zhHans: '未开启',
          zhHant: '未開啟',
          ja: 'オフ',
        );
      case ExternalEnergyPermissionStatus.unavailable:
        return AppLocaleText.tr(
          context,
          en: 'Unavailable',
          zhHans: '暂不可用',
          zhHant: '暫不可用',
          ja: '利用不可',
        );
      case ExternalEnergyPermissionStatus.notRequested:
        return AppLocaleText.tr(
          context,
          en: 'Not enabled yet',
          zhHans: '暂未开启',
          zhHant: '暫未開啟',
          ja: '未設定',
        );
    }
  }
}

class _GlassBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GlassBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('advanced-signals-back'),
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AuroraColors.line.withValues(alpha: 0.74),
              ),
              boxShadow: [
                BoxShadow(
                  color: AuroraColors.purple.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AuroraColors.ink,
              size: 23,
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String status;
  final String body;
  final bool loading;
  final bool clearing;
  final Map<String, String> hints;
  final String primaryLabel;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  const _PermissionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.status,
    required this.body,
    required this.loading,
    required this.clearing,
    required this.hints,
    required this.primaryLabel,
    required this.onPressed,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = loading || clearing;
    return AuroraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuroraSoftIconCircle(icon: icon, color: color, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AuroraChip(
                label: status,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AuroraColors.muted,
              height: 1.42,
            ),
          ),
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final hint in hints.values.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $hint',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AuroraColors.ink,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                key: const ValueKey('advanced-signals-health-enable'),
                onPressed: busy ? null : onPressed,
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(primaryLabel),
              ),
              if (onClear != null)
                OutlinedButton(
                  key: const ValueKey('advanced-signals-health-clear'),
                  onPressed: busy ? null : onClear,
                  child: clearing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Clear saved hints',
                            zhHans: '清除已保存线索',
                            zhHant: '清除已儲存線索',
                            ja: '保存済みヒントを消去',
                          ),
                        ),
                ),
            ],
          ),
          if (onClear != null) ...[
            const SizedBox(height: 10),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Clearing removes these abstract hints from Signal Path. Health access itself is managed in system Settings.',
                zhHans: '清除后，这些抽象线索会从 Signal Path 移除；健康权限请在系统设置中管理。',
                zhHant: '清除後，這些抽象線索會從 Signal Path 移除；健康權限請在系統設定中管理。',
                ja: '消去すると抽象ヒントは Signal Path から削除されます。ヘルスケア権限はシステム設定で管理します。',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AuroraColors.muted,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthNoticeCard extends StatelessWidget {
  final _HealthNotice notice;
  final VoidCallback? onRetry;

  const _HealthNoticeCard({
    required this.notice,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = notice == _HealthNotice.cleared;
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      color: isPositive
          ? AuroraColors.mint.withValues(alpha: 0.10)
          : Colors.white.withValues(alpha: 0.72),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPositive
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            color: isPositive ? AuroraColors.mint : AuroraColors.purple,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _message(context),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.ink,
                    height: 1.42,
                  ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              key: const ValueKey('advanced-signals-health-retry'),
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
        ],
      ),
    );
  }

  String _message(BuildContext context) {
    switch (notice) {
      case _HealthNotice.loadUnavailable:
        return AppLocaleText.tr(
          context,
          en: 'Health recovery hints are unavailable right now. Energy Budget will keep using your own signals.',
          zhHans: '健康恢复线索暂不可用。能量预算会继续使用你自己的信号。',
          zhHant: '健康恢復線索暫不可用。能量預算會繼續使用你自己的信號。',
          ja: 'ヘルスケア回復ヒントは現在利用できません。エネルギー予算は引き続き自分のシグナルを使います。',
        );
      case _HealthNotice.permissionDenied:
        return AppLocaleText.tr(
          context,
          en: 'Health access was not enabled. This is optional, and the rest of Signal Path still works.',
          zhHans: '健康权限未开启。这是可选功能，不影响 Signal Path 的其它功能。',
          zhHant: '健康權限未開啟。這是選用功能，不影響 Signal Path 的其他功能。',
          ja: 'ヘルスケア権限は有効になりませんでした。任意機能なので、Signal Path の他の機能はそのまま使えます。',
        );
      case _HealthNotice.readFailed:
        return AppLocaleText.tr(
          context,
          en: 'Health data could not be read this time. Previously saved hints were kept.',
          zhHans: '这次未能读取健康数据，之前保存的线索仍然保留。',
          zhHant: '這次未能讀取健康資料，之前儲存的線索仍然保留。',
          ja: '今回はヘルスケアデータを読み取れませんでした。以前のヒントは保持されています。',
        );
      case _HealthNotice.noData:
        return AppLocaleText.tr(
          context,
          en: 'No recent recovery data was available. Previously saved hints were kept.',
          zhHans: '暂时没有可用的近期恢复数据，之前保存的线索仍然保留。',
          zhHant: '暫時沒有可用的近期恢復資料，之前儲存的線索仍然保留。',
          ja: '最近の回復データは見つかりませんでした。以前のヒントは保持されています。',
        );
      case _HealthNotice.cleared:
        return AppLocaleText.tr(
          context,
          en: 'Saved recovery hints were removed. Health permission was not changed.',
          zhHans: '已清除保存的恢复线索，系统健康权限没有改变。',
          zhHant: '已清除儲存的恢復線索，系統健康權限沒有改變。',
          ja: '保存済みの回復ヒントを削除しました。ヘルスケア権限は変更していません。',
        );
      case _HealthNotice.saveFailed:
        return AppLocaleText.tr(
          context,
          en: 'The recovery hints could not be updated. Your previous saved state was kept.',
          zhHans: '恢复线索未能更新，之前保存的状态仍然保留。',
          zhHant: '恢復線索未能更新，之前儲存的狀態仍然保留。',
          ja: '回復ヒントを更新できませんでした。以前の保存状態は保持されています。',
        );
    }
  }
}
