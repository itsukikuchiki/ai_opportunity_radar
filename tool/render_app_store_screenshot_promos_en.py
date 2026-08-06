#!/usr/bin/env python3
"""Render the English Signal Path App Store promo set."""

from __future__ import annotations

import sys
from pathlib import Path

import render_app_store_screenshot_promos as base


base.SOURCE_ROOT = base.RELEASE_ROOT / "sources" / "en"
base.OUTPUT_ROOT = base.RELEASE_ROOT / "final" / "iphone-6.9" / "en"
base.PREVIEW_ROOT = base.RELEASE_ROOT / "previews" / "en"
base.FONT_ZH = Path("/System/Library/Fonts/SFNS.ttf")
base.FONT_VARIATION_REGULAR = b"Regular"
base.FONT_VARIATION_BOLD = b"Bold"
base.JOURNEY_DETAIL_SOURCE = "journey-detail.png"
base.PRESENTATION_BOTTOM_CROP = {
    "today.png": 120,
    "weekly.png": 120,
    "life-experiment-overview.png": 120,
    "journey.png": 120,
    "pro.png": 120,
}

base.SLIDES = (
    base.Slide(
        "01-summary.png",
        "Your life, in Signals",
        "Turn daily moments into a life path you can see.",
        "Capture · Reflect · Experiment · Notice changes",
        "today.png",
        "#7665F2",
        "SUMMARY",
    ),
    base.Slide(
        "02-today.png",
        "Notice today",
        "Capture one real moment in text, voice, or mood.",
        "One small Signal is enough",
        "today.png",
        "#578FEF",
        "TODAY",
    ),
    base.Slide(
        "03-weekly.png",
        "Connect the week",
        "Find recurring patterns across your recorded Signals.",
        "Facts → Patterns → Small next step",
        "weekly.png",
        "#7A67F2",
        "WEEKLY",
    ),
    base.Slide(
        "04-life-experiment.png",
        "Try one small change",
        "Try small changes and learn what fits your rhythm.",
        "Ten minutes can be enough",
        "life-experiment-overview.png",
        "#4FC3A2",
        "LIFE EXPERIMENT",
    ),
    base.Slide(
        "05-journey.png",
        "See your longer journey",
        "Connect scattered days into your evolving story.",
        "Monthly view · Themes · Gentle review",
        "journey.png",
        "#836BEF",
        "JOURNEY",
    ),
    base.Slide(
        "06-pro.png",
        "Know what works for you",
        "Compare what helps, what feels manageable, and when.",
        "Pro · Action preference report",
        "pro.png",
        "#F09D5B",
        "PRO",
    ),
)

base.SOURCE_PROVENANCE = {
    "today.png": "Simulator Screenshot - Signal Path English iPhone 16e - 2026-08-02 at 15.56.01.png",
    "weekly.png": "Simulator Screenshot - Signal Path English iPhone 16e - 2026-08-02 at 15.56.32.png",
    "weekly-detail.png": "Simulator Screenshot - Signal Path English iPhone 16e - 2026-08-02 at 17.57.00.png",
    "life-experiment-overview.png": "Simulator Screenshot - Signal Path English iPhone 16e - 2026-08-02 at 15.59.06.png",
    "life-experiment-small.png": "Simulator Screenshot - Signal Path English iPhone 16e - 2026-08-02 at 16.00.06.png",
    "life-experiment-goal.png": "Simulator Screenshot - Signal Path English iPhone 16e - 2026-08-02 at 16.00.15.png",
    "journey.png": "Simulator Screenshot - Signal Path English iPhone 16e - 2026-08-02 at 16.00.35.png",
    "journey-detail.png": "Simulator Screenshot - Signal Path English iPhone 16e - 2026-08-02 at 16.00.58.png",
    "pro.png": "Simulator Screenshot - Signal Path English iPhone 16e - 2026-08-02 at 16.03.15.png",
}


if __name__ == "__main__":
    if sys.argv[1:] == ["--weekly-only"]:
        indices = {2}
    elif sys.argv[1:] == ["--life-experiment-only"]:
        indices = {3}
    elif sys.argv[1:] == ["--journey-only"]:
        indices = {4}
    else:
        indices = None
    base.main(indices)
