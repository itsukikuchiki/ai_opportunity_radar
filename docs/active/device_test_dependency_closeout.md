# 真机测试依赖项收口

更新时间：2026-07-12

## 已完成

### 1. 埋点

已复用现有 `AnalyticsRepository` 和 `/api/v1/analytics/events`，不引入新 SDK。

原则：

- 不记录用户输入正文、语音转写正文、反馈正文。
- 只记录页面入口、动作类型、状态、数量和布尔标记。
- 埋点失败不阻塞主流程。

已覆盖事件：

- `onboarding_completed`
- `onboarding_skipped`
- `today_voice_sheet_opened`
- `today_status_sheet_opened`
- `today_signal_library_opened`
- `ai_judgement_generated`
- `ai_judgement_responded`
- `micro_action_chosen`
- `micro_action_feedback_submitted`
- `life_experiment_feedback_submitted`
- `signal_library_opened`
- `signal_library_category_selected`
- `signal_library_pattern_saved`
- `signal_library_pattern_action`
- `signal_library_pattern_copied`

Retired legacy events are kept only in historical telemetry and are no longer
emitted by the active app: `today_schedule_sheet_opened`,
`today_schedule_feedback_opened`, `schedule_signal_created`,
`schedule_signal_updated`, `schedule_signal_deleted`, and
`schedule_feedback_recorded`.

### 2. 后端接口错误码 / 幂等确认

已完成 captures 主链确认：

- 缺少 `X-User-Id` 返回稳定错误码 `MISSING_USER_ID`。
- SignalCard 不存在返回稳定错误码 `SIGNAL_CARD_NOT_FOUND`。
- captures submit / recent / confirmation / delete / restore 的失败返回 `{code, message}` 结构。
- 前端 `ApiClient` 已解析后端 `{detail: {code, message}}` 为 `ApiException`。
- 首次远端 SignalCard 提交会携带本地 `client_id`。
- retry 继续使用同一个 `client_id`。
- `/api/v1/captures` 接收 `raw_payload_json` 并写入 SignalCard metadata。

已补测试：

- 前端首次提交携带 `client_id`。
- 后端缺用户错误码。
- 后端 SignalCard not found 错误码。
- 后端同一 `client_id` 重复提交只创建一条 SignalCard。
- 后端 source metadata 可落到 SignalCard。

### 3. 设计侧高质量切图替换

当前仓库已有图片资产：

- `assets/onboarding/*`
- `assets/weekly/*`
- `assets/journey/*`
- `assets/me/*`
- brand icon 系列

当前没有发现新的设计导出源文件可替换现有切图，因此本轮未硬改图片资产。

已确认：

- 当前页面可继续使用现有 PNG 资产和代码绘制插画。
- 真正替换高质量切图需要设计侧提供最终导出文件。

最终高质量导出文件、倍率与命名清单尚未提供，因此完整切图替换为
**Target / Pending**，不能在发布记录中标成已完成。

### 4. 插画与 UI 当前口径

当前决定采用“语义 PNG 资产 + 响应式代码布局”的混合方案，不要求把
Onboarding、Today、Weekly、Life Experiment、Journey、Me 全部改成整页 bitmap。

统一规则：

- `docs/active/main_tab_ui_standard.md` 是 Today / Weekly / Life Experiment /
  Journey / Me 的字体、字号、卡片密度、圆角、页面间距和底部安全区标准。
- Today 是主页面视觉密度基准；其它主 tab 不能自行放大 Hero、标题或卡片。
- 四页 Onboarding 使用放大的原始 Signal Path icon 作为背景语义元素，替代旧的
  装饰圆环；四页应保持同一背景语言，但不能让图像遮挡文案或选项。
- Weekly / Journey / Me 可以使用现有页面专属 PNG；Life Experiment 继续使用
  与 Today 一致的卡片语言。插画只承担主题与层级，不承载唯一业务信息。
- 图表、进度格、候选选择状态、按钮与动态文案必须由代码渲染，确保真实数据、
  多语言、Dynamic Type 与窄屏适配；不得烘焙进 bitmap。
- 图片使用 `BoxFit`、裁切和透明度时必须保留主体安全区，并在 `320 x 640`、
  `390 x 844`、`430 x 932`、`768 x 1024` 四档验证无溢出和可点击性。
- 未取得最终设计导出时，现有可用 PNG 不应被临时低清替代；后续替换必须保持
  文件职责与可访问性语义稳定。

真机 UI 关闭条件：

- 首次启动没有白色 Flutter 过渡帧，直接进入 Onboarding 第 1 页。
- Onboarding 四页与五个主 tab 的字号、布局和插画主体均通过真实设备截图。
- Today 动态 Hero、Weekly 当前区块、Journey 当前区块、独立候选页（完成实现后）
  和真实 `X/7` 进度在大字体下不溢出。
- Restore Purchase 当前仍是 reopened blocker；视觉通过不能替代购买链验证。

## 不确定 / 需要确认

1. 埋点平台是否只使用现有后端 `analytics_events`，还是后续还要接 Firebase / App Store Analytics / 第三方产品分析。
2. 埋点事件命名是否需要和商业分析口径统一，例如是否要增加 session id、build number、environment、TestFlight group。
3. 后端错误码是否只先覆盖 captures 主链，还是要继续推广到 `/api/v1/ai/*`、weekly、memory、backup/account。
4. captures 的 `raw_payload_json` 是否允许长期保存所有非正文 metadata，还是需要进一步白名单化字段。
5. 高质量切图需要设计侧提供文件清单、尺寸、倍率和命名规则（Target / Pending）。
6. TestFlight internal build 是否要把埋点事件在 Debug Trace 面板里可视化展示。
