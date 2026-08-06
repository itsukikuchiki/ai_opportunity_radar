#!/usr/bin/env python3
"""Render the Traditional Chinese Signal Path App Store promo set."""

from __future__ import annotations

import sys

import render_app_store_screenshot_promos as base


base.SOURCE_ROOT = base.RELEASE_ROOT / "sources" / "zh-Hant"
base.OUTPUT_ROOT = base.RELEASE_ROOT / "final" / "iphone-6.9" / "zh-Hant"
base.PREVIEW_ROOT = base.RELEASE_ROOT / "previews" / "zh-Hant"

base.SLIDES = (
    base.Slide(
        "01-summary.png",
        "從一條記錄開始",
        "讓日常 Signal，慢慢連成生活軌跡",
        "記錄・每週復盤・小實驗・看見變化",
        "today.png",
        "#7665F2",
        "SUMMARY",
    ),
    base.Slide(
        "02-today.png",
        "把今天輕輕記下",
        "用文字、語音與狀態，留下當下的 Signal",
        "隨手留下一點真實",
        "today.png",
        "#578FEF",
        "TODAY",
    ),
    base.Slide(
        "03-weekly.png",
        "把一週連成線索",
        "從真實記錄裡，發現重複的模式",
        "事實 → 模式 → 嘗試結果",
        "weekly.png",
        "#7A67F2",
        "WEEKLY",
    ),
    base.Slide(
        "04-life-experiment.png",
        "讓改變從小步開始",
        "用輕量嘗試，慢慢靠近適合的節奏",
        "10 分鐘內，也可以開始",
        "life-experiment-overview.png",
        "#4FC3A2",
        "LIFE EXPERIMENT",
    ),
    base.Slide(
        "05-journey.png",
        "看見更長的旅程",
        "把零散的日子，串成自己的生活軌跡",
        "月度視圖・主題變化・溫柔回顧",
        "journey.png",
        "#836BEF",
        "JOURNEY",
    ),
    base.Slide(
        "06-pro.png",
        "讀懂你的行動偏好",
        "比較幫助與負擔，整理更合適的嘗試",
        "專業版・行動偏好深度報告",
        "pro.png",
        "#F09D5B",
        "PRO",
    ),
)

base.SOURCE_PROVENANCE = {
    "today.png": "Simulator Screenshot - Signal Path 繁中 iPhone 16e - 2026-08-02 at 21.21.36.png",
    "weekly.png": "Simulator Screenshot - Signal Path 繁中 iPhone 16e - 2026-08-02 at 21.21.54.png",
    "weekly-detail.png": "Simulator Screenshot - Signal Path 繁中 iPhone 16e - 2026-08-02 at 21.22.16.png",
    "life-experiment-overview.png": "Simulator Screenshot - Signal Path 繁中 iPhone 16e - 2026-08-02 at 21.22.28.png",
    "life-experiment-small.png": "Simulator Screenshot - Signal Path 繁中 iPhone 16e - 2026-08-02 at 21.22.46.png",
    "life-experiment-goal.png": "Simulator Screenshot - Signal Path 繁中 iPhone 16e - 2026-08-02 at 21.22.56.png",
    "journey.png": "Simulator Screenshot - Signal Path 繁中 iPhone 16e - 2026-08-02 at 21.23.04.png",
    "pro.png": "Simulator Screenshot - Signal Path 繁中 iPhone 16e - 2026-08-02 at 21.23.58.png",
}


if __name__ == "__main__":
    if sys.argv[1:] == ["--weekly-only"]:
        indices = {2}
    elif sys.argv[1:] == ["--life-experiment-only"]:
        indices = {3}
    else:
        indices = None
    base.main(indices)
