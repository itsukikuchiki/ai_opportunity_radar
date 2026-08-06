# Main Tab UI Standard

Last updated: 2026-07-28

Today is the visual-density reference for the five primary tabs: Today,
Weekly, Life Experiment, Journey, and Me. Page-specific illustrations and
content remain distinct, but typography and region sizing follow one contract.

Today's hero represents Signal input. Weekly follows the same dimensions and
typographic hierarchy but uses its own review-loop relationship pattern: seven
local-day nodes connected by one continuous returning path, expressing Signal
facts -> repeated pattern -> attempt results -> the next recording cycle.
Neither Weekly nor its owned secondary surfaces may use the application icon or
a generic feature icon as the hero illustration.

The five related hero motifs form one visual family: Today gathers glowing
Signal points; Weekly connects them into a review loop; Life Experiment lets
them branch into possible changes; Journey turns them into a path around its
ring; Me uses a soft Aurora path/landscape to represent personal direction.
Me keeps the same hero bounds, title hierarchy, card radius, and background
continuity as the other tabs instead of opening with a plain settings header.
Its edit pencil is attached to the user name and never doubles as a whole-profile
editor.

| Token | Standard |
| --- | --- |
| Page padding | 18 horizontal, 14 top |
| Bottom navigation clearance | device safe area + 96 |
| Hero title | 36, or 34 below 360-point width |
| Hero/supporting copy | 13.5–14 |
| Hero-to-first-section gap | 14 |
| Section gap | 10 |
| Primary card radius | 18–20 |
| Primary card padding | 12–16 |
| Section title | 16–17 |
| Body copy | 13.5–14 |
| Supporting copy | 10.5–12.5 |

All five tabs use the application `SF Pro Text` family. A feature page must not
introduce a decorative font for its primary title. Complex content may retain
the height needed for legibility, and cards may grow when Dynamic Type is
enlarged; fixed-height regions must not clip or overflow accessibility text.

User-visible narrative copy is never silently shortened. Generated summaries,
analysis, user-authored directions, experiment reasons, and observation text
wrap to their full height with no `maxLines + ellipsis` combination. A compact
preview may be shortened only when the same control clearly opens the complete
content, such as a timeline row leading to the diary or a chart node leading to
its detail. Chips, dates, metrics, and navigation labels remain compact controls
and may use a one-line fit or controlled ellipsis.

The implementation source of truth is `AuroraMainPageSpec` in
`frontend_flutter/lib/shared/widgets/aurora_ui.dart`.

## Simplified Chinese Terminology

In the Simplified Chinese interface, `Signal` and `Signal Path` are the only
English product terms that remain visible. All other interface copy,
navigation, state labels, source labels, purchase messages, analysis headings,
and generated taxonomy labels use natural Simplified Chinese. In particular:

- `AI` is presented by role, such as `智能助手`, `智能预判`, or `智能分析`;
- `Pro` is `专业版`;
- `Library` is `信号库`;
- `Signal Card` is `Signal 卡片` or `信号卡`, depending on sentence context;
- platform and implementation terms such as `StoreKit`, `App Store`, `iOS`,
  internal enum keys, and snake-case taxonomy values are translated before
  display.

This is a presentation rule only. Stable storage keys and source hashes remain
language-independent, and text authored by the user is never translated or
rewritten. Generated Weekly, Journey, and deep-analysis copy must pass through
the shared taxonomy-localization layer so keys such as `work`,
`body_tension`, or `context_switching` cannot leak into the interface.

## Secondary Surfaces

Candidate hubs, pre-save editable timeline decisions, read-only diary,
current-day experiment feedback, source-detail sheets, and Pro reports inherit
the same typography and card-density language unless a full-screen task
requires a different composition. Onboarding
uses a separate full-screen layout but keeps the same brand, copy hierarchy, and
accessible control standards.

Me-owned Life Direction and the user-visible `联动` Health surface inherit the
Me Aurora path/landscape motif and these same dimensions. `联动` is a
relationship explanation, not a raw Health dashboard: it uses short cards to show how a
sanitized Health hint may influence Today, Weekly, and Life Experiment while
keeping raw values out of the interface.

Me does not show a “stored on this device” badge or a Terms of Use row. Privacy
and Security opens the public `/privacy` policy directly; Help and Support opens
the public `#guestbook` form directly. These external destinations replace
intermediate in-app explanation pages.

Weekly-owned secondary surfaces, including Weekly Deep Analysis and next-week
experiment selection, inherit the Weekly review-loop pattern and hero
proportions. The review-loop hero pattern remains decorative; the page title
and supporting copy carry the task meaning, and assistive technology receives
an equivalent review-cycle label. User-visible Weekly copy says `Signal`, `linked Signal`, or
`source Signal`; it never says Evidence／证据.

## Today Compact State

The three visible titles are fixed to `Energy / 精力 / 精力 / エネルギー`,
`Load / 负担 / 負擔 / 負担`, and
`Recovery / 恢复 / 恢復 / 回復`. Do not use the old user-facing titles
`能量` or `摩擦`.

- Energy is a whole-day composite of real eligible Signals, the newest explicit
  status as a high-weight anchor, and completed time-use feedback. It is not a
  mirror of the latest status row.
- Load is actual burden context; low energy alone does not prove load.
- Recovery is explicit recovery context; missing evidence says “not seen yet,”
  never “insufficient recovery.”
- One indirect Signal stays neutral instead of producing a strong score.
- Planned time-use and release-QA showcase fixtures never affect Today count,
  summary, timeline, or these three values.
- Every state must have text and semantics; color and icon are supplementary.

## Weekly Report Components

The user-facing energy component is always named `This week’s energy state` /
`本周能量状态` / `本週能量狀態` / `今週のエネルギー状態`. Internal
`EnergyBudgetSnapshot` and Energy Budget names do not appear in the UI. This
component is contextual, not a budget, score, or health assessment. When a ring
is used, every eligible Signal must map to exactly one of five mutually
exclusive primary states: orange `draining / 偏耗力`, blue `steady / 平稳`,
yellow `ease / 有余力`, green `recovery / 恢复`, or purple
`boundary_buffer / 边界与余地`. `ease` means the user already feels light or
has spare capacity; `recovery` means an actual replenishing process or result.
A Signal that is neither clearly draining, at ease, recovering, nor creating a
boundary/buffer maps to blue `steady`; there is no gray, unknown, or
unclassified ring segment. This fallback is a product projection and must not
be worded as an explicit user confirmation.

Classification is deterministic: explicit `energy_level 0 / 1 / 2` wins and
maps to `draining / steady / ease`; legacy `energy_effect` is read only when the
new field is absent and maps `draining / neutral / restoring` to
`draining / steady / recovery`. Only when both are absent may traceable cues be
used, in the fixed stop-on-match order `boundary_buffer > recovery > draining >
ease`; no matched direction falls back to `steady`. Switching and deep focus
remain overlapping secondary descriptors outside the ring. `boundary_buffer`
is a primary color and is not counted twice as a secondary descriptor. All five
text legends stay visible together, including a `0` count when a category has
no Signals; the ring itself draws only non-zero segments. Every legend also has
a distinct non-color marker and VoiceOver label that announces its category
and count. The five counts cover all eligible Signals in the snapshot. The
center uses a qualitative summary such as `mostly steady`, `more draining`,
`more recovery`, or `more boundary and buffer`, with no unknown/gray state,
fabricated percentage, or decorative delta.

The repeated-pattern layer uses responsive content blocks for `Trigger`,
`Typical reaction`, `Short-term result`, and `Long-term impact`. Blocks are
optional; missing values read as forming rather than borrowing a generic title
or summary. Long-term impact requires cross-week support. At narrow widths or
large Dynamic Type, the grid becomes one column without clipping. There is no
separate duplicate Pattern Breakdown section. Weekly Deep Analysis removes
fabricated percentages and empty label-only tiles, and adds only cross-layer
relationships, time positions, support level, or next-week validation that the
standard Signal-facts, repeated-pattern, attempt-results, and energy sections
have not already stated.

Within the standard Weekly report, Signal distribution uses a compact luminous
donut beside ranked focus-domain rows on regular widths and stacks them on
narrow or 1.3x Dynamic Type layouts. Behavior patterns use full-width cards
with one catalog illustration, a concrete pattern statement, and visible
Signal/date trace. Small-experiment and goal rows keep the real registration
grid; the feedback illustration and factual conclusion belong to a distinct
review panel after those rows. These visuals must never replace missing data
with decorative percentages or a fixed seven-day success score.

## Weekly Deep Analysis Components

Weekly answers `what happened this week`; Weekly Deep Analysis answers `how
those layers co-occurred, when the relationship was more visible, and what next
week could test`. Its compact hero shows the local week plus factual `N Signals
· D recorded days`. It never shows decorative `3/4`, model-confidence
percentages, or a second app/feature icon.

The content order is:

1. one relationship headline, no more than two UI lines;
2. a 3-5-node relationship map linking Signal context, repeated pattern,
   energy state, and attempt result with 2-4 scoped co-occurrence lines;
3. a Monday-Sunday overlay of Signal count, qualitative energy state, and
   whether attempt feedback exists that day;
4. three compact validation tiles: `Why try / How next week / What to watch`;
5. source-Signal count and drill-down;
6. an optional grounded Signal reminder suggestion.

Relationship lines are visually undirected unless a separately traceable
causal contract exists; current UI copy says `co-occurred / related`. The
seven-day overlay is an aggregate cross-layer chart and never repeats Weekly's
per-object completion grid. Weekly's complete energy ring also does not appear
again on this page. Charts may use reproducible counts, dates, the five energy
states, and effective feedback facts; generated mood/friction scores, theme
shares, fake percentages, and decorative ratios are forbidden.

User-visible support uses text plus shape, not color or a number:
`forming / repeated this week / supported across weeks` (`刚开始形成 / 本周重复出现
/ 跨周仍出现`). The page does not show an Analysis Scope card; non-causal and
no-long-term-conclusion limits remain generation guardrails. At
320/390/430-point widths or 1.3x Dynamic Type, the relationship
map becomes a vertical node-and-line stack and validation tiles become one
column; labels remain readable rather than being ellipsized into ambiguity.

## Weekly Illustration Placement

The current illustration inventory contains 24 behavior-pattern keys, 30
review-pattern keys, and 9 focus-area keys. It is not one interchangeable set
of 30 behavior icons. Review assets remain scoped to attempt-result/feedback
meaning, including compatibility-only legacy states.

Weekly may show one behavior illustration beside its primary repeated-pattern
block. Weekly Deep Analysis may show one illustration in the central pattern
node of its relationship map. Both use the same stable
`behavior_illustration_key` for a matching source hash; neither uses the image
as the hero or substitutes the application icon. AI provides a catalog key,
never an asset path. Selection is deterministic by traceable primary pattern,
distinct supporting dates, supporting Signal count, then stable key order; raw
copy fuzzy matching is not authoritative. Missing keys use the versioned
neutral `pattern_forming` asset.

Because the image communicates the selected behavior, its accessibility label
names that behavior. It is not hidden as decoration, and color is never its only
meaning cue.

## Accessibility Verification

- Dynamic Type at least 1.3x on all five tabs and decision/candidate sheets.
- No clipped or overlapping content at 320, 390, 430, and 768-point widths.
- Minimum 44-point interactive targets.
- VoiceOver labels include object type, state, and progress summary.
- Selection, error, source relationship, and progress never rely on color alone.
- Reduced Motion and Reduce Transparency preserve meaning and readability.
- Bottom navigation and the keyboard do not obscure the active control.
