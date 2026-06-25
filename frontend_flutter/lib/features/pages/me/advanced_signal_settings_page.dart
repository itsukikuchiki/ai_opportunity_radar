import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/app_dependencies.dart';
import '../../../core/i18n/app_locale_text.dart';
import '../../../core/models/advanced_energy_boundary_models.dart';
import '../../../core/platform/external_energy_platform_service.dart';
import '../../../shared/widgets/aurora_ui.dart';

class AdvancedSignalSettingsPage extends StatefulWidget {
  const AdvancedSignalSettingsPage({super.key});

  @override
  State<AdvancedSignalSettingsPage> createState() =>
      _AdvancedSignalSettingsPageState();
}

class _AdvancedSignalSettingsPageState
    extends State<AdvancedSignalSettingsPage> {
  final ExternalEnergyPlatformService _service =
      const ExternalEnergyPlatformService();

  ExternalEnergyPermissionStatus _calendar =
      ExternalEnergyPermissionStatus.notRequested;
  ExternalEnergyPermissionStatus _health =
      ExternalEnergyPermissionStatus.notRequested;
  bool _loading = true;
  bool _requestingCalendar = false;
  bool _requestingHealth = false;
  Map<String, String> _calendarHints = const {};
  Map<String, String> _healthHints = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final calendar = await _service.calendarPermissionStatus();
    final health = await _service.healthPermissionStatus();
    if (!mounted) return;
    setState(() {
      _calendar = calendar;
      _health = health;
      _loading = false;
    });
  }

  Future<void> _requestCalendar() async {
    final deps = context.read<AppDependencies>();
    setState(() => _requestingCalendar = true);
    final result = await _service.requestCalendarHints();
    await deps.energyBudgetRepository.externalEnergyHintStore
        ?.saveCalendarHints(result.abstractHints);
    if (!mounted) return;
    setState(() {
      _calendar = result.usesInternalEnergyBudgetFallback
          ? _calendar
          : ExternalEnergyPermissionStatus.authorized;
      _calendarHints = result.abstractHints;
      _requestingCalendar = false;
    });
  }

  Future<void> _requestHealth() async {
    final deps = context.read<AppDependencies>();
    setState(() => _requestingHealth = true);
    final result = await _service.requestHealthHints();
    await deps.energyBudgetRepository.externalEnergyHintStore
        ?.saveHealthHints(result.abstractHints);
    if (!mounted) return;
    setState(() {
      _health = result.usesInternalEnergyBudgetFallback
          ? _health
          : ExternalEnergyPermissionStatus.authorized;
      _healthHints = result.abstractHints;
      _requestingHealth = false;
    });
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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
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
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Advanced signal settings',
                            zhHans: '高级线索设置',
                            zhHant: '進階線索設定',
                            ja: '高度なシグナル設定',
                          ),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocaleText.tr(
                            context,
                            en: 'Calendar and Health are optional. They only add abstract hints for Energy Budget; raw details are not shown, uploaded, or sent to Signal Library.',
                            zhHans:
                                '日历和健康都是可选项，只会为 Energy Budget 增加抽象线索；具体日程和健康明细不会展示、上传，也不会进入信号库。',
                            zhHant:
                                '日曆和健康都是可選項，只會為 Energy Budget 增加抽象線索；具體日程和健康明細不會展示、上傳，也不會進入信號庫。',
                            ja: 'カレンダーとヘルスケアは任意です。Energy Budget の抽象的なヒントだけに使い、詳細は表示・アップロード・シグナルライブラリ利用しません。',
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
                      icon: Icons.calendar_month_rounded,
                      color: AuroraColors.blue,
                      title: AppLocaleText.tr(
                        context,
                        en: 'Calendar schedule density',
                        zhHans: '日历密度线索',
                        zhHant: '日曆密度線索',
                        ja: 'カレンダー密度のヒント',
                      ),
                      status: _statusLabel(context, _calendar),
                      body: AppLocaleText.tr(
                        context,
                        en: 'Only busy blocks and density are used. Titles, locations, attendees, and notes do not leave the device.',
                        zhHans: '只使用忙碌区块和密度。标题、地点、参与人和备注不会离开设备。',
                        zhHant: '只使用忙碌區塊和密度。標題、地點、參與人和備註不會離開裝置。',
                        ja: '予定の密度だけを使います。タイトル、場所、参加者、メモは端末外に出ません。',
                      ),
                      loading: _requestingCalendar,
                      hints: _calendarHints,
                      onPressed: _requestCalendar,
                    ),
                    const SizedBox(height: 12),
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
                      status: _statusLabel(context, _health),
                      body: AppLocaleText.tr(
                        context,
                        en: 'Only abstract sleep, movement, and workout recovery hints are used. This is not a score or diagnosis.',
                        zhHans: '只使用睡眠、活动、运动的抽象恢复线索。这不是评分，也不是诊断。',
                        zhHant: '只使用睡眠、活動、運動的抽象恢復線索。這不是評分，也不是診斷。',
                        ja: '睡眠、動き、運動の抽象的な回復ヒントだけを使います。点数や診断ではありません。',
                      ),
                      loading: _requestingHealth,
                      hints: _healthHints,
                      onPressed: _requestHealth,
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

  String _statusLabel(
    BuildContext context,
    ExternalEnergyPermissionStatus status,
  ) {
    switch (status) {
      case ExternalEnergyPermissionStatus.authorized:
        return AppLocaleText.tr(
          context,
          en: 'On',
          zhHans: '已开启',
          zhHant: '已開啟',
          ja: 'オン',
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
  final Map<String, String> hints;
  final VoidCallback onPressed;

  const _PermissionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.status,
    required this.body,
    required this.loading,
    required this.hints,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          FilledButton(
            onPressed: loading ? null : onPressed,
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    AppLocaleText.tr(
                      context,
                      en: 'Enable optional hints',
                      zhHans: '开启可选线索',
                      zhHant: '開啟可選線索',
                      ja: '任意のヒントをオンにする',
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
