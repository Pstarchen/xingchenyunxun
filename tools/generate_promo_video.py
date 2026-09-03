from pathlib import Path
from typing import List, Tuple

import cv2
import numpy as np
from PIL import Image, ImageDraw

from generate_promo_assets import ROOT, OUTPUT_DIR, font, rounded_image


WIDTH = 1080
HEIGHT = 1920
FPS = 30
SECONDS_PER_SLIDE = 2.8
TRANSITION_SECONDS = 0.4


def background() -> Image.Image:
    canvas = Image.new("RGB", (WIDTH, HEIGHT), "#061124")
    draw = ImageDraw.Draw(canvas)
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        color = (
            int(6 + 8 * ratio),
            int(17 + 17 * ratio),
            int(36 + 42 * ratio),
        )
        draw.line((0, y, WIDTH, y), fill=color)
    for y in range(40, HEIGHT, 96):
        draw.line((0, y, WIDTH, y), fill="#0D2547", width=1)
    return canvas


def add_brand(canvas: Image.Image) -> None:
    logo = Image.open(ROOT / "素材" / "星辰云巡logo.png").convert("RGBA")
    logo = rounded_image(logo, (104, 104), 20)
    canvas.paste(logo, (54, 56), logo)
    draw = ImageDraw.Draw(canvas)
    draw.text((184, 62), "星辰云巡", font=font(48, bold=True), fill="white")
    draw.text((184, 121), "HarmonyOS 服务器监控客户端", font=font(24), fill="#9DC9FF")


def feature_slide(image_name: str, title: str, subtitle: str, accent: str) -> Image.Image:
    canvas = background()
    add_brand(canvas)
    draw = ImageDraw.Draw(canvas)

    screenshot = Image.open(ROOT / "素材" / "宣传图" / image_name).convert("RGBA")
    screenshot = rounded_image(screenshot, (1000, 563), 24)
    draw.rounded_rectangle((30, 284, 1050, 867), radius=28, fill="#10284A")
    canvas.paste(screenshot, (40, 294), screenshot)

    draw.rounded_rectangle((54, 960, 78, 1088), radius=12, fill=accent)
    draw.text((112, 946), title, font=font(58, bold=True), fill="white")
    draw.multiline_text(
        (112, 1042),
        subtitle,
        font=font(30),
        fill="#B8CBE7",
        spacing=16,
    )

    draw.rounded_rectangle((54, 1270, 1026, 1518), radius=28, fill="#0D2343")
    features = [
        "实时资源与设备状态",
        "历史趋势与服务探测",
        "分级告警与多空间管理",
    ]
    for index, feature in enumerate(features):
        y = 1310 + index * 66
        draw.ellipse((92, y + 8, 112, y + 28), fill=accent)
        draw.text((138, y), feature, font=font(27), fill="#E7F1FF")

    draw.text((54, 1730), "华为应用市场搜索「星辰云巡」", font=font(32, bold=True), fill="white")
    draw.text((54, 1784), "配套开源服务端：xcmon.xciy.cn", font=font(24), fill="#91ABD0")
    return canvas


def poster_slide() -> Image.Image:
    canvas = background()
    draw = ImageDraw.Draw(canvas)
    draw.text((54, 62), "服务器状态，随时掌握", font=font(50, bold=True), fill="white")
    draw.text((54, 128), "把实时指标、趋势和告警装进口袋", font=font(26), fill="#9DC9FF")

    poster = Image.open(OUTPUT_DIR / "星辰云巡-竖版海报.png").convert("RGBA")
    poster = rounded_image(poster, (1000, 1333), 28)
    canvas.paste(poster, (40, 218), poster)

    draw.rounded_rectangle((54, 1640, 1026, 1814), radius=28, fill="#0D2343")
    draw.text((92, 1680), "HarmonyOS 原生体验", font=font(36, bold=True), fill="white")
    draw.text((92, 1738), "实时监控 · 服务探测 · 历史趋势 · 告警管理", font=font(24), fill="#B8CBE7")
    return canvas


def call_to_action_slide() -> Image.Image:
    canvas = background()
    add_brand(canvas)
    draw = ImageDraw.Draw(canvas)

    draw.text((54, 330), "现在体验", font=font(44), fill="#9DC9FF")
    draw.text((54, 392), "星辰云巡", font=font(86, bold=True), fill="white")
    draw.text((54, 512), "打开华为应用市场搜索应用名称", font=font(30), fill="#B8CBE7")

    qr = Image.open(OUTPUT_DIR / "应用市场二维码.png").convert("RGB")
    qr = qr.resize((520, 520), Image.Resampling.NEAREST)
    draw.rounded_rectangle((260, 690, 820, 1250), radius=32, fill="white")
    canvas.paste(qr, (280, 710))

    draw.rounded_rectangle((54, 1365, 1026, 1585), radius=28, fill="#0D2343")
    draw.text((92, 1408), "配套服务端「星辰监控」已开源", font=font(34, bold=True), fill="white")
    draw.text((92, 1470), "官网  xcmon.xciy.cn", font=font(26), fill="#29C786")
    draw.text((92, 1520), "GitHub / Gitee：monitor-for-server", font=font(23), fill="#B8CBE7")
    draw.text((54, 1740), "扫码进入应用详情", font=font(36, bold=True), fill="white")
    return canvas


def zoom(frame: np.ndarray, scale: float) -> np.ndarray:
    if scale <= 1:
        return frame
    crop_width = int(WIDTH / scale)
    crop_height = int(HEIGHT / scale)
    left = (WIDTH - crop_width) // 2
    top = (HEIGHT - crop_height) // 2
    cropped = frame[top : top + crop_height, left : left + crop_width]
    return cv2.resize(cropped, (WIDTH, HEIGHT), interpolation=cv2.INTER_LINEAR)


def write_video(slides: List[Image.Image], output_path: Path) -> None:
    slide_frames = int(SECONDS_PER_SLIDE * FPS)
    transition_frames = int(TRANSITION_SECONDS * FPS)
    frames = [cv2.cvtColor(np.asarray(slide), cv2.COLOR_RGB2BGR) for slide in slides]

    writer = cv2.VideoWriter(
        str(output_path),
        cv2.VideoWriter_fourcc(*"mp4v"),
        FPS,
        (WIDTH, HEIGHT),
    )
    if not writer.isOpened():
        raise RuntimeError("Unable to initialize MP4 video writer")

    try:
        for slide_index, frame in enumerate(frames):
            for frame_index in range(slide_frames):
                progress = frame_index / max(slide_frames - 1, 1)
                current = zoom(frame, 1 + progress * 0.018)
                if slide_index < len(frames) - 1 and frame_index >= slide_frames - transition_frames:
                    fade = (frame_index - (slide_frames - transition_frames)) / transition_frames
                    following = zoom(frames[slide_index + 1], 1 + fade * 0.004)
                    current = cv2.addWeighted(current, 1 - fade, following, fade, 0)
                writer.write(current)
    finally:
        writer.release()


def write_preview(slides: List[Image.Image], output_path: Path) -> None:
    width = 360
    height = 640
    preview = Image.new("RGB", (width * 3, height * 2), "#061124")
    for index, slide in enumerate(slides):
        preview.paste(slide.resize((width, height), Image.Resampling.LANCZOS), ((index % 3) * width, (index // 3) * height))
    preview.save(output_path, optimize=True)


def verify(video_path: Path, expected_frames: int) -> None:
    capture = cv2.VideoCapture(str(video_path))
    try:
        width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
        frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
        fps = round(capture.get(cv2.CAP_PROP_FPS))
        if (width, height, fps) != (WIDTH, HEIGHT, FPS):
            raise RuntimeError(f"Unexpected video properties: {width}x{height} at {fps} FPS")
        if frames != expected_frames:
            raise RuntimeError(f"Unexpected frame count: {frames} (expected {expected_frames})")
    finally:
        capture.release()


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    slides: List[Image.Image] = [
        poster_slide(),
        feature_slide("1.png", "关键状态，一眼掌握", "CPU、内存、磁盘、网络与温度\n打开手机就能查看。", "#28A6FF"),
        feature_slide("2.png", "异常变化，及时发现", "服务探测、分级告警与历史结果\n帮助快速定位问题。", "#FF665E"),
        feature_slide("3.png", "原生体验，多种主题", "跟随系统切换深浅色模式\n紧凑屏与大屏设备均可使用。", "#7A78FF"),
        feature_slide("4.png", "连接简单，凭据留在本机", "扫码或手动绑定监控空间\nAPI Token 使用系统能力保存。", "#29C786"),
        call_to_action_slide(),
    ]

    video_path = OUTPUT_DIR / "星辰云巡-抖音竖版短视频.mp4"
    preview_path = OUTPUT_DIR / "星辰云巡-短视频分镜预览.png"
    write_video(slides, video_path)
    write_preview(slides, preview_path)
    verify(video_path, len(slides) * int(SECONDS_PER_SLIDE * FPS))
    print(f"Video: {video_path}")
    print(f"Preview: {preview_path}")


if __name__ == "__main__":
    main()
