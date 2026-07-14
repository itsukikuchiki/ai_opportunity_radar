# Main Tab UI Standard

Last updated: 2026-07-12

Today is the visual-density reference for the five primary tabs: Today,
Weekly, Life Experiment, Journey, and Me. Page-specific illustrations and
content remain distinct, but typography and region sizing follow one contract.

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

Candidate hubs, editable timeline decisions, diary, experiment feedback,
evidence sheets, and Pro reports inherit the same typography and card-density
language unless a full-screen task requires a different composition. Onboarding
uses a separate full-screen layout but keeps the same brand, copy hierarchy, and
accessible control standards.

## Accessibility Verification

- Dynamic Type at least 1.3x on all five tabs and decision/candidate sheets.
- No clipped or overlapping content at 320, 390, 430, and 768-point widths.
- Minimum 44-point interactive targets.
- VoiceOver labels include object type, state, and progress summary.
- Selection, error, evidence, and progress never rely on color alone.
- Reduced Motion and Reduce Transparency preserve meaning and readability.
- Bottom navigation and the keyboard do not obscure the active control.
