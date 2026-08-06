#!/usr/bin/env python3
"""Render the Japanese Signal Path App Store promo set."""

from __future__ import annotations

import sys

import render_app_store_screenshot_promos as base


base.SOURCE_ROOT = base.RELEASE_ROOT / "sources" / "ja"
base.OUTPUT_ROOT = base.RELEASE_ROOT / "final" / "iphone-6.9" / "ja"
base.PREVIEW_ROOT = base.RELEASE_ROOT / "previews" / "ja"
base.GENERATED_DATE = "2026-08-04"
base.FONT_INDEX_REGULAR = 0
base.FONT_INDEX_BOLD = 2
base.FONT_VARIATION_REGULAR = None
base.FONT_VARIATION_BOLD = None
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
        "ひとつの記録から",
        "日々のSignalが、暮らしの軌跡につながる",
        "記録・週間レビュー・小実験",
        "today.png",
        "#7665F2",
        "SUMMARY",
    ),
    base.Slide(
        "02-today.png",
        "今日を、そっと残す",
        "文字や声で、今この瞬間のSignalを記録",
        "小さな事実をひとつ",
        "today.png",
        "#578FEF",
        "TODAY",
    ),
    base.Slide(
        "03-weekly.png",
        "一週間を、線で見る",
        "記録をつないで、繰り返しの傾向に気づく",
        "事実 → パターン → 試した結果",
        "weekly.png",
        "#7A67F2",
        "WEEKLY",
    ),
    base.Slide(
        "04-life-experiment.png",
        "小さく試してみる",
        "無理のない一歩で、自分に合うペースへ",
        "10分から、気軽に",
        "life-experiment-overview.png",
        "#4FC3A2",
        "LIFE EXPERIMENT",
    ),
    base.Slide(
        "05-journey.png",
        "日々を、自分の旅にする",
        "点在する記録を、自分だけの軌跡につなぐ",
        "月間・テーマ・振り返り",
        "journey.png",
        "#836BEF",
        "JOURNEY",
    ),
    base.Slide(
        "06-pro.png",
        "行動の傾向を知る",
        "役立ちやすさと負担感から、自分に合う試し方を整理",
        "プロ版・行動傾向レポート",
        "pro.png",
        "#F09D5B",
        "PRO",
    ),
)

base.SOURCE_PROVENANCE = {
    "today.png": "Simulator Screenshot - Signal Path 日本語 iPhone 16e - 2026-08-02 at 23.43.06.png",
    "weekly.png": "Simulator Screenshot - Signal Path 日本語 iPhone 16e - 2026-08-02 at 23.43.43.png",
    "weekly-detail.png": "Simulator Screenshot - Signal Path 日本語 iPhone 16e - 2026-08-02 at 23.43.55.png",
    "life-experiment-overview.png": "Simulator Screenshot - Signal Path 日本語 iPhone 16e - 2026-08-02 at 23.44.30.png",
    "life-experiment-small.png": "Simulator Screenshot - Signal Path 日本語 iPhone 16e - 2026-08-02 at 23.44.40.png",
    "life-experiment-goal.png": "Simulator Screenshot - Signal Path 日本語 iPhone 16e - 2026-08-02 at 23.44.53.png",
    "journey.png": "Simulator Screenshot - Signal Path 日本語 iPhone 16e - 2026-08-02 at 23.45.13.png",
    "journey-detail.png": "Simulator Screenshot - Signal Path 日本語 iPhone 16e - 2026-08-02 at 23.45.27.png",
    "pro.png": "Simulator Screenshot - Signal Path 日本語 iPhone 16e - 2026-08-02 at 23.45.02.png",
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
