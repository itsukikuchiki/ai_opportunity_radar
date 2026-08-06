import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_router.dart';
import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/local/external_energy_hint_store.dart';
import '../../../core/models/advanced_energy_boundary_models.dart';
import '../../../core/models/health_recovery_signal_models.dart';
import '../../../core/navigation/app_back_navigation.dart';
import '../../../core/platform/external_energy_platform_service.dart';
import '../../../shared/utils/user_visible_text_sanitizer.dart';
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
                    onPressed: () => context.popOrGo(AppRoutes.me),
                  ),
                  const SizedBox(height: 14),
                  AuroraCard(
                    padding: EdgeInsets.zero,
                    child: _LinkageHero(theme: theme),
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
                    _LinkageImpactCard(
                      active: _healthHints.isNotEmpty,
                    ),
                    const SizedBox(height: 14),
                    _PermissionCard(
                      icon: Icons.favorite_rounded,
                      color: AuroraColors.mint,
                      title: AppLocaleText.tr(
                        context,
                        en: 'Health data',
                        zhHans: '健康数据',
                        zhHant: '健康資料',
                        ja: 'ヘルスケアデータ',
                      ),
                      status: _statusLabel(
                        context,
                        _health,
                        hasActiveHints: _healthHints.isNotEmpty,
                      ),
                      body: AppLocaleText.tr(
                        context,
                        en: 'Signal Path reads only summarized sleep, movement, and workout data, then converts it into abstract recovery context. It never writes Health data.',
                        zhHans:
                            'Signal Path 只读取睡眠、活动和运动的汇总数据，再转换成抽象恢复线索；不会写入健康数据。',
                        zhHant:
                            'Signal Path 只讀取睡眠、活動和運動的彙總資料，再轉換成抽象恢復線索；不會寫入健康資料。',
                        ja: 'Signal Path は睡眠・活動・運動の集計データだけを読み取り、抽象的な回復ヒントに変換します。ヘルスケアへの書き込みは行いません。',
                      ),
                      loading: _requestingHealth,
                      clearing: _clearingHealth,
                      hints: _healthHints,
                      permissionStatus: _health,
                      primaryLabel: _healthHints.isEmpty
                          ? AppLocaleText.tr(
                              context,
                              en: 'Connect Health data',
                              zhHans: '连接健康数据',
                              zhHant: '連接健康資料',
                              ja: 'ヘルスケアデータを連携',
                            )
                          : AppLocaleText.tr(
                              context,
                              en: 'Update connected data',
                              zhHans: '更新联动数据',
                              zhHant: '更新聯動資料',
                              ja: '連携データを更新',
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
                    const SizedBox(height: 12),
                    const _PrivacyBoundaryCard(),
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
        en: 'Connected',
        zhHans: '联动中',
        zhHant: '聯動中',
        ja: '連携中',
      );
    }
    switch (status) {
      case ExternalEnergyPermissionStatus.authorized:
        return AppLocaleText.tr(
          context,
          en: 'No recent data',
          zhHans: '暂无近期数据',
          zhHant: '暫無近期資料',
          ja: '最近のデータなし',
        );
      case ExternalEnergyPermissionStatus.denied:
      case ExternalEnergyPermissionStatus.revoked:
        return AppLocaleText.tr(
          context,
          en: 'Permission off',
          zhHans: '权限未开启',
          zhHant: '權限未開啟',
          ja: '権限オフ',
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
          en: 'Not connected',
          zhHans: '尚未联动',
          zhHant: '尚未聯動',
          ja: '未連携',
        );
    }
  }
}

class _LinkageHero extends StatelessWidget {
  final ThemeData theme;

  const _LinkageHero({required this.theme});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 184),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.92),
              const Color(0xFFF2EDFF).withValues(alpha: 0.88),
              const Color(0xFFE9F7F5).withValues(alpha: 0.82),
            ],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 178,
              child: IgnorePointer(
                child: Image(
                  image: AssetImage(
                    'assets/hero_art/weekly-review-network-v1.png',
                  ),
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 112, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AuroraSectionIcon(
                        icon: Icons.hub_rounded,
                        color: AuroraColors.purple,
                        size: 42,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Connected insights',
                            zhHans: '联动',
                            zhHant: '聯動',
                            ja: '連携',
                          ),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AuroraColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Let optional Health context gently inform your daily overview, weekly choices, and experiments.',
                      zhHans: '让可选的健康数据，温和地参与今天概览、每周选择和生活小实验。',
                      zhHant: '讓選用的健康資料，溫和地參與今天概覽、每週選擇和生活小實驗。',
                      ja: '任意のヘルスケア情報を、今日の概要・毎週の選択・生活実験に穏やかに反映します。',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AuroraColors.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AuroraChip(
                    label: AppLocaleText.tr(
                      context,
                      en: 'Optional · Read only',
                      zhHans: '可选 · 仅读取',
                      zhHant: '選用 · 僅讀取',
                      ja: '任意 · 読み取り専用',
                    ),
                    color: AuroraColors.mint,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkageImpactCard extends StatelessWidget {
  final bool active;

  const _LinkageImpactCard({required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AuroraSoftIconCircle(
                icon: Icons.auto_awesome_rounded,
                color: AuroraColors.purple,
                size: 42,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  AppLocaleText.tr(
                    context,
                    en: 'How Health data participates',
                    zhHans: '健康数据如何参与',
                    zhHant: '健康資料如何參與',
                    ja: 'ヘルスケアデータの反映先',
                  ),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AuroraColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AuroraChip(
                label: active
                    ? AppLocaleText.tr(
                        context,
                        en: 'Active',
                        zhHans: '已生效',
                        zhHant: '已生效',
                        ja: '反映中',
                      )
                    : AppLocaleText.tr(
                        context,
                        en: 'Preview',
                        zhHans: '效果预览',
                        zhHant: '效果預覽',
                        ja: 'プレビュー',
                      ),
                color: active ? AuroraColors.mint : AuroraColors.purple,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _LinkageSourceFlow(active: active),
          const SizedBox(height: 14),
          _ImpactTile(
            key: const ValueKey('linked-impact-today'),
            icon: Icons.wb_sunny_outlined,
            color: AuroraColors.orange,
            title: AppLocaleText.tr(
              context,
              en: 'Today overview',
              zhHans: '今天概览',
              zhHant: '今天概覽',
              ja: '今日の概要',
            ),
            body: AppLocaleText.tr(
              context,
              en: 'Adds context to energy, load, and recovery. It supplements your Signals and never decides the status by itself.',
              zhHans: '辅助判断精力、负担和恢复；只补充你的 Signal，不会单独决定状态。',
              zhHant: '輔助判斷精力、負擔和恢復；只補充你的 Signal，不會單獨決定狀態。',
              ja: '活力・負担・回復の判断を補助します。Signal を補うだけで、単独では状態を決めません。',
            ),
          ),
          const SizedBox(height: 10),
          _ImpactTile(
            key: const ValueKey('linked-impact-weekly'),
            icon: Icons.calendar_view_week_rounded,
            color: AuroraColors.blue,
            title: AppLocaleText.tr(
              context,
              en: 'Weekly review',
              zhHans: '每周复盘',
              zhHant: '每週回顧',
              ja: '毎週の振り返り',
            ),
            body: AppLocaleText.tr(
              context,
              en: 'Helps rank lower-load candidates first and informs whether next week should reduce, maintain, or gently increase load.',
              zhHans: '恢复偏低时优先排序低负担候选，并辅助给出下周减量、维持或小幅加量建议。',
              zhHant: '恢復偏低時優先排序低負擔候選，並輔助提出下週減量、維持或小幅加量建議。',
              ja: '回復が低い時は低負担の候補を優先し、翌週の負荷を減らす・維持する・少し増やす判断を補助します。',
            ),
          ),
          const SizedBox(height: 10),
          _ImpactTile(
            key: const ValueKey('linked-impact-experiment'),
            icon: Icons.science_outlined,
            color: AuroraColors.mint,
            title: AppLocaleText.tr(
              context,
              en: 'Life experiments',
              zhHans: '生活小实验',
              zhHant: '生活小實驗',
              ja: '生活実験',
            ),
            body: AppLocaleText.tr(
              context,
              en: 'Helps match experiment and goal candidates to current recovery and load. It never creates or adopts a plan automatically.',
              zhHans: '辅助匹配适合当前恢复与负担的小实验、目标候选；不会自动创建或采纳计划。',
              zhHant: '輔助配對適合目前恢復與負擔的小實驗、目標候選；不會自動建立或採納計畫。',
              ja: '現在の回復と負担に合う実験・目標候補を選びやすくします。自動で作成・採用はしません。',
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkageSourceFlow extends StatelessWidget {
  final bool active;

  const _LinkageSourceFlow({required this.active});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AuroraColors.mint.withValues(alpha: 0.10),
            AuroraColors.purple.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AuroraColors.line.withValues(alpha: 0.78),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SourcePill(
                  icon: Icons.bedtime_outlined,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Sleep',
                    zhHans: '睡眠',
                    zhHant: '睡眠',
                    ja: '睡眠',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SourcePill(
                  icon: Icons.directions_walk_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Movement',
                    zhHans: '活动',
                    zhHant: '活動',
                    ja: '活動',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SourcePill(
                  icon: Icons.fitness_center_rounded,
                  label: AppLocaleText.tr(
                    context,
                    en: 'Workout',
                    zhHans: '运动',
                    zhHant: '運動',
                    ja: '運動',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AuroraColors.purple.withValues(alpha: 0.64),
          ),
          Text(
            active
                ? AppLocaleText.tr(
                    context,
                    en: 'Converted into abstract recovery context',
                    zhHans: '已转换为抽象恢复线索',
                    zhHant: '已轉換為抽象恢復線索',
                    ja: '抽象的な回復ヒントに変換済み',
                  )
                : AppLocaleText.tr(
                    context,
                    en: 'Connect to create abstract recovery context',
                    zhHans: '联动后转换为抽象恢复线索',
                    zhHant: '聯動後轉換為抽象恢復線索',
                    ja: '連携後、抽象的な回復ヒントに変換',
                  ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: active ? AuroraColors.mint : AuroraColors.purple,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourcePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SourcePill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 19, color: AuroraColors.mint),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.fade,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AuroraColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ImpactTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _ImpactTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuroraSoftIconCircle(icon: icon, color: color, size: 38),
          const SizedBox(width: 11),
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
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyBoundaryCard extends StatelessWidget {
  const _PrivacyBoundaryCard();

  @override
  Widget build(BuildContext context) {
    return AuroraCard(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      color: Colors.white.withValues(alpha: 0.70),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_outlined,
            color: AuroraColors.blue,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocaleText.tr(
                context,
                en: 'Abstract Health context is not a Signal, does not increase report thresholds, and is not a score or diagnosis.',
                zhHans: '抽象健康线索不是 Signal，不增加报告门槛，也不是评分或诊断。',
                zhHant: '抽象健康線索不是 Signal，不增加報告門檻，也不是評分或診斷。',
                ja: '抽象的なヘルスケア情報は Signal ではなく、レポート条件に加算されず、評価や診断にも使いません。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.muted,
                    height: 1.42,
                  ),
            ),
          ),
        ],
      ),
    );
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
  final ExternalEnergyPermissionStatus permissionStatus;
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
    required this.permissionStatus,
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
          const SizedBox(height: 12),
          _HealthConnectionState(
            permissionStatus: permissionStatus,
            hasHints: hints.isNotEmpty,
          ),
          if (hints.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              AppLocaleText.tr(
                context,
                en: 'Current connected summary',
                zhHans: '当前联动摘要',
                zhHant: '目前聯動摘要',
                ja: '現在の連携サマリー',
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                color: AuroraColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final hint in hints.values.take(2))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                decoration: BoxDecoration(
                  color: AuroraColors.mint.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 17,
                      color: AuroraColors.mint,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        localizeUserVisibleDynamicText(context, hint),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AuroraColors.ink,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
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
                            en: 'Clear connected data',
                            zhHans: '清除联动数据',
                            zhHant: '清除聯動資料',
                            ja: '連携データを消去',
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
                en: 'Clearing removes the abstract context from Signal Path. Health permission itself remains managed in system Settings.',
                zhHans: '清除后，抽象恢复线索会从 Signal Path 移除；健康权限仍由系统设置管理。',
                zhHant: '清除後，抽象恢復線索會從 Signal Path 移除；健康權限仍由系統設定管理。',
                ja: '消去すると抽象的な回復情報は Signal Path から削除されます。ヘルスケア権限はシステム設定で管理します。',
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

class _HealthConnectionState extends StatelessWidget {
  final ExternalEnergyPermissionStatus permissionStatus;
  final bool hasHints;

  const _HealthConnectionState({
    required this.permissionStatus,
    required this.hasHints,
  });

  @override
  Widget build(BuildContext context) {
    final active = hasHints;
    final color = active
        ? AuroraColors.mint
        : permissionStatus == ExternalEnergyPermissionStatus.unavailable
            ? AuroraColors.orange
            : AuroraColors.blue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            active
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _message(context),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AuroraColors.ink,
                    height: 1.38,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  String _message(BuildContext context) {
    if (hasHints) {
      return AppLocaleText.tr(
        context,
        en: 'Recent Health summaries are connected as abstract recovery context.',
        zhHans: '近期健康汇总已转换为抽象恢复线索并参与联动。',
        zhHant: '近期健康彙總已轉換為抽象恢復線索並參與聯動。',
        ja: '最近のヘルスケア集計が抽象的な回復情報として連携されています。',
      );
    }
    switch (permissionStatus) {
      case ExternalEnergyPermissionStatus.authorized:
        return AppLocaleText.tr(
          context,
          en: 'Permission is enabled, but no recent Health data is available. Signal Path will keep using your own Signals.',
          zhHans: '权限已开启，但暂无近期健康数据；Signal Path 会继续使用你自己的 Signal。',
          zhHant: '權限已開啟，但暫無近期健康資料；Signal Path 會繼續使用你自己的 Signal。',
          ja: '権限は有効ですが、最近のデータがありません。Signal Path は自分の Signal を引き続き使います。',
        );
      case ExternalEnergyPermissionStatus.denied:
      case ExternalEnergyPermissionStatus.revoked:
        return AppLocaleText.tr(
          context,
          en: 'Health permission is off. Linking is optional and all recording and review features remain available.',
          zhHans: '健康权限未开启。联动是可选功能，不影响记录、复盘和生活小实验。',
          zhHant: '健康權限未開啟。聯動是選用功能，不影響記錄、回顧和生活小實驗。',
          ja: 'ヘルスケア権限はオフです。連携は任意で、記録・振り返り・生活実験はそのまま使えます。',
        );
      case ExternalEnergyPermissionStatus.unavailable:
        return AppLocaleText.tr(
          context,
          en: 'Health data cannot be read on this device right now. Signal Path still works without it.',
          zhHans: '这台设备目前无法读取健康数据；不联动也可以正常使用 Signal Path。',
          zhHant: '這台裝置目前無法讀取健康資料；不聯動也可以正常使用 Signal Path。',
          ja: 'この端末では現在ヘルスケアデータを読み取れません。連携なしでも Signal Path は使えます。',
        );
      case ExternalEnergyPermissionStatus.notRequested:
        return AppLocaleText.tr(
          context,
          en: 'Health permission has not been requested. Connect only if you want this extra context.',
          zhHans: '尚未请求健康权限。只有希望增加这层参考时才需要联动。',
          zhHant: '尚未要求健康權限。只有希望增加這層參考時才需要聯動。',
          ja: 'ヘルスケア権限はまだ要求していません。この追加情報が必要な場合だけ連携してください。',
        );
    }
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
          en: 'Health data is unavailable right now. Signal Path will keep using your own Signals.',
          zhHans: '健康数据暂不可用。Signal Path 会继续使用你自己的 Signal。',
          zhHant: '健康資料暫不可用。Signal Path 會繼續使用你自己的 Signal。',
          ja: 'ヘルスケアデータは現在利用できません。Signal Path は自分の Signal を引き続き使います。',
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
          en: 'Health data could not be read this time. Previous connected context was kept.',
          zhHans: '这次未能读取健康数据，之前的联动线索仍然保留。',
          zhHant: '這次未能讀取健康資料，之前的聯動線索仍然保留。',
          ja: '今回はヘルスケアデータを読み取れませんでした。以前の連携情報は保持されています。',
        );
      case _HealthNotice.noData:
        return AppLocaleText.tr(
          context,
          en: 'No recent Health data was available. Previous connected context was kept.',
          zhHans: '暂时没有可用的近期健康数据，之前的联动线索仍然保留。',
          zhHant: '暫時沒有可用的近期健康資料，之前的聯動線索仍然保留。',
          ja: '最近のヘルスケアデータは見つかりませんでした。以前の連携情報は保持されています。',
        );
      case _HealthNotice.cleared:
        return AppLocaleText.tr(
          context,
          en: 'Connected Health context was removed. System Health permission was not changed.',
          zhHans: '已清除联动的健康线索，系统健康权限没有改变。',
          zhHant: '已清除聯動的健康線索，系統健康權限沒有改變。',
          ja: '連携したヘルスケア情報を削除しました。システムの権限は変更していません。',
        );
      case _HealthNotice.saveFailed:
        return AppLocaleText.tr(
          context,
          en: 'Connected Health context could not be updated. The previous state was kept.',
          zhHans: '联动的健康线索未能更新，之前的状态仍然保留。',
          zhHant: '聯動的健康線索未能更新，之前的狀態仍然保留。',
          ja: '連携したヘルスケア情報を更新できませんでした。以前の状態は保持されています。',
        );
    }
  }
}
