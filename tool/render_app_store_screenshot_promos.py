#!/usr/bin/env python3
"""Render six screenshot-faithful Signal Path App Store promo images."""

from __future__ import annotations

import hashlib
import json
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
RELEASE_ROOT = ROOT / "release_assets" / "app_store" / "2026-08-03"
SOURCE_ROOT = RELEASE_ROOT / "sources"
OUTPUT_ROOT = RELEASE_ROOT / "final" / "iphone-6.9" / "zh-Hans"
PREVIEW_ROOT = RELEASE_ROOT / "previews"
BACKGROUND = RELEASE_ROOT / "generated" / "master-background.png"
APP_ICON = ROOT / "frontend_flutter" / "assets" / "icon-1024-noalpha.png"

WIDTH = 1320
HEIGHT = 2868
GENERATED_DATE = "2026-08-04"

FONT_ZH = Path("/System/Library/Fonts/Hiragino Sans GB.ttc")
FONT_INDEX_REGULAR = 0
FONT_INDEX_BOLD = 1
FONT_VARIATION_REGULAR: bytes | None = None
FONT_VARIATION_BOLD: bytes | None = None
PRESENTATION_BOTTOM_CROP = {"today.png": 100}
WEEKLY_DETAIL_SOURCE: str | None = "weekly-detail.png"
LIFE_EXPERIMENT_DETAIL_SOURCES: tuple[str, str] | None = (
    "life-experiment-small.png",
    "life-experiment-goal.png",
)
JOURNEY_DETAIL_SOURCE: str | None = "journey-detail.png"

NAVY = "#1A2144"
BODY = "#454F70"
WHITE = "#FFFFFF"


@dataclass(frozen=True)
class Slide:
    filename: str
    title: str
    subtitle: str
    cue: str
    source: str
    accent: str
    label: str


SLIDES = (
    Slide(
        "01-summary.png",
        "从一条记录开始",
        "让日常 Signal，慢慢连成生活轨迹",
        "记录 · 复盘 · 尝试 · 看见变化",
        "today.png",
        "#7665F2",
        "SUMMARY",
    ),
    Slide(
        "02-today.png",
        "把今天轻轻记下",
        "用文字、语音与状态，留住当下 Signal",
        "随手留下一点真实",
        "today.png",
        "#578FEF",
        "TODAY",
    ),
    Slide(
        "03-weekly.png",
        "把一周连成线索",
        "从真实记录里，发现重复的模式",
        "事实 → 模式 → 尝试结果",
        "weekly.png",
        "#7A67F2",
        "WEEKLY",
    ),
    Slide(
        "04-life-experiment.png",
        "让改变小步发生",
        "用轻量尝试，慢慢靠近适合的节奏",
        "10 分钟内，也可以开始",
        "life-experiment-overview.png",
        "#4FC3A2",
        "LIFE EXPERIMENT",
    ),
    Slide(
        "05-journey.png",
        "看见更长的旅程",
        "把零散的日子，串成自己的生活轨迹",
        "月度视图 · 主题变化 · 温柔回顾",
        "journey.png",
        "#836BEF",
        "JOURNEY",
    ),
    Slide(
        "06-pro.png",
        "读懂你的行动偏好",
        "比较帮助与负担，整理更合适的尝试",
        "专业版深度视图",
        "pro.png",
        "#F09D5B",
        "PRO",
    ),
)

SOURCE_PROVENANCE = {
    "today.png": "Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.02.47.png",
    "weekly.png": "Simulator Screenshot - Signal Path 简体中文 iPhone 16e - 2026-08-02 at 20.09.07.png",
    "weekly-detail.png": "Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.04.05.png",
    "life-experiment-overview.png": "Simulator Screenshot - Signal Path 简体中文 iPhone 16e - 2026-08-02 at 20.08.34.png",
    "life-experiment-small.png": "Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.14.43.png",
    "life-experiment-goal.png": "Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.15.12.png",
    "journey.png": "Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.19.30.png",
    "journey-detail.png": "Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.22.25.png",
    "pro.png": "Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.05.15.png",
}


def font(size: int, *, bold: bool = False) -> ImageFont.FreeTypeFont:
    index = FONT_INDEX_BOLD if bold else FONT_INDEX_REGULAR
    try:
        loaded = ImageFont.truetype(str(FONT_ZH), size=size, index=index)
    except OSError:
        loaded = ImageFont.truetype(str(FONT_ZH), size=size, index=FONT_INDEX_REGULAR)
    variation = FONT_VARIATION_BOLD if bold else FONT_VARIATION_REGULAR
    if variation is not None:
        try:
            loaded.set_variation_by_name(variation)
        except (OSError, ValueError):
            pass
    return loaded


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_color.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def fit_background(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.fit(
        source.convert("RGB"),
        size,
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    ).convert("RGBA")


def presentation_source(path: Path) -> Image.Image:
    source = Image.open(path)
    crop_bottom = PRESENTATION_BOTTOM_CROP.get(path.name, 0)
    if crop_bottom:
        # Simulator captures can contain a covered content tail beneath the
        # floating tab bar. Trimming only that tail keeps the visible UI intact.
        return source.crop((0, 0, source.width, source.height - crop_bottom))
    return source


def add_top_wash(canvas: Image.Image) -> None:
    wash = Image.new("RGBA", canvas.size, (255, 255, 255, 0))
    draw = ImageDraw.Draw(wash)
    for y in range(920):
        t = y / 919
        alpha = round(205 * (1 - t) ** 1.65)
        draw.line((0, y, WIDTH, y), fill=(255, 255, 255, alpha), width=1)
    canvas.alpha_composite(wash)


def add_glow(
    canvas: Image.Image,
    center: tuple[int, int],
    diameter: int,
    color: str,
    alpha: int,
) -> None:
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    radius = diameter // 2
    box = (
        center[0] - radius,
        center[1] - radius,
        center[0] + radius,
        center[1] + radius,
    )
    draw.ellipse(box, fill=rgba(color, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(radius=diameter // 5))
    canvas.alpha_composite(glow)


def rounded_overlay(
    canvas: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int] | None = None,
    width: int = 1,
) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)
    canvas.alpha_composite(layer)


def draw_background(canvas: Image.Image, background: Image.Image, slide: Slide, index: int) -> None:
    canvas.alpha_composite(fit_background(background, canvas.size))
    canvas.alpha_composite(Image.new("RGBA", canvas.size, (255, 255, 255, 28)))
    add_top_wash(canvas)
    add_glow(
        canvas,
        center=(1110, 560) if index % 2 == 0 else (170, 560),
        diameter=720,
        color=slide.accent,
        alpha=46,
    )
    rounded_overlay(
        canvas,
        (44, 44, WIDTH - 44, 634),
        54,
        (255, 255, 255, 42),
        (255, 255, 255, 110),
        2,
    )


def paste_rounded(
    destination: Image.Image,
    source: Image.Image,
    position: tuple[int, int],
    size: tuple[int, int],
    radius: int,
) -> None:
    resized = source.convert("RGB").resize(size, Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    destination.paste(resized, position, mask)


def screenshot_card(source: Image.Image, screen_width: int) -> Image.Image:
    screen_height = round(screen_width * source.height / source.width)
    frame = 18
    padding = 54
    frame_size = (screen_width + frame * 2, screen_height + frame * 2)
    card = Image.new(
        "RGBA",
        (frame_size[0] + padding * 2, frame_size[1] + padding * 2),
        (0, 0, 0, 0),
    )

    mask = Image.new("L", card.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (padding, padding, padding + frame_size[0], padding + frame_size[1]),
        radius=92,
        fill=190,
    )
    shadow = Image.new("RGBA", card.size, rgba(NAVY, 0))
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(34)))
    shifted = Image.new("RGBA", card.size, (0, 0, 0, 0))
    shifted.alpha_composite(shadow, (0, 18))
    card.alpha_composite(shifted)

    draw = ImageDraw.Draw(card)
    frame_box = (
        padding,
        padding,
        padding + frame_size[0],
        padding + frame_size[1],
    )
    draw.rounded_rectangle(frame_box, radius=92, fill=(255, 255, 255, 248))

    inner_position = (padding + frame, padding + frame)
    paste_rounded(
        card,
        source,
        inner_position,
        (screen_width, screen_height),
        radius=74,
    )
    draw.rounded_rectangle(
        (
            inner_position[0],
            inner_position[1],
            inner_position[0] + screen_width,
            inner_position[1] + screen_height,
        ),
        radius=74,
        outline=(255, 255, 255, 150),
        width=2,
    )
    return card


def alpha_paste(destination: Image.Image, source: Image.Image, position: tuple[int, int]) -> None:
    destination.alpha_composite(source, dest=position)


def paste_centered(
    destination: Image.Image,
    source: Image.Image,
    center: tuple[int, int],
) -> None:
    alpha_paste(
        destination,
        source,
        (round(center[0] - source.width / 2), round(center[1] - source.height / 2)),
    )


def draw_single_screenshot(canvas: Image.Image, source: Image.Image, slide: Slide) -> None:
    rounded_overlay(
        canvas,
        (145, 620, 1175, HEIGHT + 70),
        116,
        (255, 255, 255, 70),
        (255, 255, 255, 110),
        2,
    )
    add_glow(canvas, center=(660, 1730), diameter=1220, color=slide.accent, alpha=22)
    card = screenshot_card(source, 980)
    alpha_paste(canvas, card, ((WIDTH - card.width) // 2, 642))


def draw_weekly_dual(
    canvas: Image.Image,
    primary: Image.Image,
    detail: Image.Image,
    slide: Slide,
) -> None:
    """Layer the weekly overview with a focused behavior/results continuation."""
    rounded_overlay(
        canvas,
        (72, 620, 1248, HEIGHT + 70),
        116,
        (255, 255, 255, 66),
        (255, 255, 255, 110),
        2,
    )
    add_glow(canvas, center=(530, 1580), diameter=1120, color=slide.accent, alpha=24)
    add_glow(canvas, center=(1030, 2200), diameter=760, color="#4FC3A2", alpha=20)

    primary_card = screenshot_card(primary, 820)
    alpha_paste(canvas, primary_card, (54, 642))

    detail_top = round(detail.height * 0.05)
    detail_bottom = round(detail.height * 0.87)
    detail_crop = detail.crop((0, detail_top, detail.width, detail_bottom))
    detail_card = screenshot_card(detail_crop, 540)
    alpha_paste(canvas, detail_card, (626, 1588))


def draw_life_experiment_triple(
    canvas: Image.Image,
    overview: Image.Image,
    small_experiment: Image.Image,
    goal: Image.Image,
    slide: Slide,
) -> None:
    """Show the overview with focused small-experiment and goal continuations."""
    rounded_overlay(
        canvas,
        (54, 620, 1266, HEIGHT + 70),
        116,
        (255, 255, 255, 64),
        (255, 255, 255, 110),
        2,
    )
    add_glow(canvas, center=(470, 1580), diameter=1080, color=slide.accent, alpha=24)
    add_glow(canvas, center=(1030, 2050), diameter=820, color="#7665F2", alpha=20)

    overview_crop = overview.crop(
        (0, 0, overview.width, round(overview.height * 0.62))
    )
    overview_card = screenshot_card(overview_crop, 900)
    alpha_paste(canvas, overview_card, ((WIDTH - overview_card.width) // 2, 642))

    small_crop = small_experiment.crop(
        (
            0,
            round(small_experiment.height * 0.46),
            small_experiment.width,
            round(small_experiment.height * 0.87),
        )
    )
    small_card = screenshot_card(small_crop, 490)
    alpha_paste(canvas, small_card, (20, 1980))

    goal_crop = goal.crop(
        (
            0,
            round(goal.height * 0.40),
            goal.width,
            round(goal.height * 0.87),
        )
    )
    goal_card = screenshot_card(goal_crop, 490)
    alpha_paste(canvas, goal_card, (666, 1980))


def draw_journey_dual(
    canvas: Image.Image,
    overview: Image.Image,
    detail: Image.Image,
    slide: Slide,
) -> None:
    """Layer the monthly overview with its theme-change continuation."""
    rounded_overlay(
        canvas,
        (72, 620, 1248, HEIGHT + 70),
        116,
        (255, 255, 255, 66),
        (255, 255, 255, 110),
        2,
    )
    add_glow(canvas, center=(510, 1580), diameter=1120, color=slide.accent, alpha=24)
    add_glow(canvas, center=(1030, 2190), diameter=780, color="#F29ACB", alpha=20)

    overview_card = screenshot_card(overview, 820)
    alpha_paste(canvas, overview_card, (54, 642))

    detail_crop = detail.crop(
        (
            0,
            round(detail.height * 0.04),
            detail.width,
            round(detail.height * 0.76),
        )
    )
    detail_card = screenshot_card(detail_crop, 540)
    alpha_paste(canvas, detail_card, (626, 1600))


def draw_summary(canvas: Image.Image, sources: dict[str, Image.Image], slide: Slide) -> None:
    rounded_overlay(
        canvas,
        (24, 620, 1296, HEIGHT + 30),
        120,
        (255, 255, 255, 36),
        (255, 255, 255, 90),
        2,
    )
    left = screenshot_card(sources["weekly"], 590).rotate(
        8,
        resample=Image.Resampling.BICUBIC,
        expand=True,
    )
    right = screenshot_card(sources["journey"], 590).rotate(
        -8,
        resample=Image.Resampling.BICUBIC,
        expand=True,
    )
    center = screenshot_card(sources["today"], 850)

    paste_centered(canvas, left, (82, 1770))
    paste_centered(canvas, right, (1235, 1740))
    add_glow(canvas, center=(660, 1590), diameter=1200, color=slide.accent, alpha=40)
    alpha_paste(canvas, center, ((WIDTH - center.width) // 2, 690))


def draw_header(
    canvas: Image.Image,
    icon: Image.Image,
    slide: Slide,
    index: int,
) -> None:
    draw = ImageDraw.Draw(canvas)

    chip_box = (78, 78, 356, 154)
    draw.rounded_rectangle(
        chip_box,
        radius=38,
        fill=(255, 255, 255, 186),
        outline=rgba(slide.accent, 58),
        width=2,
    )
    paste_rounded(canvas, icon, (92, 90), (52, 52), radius=14)
    draw.text((158, 101), "Signal Path", font=font(29, bold=True), fill=NAVY)
    draw.text(
        (1234, 101),
        f"{index + 1:02d} / 06",
        font=font(27, bold=True),
        fill=slide.accent,
        anchor="ra",
        stroke_width=0,
    )

    label_font = font(21, bold=True)
    label_bbox = draw.textbbox((0, 0), slide.label, font=label_font)
    label_width = max(122, label_bbox[2] - label_bbox[0] + 42)
    label_box = (78, 180, 78 + label_width, 232)
    draw.rounded_rectangle(label_box, radius=26, fill=rgba(slide.accent, 30))
    draw.text((98, 193), slide.label, font=label_font, fill=WHITE)

    draw.rounded_rectangle((78, 262, 90, 374), radius=6, fill=slide.accent)
    draw.text((116, 244), slide.title, font=font(82, bold=True), fill=NAVY)
    draw.text((116, 383), slide.subtitle, font=font(39), fill=BODY)

    cue_font = font(27, bold=True)
    cue_bbox = draw.textbbox((0, 0), slide.cue, font=cue_font)
    cue_width = min(700, max(300, cue_bbox[2] - cue_bbox[0] + 102))
    cue_box = (116, 510, 116 + cue_width, 580)
    draw.rounded_rectangle(
        cue_box,
        radius=35,
        fill=(255, 255, 255, 190),
        outline=rgba(slide.accent, 62),
        width=2,
    )
    draw.ellipse((142, 538, 156, 552), fill=slide.accent)
    draw.text((176, 525), slide.cue, font=cue_font, fill=NAVY)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_metadata() -> None:
    locale = OUTPUT_ROOT.name
    metadata_suffix = "" if locale == "zh-Hans" else f"-{locale}"
    files = []
    for slide in SLIDES:
        path = OUTPUT_ROOT / slide.filename
        with Image.open(path) as rendered:
            record = {
                "path": str(path.relative_to(RELEASE_ROOT)),
                "width": rendered.width,
                "height": rendered.height,
                "mode": rendered.mode,
                "bytes": path.stat().st_size,
                "sha256": sha256(path),
                "source": slide.source,
                "headline": slide.title,
                "subtitle": slide.subtitle,
            }
            if (
                slide.filename == "03-weekly.png"
                and WEEKLY_DETAIL_SOURCE is not None
                and (SOURCE_ROOT / WEEKLY_DETAIL_SOURCE).exists()
            ):
                record["supporting_sources"] = [WEEKLY_DETAIL_SOURCE]
            elif (
                slide.filename == "04-life-experiment.png"
                and LIFE_EXPERIMENT_DETAIL_SOURCES is not None
                and all((SOURCE_ROOT / name).exists() for name in LIFE_EXPERIMENT_DETAIL_SOURCES)
            ):
                record["supporting_sources"] = list(LIFE_EXPERIMENT_DETAIL_SOURCES)
            elif (
                slide.filename == "05-journey.png"
                and JOURNEY_DETAIL_SOURCE is not None
                and (SOURCE_ROOT / JOURNEY_DETAIL_SOURCE).exists()
            ):
                record["supporting_sources"] = [JOURNEY_DETAIL_SOURCE]
            files.append(record)

    manifest = {
        "generated": GENERATED_DATE,
        "locale": locale,
        "device": "iphone-6.9",
        "dimensions": {"width": WIDTH, "height": HEIGHT},
        "format": "PNG",
        "files": files,
    }
    (RELEASE_ROOT / f"manifest{metadata_suffix}.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    copy = {
        slide.filename: {
            "headline": slide.title,
            "subtitle": slide.subtitle,
            "cue": slide.cue,
        }
        for slide in SLIDES
    }
    (RELEASE_ROOT / f"copy{metadata_suffix}.json").write_text(
        json.dumps(copy, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    provenance = {
        "composition": "Deterministic layout; source screenshots are only resized, rounded, framed, and layered.",
        "background": {
            "path": "generated/master-background.png",
            "method": "Built-in ImageGen",
            "prompt_summary": "Warm ivory portrait backdrop with translucent ribbons and glowing signal nodes; no text, logo, device, screenshot, or UI.",
        },
        "sources": SOURCE_PROVENANCE,
    }
    (RELEASE_ROOT / f"provenance{metadata_suffix}.json").write_text(
        json.dumps(provenance, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def write_contact_sheet() -> None:
    previews = [Image.open(PREVIEW_ROOT / slide.filename).convert("RGB") for slide in SLIDES]
    cell_width, cell_height = previews[0].size
    gap = 24
    sheet = Image.new(
        "RGB",
        (cell_width * 3 + gap * 4, cell_height * 2 + gap * 3),
        (246, 244, 251),
    )
    for index, preview in enumerate(previews):
        column = index % 3
        row = index // 3
        x = gap + column * (cell_width + gap)
        y = gap + row * (cell_height + gap)
        sheet.paste(preview, (x, y))
    sheet.save(PREVIEW_ROOT / "contact-sheet.png", format="PNG", compress_level=6)


def main(indices: set[int] | None = None) -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    PREVIEW_ROOT.mkdir(parents=True, exist_ok=True)

    background = Image.open(BACKGROUND)
    icon = Image.open(APP_ICON)
    sources = {
        "today": presentation_source(SOURCE_ROOT / "today.png"),
        "weekly": presentation_source(SOURCE_ROOT / "weekly.png"),
        "journey": presentation_source(SOURCE_ROOT / "journey.png"),
    }

    for index, slide in enumerate(SLIDES):
        if indices is not None and index not in indices:
            continue
        canvas = Image.new("RGBA", (WIDTH, HEIGHT), (255, 255, 255, 255))
        draw_background(canvas, background, slide, index)
        if index == 0:
            draw_summary(canvas, sources, slide)
        elif (
            index == 2
            and WEEKLY_DETAIL_SOURCE is not None
            and (SOURCE_ROOT / WEEKLY_DETAIL_SOURCE).exists()
        ):
            draw_weekly_dual(
                canvas,
                presentation_source(SOURCE_ROOT / slide.source),
                Image.open(SOURCE_ROOT / WEEKLY_DETAIL_SOURCE),
                slide,
            )
        elif (
            index == 3
            and LIFE_EXPERIMENT_DETAIL_SOURCES is not None
            and all((SOURCE_ROOT / name).exists() for name in LIFE_EXPERIMENT_DETAIL_SOURCES)
        ):
            draw_life_experiment_triple(
                canvas,
                presentation_source(SOURCE_ROOT / slide.source),
                Image.open(SOURCE_ROOT / LIFE_EXPERIMENT_DETAIL_SOURCES[0]),
                Image.open(SOURCE_ROOT / LIFE_EXPERIMENT_DETAIL_SOURCES[1]),
                slide,
            )
        elif (
            index == 4
            and JOURNEY_DETAIL_SOURCE is not None
            and (SOURCE_ROOT / JOURNEY_DETAIL_SOURCE).exists()
        ):
            draw_journey_dual(
                canvas,
                presentation_source(SOURCE_ROOT / slide.source),
                Image.open(SOURCE_ROOT / JOURNEY_DETAIL_SOURCE),
                slide,
            )
        else:
            draw_single_screenshot(canvas, presentation_source(SOURCE_ROOT / slide.source), slide)
        draw_header(canvas, icon, slide, index)

        final = canvas.convert("RGB")
        final_path = OUTPUT_ROOT / slide.filename
        final.save(final_path, format="PNG", compress_level=6)
        preview = final.resize((520, round(520 * HEIGHT / WIDTH)), Image.Resampling.LANCZOS)
        preview.save(PREVIEW_ROOT / slide.filename, format="PNG", compress_level=6)
        print(f"Rendered {slide.filename}")

    write_contact_sheet()
    write_metadata()


if __name__ == "__main__":
    if sys.argv[1:] == ["--contact-only"]:
        write_contact_sheet()
    elif sys.argv[1:] == ["--weekly-only"]:
        main({2})
    elif sys.argv[1:] == ["--life-experiment-only"]:
        main({3})
    elif sys.argv[1:] == ["--journey-only"]:
        main({4})
    else:
        main()
