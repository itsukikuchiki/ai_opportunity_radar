# Main Tab UI Standard

Last updated: 2026-07-17

Today is the visual-density reference for the five primary tabs: Today,
Weekly, Life Experiment, Journey, and Me. Page-specific illustrations and
content remain distinct, but typography and region sizing follow one contract.

Today's hero represents Signal input. Weekly follows the same dimensions and
typographic hierarchy but uses its own review-loop relationship pattern: seven
local-day nodes connected by one continuous returning path, expressing Signal
facts -> repeated pattern -> attempt results -> the next recording cycle.
Neither Weekly nor its owned secondary surfaces may use the application icon or
a generic feature icon as the hero illustration.

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

The implementation source of truth is `AuroraMainPageSpec` in
`frontend_flutter/lib/shared/widgets/aurora_ui.dart`.

## Secondary Surfaces

Candidate hubs, pre-save editable timeline decisions, read-only diary,
current-day experiment feedback, source-detail sheets, and Pro reports inherit
the same typography and card-density language unless a full-screen task
requires a different composition. Onboarding
uses a separate full-screen layout but keeps the same brand, copy hierarchy, and
accessible control standards.

Weekly-owned secondary surfaces, including Weekly Deep Analysis and next-week
experiment selection, inherit the Weekly review-loop pattern and hero
proportions. The review-loop hero pattern remains decorative; the page title
and supporting copy carry the task meaning, and assistive technology receives
an equivalent review-cycle label. User-visible Weekly copy says `Signal`, `linked Signal`, or
`source Signal`; it never says Evidence／证据.

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
6. `Analysis scope / 分析范围`, replacing `Use gently / 温和使用`.

Relationship lines are visually undirected unless a separately traceable
causal contract exists; current UI copy says `co-occurred / related`. The
seven-day overlay is an aggregate cross-layer chart and never repeats Weekly's
per-object completion grid. Weekly's complete energy ring also does not appear
again on this page. Charts may use reproducible counts, dates, the five energy
states, and effective feedback facts; generated mood/friction scores, theme
shares, fake percentages, and decorative ratios are forbidden.

User-visible support uses text plus shape, not color or a number:
`forming / repeated this week / supported across weeks` (`刚开始形成 / 本周重复出现
/ 跨周仍出现`). The final scope copy states the actual Signal count and recorded
days and says that co-occurrence is neither causation nor a long-term
conclusion. At 320/390/430-point widths or 1.3x Dynamic Type, the relationship
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
