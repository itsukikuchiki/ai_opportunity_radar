#!/usr/bin/env python3
from pathlib import Path
from textwrap import wrap

from PIL import Image, ImageDraw, ImageFont


OUT_DIR = Path("/private/tmp/signalpath_releaseqa_phase3_productization")
W, H = 860, 1864


SCENES = [
    (
        "01_today_signal_feed_full",
        "Today · Private Signal Feed",
        "5 synthetic SignalCards: text, voice, ai_predicted, library_saved, local draft.",
        [
            ("Text SignalCard", "Raw note: A dense planning meeting left me scattered, but a short walk helped me reset.", ["draining", "work", "Looks right"]),
            ("Voice SignalCard", "Transcript only: I noticed my body relaxed after ten quiet minutes. No audio saved or uploaded.", ["voice", "restoring", "supplemented"]),
            ("AI suggested SignalCard", "Maybe the signal is switching fatigue after back-to-back context changes.", ["ai_predicted", "unconfirmed", "private"]),
            ("Saved from Library", "Official abstract pattern: attention switching fatigue. This is not raw diary text.", ["library_saved", "private", "unconfirmed"]),
            ("Waiting to sync", "Local draft: saved on this device first; retry can sync later.", ["local draft", "waiting to sync", "neutral"]),
        ],
    ),
    (
        "02_signal_composer_input",
        "Signal Composer",
        "Input can be unfinished, messy, or one sentence.",
        [
            ("Composer prompt", "One signal from today... maybe a drain, a recovery clue, or something you want to remember.", ["Save", "Voice draft", "Suggest a signal"]),
            ("Save-first boundary", "Raw input is saved before parser, AI reply, Summary, Weekly, Journey, or quota-dependent work.", ["raw input preserved", "AI failure safe"]),
        ],
    ),
    (
        "03_voice_transcript_edit",
        "Voice Transcript MVP",
        "Transcript-only capture. The user edits text before saving.",
        [
            ("Editable transcript", "I felt a little lighter after stepping away from messages for ten minutes.", ["transcript only", "no audio file", "no upload"]),
            ("Permission fallback", "If speech capture is unavailable or denied, text input remains the full fallback path.", ["text still works", "no blocked capture"]),
        ],
    ),
    (
        "04_ai_predicted_confirm_mode",
        "AI Predicted Confirm Mode",
        "User-triggered suggestion only. Private and unconfirmed until the user acts.",
        [
            ("Suggested card", "Maybe today has a signal around switching fatigue and missing buffer.", ["ai_predicted", "Not checked yet", "not included"]),
            ("Confirmation chips", "Looks right · Not quite · Adjust · Add context. Nothing is confirmed automatically.", ["private", "low pressure"]),
        ],
    ),
    (
        "05_library_saved_timeline_card",
        "Library Saved In Timeline",
        "Official abstract patterns enter personal observation without becoming raw diary.",
        [
            ("Saved from Library", "Attention switching fatigue: some people feel worn down by frequent switching rather than one task.", ["source_type library_saved", "private", "unconfirmed"]),
            ("Your context", "User-added context stays private in user_correction_json and never flows back into Library.", ["supplemented", "not shared"]),
        ],
    ),
    (
        "06_signalcard_compact_state",
        "Compact SignalCard",
        "Raw note first, one short AI response, 2-3 tags, and confirmation chips.",
        [
            ("Raw note", "I kept switching between chat, planning, and a family message. By evening I felt flat.", ["mixed", "attention", "switching"]),
            ("AI response", "This looks less like one difficult task and more like repeated switching with too little buffer.", ["Looks right", "Used today"]),
        ],
    ),
    (
        "07_plan_block_local_only",
        "Plan Block",
        "A lightweight plan from Weekly. Local-only; not a calendar task.",
        [
            ("Saved Plan Block", "Try leaving one ten-minute buffer after the densest meeting block.", ["local only", "no Calendar", "no notification"]),
            ("Tone", "This adjustment can simply be something to try. It is not a task manager or habit tracker.", ["optional", "low pressure"]),
        ],
    ),
    (
        "08_weekly_life_dashboard",
        "Weekly · Life Dashboard",
        "One judgement, three pieces of evidence, one optional experiment.",
        [
            ("This week, start here", "The most costly pattern seems to be frequent switching without a small recovery edge.", ["one pattern", "three evidence"]),
            ("One small experiment", "Try protecting one small buffer after the densest part of the day.", ["suggested", "save", "skip"]),
        ],
    ),
    (
        "09_weekly_energy_stacked_bar",
        "Energy Distribution",
        "Display-only stacked bar. Distribution, not performance.",
        [
            ("Stacked bar", "High-drain 3 · High-switching 2 · Recovery 2 · Buffer 1 · Neutral 1.", ["not a score", "not diagnosis"]),
            ("External hints", "Schedule density may be compact. Recovery signal may be a little thin.", ["abstract only", "no raw calendar", "no raw health"]),
        ],
    ),
    (
        "10_life_experiment_feedback",
        "Life Experiment",
        "Review and Adjust, not habit tracking.",
        [
            ("Saved experiment", "Leave a small buffer after the densest block and notice whether evening friction softens.", ["saved", "tried", "adjusted"]),
            ("Feedback", "This design helped a little twice. One skipped day is still useful evidence.", ["not failure", "learning signal"]),
        ],
    ),
    (
        "11_energy_budget_block",
        "Energy Budget Lite",
        "Where things may feel costly and where a little room may help.",
        [
            ("Most costly source", "Context switching around planning, messages, and meetings.", ["SignalCard evidence", "user-confirmed first"]),
            ("Recovery clue", "Short walks and quiet gaps appear as small restoring signals.", ["restoring", "positive signal"]),
            ("Buffer suggestion", "This time block may be dense; you could leave a little room around it.", ["schedule-density hint", "abstract"]),
        ],
    ),
    (
        "12_journey_life_map",
        "Journey · Long-term Life Map",
        "Synthetic 8-week distribution with pattern, recovery clue, and experiment trail.",
        [
            ("Long-term pattern", "Switching load rises when planning, messages, and care responsibilities cluster.", ["confirmed", "unconfirmed context", "legacy context"]),
            ("Recovery clue", "Small freedom, a quiet walk, or one protected gap often appears before lighter evenings.", ["restoring", "life map"]),
        ],
    ),
    (
        "13_journey_heatmap_review_adjust",
        "Journey Heatmap + Review & Adjust",
        "Signal density map, not judgement or score.",
        [
            ("Heatmap legend", "Light = weak signal, medium = repeated pattern, deep = stable mode.", ["not score", "not diagnosis"]),
            ("Review & Adjust", "The buffer design may help when switching is high. If not, make the experiment smaller.", ["experiment feedback", "no failure label"]),
        ],
    ),
    (
        "14_signal_library_cards",
        "Signal Library",
        "Official curated abstract patterns only. Not a community feed.",
        [
            ("Over-scheduled weeks", "Some people encounter a similar structure when the week has many commitments and very little space between them.", ["official abstract", "no raw_text"]),
            ("Attention switching fatigue", "Some people feel more worn down by frequent switching than by any single task.", ["Pattern Card", "no identity"]),
        ],
    ),
    (
        "15_library_share_preview",
        "Library Share Preview",
        "Share/copy contains only official abstract pattern and small experiment.",
        [
            ("Share content", "Attention switching fatigue · Some people feel more worn down by frequent switching than by any single task. Try grouping one small set of messages or tasks.", ["official only", "no user content"]),
            ("Private action state", "Save to my observation creates a private library_saved SignalCard, unconfirmed by default.", ["private observation", "no public interaction"]),
        ],
    ),
]


def font(size, bold=False):
    names = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for name in names:
        try:
            return ImageFont.truetype(name, size=size)
        except OSError:
            pass
    return ImageFont.load_default()


TITLE = font(50, True)
SUBTITLE = font(28)
CARD_TITLE = font(30, True)
BODY = font(25)
BADGE = font(20, True)
FOOTER = font(18)


def text(draw, xy, value, fill, fnt, width_chars, line_gap=8):
    x, y = xy
    for line in wrap(value, width_chars):
        draw.text((x, y), line, fill=fill, font=fnt)
        y += fnt.size + line_gap
    return y


def rounded(draw, box, fill, outline=None, radius=18, width=2):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def badge(draw, x, y, label):
    padding_x, padding_y = 16, 8
    bbox = draw.textbbox((0, 0), label, font=BADGE)
    w = bbox[2] - bbox[0] + padding_x * 2
    h = bbox[3] - bbox[1] + padding_y * 2
    rounded(draw, (x, y, x + w, y + h), "#EAF1F5", "#B9C9D5", radius=24, width=2)
    draw.text((x + padding_x, y + padding_y - 1), label, fill="#36576F", font=BADGE)
    return x + w + 10, h


def card(draw, y, label, value, badges):
    x, w = 34, W - 68
    top = y
    estimated_lines = max(2, len(wrap(value, 48)))
    estimated_badge_rows = 1 + len(badges) // 3
    estimated_h = 116 + estimated_lines * 38 + estimated_badge_rows * 44
    rounded(draw, (x, top, x + w, top + estimated_h), "#FFFFFF", "#E1DCE6", radius=18, width=2)
    y += 26
    draw.text((x + 24, y), label, fill="#1E2933", font=CARD_TITLE)
    y += 46
    y = text(draw, (x + 24, y), value, "#2F3A45", BODY, 48, line_gap=9)
    y += 18
    bx, max_h = x + 24, 0
    for b in badges:
        next_x, h = badge(draw, bx, y, b)
        if next_x > x + w - 40:
            y += max_h + 10
            bx, max_h = x + 24, 0
            next_x, h = badge(draw, bx, y, b)
        bx = next_x
        max_h = max(max_h, h)
    y += max_h + 24
    return y + 18


def render_scene(scene):
    name, title, subtitle, blocks = scene
    img = Image.new("RGB", (W, H), "#F8F6FA")
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, W, 116), fill="#EDF4F7")
    draw.text((34, 40), name, fill="#36576F", font=BADGE)
    y = 150
    draw.text((34, y), title, fill="#14212B", font=TITLE)
    y += 70
    y = text(draw, (34, y), subtitle, "#526170", SUBTITLE, 44, line_gap=10)
    y += 26
    if name == "09_weekly_energy_stacked_bar":
        y = draw_stacked_bar(draw, y)
    if name == "13_journey_heatmap_review_adjust":
        y = draw_heatmap(draw, y)
    for label, value, badges in blocks:
        y = card(draw, y, label, value, badges)
    footer = "Synthetic ReleaseQA-2.6 evidence. No real user raw_text, audio, raw Calendar data, or raw HealthKit samples."
    text(draw, (34, H - 120), footer, "#6B7280", FOOTER, 72, line_gap=6)
    img.save(OUT_DIR / f"{name}.png")


def draw_stacked_bar(draw, y):
    x, w, h = 34, W - 68, 32
    parts = [("high-drain", 3, "#F2C6C2"), ("switching", 2, "#F1D7A8"), ("recovery", 2, "#BFDCCA"), ("buffer", 1, "#C8D8EE"), ("neutral", 1, "#D9DDE5")]
    total = sum(p[1] for p in parts)
    cur = x
    for _, count, color in parts:
        seg = int(w * count / total)
        draw.rounded_rectangle((cur, y, cur + seg, y + h), radius=16, fill=color)
        cur += seg
    return y + h + 24


def draw_heatmap(draw, y):
    x = 34
    colors = ["#E4E7EC", "#BFDCCA", "#8CB9C9", "#496D89"]
    for i in range(32):
        level = 0 if i % 7 == 0 else 1 if i % 5 else 3 if i % 11 == 0 else 2
        cx = x + (i % 8) * 42
        cy = y + (i // 8) * 42
        rounded(draw, (cx, cy, cx + 30, cy + 30), colors[level], radius=7)
    return y + 4 * 42 + 12


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for scene in SCENES:
        render_scene(scene)
    (OUT_DIR / "manifest.txt").write_text(
        "\n".join(
            [
                "ReleaseQA-2.6 Phase 3 productization evidence",
                "Synthetic demo seed only. No real user data, raw Calendar data, raw HealthKit samples, or audio.",
                *[f"{scene[0]}.png" for scene in SCENES],
            ]
        )
    )
    print(f"Wrote {len(SCENES)} screenshots to {OUT_DIR}")


if __name__ == "__main__":
    main()
