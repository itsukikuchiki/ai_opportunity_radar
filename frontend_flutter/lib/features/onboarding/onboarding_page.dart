import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/app_router.dart';
import 'onboarding_view_model.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('欢迎使用'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Opportunity Radar',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '你不需要每天写报告，也不需要整理复杂表格。\n'
                '只要随手记录那些让你觉得麻烦、重复、卡住、想省力的瞬间，\n'
                '系统就会逐渐帮你发现：哪些事情值得交给 AI 或自动化。',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),

              _SectionTitle(title: '这类产品适合你吗？'),
              const SizedBox(height: 8),
              const _BulletText(text: '经常觉得很多小事很碎，但说不清哪里最耗时间'),
              const _BulletText(text: '反复在整理信息、改计划、写表达之间切换'),
              const _BulletText(text: '想找到适合自己的 AI 用法，而不是只看别人教程'),

              const SizedBox(height: 24),
              _SectionTitle(title: '最近最常重复的场景'),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: vm.selectedRepeatArea,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '请选择一个最接近的场景',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'information_gathering',
                    child: Text('整理资料 / 找信息'),
                  ),
                  DropdownMenuItem(
                    value: 'scheduling',
                    child: Text('排时间 / 改计划'),
                  ),
                  DropdownMenuItem(
                    value: 'writing',
                    child: Text('写东西 / 组织表达'),
                  ),
                ],
                onChanged: vm.submitting
                    ? null
                    : (value) {
                        if (value != null) {
                          vm.updateRepeatArea(value);
                        }
                      },
              ),

              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _helperText(vm.selectedRepeatArea),
                  style: theme.textTheme.bodyMedium,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: vm.submitting
                      ? null
                      : () async {
                          try {
                            await vm.complete();
                            if (context.mounted) {
                              context.go(AppRoutes.today);
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('提交失败：$e'),
                              ),
                            );
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(vm.submitting ? '提交中...' : '开始使用'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '之后你就可以开始随手记录日常片段了。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _helperText(String? value) {
    switch (value) {
      case 'information_gathering':
        return '你可能适合从“资料整理、信息汇总、找链接、找规则”这类场景开始记录。';
      case 'scheduling':
        return '你可能适合从“排期、改约、任务先后顺序、时间冲突”这类场景开始记录。';
      case 'writing':
        return '你可能适合从“写消息、写文案、整理表达、改措辞”这类场景开始记录。';
      default:
        return '先选一个最接近你的重复场景，系统会据此调整最初的观察重点。';
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;

  const _BulletText({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
