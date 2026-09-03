from pathlib import Path
from typing import Tuple

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "素材" / "推广素材"
APP_LINK = (
    "https://appgallery.huawei.com/app/detail?"
    "id=cn.xciy.xcyx&channelId=SHARE&source=appshare"
)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    filename = "msyhbd.ttc" if bold else "msyh.ttc"
    return ImageFont.truetype(str(Path("C:/Windows/Fonts") / filename), size)


def rounded_image(image: Image.Image, size: Tuple[int, int], radius: int) -> Image.Image:
    fitted = image.resize(size, Image.Resampling.LANCZOS)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *size), radius=radius, fill=255)
    fitted.putalpha(mask)
    return fitted


def make_qr() -> Image.Image:
    encoder = cv2.QRCodeEncoder_create()
    qr = encoder.encode(APP_LINK)
    qr = cv2.copyMakeBorder(qr, 4, 4, 4, 4, cv2.BORDER_CONSTANT, value=255)
    qr = cv2.resize(qr, (600, 600), interpolation=cv2.INTER_NEAREST)
    qr_image = Image.fromarray(qr).convert("RGB")
    qr_image.save(OUTPUT_DIR / "应用市场二维码.png", optimize=True)
    return qr_image


def make_poster(qr_image: Image.Image) -> None:
    width, height = 1080, 1440
    canvas = Image.new("RGB", (width, height), "#061124")
    draw = ImageDraw.Draw(canvas)

    for y in range(height):
        ratio = y / height
        color = (
            int(6 + 7 * ratio),
            int(17 + 14 * ratio),
            int(36 + 32 * ratio),
        )
        draw.line((0, y, width, y), fill=color)

    for y in range(32, height, 72):
        draw.line((0, y, width, y), fill="#0D2547", width=1)

    logo = Image.open(ROOT / "素材" / "星辰云巡logo.png").convert("RGBA")
    logo = rounded_image(logo, (112, 112), 22)
    canvas.paste(logo, (44, 44), logo)

    draw.text((184, 48), "星辰云巡", font=font(52, bold=True), fill="white")
    draw.text((184, 112), "服务器监控 · 运维更轻松", font=font(24), fill="#9DC9FF")
    draw.rounded_rectangle((830, 58, 1034, 122), radius=20, fill="#0C6CF2")
    draw.text((872, 73), "HarmonyOS", font=font(24, bold=True), fill="white")

    hero = Image.open(ROOT / "素材" / "宣传图" / "1.png").convert("RGBA")
    hero = rounded_image(hero, (1008, 567), 24)
    canvas.paste(hero, (36, 196), hero)

    draw.text((48, 820), "把服务器状态装进口袋", font=font(56, bold=True), fill="white")
    draw.text(
        (50, 900),
        "实时指标、历史趋势、服务探测与告警动态，一处掌握。",
        font=font(25),
        fill="#B8CBE7",
    )

    features = [
        ("实时监控", "CPU / 内存 / 磁盘 / 网络", "#28A6FF"),
        ("服务探测", "HTTP / Ping / TCPing", "#29C786"),
        ("安全连接", "凭据使用系统能力保存在本机", "#7A78FF"),
    ]
    x_positions = [48, 386, 724]
    for x, (title, subtitle, accent) in zip(x_positions, features):
        draw.rounded_rectangle((x, 970, x + 306, 1057), radius=16, fill="#0D2343")
        draw.rounded_rectangle((x + 14, 989, x + 24, 1038), radius=5, fill=accent)
        draw.text((x + 42, 981), title, font=font(23, bold=True), fill="white")
        draw.text((x + 42, 1018), subtitle, font=font(14), fill="#94AED1")

    draw.rounded_rectangle((36, 1100, 1044, 1402), radius=24, fill="#F7FAFF")
    draw.text((72, 1144), "现在体验星辰云巡", font=font(38, bold=True), fill="#0A2145")
    draw.text((72, 1204), "打开华为应用市场，搜索「星辰云巡」", font=font(22), fill="#405675")
    draw.text((72, 1255), "或使用 HarmonyOS 设备扫码进入应用详情", font=font(22), fill="#405675")
    draw.rounded_rectangle((72, 1322, 660, 1371), radius=14, fill="#E7F1FF")
    draw.text((96, 1332), "开源 · 多空间 · 多主题 · 告警管理", font=font(19, bold=True), fill="#0B5CC7")

    qr = qr_image.resize((244, 244), Image.Resampling.NEAREST)
    draw.rounded_rectangle((752, 1129, 1016, 1393), radius=16, fill="white")
    canvas.paste(qr, (762, 1139))

    canvas.save(OUTPUT_DIR / "星辰云巡-竖版海报.png", optimize=True)


def verify() -> None:
    detector = cv2.QRCodeDetector()
    qr_path = OUTPUT_DIR / "应用市场二维码.png"
    poster_path = OUTPUT_DIR / "星辰云巡-竖版海报.png"

    qr = cv2.imdecode(np.fromfile(qr_path, dtype=np.uint8), cv2.IMREAD_COLOR)
    qr_value, _, _ = detector.detectAndDecode(qr)
    if qr_value != APP_LINK:
        raise RuntimeError("QR verification failed")

    poster = cv2.imdecode(np.fromfile(poster_path, dtype=np.uint8), cv2.IMREAD_COLOR)
    poster_value, _, _ = detector.detectAndDecode(poster)
    if poster_value != APP_LINK:
        raise RuntimeError("Poster QR verification failed")

    print(f"QR verified: {qr_value}")
    print(f"Poster: {poster_path}")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    qr_image = make_qr()
    make_poster(qr_image)
    verify()


if __name__ == "__main__":
    main()
