#!/usr/bin/env python3
"""Render deterministic App Store screenshot artwork for Signal Path.

The renderer intentionally uses the app's checked-in brand artwork and a
localized, app-like product composition instead of device screenshots with
stale fixture text.  Outputs are exact App Store dimensions, RGB, and
non-transparent.
"""

from __future__ import annotations

import argparse
import calendar
import hashlib
import json
import math
import shutil
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "frontend_flutter" / "assets"
DEFAULT_OUTPUT = ROOT / "release_assets" / "app_store" / "2026-07-29"

FONT_ZH = Path("/System/Library/Fonts/Hiragino Sans GB.ttc")
FONT_JA = Path("/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc")
FONT_EN = Path("/System/Library/Fonts/HelveticaNeue.ttc")

NAVY = "#252B4A"
TEXT = "#3F4666"
MUTED = "#7E859F"
PURPLE = "#7867F2"
BLUE = "#5B8FF0"
CYAN = "#57C8D6"
MINT = "#5CC4A1"
ORANGE = "#F3A15F"
PINK = "#E884B3"
CREAM = "#FFF8F2"
WHITE = "#FFFFFF"


@dataclass(frozen=True)
class Device:
    slug: str
    width: int
    height: int
    scale: float
    tablet: bool


DEVICES = (
    Device("iphone-6.9", 1320, 2868, 1.0, False),
    Device("ipad-13", 2064, 2752, 1.25, True),
)

PAGE_SPECS = (
    ("01-today-signal", "today"),
    ("02-today-state", "state"),
    ("03-weekly-review", "weekly"),
    ("04-life-experiment", "experiment"),
    ("05-journey", "journey"),
    ("06-pro-depth", "pro"),
)

LOCALES = ("zh-Hans", "zh-Hant", "ja", "en-US")

EXTRA_COPY: dict[str, dict[str, str]] = {
    "zh-Hans": {
        "timeline_second": "14:30–15:10 处理需要专注的工作",
        "timeline_third": "傍晚没有立刻继续工作，先坐了一会儿。",
        "reply_second": "把时间留给真正需要专注的事，也是在保护自己的精力。",
        "reply_third": "先停一下，也是一种有效的选择。",
        "prediction": "智能预判",
        "prediction_text": "任务切换密集时，你可能更需要一小段恢复空隙。",
        "weekly_days": "登记 4 天",
        "weekly_done": "完成 6 次",
        "weekly_conclusion": "事实总结",
        "weekly_conclusion_text": "轻量缓冲更容易发生；任务密集时，恢复效果也更明显。",
        "weekly_next": "下周可继续",
        "weekly_next_text": "保留两分钟缓冲，不增加新的负担。",
        "feedback_title": "真实反馈",
        "feedback_1": "有帮助",
        "feedback_2": "一般",
        "feedback_3": "有帮助",
        "goal_summary": "目标进展",
        "goal_summary_text": "已记录 8 天；午后离屏时，恢复感更容易出现。",
        "gentle_1": "工作密集的日子里，你仍留出了几次缓冲。",
        "gentle_2": "恢复不是停下所有事，而是找回一点自己的节奏。",
        "gentle_3": "下个月可以继续留意：什么时刻最容易真正放松。",
        "month_1": "7月上旬",
        "month_2": "7月中旬",
        "month_3": "7月下旬",
        "long_summary": "恢复空间增加",
        "long_summary_detail": "低负担的小实验更容易持续，也更常得到正向反馈。",
    },
    "zh-Hant": {
        "timeline_second": "14:30–15:10 處理需要專注的工作",
        "timeline_third": "傍晚沒有立刻繼續工作，先坐了一會兒。",
        "reply_second": "把時間留給真正需要專注的事，也是在保護自己的精力。",
        "reply_third": "先停一下，也是一種有效的選擇。",
        "prediction": "智慧預判",
        "prediction_text": "任務切換密集時，你可能更需要一小段恢復空隙。",
        "weekly_days": "登記 4 天",
        "weekly_done": "完成 6 次",
        "weekly_conclusion": "事實總結",
        "weekly_conclusion_text": "輕量緩衝更容易發生；任務密集時，恢復效果也更明顯。",
        "weekly_next": "下週可繼續",
        "weekly_next_text": "保留兩分鐘緩衝，不增加新的負擔。",
        "feedback_title": "真實回饋",
        "feedback_1": "有幫助",
        "feedback_2": "一般",
        "feedback_3": "有幫助",
        "goal_summary": "目標進展",
        "goal_summary_text": "已記錄 8 天；午後離屏時，恢復感更容易出現。",
        "gentle_1": "工作密集的日子裡，你仍留出了幾次緩衝。",
        "gentle_2": "恢復不是停下所有事，而是找回一點自己的節奏。",
        "gentle_3": "下個月可以繼續留意：什麼時刻最容易真正放鬆。",
        "month_1": "7月上旬",
        "month_2": "7月中旬",
        "month_3": "7月下旬",
        "long_summary": "恢復空間增加",
        "long_summary_detail": "低負擔的小實驗更容易持續，也更常得到正向回饋。",
    },
    "ja": {
        "timeline_second": "14:30–15:10 集中したい作業に使う",
        "timeline_third": "夕方、すぐ作業に戻らず少し座って休んだ。",
        "reply_second": "本当に集中したいことへ時間を残すのも、余力を守る方法です。",
        "reply_third": "いったん止まることも、十分に意味のある選択です。",
        "prediction": "AI の予測",
        "prediction_text": "切り替えが続くときは、短い回復の余白が必要かもしれません。",
        "weekly_days": "記録 4 日",
        "weekly_done": "完了 6 回",
        "weekly_conclusion": "事実のまとめ",
        "weekly_conclusion_text": "短い余白は続けやすく、予定が詰まった日に回復を感じやすい傾向でした。",
        "weekly_next": "来週も続ける",
        "weekly_next_text": "新しい負担を増やさず、2分の余白を残します。",
        "feedback_title": "実際のフィードバック",
        "feedback_1": "役に立った",
        "feedback_2": "ふつう",
        "feedback_3": "役に立った",
        "goal_summary": "目標の進み方",
        "goal_summary_text": "8日記録。午後に画面から離れた日は、回復を感じやすくなりました。",
        "gentle_1": "忙しい日にも、何度か短い余白を残せていました。",
        "gentle_2": "回復は全部を止めることではなく、自分のリズムを取り戻すこと。",
        "gentle_3": "来月は、本当に力が抜ける瞬間をもう少し見つめてみましょう。",
        "month_1": "7月上旬",
        "month_2": "7月中旬",
        "month_3": "7月下旬",
        "long_summary": "回復の余白が増加",
        "long_summary_detail": "負担の小さい実験ほど続けやすく、よい反応も増えています。",
    },
    "en-US": {
        "timeline_second": "14:30–15:10 Focused work block",
        "timeline_third": "In the evening, I sat for a moment before returning to work.",
        "reply_second": "Saving time for what truly needs focus is also a way to protect your energy.",
        "reply_third": "Pausing first can be a meaningful choice, too.",
        "prediction": "AI prediction",
        "prediction_text": "When switching builds up, a small recovery gap may help.",
        "weekly_days": "4 days logged",
        "weekly_done": "6 completions",
        "weekly_conclusion": "What the facts show",
        "weekly_conclusion_text": "Short buffers happened more often and felt most useful on task-heavy afternoons.",
        "weekly_next": "Continue next week",
        "weekly_next_text": "Keep the two-minute buffer without adding a new burden.",
        "feedback_title": "Real feedback",
        "feedback_1": "Helpful",
        "feedback_2": "Neutral",
        "feedback_3": "Helpful",
        "goal_summary": "Goal progress",
        "goal_summary_text": "8 days logged; stepping away in the afternoon was more often linked with recovery.",
        "gentle_1": "Even on busy workdays, you still made room for a few pauses.",
        "gentle_2": "Recovery was less about stopping everything and more about finding your rhythm.",
        "gentle_3": "Next month, notice the moments when you can genuinely let go.",
        "month_1": "Early Jul",
        "month_2": "Mid Jul",
        "month_3": "Late Jul",
        "long_summary": "More room to recover",
        "long_summary_detail": "Low-effort experiments were easier to sustain and more often received positive feedback.",
    },
}


COPY: dict[str, dict[str, Any]] = {
    "zh-Hans": {
        "marketing": {
            "today": ("把今天，留成真实 Signal", "用文字、语音、状态和安排，记录当下发生的生活。"),
            "state": ("从当天 Signal，看见精力、负担与恢复", "状态随真实记录更新，智能助手先承接你的表达，不替你下结论。"),
            "weekly": ("把本周 Signal，连成可复盘的模式", "回看事实、行为模式与尝试结果，再决定下周继续什么。"),
            "experiment": ("把看见的模式，变成可以尝试的改变", "用轻量尝试回应当下，用目标持续观察中长期变化。"),
            "journey": ("沿着时间，看见这个月留下的轨迹", "用月度视图、主题变化与温柔回顾，理解真实生活怎样展开。"),
            "pro": ("专业版，让 Signal 看得更深、更远", "查看本周深度分析、行动偏好，以及使用 Signal Path 以来的长期变化。"),
        },
        "tabs": ("今天", "每周复盘", "生活小实验", "旅程", "我的"),
        "ui": {
            "today": "今天",
            "date": "7月29日 周三",
            "energy": "精力",
            "burden": "负担",
            "recovery": "恢复",
            "steady": "较足",
            "medium": "适中",
            "rising": "正在恢复",
            "prompt": "今天过得怎么样？",
            "placeholder": "留下一点今天的 Signal…",
            "voice": "语音",
            "status": "状态",
            "schedule": "安排",
            "library": "信号库",
            "timeline": "今日时间线",
            "timeline_item": "上午连续切换任务后，先停了两分钟。",
            "assistant": "智能助手",
            "assistant_reply": "听起来你一直在应付切换，能停一下已经很不容易。",
            "state_title": "从今天的 Signal 看状态",
            "state_note": "这些状态来自今天留下的真实记录，会随着新 Signal 更新。",
            "time_block": "14:30–15:10  留给需要专注的工作",
            "weekly": "每周复盘",
            "week": "7月27日–8月2日",
            "signal_dist": "本周 Signal 分布",
            "emotion": "情绪稳定",
            "boundary": "自我边界",
            "sleep": "饮食睡眠",
            "growth": "成长计划",
            "pattern": "本周行为模式",
            "pattern_1": "安排变密",
            "pattern_2": "休息被压缩",
            "pattern_3": "晚上空转",
            "result": "本周尝试反馈",
            "result_text": "切换前留两分钟缓冲，在任务密集的下午更有帮助。",
            "experiment": "生活小实验",
            "overview": "尝试总览",
            "small": "小实验 · 轻量尝试",
            "goal": "目标 · 中长期",
            "small_name": "任务切换前留两分钟缓冲",
            "goal_name": "午后十分钟离屏恢复",
            "attempts": "本轮尝试 4 次",
            "helpful": "3 次有帮助",
            "load": "多数轻松",
            "goal_progress": "本月完成 8 天",
            "feedback": "反馈趋势",
            "journey": "旅程",
            "month": "2026年7月",
            "month_overview": "本月概览",
            "record_days": "记录日",
            "signals": "Signal",
            "themes": "主题变化",
            "calendar": "月度视图",
            "theme_a": "恢复空间",
            "theme_b": "专注节奏",
            "theme_c": "关系连接",
            "gentle": "温柔回顾",
            "gentle_text": "真正值得留下的，往往不是做了多少，而是哪些时刻让你更像自己。",
            "pro": "专业版深度视图",
            "deep": "本周深度分析",
            "relation": "场景、行为、能量与反馈",
            "scene": "切换密集",
            "behavior": "继续推进",
            "state_word": "负担升高",
            "response": "缓冲有效",
            "preference": "行动偏好",
            "preference_text": "低负担、马上能开始的小实验，更容易形成真实反馈。",
            "long_term": "长期变化",
            "load_suggestion": "下周负荷建议：维持",
        },
    },
    "zh-Hant": {
        "marketing": {
            "today": ("把今天，留成真實 Signal", "用文字、語音、狀態與安排，記下此刻發生的生活。"),
            "state": ("從當天 Signal，看見精力、負擔與恢復", "狀態會隨真實記錄更新，智慧助理先承接你的表達，不替你下結論。"),
            "weekly": ("把本週 Signal，連成可複盤的模式", "回看事實、行為模式與嘗試結果，再決定下週要繼續什麼。"),
            "experiment": ("把看見的模式，變成可以嘗試的改變", "用輕量嘗試回應當下，用目標持續觀察中長期變化。"),
            "journey": ("沿著時間，看見這個月留下的軌跡", "用月度視圖、主題變化與溫柔回顧，理解真實生活如何展開。"),
            "pro": ("專業版，讓 Signal 看得更深、更遠", "查看本週深度分析、行動偏好，以及使用 Signal Path 以來的長期變化。"),
        },
        "tabs": ("今天", "每週複盤", "生活小實驗", "旅程", "我的"),
        "ui": {
            "today": "今天",
            "date": "7月29日 週三",
            "energy": "精力",
            "burden": "負擔",
            "recovery": "恢復",
            "steady": "較足",
            "medium": "適中",
            "rising": "正在恢復",
            "prompt": "今天過得怎麼樣？",
            "placeholder": "留下一點今天的 Signal…",
            "voice": "語音",
            "status": "狀態",
            "schedule": "安排",
            "library": "信號庫",
            "timeline": "今日時間線",
            "timeline_item": "上午連續切換任務後，先停了兩分鐘。",
            "assistant": "智慧助理",
            "assistant_reply": "聽起來你一直在應付切換，能停一下已經很不容易。",
            "state_title": "從今天的 Signal 看狀態",
            "state_note": "這些狀態來自今天留下的真實記錄，會隨新 Signal 更新。",
            "time_block": "14:30–15:10  留給需要專注的工作",
            "weekly": "每週複盤",
            "week": "7月27日–8月2日",
            "signal_dist": "本週 Signal 分布",
            "emotion": "情緒穩定",
            "boundary": "自我邊界",
            "sleep": "飲食睡眠",
            "growth": "成長計畫",
            "pattern": "本週行為模式",
            "pattern_1": "安排變密",
            "pattern_2": "休息被壓縮",
            "pattern_3": "晚上空轉",
            "result": "本週嘗試回饋",
            "result_text": "切換前留兩分鐘緩衝，在任務密集的下午更有幫助。",
            "experiment": "生活小實驗",
            "overview": "嘗試總覽",
            "small": "小實驗 · 輕量嘗試",
            "goal": "目標 · 中長期",
            "small_name": "任務切換前留兩分鐘緩衝",
            "goal_name": "午後十分鐘離屏恢復",
            "attempts": "本輪嘗試 4 次",
            "helpful": "3 次有幫助",
            "load": "多數輕鬆",
            "goal_progress": "本月完成 8 天",
            "feedback": "回饋趨勢",
            "journey": "旅程",
            "month": "2026年7月",
            "month_overview": "本月概覽",
            "record_days": "記錄日",
            "signals": "Signal",
            "themes": "主題變化",
            "calendar": "月度視圖",
            "theme_a": "恢復空間",
            "theme_b": "專注節奏",
            "theme_c": "關係連結",
            "gentle": "溫柔回顧",
            "gentle_text": "真正值得留下的，往往不是做了多少，而是哪些時刻讓你更像自己。",
            "pro": "專業版深度視圖",
            "deep": "本週深度分析",
            "relation": "場景、行為、能量與回饋",
            "scene": "切換密集",
            "behavior": "繼續推進",
            "state_word": "負擔升高",
            "response": "緩衝有效",
            "preference": "行動偏好",
            "preference_text": "低負擔、馬上能開始的小實驗，更容易形成真實回饋。",
            "long_term": "長期變化",
            "load_suggestion": "下週負荷建議：維持",
        },
    },
    "ja": {
        "marketing": {
            "today": ("今日を、ありのままの\nSignal として残す", "文字・音声・状態・時間の使い方から、今の暮らしを残せます。"),
            "state": ("今日の Signal から、\n余力・負担・回復を見る", "状態は実際の記録に合わせて更新され、\nAI は結論を急がず、言葉を受け止めます。"),
            "weekly": ("今週の Signal をつなぎ、\n振り返れるパターンへ", "事実・行動パターン・試した結果を振り返り、\n来週に続けることを選べます。"),
            "experiment": ("見えてきたパターンを、\n試せる変化へ", "小実験は今すぐ軽く試せます。\n目標は、少し長い変化を見守ります。"),
            "journey": ("時間に沿って、今月の軌跡を見る", "月表示、テーマの変化、やさしい振り返りから、\n今月の暮らしの流れを見つめます。"),
            "pro": ("Pro で Signal を深く、\n長い時間軸で見る", "今週の深い分析、行動の好み、\nSignal Path を使い始めてからの変化を見られます。"),
        },
        "tabs": ("今日", "週間レビュー", "生活実験", "旅程", "マイ"),
        "ui": {
            "today": "今日",
            "date": "7月29日 水曜日",
            "energy": "余力",
            "burden": "負担",
            "recovery": "回復",
            "steady": "やや高め",
            "medium": "ほどほど",
            "rising": "回復中",
            "prompt": "今日はどんな一日？",
            "placeholder": "今日の Signal を少し残す…",
            "voice": "音声",
            "status": "状態",
            "schedule": "予定",
            "library": "Signal ライブラリ",
            "timeline": "今日のタイムライン",
            "timeline_item": "午前中に作業を続けて切り替えたあと、2分だけ止まった。",
            "assistant": "AI",
            "assistant_reply": "切り替え続けていたんですね。少し止まれたことも大切です。",
            "state_title": "今日の Signal から見る状態",
            "state_note": "実際の記録から読み取り、新しい Signal に合わせて更新されます。",
            "time_block": "14:30–15:10  集中したい作業の時間",
            "weekly": "週間レビュー",
            "week": "7月27日–8月2日",
            "signal_dist": "今週の Signal 分布",
            "emotion": "気持ちの安定",
            "boundary": "自分の境界",
            "sleep": "食事と睡眠",
            "growth": "成長プラン",
            "pattern": "今週の行動パターン",
            "pattern_1": "予定が密になる",
            "pattern_2": "休憩が縮む",
            "pattern_3": "夜に空回り",
            "result": "今週の実験フィードバック",
            "result_text": "切り替え前の2分休憩は、予定の多い午後ほど役立ちました。",
            "experiment": "生活実験",
            "overview": "実験の概要",
            "small": "小さな実験 · 軽く試す",
            "goal": "目標 · 中長期",
            "small_name": "切り替え前に2分休む",
            "goal_name": "午後に10分間、画面から離れる",
            "attempts": "この期間に4回",
            "helpful": "3回役に立った",
            "load": "ほとんど楽",
            "goal_progress": "今月は8日実行",
            "feedback": "フィードバックの傾向",
            "journey": "旅程",
            "month": "2026年7月",
            "month_overview": "今月の概要",
            "record_days": "記録日",
            "signals": "Signal",
            "themes": "テーマの変化",
            "calendar": "月表示",
            "theme_a": "回復の余白",
            "theme_b": "集中のリズム",
            "theme_c": "人とのつながり",
            "gentle": "やさしい振り返り",
            "gentle_text": "残したいのは、できた量よりも、自分らしくいられた瞬間かもしれません。",
            "pro": "Pro インサイト",
            "deep": "今週の深度分析",
            "relation": "場面・行動・余力・フィードバック",
            "scene": "切り替えが多い",
            "behavior": "そのまま進める",
            "state_word": "負担が上がる",
            "response": "休憩が有効",
            "preference": "行動の好み",
            "preference_text": "負担が軽く、すぐ始められる実験ほど、実感のある反応につながっています。",
            "long_term": "長期の変化",
            "load_suggestion": "来週の負荷：維持",
        },
    },
    "en-US": {
        "marketing": {
            "today": ("Capture today as it really is,\none Signal at a time", "Record what’s happening with text, voice, status, and time use."),
            "state": ("See today’s energy, burden, and recovery\nthrough your Signals", "Your state updates from real records, while AI responds without rushing to conclusions."),
            "weekly": ("Connect this week’s Signals\ninto patterns", "Review facts, behavior patterns, and experiment results, then choose what to carry forward."),
            "experiment": ("Turn patterns into changes\nyou can try", "Use quick tries for the moment, and goals to observe longer-term change."),
            "journey": ("See the path you traced\nthis month", "Use the month view, theme changes, and a gentle reflection to see how life unfolded."),
            "pro": ("Go deeper and longer with Pro", "See this week’s deeper analysis, action preferences, and long-term changes since you started Signal Path."),
        },
        "tabs": ("Today", "Weekly", "Life Experiments", "Journey", "Me"),
        "ui": {
            "today": "Today",
            "date": "Wednesday, July 29",
            "energy": "Energy",
            "burden": "Burden",
            "recovery": "Recovery",
            "steady": "Good",
            "medium": "Moderate",
            "rising": "Recovering",
            "prompt": "How has today been?",
            "placeholder": "Record a Signal from today…",
            "voice": "Voice",
            "status": "Status",
            "schedule": "Time use",
            "library": "Signal Library",
            "timeline": "Today’s timeline",
            "timeline_item": "After several task switches this morning, I paused for two minutes.",
            "assistant": "AI",
            "assistant_reply": "You’ve been handling a lot of switching. Pausing, even briefly, matters.",
            "state_title": "Your state from today’s Signals",
            "state_note": "They update as you add new Signals, based on your real records.",
            "time_block": "2:30–3:10 PM  Focused work",
            "weekly": "Weekly Review",
            "week": "July 27–August 2",
            "signal_dist": "This week’s Signal distribution",
            "emotion": "Emotional steadiness",
            "boundary": "Personal boundaries",
            "sleep": "Food & sleep",
            "growth": "Growth plan",
            "pattern": "Behavior pattern",
            "pattern_1": "Schedule fills up",
            "pattern_2": "Rest gets compressed",
            "pattern_3": "Evening spins out",
            "result": "Experiment feedback",
            "result_text": "A two-minute pause helped most on afternoons with frequent switching.",
            "experiment": "Life Experiments",
            "overview": "Experiment overview",
            "small": "Small experiment · quick try",
            "goal": "Goal · medium- to long-term",
            "small_name": "Pause for two minutes before switching",
            "goal_name": "Take ten screen-free minutes each afternoon",
            "attempts": "4 attempts this round",
            "helpful": "Helped 3 times",
            "load": "Mostly easy",
            "goal_progress": "Completed on 8 days",
            "feedback": "Feedback trend",
            "journey": "Journey",
            "month": "July 2026",
            "month_overview": "Monthly overview",
            "record_days": "Days recorded",
            "signals": "Signals",
            "themes": "Theme changes",
            "calendar": "Month view",
            "theme_a": "Recovery space",
            "theme_b": "Focus rhythm",
            "theme_c": "Connection",
            "gentle": "A gentle reflection",
            "gentle_text": "What mattered most may not be how much you did, but the moments you felt more like yourself.",
            "pro": "Pro insights",
            "deep": "This week’s deeper analysis",
            "relation": "Context, behavior, energy, and feedback",
            "scene": "Frequent switching",
            "behavior": "Keep pushing",
            "state_word": "Burden rises",
            "response": "Pauses help",
            "preference": "Action preferences",
            "preference_text": "Low-burden experiments you can start now are producing the clearest feedback.",
            "long_term": "Long-term change",
            "load_suggestion": "Next week’s load: keep steady",
        },
    },
}


HERO_ASSETS = {
    "today": ASSET_ROOT / "hero_art" / "today-signal-points-v1.png",
    "state": ASSET_ROOT / "hero_art" / "today-signal-points-v1.png",
    "weekly": ASSET_ROOT / "hero_art" / "weekly-review-network-v1.png",
    "experiment": ASSET_ROOT / "experiment" / "life-experiment-branching-v2.png",
    "journey": ASSET_ROOT / "hero_art" / "journey-ring-path-v1.png",
    "pro": ASSET_ROOT / "hero_art" / "weekly-review-network-v1.png",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rgba(color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = color.lstrip("#")
    return (
        int(value[0:2], 16),
        int(value[2:4], 16),
        int(value[4:6], 16),
        alpha,
    )


def locale_font_path(locale: str) -> Path:
    if locale == "ja":
        return FONT_JA
    if locale.startswith("zh"):
        return FONT_ZH
    return FONT_EN


def font(locale: str, size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = locale_font_path(locale)
    index = 0
    if path == FONT_ZH and bold:
        index = 1
    return ImageFont.truetype(str(path), size=size, index=index)


def text_width(draw: ImageDraw.ImageDraw, text: str, text_font: ImageFont.FreeTypeFont) -> float:
    box = draw.textbbox((0, 0), text, font=text_font)
    return float(box[2] - box[0])


def wrap_for_width(
    draw: ImageDraw.ImageDraw,
    text: str,
    text_font: ImageFont.FreeTypeFont,
    max_width: float,
) -> list[str]:
    if not text:
        return [""]
    if "\n" in text:
        hard_lines: list[str] = []
        for part in text.split("\n"):
            hard_lines.extend(wrap_for_width(draw, part, text_font, max_width))
        return hard_lines
    is_latin = any("a" <= char.lower() <= "z" for char in text) and " " in text
    tokens = text.split(" ") if is_latin else list(text)
    separator = " " if is_latin else ""
    lines: list[str] = []
    current = ""
    for token in tokens:
        candidate = token if not current else f"{current}{separator}{token}"
        if text_width(draw, candidate, text_font) <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = token
    if current:
        lines.append(current)
    return lines


def draw_wrapped(
    draw: ImageDraw.ImageDraw,
    xy: tuple[float, float],
    text: str,
    text_font: ImageFont.FreeTypeFont,
    fill: str | tuple[int, int, int, int],
    max_width: float,
    line_gap: float = 1.22,
    max_lines: int | None = None,
) -> float:
    lines = wrap_for_width(draw, text, text_font, max_width)
    if max_lines and len(lines) > max_lines:
        lines = lines[:max_lines]
        while lines and text_width(draw, f"{lines[-1]}…", text_font) > max_width:
            lines[-1] = lines[-1][:-1]
        if lines:
            lines[-1] = f"{lines[-1]}…"
    line_height = text_font.size * line_gap
    x, y = xy
    for line in lines:
        draw.text((x, y), line, font=text_font, fill=fill)
        y += line_height
    return y


def draw_gradient_text(
    image: Image.Image,
    xy: tuple[int, int],
    text: str,
    text_font: ImageFont.FreeTypeFont,
    max_width: int,
    colors: tuple[str, str] = (BLUE, PURPLE),
    line_gap: float = 1.08,
) -> int:
    temp_draw = ImageDraw.Draw(image)
    lines = wrap_for_width(temp_draw, text, text_font, max_width)
    line_height = int(text_font.size * line_gap)
    mask = Image.new("L", image.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    x, y = xy
    for line in lines:
        mask_draw.text((x, y), line, font=text_font, fill=255)
        y += line_height
    gradient = Image.new("RGBA", image.size, rgba(colors[0]))
    grad_pixels = gradient.load()
    c1 = rgba(colors[0])
    c2 = rgba(colors[1])
    start_x = xy[0]
    span = max(max_width, 1)
    for px in range(start_x, min(image.width, start_x + max_width + 1)):
        ratio = (px - start_x) / span
        color = tuple(int(c1[i] * (1 - ratio) + c2[i] * ratio) for i in range(4))
        for py in range(xy[1], min(image.height, y + 8)):
            grad_pixels[px, py] = color
    image.alpha_composite(Image.composite(gradient, Image.new("RGBA", image.size), mask))
    return y


def rounded_layer(
    size: tuple[int, int],
    box: tuple[int, int, int, int],
    radius: int,
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int] | None = None,
    width: int = 1,
    blur: int = 0,
) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)
    return layer.filter(ImageFilter.GaussianBlur(blur)) if blur else layer


def glass_card(
    image: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    fill: tuple[int, int, int, int] = (255, 255, 255, 225),
    outline: tuple[int, int, int, int] = (255, 255, 255, 245),
    shadow: bool = True,
) -> None:
    if shadow:
        shadow_box = (box[0] + 5, box[1] + 14, box[2] + 5, box[3] + 14)
        image.alpha_composite(
            rounded_layer(
                image.size,
                shadow_box,
                radius,
                (86, 75, 168, 28),
                blur=max(10, radius // 5),
            )
        )
    image.alpha_composite(rounded_layer(image.size, box, radius, fill, outline, max(2, radius // 20)))


def paste_cover(image: Image.Image, asset_path: Path, opacity: float = 1.0) -> None:
    asset = Image.open(asset_path).convert("RGBA")
    source_ratio = asset.width / asset.height
    target_ratio = image.width / image.height
    if source_ratio > target_ratio:
        new_height = image.height
        new_width = round(new_height * source_ratio)
    else:
        new_width = image.width
        new_height = round(new_width / source_ratio)
    asset = asset.resize((new_width, new_height), Image.Resampling.LANCZOS)
    x = (image.width - new_width) // 2
    y = (image.height - new_height) // 2
    if opacity < 1:
        asset.putalpha(asset.getchannel("A").point(lambda value: int(value * opacity)))
    image.alpha_composite(asset, (x, y))


def paste_contain(
    image: Image.Image,
    asset_path: Path,
    box: tuple[int, int, int, int],
    radius: int = 0,
    opacity: float = 1.0,
) -> None:
    asset = Image.open(asset_path).convert("RGBA")
    max_width = box[2] - box[0]
    max_height = box[3] - box[1]
    ratio = min(max_width / asset.width, max_height / asset.height)
    size = (max(1, int(asset.width * ratio)), max(1, int(asset.height * ratio)))
    asset = asset.resize(size, Image.Resampling.LANCZOS)
    if opacity < 1:
        asset.putalpha(asset.getchannel("A").point(lambda value: int(value * opacity)))
    if radius:
        mask = Image.new("L", size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
        asset.putalpha(Image.composite(asset.getchannel("A"), Image.new("L", size), mask))
    x = box[0] + (max_width - size[0]) // 2
    y = box[1] + (max_height - size[1]) // 2
    image.alpha_composite(asset, (x, y))


def draw_pill(
    image: Image.Image,
    box: tuple[int, int, int, int],
    text: str,
    locale: str,
    color: str,
    text_color: str | None = None,
    size: int = 34,
) -> None:
    glass_card(
        image,
        box,
        max(16, (box[3] - box[1]) // 2),
        fill=rgba(color, 35),
        outline=rgba(color, 75),
        shadow=False,
    )
    draw = ImageDraw.Draw(image)
    text_font = font(locale, size, bold=True)
    width = text_width(draw, text, text_font)
    x = box[0] + ((box[2] - box[0]) - width) / 2
    y = box[1] + ((box[3] - box[1]) - size) / 2 - 4
    draw.text((x, y), text, font=text_font, fill=text_color or color)


def draw_check_mark(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    size: float,
    color: str,
    width: int,
) -> None:
    cx, cy = center
    points = (
        (cx - size * 0.42, cy),
        (cx - size * 0.10, cy + size * 0.30),
        (cx + size * 0.48, cy - size * 0.36),
    )
    draw.line(points, fill=color, width=max(2, width), joint="curve")


def draw_action_icon(
    draw: ImageDraw.ImageDraw,
    kind: str,
    center: tuple[int, int],
    size: int,
    color: str,
) -> None:
    cx, cy = center
    line_width = max(3, size // 11)
    if kind == "voice":
        body = (cx - size * 0.18, cy - size * 0.34, cx + size * 0.18, cy + size * 0.12)
        draw.rounded_rectangle(body, radius=max(5, size // 7), outline=color, width=line_width)
        draw.arc(
            (cx - size * 0.32, cy - size * 0.08, cx + size * 0.32, cy + size * 0.34),
            start=0,
            end=180,
            fill=color,
            width=line_width,
        )
        draw.line((cx, cy + size * 0.30, cx, cy + size * 0.46), fill=color, width=line_width)
        draw.line((cx - size * 0.18, cy + size * 0.46, cx + size * 0.18, cy + size * 0.46), fill=color, width=line_width)
    elif kind == "status":
        r = size * 0.42
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=color, width=line_width)
        eye_r = max(2, size // 18)
        draw.ellipse((cx - size * 0.17 - eye_r, cy - size * 0.10 - eye_r, cx - size * 0.17 + eye_r, cy - size * 0.10 + eye_r), fill=color)
        draw.ellipse((cx + size * 0.17 - eye_r, cy - size * 0.10 - eye_r, cx + size * 0.17 + eye_r, cy - size * 0.10 + eye_r), fill=color)
        draw.arc(
            (cx - size * 0.22, cy - size * 0.03, cx + size * 0.22, cy + size * 0.28),
            start=15,
            end=165,
            fill=color,
            width=line_width,
        )
    elif kind == "schedule":
        box = (cx - size * 0.42, cy - size * 0.34, cx + size * 0.42, cy + size * 0.40)
        draw.rounded_rectangle(box, radius=max(4, size // 9), outline=color, width=line_width)
        draw.line((box[0], cy - size * 0.12, box[2], cy - size * 0.12), fill=color, width=line_width)
        for offset in (-0.22, 0.0, 0.22):
            draw.line(
                (cx + size * offset, cy - size * 0.45, cx + size * offset, cy - size * 0.26),
                fill=color,
                width=line_width,
            )
        for row in (0.05, 0.23):
            for col in (-0.22, 0.0, 0.22):
                r = max(2, size // 24)
                px, py = cx + size * col, cy + size * row
                draw.ellipse((px - r, py - r, px + r, py + r), fill=color)
    elif kind == "library":
        heights = (0.28, 0.58, 0.82, 0.48, 0.68, 0.34)
        step = size * 0.17
        start = cx - step * (len(heights) - 1) / 2
        for index, height in enumerate(heights):
            px = start + index * step
            draw.rounded_rectangle(
                (px - line_width / 2, cy - size * height / 2, px + line_width / 2, cy + size * height / 2),
                radius=max(2, line_width // 2),
                fill=color,
            )


def draw_nav_icon(
    draw: ImageDraw.ImageDraw,
    index: int,
    center: tuple[int, int],
    size: int,
    color: str,
) -> None:
    cx, cy = center
    width = max(3, size // 10)
    if index == 0:
        core = size * 0.18
        draw.ellipse((cx - core, cy - core, cx + core, cy + core), fill=color)
        orbit = size * 0.38
        for angle in range(0, 360, 45):
            radians = math.radians(angle)
            px = cx + math.cos(radians) * orbit
            py = cy + math.sin(radians) * orbit
            r = max(2, size // 18)
            draw.ellipse((px - r, py - r, px + r, py + r), fill=color)
    elif index == 1:
        heights = (0.48, 0.80, 0.62)
        for item, height in enumerate(heights):
            left = cx - size * 0.38 + item * size * 0.28
            draw.rounded_rectangle(
                (left, cy + size * 0.36 - size * height, left + size * 0.16, cy + size * 0.36),
                radius=max(3, size // 14),
                fill=color,
            )
    elif index == 2:
        draw.line((cx - size * 0.12, cy - size * 0.42, cx + size * 0.12, cy - size * 0.42), fill=color, width=width)
        draw.line((cx - size * 0.06, cy - size * 0.42, cx - size * 0.06, cy - size * 0.12), fill=color, width=width)
        draw.line((cx + size * 0.06, cy - size * 0.42, cx + size * 0.06, cy - size * 0.12), fill=color, width=width)
        body = (
            (cx - size * 0.06, cy - size * 0.12),
            (cx - size * 0.36, cy + size * 0.40),
            (cx + size * 0.36, cy + size * 0.40),
            (cx + size * 0.06, cy - size * 0.12),
        )
        draw.line((*body, body[0]), fill=color, width=width, joint="curve")
        draw.line((cx - size * 0.25, cy + size * 0.17, cx + size * 0.25, cy + size * 0.17), fill=color, width=width)
    elif index == 3:
        radius = size * 0.42
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=color, width=width)
        needle = (
            (cx + size * 0.18, cy - size * 0.28),
            (cx + size * 0.02, cy + size * 0.04),
            (cx - size * 0.20, cy + size * 0.27),
            (cx - size * 0.03, cy - size * 0.04),
        )
        draw.polygon(needle, fill=color)
    else:
        head = size * 0.18
        draw.ellipse((cx - head, cy - size * 0.40, cx + head, cy - size * 0.04), outline=color, width=width)
        draw.arc(
            (cx - size * 0.38, cy - size * 0.02, cx + size * 0.38, cy + size * 0.62),
            start=195,
            end=345,
            fill=color,
            width=width,
        )


def draw_icon_tile(
    image: Image.Image,
    box: tuple[int, int, int, int],
    kind: str,
    label: str,
    locale: str,
    color: str,
    symbol_size: int = 42,
) -> None:
    glass_card(image, box, max(24, (box[2] - box[0]) // 7), fill=(255, 255, 255, 196), shadow=False)
    draw = ImageDraw.Draw(image)
    cx = (box[0] + box[2]) // 2
    top = box[1] + int((box[3] - box[1]) * 0.14)
    r = int((box[3] - box[1]) * 0.18)
    draw.ellipse((cx - r, top, cx + r, top + 2 * r), fill=rgba(color, 40), outline=rgba(color, 100), width=2)
    draw_action_icon(draw, kind, (cx, top + r), max(26, int(symbol_size * 0.92)), color)
    label_font = font(locale, max(24, int(symbol_size * 0.58)), bold=True)
    lw = text_width(draw, label, label_font)
    draw.text((cx - lw / 2, box[3] - label_font.size - 22), label, font=label_font, fill=TEXT)


def draw_status_chip(
    image: Image.Image,
    box: tuple[int, int, int, int],
    title: str,
    value: str,
    locale: str,
    color: str,
) -> None:
    glass_card(image, box, 30, fill=rgba(WHITE, 208), outline=rgba(color, 65), shadow=False)
    draw = ImageDraw.Draw(image)
    dot = 18
    draw.ellipse((box[0] + 24, box[1] + 28, box[0] + 24 + dot, box[1] + 28 + dot), fill=color)
    draw.text((box[0] + 54, box[1] + 17), title, font=font(locale, 28, True), fill=TEXT)
    draw.text((box[0] + 54, box[1] + 56), value, font=font(locale, 27, True), fill=color)


def draw_timeline_entry(
    image: Image.Image,
    box: tuple[int, int, int, int],
    locale: str,
    time_label: str,
    title: str,
    reply: str,
    color: str,
    scale: float,
) -> None:
    draw = ImageDraw.Draw(image)
    x1, y1, x2, y2 = box
    time_font = font(locale, int(23 * scale), True)
    title_font = font(locale, int(27 * scale), True)
    reply_font = font(locale, int(23 * scale), False)
    draw.text((x1, y1 + int(8 * scale)), time_label, font=time_font, fill=MUTED)
    dot_x = x1 + int(112 * scale)
    dot_y = y1 + int(23 * scale)
    dot_r = int(10 * scale)
    draw.ellipse(
        (dot_x - dot_r, dot_y - dot_r, dot_x + dot_r, dot_y + dot_r),
        fill=WHITE,
        outline=color,
        width=max(3, int(4 * scale)),
    )
    content_x = x1 + int(150 * scale)
    title_bottom = draw_wrapped(
        draw,
        (content_x, y1),
        title,
        title_font,
        TEXT,
        x2 - content_x,
        line_gap=1.15,
        max_lines=2,
    )
    reply_top = max(y1 + int(62 * scale), int(title_bottom + 12 * scale))
    reply_box = (content_x, reply_top, x2, min(y2, reply_top + int(92 * scale)))
    glass_card(
        image,
        reply_box,
        int(24 * scale),
        fill=rgba(color, 24),
        outline=rgba(color, 42),
        shadow=False,
    )
    draw_wrapped(
        draw,
        (reply_box[0] + int(18 * scale), reply_box[1] + int(12 * scale)),
        reply,
        reply_font,
        TEXT,
        reply_box[2] - reply_box[0] - int(36 * scale),
        line_gap=1.12,
        max_lines=2,
    )


def draw_progress_row(
    image: Image.Image,
    box: tuple[int, int, int, int],
    label: str,
    value: int,
    maximum: int,
    locale: str,
    color: str,
) -> None:
    draw = ImageDraw.Draw(image)
    draw.text((box[0], box[1]), label, font=font(locale, 30, True), fill=TEXT)
    count = str(value)
    count_font = font(locale, 30, True)
    draw.text((box[2] - text_width(draw, count, count_font), box[1]), count, font=count_font, fill=TEXT)
    y = box[1] + 52
    draw.rounded_rectangle((box[0], y, box[2], y + 16), radius=8, fill=rgba("#E9E8F6"))
    fill_width = max(16, int((box[2] - box[0]) * value / maximum))
    draw.rounded_rectangle((box[0], y, box[0] + fill_width, y + 16), radius=8, fill=color)


def draw_line_chart(
    image: Image.Image,
    box: tuple[int, int, int, int],
    values: Iterable[float],
    colors: tuple[str, str] = (PURPLE, ORANGE),
    dots: bool = True,
) -> None:
    values = tuple(values)
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    x1, y1, x2, y2 = box
    for index in range(4):
        y = y1 + int((y2 - y1) * index / 3)
        draw.line((x1, y, x2, y), fill=rgba("#DCDDF0", 130), width=2)
    points: list[tuple[int, int]] = []
    low, high = min(values), max(values)
    spread = max(high - low, 1)
    for index, value in enumerate(values):
        x = x1 + int((x2 - x1) * index / max(len(values) - 1, 1))
        normalized = (value - low) / spread
        y = y2 - int((y2 - y1) * (0.18 + normalized * 0.64))
        points.append((x, y))
    if len(points) > 1:
        draw.line(points, fill=rgba(colors[0], 230), width=max(5, (x2 - x1) // 150), joint="curve")
    if dots:
        for index, point in enumerate(points):
            radius = max(8, (x2 - x1) // 85)
            color = colors[index % len(colors)]
            draw.ellipse(
                (point[0] - radius, point[1] - radius, point[0] + radius, point[1] + radius),
                fill=color,
                outline=WHITE,
                width=max(3, radius // 3),
            )
    image.alpha_composite(overlay)


def draw_donut(
    image: Image.Image,
    box: tuple[int, int, int, int],
    values: tuple[int, ...],
    colors: tuple[str, ...],
    width: int,
) -> None:
    draw = ImageDraw.Draw(image)
    total = sum(values)
    start = -90.0
    for value, color in zip(values, colors):
        sweep = 360.0 * value / total
        draw.arc(box, start=start, end=start + sweep - 2, fill=color, width=width)
        start += sweep
    inner = (box[0] + width, box[1] + width, box[2] - width, box[3] - width)
    draw.ellipse(inner, fill=rgba(WHITE, 40))


def draw_network(
    image: Image.Image,
    box: tuple[int, int, int, int],
    labels: tuple[str, ...],
    locale: str,
) -> None:
    draw = ImageDraw.Draw(image)
    x1, y1, x2, y2 = box
    centers = (
        (x1 + int((x2 - x1) * 0.18), y1 + int((y2 - y1) * 0.28)),
        (x1 + int((x2 - x1) * 0.52), y1 + int((y2 - y1) * 0.18)),
        (x1 + int((x2 - x1) * 0.82), y1 + int((y2 - y1) * 0.42)),
        (x1 + int((x2 - x1) * 0.57), y1 + int((y2 - y1) * 0.76)),
    )
    for first, second in ((0, 1), (1, 2), (2, 3), (3, 0), (1, 3)):
        draw.line((*centers[first], *centers[second]), fill=rgba(PURPLE, 85), width=5)
    colors = (ORANGE, PURPLE, BLUE, MINT)
    for center, label, color in zip(centers, labels, colors):
        radius = max(30, (x2 - x1) // 16)
        draw.ellipse(
            (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius),
            fill=rgba(color, 55),
            outline=color,
            width=5,
        )
        label_font = font(locale, max(20, radius // 3), True)
        wrapped = wrap_for_width(draw, label, label_font, radius * 1.75)
        y = center[1] - len(wrapped) * label_font.size * 0.54
        for line in wrapped[:2]:
            w = text_width(draw, line, label_font)
            draw.text((center[0] - w / 2, y), line, font=label_font, fill=TEXT)
            y += label_font.size * 1.08


def draw_marketing_header(
    image: Image.Image,
    locale: str,
    page: str,
    device: Device,
) -> tuple[int, int]:
    draw = ImageDraw.Draw(image)
    margin = 82 if not device.tablet else 120
    top = 105 if not device.tablet else 80
    title, subtitle = COPY[locale]["marketing"][page]
    draw_pill(
        image,
        (margin, top, margin + (260 if not device.tablet else 310), top + 64),
        "Signal Path",
        locale,
        PURPLE,
        size=27 if not device.tablet else 31,
    )
    number = f"{list(key for _, key in PAGE_SPECS).index(page) + 1:02d} / 06"
    number_font = font(locale, 28 if not device.tablet else 32, True)
    draw.text(
        (image.width - margin - text_width(draw, number, number_font), top + 12),
        number,
        font=number_font,
        fill=rgba(PURPLE, 210),
    )
    title_y = top + 105
    title_size = 76 if not device.tablet else 80
    max_width = image.width - margin * 2
    if locale == "en-US":
        title_size -= 5
    if page == "experiment":
        # Keep the paired idea ("patterns" → "change") together.  The larger
        # default size left a single CJK character orphaned on iPhone.
        title_size -= 10 if not device.tablet else 7
    title_font = font(locale, title_size, True)
    title_bottom = draw_gradient_text(image, (margin, title_y), title, title_font, max_width)
    subtitle_font = font(locale, 36 if not device.tablet else 38, False)
    subtitle_bottom = draw_wrapped(
        draw,
        (margin, title_bottom + 32),
        subtitle,
        subtitle_font,
        TEXT,
        max_width * (0.92 if device.tablet else 1),
        line_gap=1.28,
        max_lines=3,
    )
    return margin, int(subtitle_bottom + (48 if not device.tablet else 34))


def draw_nav(
    image: Image.Image,
    box: tuple[int, int, int, int],
    locale: str,
    selected: int,
) -> None:
    glass_card(image, box, max(34, (box[3] - box[1]) // 3), fill=(253, 253, 255, 235))
    draw = ImageDraw.Draw(image)
    tabs = COPY[locale]["tabs"]
    slot = (box[2] - box[0]) / len(tabs)
    icon_size = 34 if box[2] - box[0] < 1300 else 42
    for index, label in enumerate(tabs):
        cx = box[0] + slot * (index + 0.5)
        color = PURPLE if index == selected else "#8B90A6"
        label_font = font(locale, 22 if box[2] - box[0] < 1300 else 27, True)
        lw = text_width(draw, label, label_font)
        draw_nav_icon(draw, index, (int(cx), box[1] + 39), icon_size, color)
        draw.text((cx - lw / 2, box[1] + 66), label, font=label_font, fill=color)


def draw_app_shell(
    image: Image.Image,
    locale: str,
    page: str,
    device: Device,
    start_y: int,
) -> tuple[tuple[int, int, int, int], tuple[int, int, int, int]]:
    margin = 58 if not device.tablet else 92
    bottom = image.height - (76 if not device.tablet else 70)
    shell_box = (margin, start_y, image.width - margin, bottom)
    glass_card(image, shell_box, 62 if not device.tablet else 70, fill=(255, 255, 255, 214))
    nav_height = 142 if not device.tablet else 150
    nav_box = (
        shell_box[0] + 22,
        shell_box[3] - nav_height - 20,
        shell_box[2] - 22,
        shell_box[3] - 20,
    )
    selected_map = {"today": 0, "state": 0, "weekly": 1, "experiment": 2, "journey": 3, "pro": 4}
    draw_nav(image, nav_box, locale, selected_map[page])
    body = (
        shell_box[0] + (34 if not device.tablet else 46),
        shell_box[1] + (30 if not device.tablet else 36),
        shell_box[2] - (34 if not device.tablet else 46),
        nav_box[1] - 26,
    )
    return shell_box, body


def render_today(
    image: Image.Image,
    locale: str,
    body: tuple[int, int, int, int],
    device: Device,
) -> None:
    ui = COPY[locale]["ui"]
    draw = ImageDraw.Draw(image)
    x1, y1, x2, y2 = body
    scale = 1.0 if not device.tablet else 1.2
    draw.text((x1, y1), ui["today"], font=font(locale, int(58 * scale), True), fill=NAVY)
    draw.text((x1, y1 + int(74 * scale)), ui["date"], font=font(locale, int(27 * scale), True), fill=TEXT)
    status_y = y1 + int(126 * scale)
    gap = int(12 * scale)
    chip_width = int((x2 - x1 - gap * 2) / 3)
    for index, (title, value, color) in enumerate(
        (
            (ui["energy"], ui["steady"], BLUE),
            (ui["burden"], ui["medium"], ORANGE),
            (ui["recovery"], ui["rising"], MINT),
        )
    ):
        left = x1 + index * (chip_width + gap)
        draw_status_chip(
            image,
            (left, status_y, left + chip_width, status_y + int(106 * scale)),
            title,
            value,
            locale,
            color,
        )
    prompt_y = status_y + int(132 * scale)
    prompt_h = int(330 * scale if not device.tablet else 300 * scale)
    glass_card(image, (x1, prompt_y, x2, prompt_y + prompt_h), int(42 * scale), fill=(255, 255, 255, 226))
    draw.text(
        (x1 + int(34 * scale), prompt_y + int(28 * scale)),
        ui["prompt"],
        font=font(locale, int(36 * scale), True),
        fill=PURPLE,
    )
    input_box = (
        x1 + int(28 * scale),
        prompt_y + int(86 * scale),
        x2 - int(28 * scale),
        prompt_y + int(170 * scale),
    )
    glass_card(image, input_box, int(36 * scale), fill=(250, 250, 255, 225), shadow=False)
    draw.text(
        (input_box[0] + int(28 * scale), input_box[1] + int(20 * scale)),
        ui["placeholder"],
        font=font(locale, int(29 * scale)),
        fill=MUTED,
    )
    button_size = int(68 * scale)
    button_box = (
        input_box[2] - button_size - int(9 * scale),
        input_box[1] + int(8 * scale),
        input_box[2] - int(9 * scale),
        input_box[1] + int(8 * scale) + button_size,
    )
    draw.rounded_rectangle(button_box, radius=int(23 * scale), fill=PURPLE)
    draw_check_mark(
        draw,
        ((button_box[0] + button_box[2]) / 2, (button_box[1] + button_box[3]) / 2),
        int(30 * scale),
        WHITE,
        int(6 * scale),
    )
    action_y = prompt_y + int(190 * scale)
    action_gap = int(10 * scale)
    action_width = int((x2 - x1 - int(56 * scale) - action_gap * 3) / 4)
    for index, (kind, label, color) in enumerate(
        (
            ("voice", ui["voice"], PURPLE),
            ("status", ui["status"], ORANGE),
            ("schedule", ui["schedule"], BLUE),
            ("library", ui["library"], CYAN),
        )
    ):
        left = x1 + int(28 * scale) + index * (action_width + action_gap)
        draw_icon_tile(
            image,
            (left, action_y, left + action_width, action_y + int(112 * scale)),
            kind,
            label,
            locale,
            color,
            int(32 * scale),
        )
    timeline_y = prompt_y + prompt_h + int(26 * scale)
    glass_card(image, (x1, timeline_y, x2, y2), int(42 * scale), fill=(255, 255, 255, 218))
    draw.text(
        (x1 + int(34 * scale), timeline_y + int(28 * scale)),
        ui["timeline"],
        font=font(locale, int(35 * scale), True),
        fill=NAVY,
    )
    extra = EXTRA_COPY[locale]
    list_top = timeline_y + int(94 * scale)
    list_bottom = y2 - int(32 * scale)
    entry_height = int((list_bottom - list_top) / 3)
    dot_x = x1 + int(140 * scale)
    draw.line(
        (dot_x, list_top + int(20 * scale), dot_x, list_bottom - int(38 * scale)),
        fill=rgba(PURPLE, 55),
        width=int(3 * scale),
    )
    entries = (
        ("09:20", ui["timeline_item"], ui["assistant_reply"], PURPLE),
        ("14:30", extra["timeline_second"], extra["reply_second"], BLUE),
        ("18:40", extra["timeline_third"], extra["reply_third"], MINT),
    )
    for index, (time_label, title, reply, color) in enumerate(entries):
        top = list_top + index * entry_height
        draw_timeline_entry(
            image,
            (x1 + int(28 * scale), top, x2 - int(30 * scale), top + entry_height - int(18 * scale)),
            locale,
            time_label,
            title,
            reply,
            color,
            scale,
        )


def render_state(
    image: Image.Image,
    locale: str,
    body: tuple[int, int, int, int],
    device: Device,
) -> None:
    ui = COPY[locale]["ui"]
    draw = ImageDraw.Draw(image)
    x1, y1, x2, y2 = body
    scale = 1.0 if not device.tablet else 1.18
    draw.text((x1, y1), ui["today"], font=font(locale, int(54 * scale), True), fill=NAVY)
    draw.text((x1, y1 + int(70 * scale)), ui["date"], font=font(locale, int(27 * scale), True), fill=TEXT)
    state_y = y1 + int(122 * scale)
    state_h = int(370 * scale)
    glass_card(image, (x1, state_y, x2, state_y + state_h), int(44 * scale), fill=(255, 255, 255, 224))
    draw.text(
        (x1 + int(34 * scale), state_y + int(30 * scale)),
        ui["state_title"],
        font=font(locale, int(36 * scale), True),
        fill=PURPLE,
    )
    chip_y = state_y + int(102 * scale)
    gap = int(14 * scale)
    chip_width = int((x2 - x1 - int(68 * scale) - gap * 2) / 3)
    for index, (title, value, color) in enumerate(
        (
            (ui["energy"], ui["steady"], BLUE),
            (ui["burden"], ui["medium"], ORANGE),
            (ui["recovery"], ui["rising"], MINT),
        )
    ):
        left = x1 + int(34 * scale) + index * (chip_width + gap)
        draw_status_chip(
            image,
            (left, chip_y, left + chip_width, chip_y + int(118 * scale)),
            title,
            value,
            locale,
            color,
        )
    draw_wrapped(
        draw,
        (x1 + int(34 * scale), state_y + int(248 * scale)),
        ui["state_note"],
        font(locale, int(25 * scale)),
        MUTED,
        x2 - x1 - int(68 * scale),
        max_lines=2,
    )
    response_y = state_y + state_h + int(26 * scale)
    response_h = int(250 * scale)
    glass_card(image, (x1, response_y, x2, response_y + response_h), int(42 * scale), fill=(255, 255, 255, 220))
    draw_pill(
        image,
        (x1 + int(30 * scale), response_y + int(24 * scale), x1 + int(235 * scale), response_y + int(82 * scale)),
        ui["assistant"],
        locale,
        PURPLE,
        size=int(25 * scale),
    )
    draw_wrapped(
        draw,
        (x1 + int(34 * scale), response_y + int(108 * scale)),
        ui["assistant_reply"],
        font(locale, int(30 * scale), True),
        TEXT,
        x2 - x1 - int(70 * scale),
        max_lines=2,
    )
    timeline_y = response_y + response_h + int(26 * scale)
    glass_card(image, (x1, timeline_y, x2, y2), int(42 * scale), fill=(255, 255, 255, 218))
    draw.text(
        (x1 + int(34 * scale), timeline_y + int(28 * scale)),
        ui["timeline"],
        font=font(locale, int(35 * scale), True),
        fill=NAVY,
    )
    block_box = (
        x1 + int(32 * scale),
        timeline_y + int(94 * scale),
        x2 - int(32 * scale),
        timeline_y + int(200 * scale),
    )
    glass_card(image, block_box, int(28 * scale), fill=rgba(BLUE, 28), outline=rgba(BLUE, 65), shadow=False)
    draw.rounded_rectangle(
        (
            block_box[0] + int(18 * scale),
            block_box[1] + int(16 * scale),
            block_box[0] + int(28 * scale),
            block_box[3] - int(16 * scale),
        ),
        radius=int(5 * scale),
        fill=BLUE,
    )
    draw.text(
        (block_box[0] + int(48 * scale), block_box[1] + int(30 * scale)),
        ui["time_block"],
        font=font(locale, int(27 * scale), True),
        fill=TEXT,
    )
    extra = EXTRA_COPY[locale]
    list_top = block_box[3] + int(34 * scale)
    list_bottom = y2 - int(30 * scale)
    entry_height = int((list_bottom - list_top) / 2)
    line_x = x1 + int(172 * scale)
    draw.line(
        (line_x, list_top + int(20 * scale), line_x, list_bottom - int(30 * scale)),
        fill=rgba(MINT, 55),
        width=max(3, int(3 * scale)),
    )
    for index, (time_label, title, reply, color) in enumerate(
        (
            ("11:10", ui["timeline_item"], ui["assistant_reply"], MINT),
            ("17:45", extra["timeline_third"], extra["reply_third"], PURPLE),
        )
    ):
        top = list_top + index * entry_height
        draw_timeline_entry(
            image,
            (x1 + int(60 * scale), top, x2 - int(30 * scale), top + entry_height - int(16 * scale)),
            locale,
            time_label,
            title,
            reply,
            color,
            scale,
        )


def render_weekly(
    image: Image.Image,
    locale: str,
    body: tuple[int, int, int, int],
    device: Device,
) -> None:
    ui = COPY[locale]["ui"]
    draw = ImageDraw.Draw(image)
    x1, y1, x2, y2 = body
    scale = 1.0 if not device.tablet else 1.12
    draw.text((x1, y1), ui["weekly"], font=font(locale, int(50 * scale), True), fill=NAVY)
    draw_pill(
        image,
        (x2 - int(330 * scale), y1 - int(2 * scale), x2, y1 + int(62 * scale)),
        ui["week"],
        locale,
        PURPLE,
        size=int(24 * scale),
    )
    top_y = y1 + int(94 * scale)
    if device.tablet:
        left_box = (x1, top_y, x1 + int((x2 - x1) * 0.45), top_y + int(530 * scale))
        right_box = (left_box[2] + int(24 * scale), top_y, x2, top_y + int(530 * scale))
    else:
        left_box = (x1, top_y, x2, top_y + int(430 * scale))
        right_box = (x1, left_box[3] + int(24 * scale), x2, left_box[3] + int(470 * scale))
    glass_card(image, left_box, int(40 * scale), fill=(255, 255, 255, 223))
    draw.text(
        (left_box[0] + int(30 * scale), left_box[1] + int(28 * scale)),
        ui["signal_dist"],
        font=font(locale, int(34 * scale), True),
        fill=NAVY,
    )
    donut_size = int(210 * scale)
    donut_box = (
        left_box[0] + int(30 * scale),
        left_box[1] + int(108 * scale),
        left_box[0] + int(30 * scale) + donut_size,
        left_box[1] + int(108 * scale) + donut_size,
    )
    draw_donut(image, donut_box, (8, 5, 4, 3), (ORANGE, PURPLE, CYAN, BLUE), int(34 * scale))
    list_x = donut_box[2] + int(42 * scale)
    list_width = left_box[2] - list_x - int(28 * scale)
    for index, (label, value, color) in enumerate(
        (
            (ui["emotion"], 8, ORANGE),
            (ui["boundary"], 5, PURPLE),
            (ui["sleep"], 4, CYAN),
            (ui["growth"], 3, BLUE),
        )
    ):
        row_y = left_box[1] + int((108 + index * 72) * scale)
        draw_progress_row(
            image,
            (list_x, row_y, list_x + list_width, row_y + int(70 * scale)),
            label,
            value,
            9,
            locale,
            color,
        )
    glass_card(image, right_box, int(40 * scale), fill=(255, 255, 255, 223))
    draw.text(
        (right_box[0] + int(30 * scale), right_box[1] + int(28 * scale)),
        ui["pattern"],
        font=font(locale, int(34 * scale), True),
        fill=NAVY,
    )
    draw_network(
        image,
        (
            right_box[0] + int(36 * scale),
            right_box[1] + int(96 * scale),
            right_box[2] - int(36 * scale),
            right_box[3] - int(24 * scale),
        ),
        (ui["pattern_1"], ui["pattern_2"], ui["pattern_3"], ui["recovery"]),
        locale,
    )
    result_y = (max(left_box[3], right_box[3]) if device.tablet else right_box[3]) + int(24 * scale)
    glass_card(image, (x1, result_y, x2, y2), int(40 * scale), fill=(255, 255, 255, 218))
    draw.text(
        (x1 + int(30 * scale), result_y + int(26 * scale)),
        ui["result"],
        font=font(locale, int(34 * scale), True),
        fill=NAVY,
    )
    art_box = (
        x1 + int(28 * scale),
        result_y + int(88 * scale),
        x1 + int(220 * scale),
        result_y + int(280 * scale),
    )
    paste_contain(
        image,
        ASSET_ROOT / "weekly" / "weekly-review-break-goal-smaller-effective.png",
        art_box,
        radius=int(36 * scale),
    )
    draw_wrapped(
        draw,
        (art_box[2] + int(28 * scale), result_y + int(96 * scale)),
        ui["result_text"],
        font(locale, int(30 * scale), True),
        TEXT,
        x2 - art_box[2] - int(58 * scale),
        max_lines=3,
    )
    draw_pill(
        image,
        (
            art_box[2] + int(28 * scale),
            result_y + int(238 * scale),
            art_box[2] + int(265 * scale),
            result_y + int(298 * scale),
        ),
        ui["helpful"],
        locale,
        MINT,
        size=int(24 * scale),
    )
    extra = EXTRA_COPY[locale]
    metrics_y = result_y + int(340 * scale)
    metric_gap = int(12 * scale)
    metric_width = int((x2 - x1 - int(60 * scale) - metric_gap * 2) / 3)
    for index, (label, color) in enumerate(
        (
            (extra["weekly_days"], BLUE),
            (extra["weekly_done"], PURPLE),
            (extra["feedback_1"], MINT),
        )
    ):
        left = x1 + int(30 * scale) + index * (metric_width + metric_gap)
        draw_pill(
            image,
            (left, metrics_y, left + metric_width, metrics_y + int(62 * scale)),
            label,
            locale,
            color,
            size=int(22 * scale),
        )
    conclusion_top = metrics_y + int(86 * scale)
    conclusion_bottom = y2 - int(30 * scale)
    if conclusion_bottom - conclusion_top > int(170 * scale):
        glass_card(
            image,
            (x1 + int(28 * scale), conclusion_top, x2 - int(28 * scale), conclusion_bottom),
            int(34 * scale),
            fill=rgba(PURPLE, 20),
            outline=rgba(PURPLE, 42),
            shadow=False,
        )
        draw.text(
            (x1 + int(56 * scale), conclusion_top + int(28 * scale)),
            extra["weekly_conclusion"],
            font=font(locale, int(29 * scale), True),
            fill=PURPLE,
        )
        summary_bottom = draw_wrapped(
            draw,
            (x1 + int(56 * scale), conclusion_top + int(84 * scale)),
            extra["weekly_conclusion_text"],
            font(locale, int(27 * scale), True),
            TEXT,
            x2 - x1 - int(112 * scale),
            line_gap=1.22,
            max_lines=3,
        )
        next_top = max(conclusion_top + int(208 * scale), int(summary_bottom + 26 * scale))
        if next_top + int(104 * scale) < conclusion_bottom:
            draw.rounded_rectangle(
                (
                    x1 + int(52 * scale),
                    next_top,
                    x2 - int(52 * scale),
                    min(conclusion_bottom - int(26 * scale), next_top + int(132 * scale)),
                ),
                radius=int(28 * scale),
                fill=rgba(MINT, 28),
                outline=rgba(MINT, 55),
                width=max(2, int(2 * scale)),
            )
            draw.text(
                (x1 + int(78 * scale), next_top + int(18 * scale)),
                extra["weekly_next"],
                font=font(locale, int(25 * scale), True),
                fill=MINT,
            )
            draw_wrapped(
                draw,
                (x1 + int(78 * scale), next_top + int(58 * scale)),
                extra["weekly_next_text"],
                font(locale, int(23 * scale)),
                TEXT,
                x2 - x1 - int(156 * scale),
                max_lines=2,
            )


def render_experiment(
    image: Image.Image,
    locale: str,
    body: tuple[int, int, int, int],
    device: Device,
) -> None:
    ui = COPY[locale]["ui"]
    draw = ImageDraw.Draw(image)
    x1, y1, x2, y2 = body
    scale = 1.0 if not device.tablet else 1.12
    draw.text((x1, y1), ui["experiment"], font=font(locale, int(50 * scale), True), fill=NAVY)
    draw.text(
        (x1, y1 + int(67 * scale)),
        ui["overview"],
        font=font(locale, int(27 * scale), True),
        fill=MUTED,
    )
    summary_y = y1 + int(115 * scale)
    gap = int(14 * scale)
    card_width = int((x2 - x1 - gap * 2) / 3)
    for index, (label, value, color) in enumerate(
        (
            (ui["attempts"], "4", PURPLE),
            (ui["helpful"], "3", MINT),
            (ui["goal_progress"], "8", ORANGE),
        )
    ):
        left = x1 + index * (card_width + gap)
        glass_card(
            image,
            (left, summary_y, left + card_width, summary_y + int(136 * scale)),
            int(34 * scale),
            fill=(255, 255, 255, 222),
            shadow=False,
        )
        draw.text(
            (left + int(22 * scale), summary_y + int(18 * scale)),
            value,
            font=font(locale, int(44 * scale), True),
            fill=color,
        )
        draw_wrapped(
            draw,
            (left + int(22 * scale), summary_y + int(78 * scale)),
            label,
            font(locale, int(21 * scale), True),
            TEXT,
            card_width - int(42 * scale),
            max_lines=1,
        )
    small_y = summary_y + int(164 * scale)
    small_h = int(430 * scale if not device.tablet else 390 * scale)
    glass_card(image, (x1, small_y, x2, small_y + small_h), int(42 * scale), fill=rgba(MINT, 23))
    draw.text(
        (x1 + int(34 * scale), small_y + int(28 * scale)),
        ui["small"],
        font=font(locale, int(34 * scale), True),
        fill=MINT,
    )
    draw_wrapped(
        draw,
        (x1 + int(34 * scale), small_y + int(92 * scale)),
        ui["small_name"],
        font(locale, int(33 * scale), True),
        NAVY,
        x2 - x1 - int(70 * scale),
        max_lines=2,
    )
    draw_pill(
        image,
        (x1 + int(34 * scale), small_y + int(188 * scale), x1 + int(310 * scale), small_y + int(248 * scale)),
        ui["attempts"],
        locale,
        PURPLE,
        size=int(23 * scale),
    )
    draw_pill(
        image,
        (x1 + int(326 * scale), small_y + int(188 * scale), x1 + int(585 * scale), small_y + int(248 * scale)),
        ui["helpful"],
        locale,
        MINT,
        size=int(23 * scale),
    )
    draw_pill(
        image,
        (x1 + int(601 * scale), small_y + int(188 * scale), min(x2 - int(34 * scale), x1 + int(820 * scale)), small_y + int(248 * scale)),
        ui["load"],
        locale,
        ORANGE,
        size=int(23 * scale),
    )
    draw_line_chart(
        image,
        (
            x1 + int(34 * scale),
            small_y + int(278 * scale),
            x2 - int(34 * scale),
            small_y + small_h - int(32 * scale),
        ),
        (2.8, 3.6, 4.2, 3.9, 4.6),
        (MINT, PURPLE),
    )
    goal_y = small_y + small_h + int(24 * scale)
    glass_card(image, (x1, goal_y, x2, y2), int(42 * scale), fill=rgba(BLUE, 21))
    draw.text(
        (x1 + int(34 * scale), goal_y + int(28 * scale)),
        ui["goal"],
        font=font(locale, int(34 * scale), True),
        fill=BLUE,
    )
    draw_wrapped(
        draw,
        (x1 + int(34 * scale), goal_y + int(92 * scale)),
        ui["goal_name"],
        font(locale, int(33 * scale), True),
        NAVY,
        x2 - x1 - int(70 * scale),
        max_lines=2,
    )
    progress_y = goal_y + int(192 * scale)
    for index in range(10):
        box_w = int((x2 - x1 - int(68 * scale) - int(9 * scale) * 9) / 10)
        left = x1 + int(34 * scale) + index * (box_w + int(9 * scale))
        fill = rgba(MINT, 45) if index < 8 else rgba("#D8DAE8", 95)
        outline = rgba(MINT, 110) if index < 8 else rgba("#A8ADC1", 90)
        glass_card(
            image,
            (left, progress_y, left + box_w, progress_y + int(76 * scale)),
            int(18 * scale),
            fill=fill,
            outline=outline,
            shadow=False,
        )
        center = (left + box_w / 2, progress_y + int(38 * scale))
        if index < 8:
            draw_check_mark(draw, center, int(22 * scale), MINT, int(4 * scale))
        else:
            circle_r = int(12 * scale)
            draw.ellipse(
                (
                    center[0] - circle_r,
                    center[1] - circle_r,
                    center[0] + circle_r,
                    center[1] + circle_r,
                ),
                outline=MUTED,
                width=max(2, int(3 * scale)),
            )
    extra = EXTRA_COPY[locale]
    feedback_y = progress_y + int(112 * scale)
    draw.text(
        (x1 + int(34 * scale), feedback_y),
        extra["feedback_title"],
        font=font(locale, int(27 * scale), True),
        fill=NAVY,
    )
    feedback_gap = int(12 * scale)
    feedback_width = int((x2 - x1 - int(68 * scale) - feedback_gap * 2) / 3)
    for index, (label, color) in enumerate(
        (
            (extra["feedback_1"], MINT),
            (extra["feedback_2"], ORANGE),
            (extra["feedback_3"], MINT),
        )
    ):
        left = x1 + int(34 * scale) + index * (feedback_width + feedback_gap)
        draw_pill(
            image,
            (left, feedback_y + int(48 * scale), left + feedback_width, feedback_y + int(110 * scale)),
            label,
            locale,
            color,
            size=int(21 * scale),
        )
    chart_label_y = feedback_y + int(142 * scale)
    draw.text(
        (x1 + int(34 * scale), chart_label_y),
        ui["feedback"],
        font=font(locale, int(25 * scale), True),
        fill=BLUE,
    )
    chart_top = chart_label_y + int(52 * scale)
    chart_bottom = min(chart_top + int(230 * scale), y2 - int(250 * scale))
    if chart_bottom - chart_top > int(110 * scale):
        draw_line_chart(
            image,
            (x1 + int(44 * scale), chart_top, x2 - int(44 * scale), chart_bottom),
            (2.8, 3.1, 3.8, 4.2, 4.0, 4.6),
            (BLUE, PURPLE),
        )
    summary_top = chart_bottom + int(24 * scale)
    if y2 - summary_top > int(130 * scale):
        glass_card(
            image,
            (x1 + int(30 * scale), summary_top, x2 - int(30 * scale), y2 - int(30 * scale)),
            int(30 * scale),
            fill=rgba(BLUE, 22),
            outline=rgba(BLUE, 45),
            shadow=False,
        )
        draw.text(
            (x1 + int(56 * scale), summary_top + int(24 * scale)),
            extra["goal_summary"],
            font=font(locale, int(27 * scale), True),
            fill=BLUE,
        )
        draw_wrapped(
            draw,
            (x1 + int(56 * scale), summary_top + int(72 * scale)),
            extra["goal_summary_text"],
            font(locale, int(24 * scale)),
            TEXT,
            x2 - x1 - int(112 * scale),
            line_gap=1.18,
            max_lines=3,
        )


def render_journey(
    image: Image.Image,
    locale: str,
    body: tuple[int, int, int, int],
    device: Device,
) -> None:
    ui = COPY[locale]["ui"]
    draw = ImageDraw.Draw(image)
    x1, y1, x2, y2 = body
    scale = 1.0 if not device.tablet else 1.1
    draw.text((x1, y1), ui["journey"], font=font(locale, int(50 * scale), True), fill=NAVY)
    draw_pill(
        image,
        (x2 - int(260 * scale), y1 - int(2 * scale), x2, y1 + int(62 * scale)),
        ui["month"],
        locale,
        PURPLE,
        size=int(24 * scale),
    )
    summary_y = y1 + int(94 * scale)
    glass_card(image, (x1, summary_y, x2, summary_y + int(156 * scale)), int(38 * scale), fill=(255, 255, 255, 222))
    metrics = ((ui["record_days"], "18"), (ui["signals"], "36"), (ui["themes"], "3"))
    width = (x2 - x1) / 3
    for index, (label, value) in enumerate(metrics):
        left = x1 + int(index * width)
        draw.text(
            (left + int(28 * scale), summary_y + int(24 * scale)),
            value,
            font=font(locale, int(46 * scale), True),
            fill=(PURPLE, BLUE, MINT)[index],
        )
        draw.text(
            (left + int(28 * scale), summary_y + int(92 * scale)),
            label,
            font=font(locale, int(25 * scale), True),
            fill=TEXT,
        )
    calendar_y = summary_y + int(182 * scale)
    calendar_h = int(430 * scale if not device.tablet else 390 * scale)
    glass_card(image, (x1, calendar_y, x2, calendar_y + calendar_h), int(42 * scale), fill=(255, 255, 255, 218))
    draw.text(
        (x1 + int(30 * scale), calendar_y + int(26 * scale)),
        ui["calendar"],
        font=font(locale, int(33 * scale), True),
        fill=NAVY,
    )
    cols = 7
    weeks = calendar.Calendar(firstweekday=6).monthdayscalendar(2026, 7)
    rows = len(weeks)
    grid_x1 = x1 + int(30 * scale)
    weekday_y = calendar_y + int(78 * scale)
    grid_y1 = calendar_y + int(120 * scale)
    grid_w = x2 - x1 - int(60 * scale)
    grid_h = calendar_h - int(188 * scale)
    weekday_labels = {
        "zh-Hans": ("日", "一", "二", "三", "四", "五", "六"),
        "zh-Hant": ("日", "一", "二", "三", "四", "五", "六"),
        "ja": ("日", "月", "火", "水", "木", "金", "土"),
        "en-US": ("S", "M", "T", "W", "T", "F", "S"),
    }[locale]
    weekday_font = font(locale, int(18 * scale), True)
    for col, label in enumerate(weekday_labels):
        cx = grid_x1 + grid_w * (col + 0.5) / cols
        draw.text(
            (cx - text_width(draw, label, weekday_font) / 2, weekday_y),
            label,
            font=weekday_font,
            fill=MUTED,
        )
    for row, week in enumerate(weeks):
        for col, day in enumerate(week):
            cx = grid_x1 + grid_w * (col + 0.5) / cols
            cy = grid_y1 + grid_h * (row + 0.42) / rows
            if day == 0:
                continue
            day_font = font(locale, int(21 * scale), True)
            label = str(day)
            draw.text((cx - text_width(draw, label, day_font) / 2, cy - int(20 * scale)), label, font=day_font, fill=TEXT)
            if day in (2, 4, 6, 8, 9, 12, 15, 16, 18, 21, 24, 27, 28, 29):
                color = (PURPLE, MINT, ORANGE, BLUE)[day % 4]
                radius = int(6 * scale)
                draw.ellipse((cx - radius, cy + int(18 * scale) - radius, cx + radius, cy + int(18 * scale) + radius), fill=color)
    legend_y = calendar_y + calendar_h - int(48 * scale)
    legend_items = (
        ("Signal", PURPLE),
        (ui["small"].split(" ·")[0], MINT),
        (ui["goal"].split(" ·")[0], ORANGE),
    )
    legend_slot = (x2 - x1 - int(60 * scale)) / 3
    legend_font = font(locale, int(18 * scale), True)
    for index, (label, color) in enumerate(legend_items):
        left = x1 + int(30 * scale) + index * legend_slot
        r = int(6 * scale)
        draw.ellipse((left, legend_y + int(5 * scale), left + 2 * r, legend_y + int(5 * scale) + 2 * r), fill=color)
        draw.text((left + int(20 * scale), legend_y), label, font=legend_font, fill=MUTED)
    theme_y = calendar_y + calendar_h + int(24 * scale)
    theme_h = int(390 * scale)
    glass_card(image, (x1, theme_y, x2, theme_y + theme_h), int(42 * scale), fill=(255, 255, 255, 218))
    draw.text(
        (x1 + int(30 * scale), theme_y + int(26 * scale)),
        ui["themes"],
        font=font(locale, int(33 * scale), True),
        fill=NAVY,
    )
    theme_legend_y = theme_y + int(76 * scale)
    theme_legend = (
        (ui["theme_a"], PURPLE),
        (ui["theme_b"], MINT),
        (ui["theme_c"], BLUE),
    )
    theme_slot = (x2 - x1 - int(60 * scale)) / 3
    theme_font = font(locale, int(18 * scale), True)
    for index, (label, color) in enumerate(theme_legend):
        left = x1 + int(30 * scale) + index * theme_slot
        draw.rounded_rectangle(
            (left, theme_legend_y + int(7 * scale), left + int(24 * scale), theme_legend_y + int(14 * scale)),
            radius=int(4 * scale),
            fill=color,
        )
        draw.text((left + int(32 * scale), theme_legend_y), label, font=theme_font, fill=MUTED)
    chart_box = (
        x1 + int(30 * scale),
        theme_y + int(132 * scale),
        x2 - int(30 * scale),
        theme_y + theme_h - int(42 * scale),
    )
    draw_line_chart(image, chart_box, (2.0, 2.4, 2.2, 3.1, 3.6, 3.4, 4.2), (PURPLE, ORANGE))
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    odraw = ImageDraw.Draw(overlay)
    for offset, color, values in (
        (28, MINT, (1.6, 2.0, 2.6, 2.5, 3.2, 3.7, 3.9)),
        (50, BLUE, (2.8, 2.5, 2.9, 3.4, 3.2, 3.8, 4.0)),
    ):
        points = []
        for index, value in enumerate(values):
            px = chart_box[0] + int((chart_box[2] - chart_box[0]) * index / 6)
            py = chart_box[3] - int((chart_box[3] - chart_box[1]) * value / 5) + int(offset * scale)
            points.append((px, py))
        odraw.line(points, fill=rgba(color, 190), width=int(5 * scale), joint="curve")
    image.alpha_composite(overlay)
    gentle_y = theme_y + theme_h + int(24 * scale)
    if gentle_y < y2:
        glass_card(image, (x1, gentle_y, x2, y2), int(42 * scale), fill=rgba(PURPLE, 18))
        draw.text(
            (x1 + int(30 * scale), gentle_y + int(26 * scale)),
            ui["gentle"],
            font=font(locale, int(33 * scale), True),
            fill=PURPLE,
        )
        extra = EXTRA_COPY[locale]
        bullet_top = gentle_y + int(90 * scale)
        available = y2 - bullet_top - int(24 * scale)
        bullet_height = max(int(92 * scale), int(available / 3))
        for index, (text_value, color) in enumerate(
            (
                (extra["gentle_1"], PURPLE),
                (extra["gentle_2"], MINT),
                (extra["gentle_3"], ORANGE),
            )
        ):
            top = bullet_top + index * bullet_height
            radius = int(10 * scale)
            draw.ellipse(
                (
                    x1 + int(34 * scale),
                    top + int(12 * scale),
                    x1 + int(34 * scale) + 2 * radius,
                    top + int(12 * scale) + 2 * radius,
                ),
                fill=color,
            )
            draw_wrapped(
                draw,
                (x1 + int(72 * scale), top),
                text_value,
                font(locale, int(24 * scale), True),
                TEXT,
                x2 - x1 - int(108 * scale),
                line_gap=1.16,
                max_lines=2,
            )


def render_pro(
    image: Image.Image,
    locale: str,
    body: tuple[int, int, int, int],
    device: Device,
) -> None:
    ui = COPY[locale]["ui"]
    draw = ImageDraw.Draw(image)
    x1, y1, x2, y2 = body
    scale = 1.0 if not device.tablet else 1.12
    draw.text((x1, y1), ui["pro"], font=font(locale, int(50 * scale), True), fill=NAVY)
    draw_pill(
        image,
        (x2 - int(290 * scale), y1 - int(2 * scale), x2, y1 + int(62 * scale)),
        ui["deep"],
        locale,
        ORANGE,
        size=int(23 * scale),
    )
    relation_y = y1 + int(94 * scale)
    relation_h = int(560 * scale if not device.tablet else 500 * scale)
    glass_card(image, (x1, relation_y, x2, relation_y + relation_h), int(44 * scale), fill=(255, 255, 255, 222))
    draw.text(
        (x1 + int(30 * scale), relation_y + int(26 * scale)),
        ui["relation"],
        font=font(locale, int(34 * scale), True),
        fill=NAVY,
    )
    draw_network(
        image,
        (
            x1 + int(40 * scale),
            relation_y + int(92 * scale),
            x2 - int(40 * scale),
            relation_y + relation_h - int(38 * scale),
        ),
        (ui["scene"], ui["behavior"], ui["state_word"], ui["response"]),
        locale,
    )
    preference_y = relation_y + relation_h + int(24 * scale)
    preference_h = int(340 * scale)
    glass_card(image, (x1, preference_y, x2, preference_y + preference_h), int(42 * scale), fill=rgba(MINT, 21))
    draw.text(
        (x1 + int(30 * scale), preference_y + int(26 * scale)),
        ui["preference"],
        font=font(locale, int(34 * scale), True),
        fill=MINT,
    )
    illustration_box = (
        x1 + int(30 * scale),
        preference_y + int(92 * scale),
        x1 + int(220 * scale),
        preference_y + int(282 * scale),
    )
    paste_contain(
        image,
        ASSET_ROOT / "weekly" / "weekly-pattern-small-action-stabilizes.png",
        illustration_box,
        radius=int(34 * scale),
    )
    draw_wrapped(
        draw,
        (illustration_box[2] + int(28 * scale), preference_y + int(105 * scale)),
        ui["preference_text"],
        font(locale, int(29 * scale), True),
        TEXT,
        x2 - illustration_box[2] - int(58 * scale),
        max_lines=4,
    )
    long_y = preference_y + preference_h + int(24 * scale)
    glass_card(image, (x1, long_y, x2, y2), int(42 * scale), fill=rgba(BLUE, 18))
    draw.text(
        (x1 + int(30 * scale), long_y + int(26 * scale)),
        ui["long_term"],
        font=font(locale, int(34 * scale), True),
        fill=BLUE,
    )
    draw_line_chart(
        image,
        (
            x1 + int(48 * scale),
            long_y + int(96 * scale),
            x2 - int(48 * scale),
            min(y2 - int(310 * scale), long_y + int(330 * scale)),
        ),
        (2.1, 2.4, 2.8, 3.0, 3.7, 3.6, 4.2, 4.5),
        (BLUE, PURPLE),
    )
    extra = EXTRA_COPY[locale]
    chart_bottom = min(y2 - int(310 * scale), long_y + int(330 * scale))
    month_font = font(locale, int(19 * scale), True)
    month_labels = (extra["month_1"], extra["month_2"], extra["month_3"])
    for index, label in enumerate(month_labels):
        cx = x1 + int(52 * scale) + (x2 - x1 - int(104 * scale)) * index / 2
        draw.text(
            (cx - text_width(draw, label, month_font) / 2, chart_bottom + int(14 * scale)),
            label,
            font=month_font,
            fill=MUTED,
        )
    summary_top = chart_bottom + int(66 * scale)
    summary_bottom = y2 - int(118 * scale)
    if summary_bottom - summary_top > int(118 * scale):
        glass_card(
            image,
            (
                x1 + int(34 * scale),
                summary_top,
                x2 - int(34 * scale),
                summary_bottom,
            ),
            int(28 * scale),
            fill=rgba(BLUE, 20),
            outline=rgba(BLUE, 48),
            shadow=False,
        )
        draw.text(
            (x1 + int(62 * scale), summary_top + int(22 * scale)),
            extra["long_summary"],
            font=font(locale, int(28 * scale), True),
            fill=BLUE,
        )
        draw_wrapped(
            draw,
            (x1 + int(62 * scale), summary_top + int(70 * scale)),
            extra["long_summary_detail"],
            font(locale, int(23 * scale), True),
            TEXT,
            x2 - x1 - int(124 * scale),
            line_gap=1.18,
            max_lines=3,
        )
    pill_top = y2 - int(92 * scale)
    draw_pill(
        image,
        (x1 + int(34 * scale), pill_top, min(x2 - int(34 * scale), x1 + int(520 * scale)), y2 - int(28 * scale)),
        ui["load_suggestion"],
        locale,
        MINT,
        size=int(24 * scale),
    )


RENDERERS = {
    "today": render_today,
    "state": render_state,
    "weekly": render_weekly,
    "experiment": render_experiment,
    "journey": render_journey,
    "pro": render_pro,
}


def render_one(locale: str, page: str, device: Device) -> Image.Image:
    image = Image.new("RGBA", (device.width, device.height), rgba(CREAM))
    paste_cover(image, HERO_ASSETS[page], opacity=0.98)
    soft = Image.new("RGBA", image.size, (255, 255, 255, 0))
    soft_draw = ImageDraw.Draw(soft)
    soft_draw.rectangle((0, 0, image.width, image.height), fill=(255, 250, 247, 38))
    soft_draw.ellipse(
        (
            -int(image.width * 0.35),
            int(image.height * 0.35),
            int(image.width * 0.55),
            int(image.height * 1.05),
        ),
        fill=(255, 255, 255, 80),
    )
    image.alpha_composite(soft.filter(ImageFilter.GaussianBlur(max(12, image.width // 80))))
    _, shell_start = draw_marketing_header(image, locale, page, device)
    minimum_shell = 650 if not device.tablet else 520
    shell_start = max(shell_start, minimum_shell)
    _, body = draw_app_shell(image, locale, page, device, shell_start)
    RENDERERS[page](image, locale, body, device)
    return image.convert("RGB")


def validate_image(path: Path, device: Device) -> dict[str, Any]:
    with Image.open(path) as image:
        return {
            "width": image.width,
            "height": image.height,
            "mode": image.mode,
            "has_alpha": "A" in image.getbands(),
            "valid_dimensions": image.size == (device.width, device.height),
            "valid_mode": image.mode == "RGB" and "A" not in image.getbands(),
        }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--clean", action="store_true")
    parser.add_argument("--locale", action="append", choices=LOCALES)
    parser.add_argument("--device", action="append", choices=tuple(device.slug for device in DEVICES))
    parser.add_argument("--page", action="append", choices=tuple(page for _, page in PAGE_SPECS))
    args = parser.parse_args()
    selected_locales = tuple(args.locale or LOCALES)
    selected_devices = tuple(
        device for device in DEVICES if not args.device or device.slug in args.device
    )
    selected_pages = tuple(
        (filename, page)
        for filename, page in PAGE_SPECS
        if not args.page or page in args.page
    )
    output = args.output.resolve()
    if args.clean and output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)

    final_root = output / "final"
    previews_root = output / "previews"
    final_root.mkdir(parents=True, exist_ok=True)
    previews_root.mkdir(parents=True, exist_ok=True)

    manifest: dict[str, Any] = {
        "product": "Signal Path",
        "generated_on": "2026-07-29",
        "source": "deterministic Pillow renderer using checked-in Signal Path artwork",
        "devices": {
            device.slug: {"width": device.width, "height": device.height}
            for device in selected_devices
        },
        "locales": list(selected_locales),
        "screenshots": [],
        "source_assets": [],
    }
    for page, asset in HERO_ASSETS.items():
        manifest["source_assets"].append(
            {"page": page, "path": str(asset.relative_to(ROOT)), "sha256": sha256(asset)}
        )

    for locale in selected_locales:
        for device in selected_devices:
            destination = final_root / device.slug / locale
            destination.mkdir(parents=True, exist_ok=True)
            for filename, page in selected_pages:
                image = render_one(locale, page, device)
                path = destination / f"{filename}.png"
                image.save(path, "PNG", optimize=True)
                validation = validate_image(path, device)
                manifest["screenshots"].append(
                    {
                        "locale": locale,
                        "device": device.slug,
                        "page": page,
                        "path": str(path.relative_to(output)),
                        "sha256": sha256(path),
                        **validation,
                    }
                )

    # Reader-friendly previews use the simplified-Chinese iPhone set.
    preview_source = final_root / "iphone-6.9" / "zh-Hans"
    if preview_source.exists():
        for path in sorted(preview_source.glob("*.png")):
            with Image.open(path) as image:
                preview = image.copy()
                preview.thumbnail((440, 956), Image.Resampling.LANCZOS)
                preview.save(previews_root / path.name, "PNG", optimize=True)

    copy_payload = {
        locale: {
            page: {"headline": value[0], "subtitle": value[1]}
            for page, value in payload["marketing"].items()
        }
        for locale, payload in COPY.items()
    }
    (output / "copy.json").write_text(
        json.dumps(copy_payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    (output / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    report = {
        "total": len(manifest["screenshots"]),
        "passed": sum(
            1
            for item in manifest["screenshots"]
            if item["valid_dimensions"] and item["valid_mode"]
        ),
        "failed": [
            item["path"]
            for item in manifest["screenshots"]
            if not item["valid_dimensions"] or not item["valid_mode"]
        ],
    }
    (output / "validation-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
