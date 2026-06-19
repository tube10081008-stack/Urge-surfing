#!/usr/bin/env python3
"""
오리지널 노출 자극 미디어 생성기 (저작권 프리).

- slot_jackpot.gif : 3릴 슬롯 스핀 → 777 정렬 + BIG WIN 연출 (강한 강도)
- slot_soft.gif    : 느리고 차분한 슬롯 스핀 (약한 강도)
- odds_board.png   : 스포츠 베팅 배당률 보드 (정적)
- win_jingle.wav   : 잭팟 사운드 (상승 아르페지오 + 코인)

실제 게임사 콘텐츠가 아닌 직접 생성물이라 배포/커밋에 제약이 없다.
의존성: Pillow, numpy (오디오는 표준 wave 모듈).
"""
import math
import os
import random
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "exposure")
os.makedirs(OUT, exist_ok=True)

W, H = 480, 270
CELL = 90  # 셀 높이(3칸 = 270)

FONT_DIR = "/usr/share/fonts/truetype/dejavu"


def font(size, bold=True):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    path = os.path.join(FONT_DIR, name)
    if not os.path.exists(path):
        path = os.path.join(FONT_DIR, "DejaVuSans.ttf")
    return ImageFont.truetype(path, size)


def centered(draw, cx, cy, text, fnt, fill):
    l, t, r, b = draw.textbbox((0, 0), text, font=fnt)
    draw.text((cx - (r - l) / 2 - l, cy - (b - t) / 2 - t), text, font=fnt, fill=fill)


SYMBOLS = ["7", "★", "♥", "♦", "$", "♣"]
SYM_COLOR = {
    "7": (230, 60, 60),
    "★": (245, 200, 40),
    "♥": (230, 80, 110),
    "♦": (90, 160, 230),
    "$": (80, 200, 130),
    "♣": (150, 120, 220),
}


def make_strip(win_symbol, target_center, length=24):
    """길이 length의 심볼 배열. 정렬 시 중앙칸이 win_symbol 이 되도록 배치."""
    strip = [random.choice(SYMBOLS) for _ in range(length)]
    strip[(target_center + 1) % length] = win_symbol
    return strip


def ease_out_cubic(t):
    return 1 - (1 - t) ** 3


def render_slot(filename, *, jackpot, frames, fps, bg, jitter_win):
    sym_fnt = font(64, bold=True)
    big_fnt = font(46, bold=True)
    reel_w = 150
    gap = (W - reel_w * 3) // 4
    reel_x = [gap + i * (reel_w + gap) for i in range(3)]

    win_syms = ["7", "7", "7"] if jackpot else ["★", "♦", "7"]
    target = [random.randint(2, 20) for _ in range(3)]
    strips = [make_strip(win_syms[i], target[i]) for i in range(3)]
    spin_dist = [CELL * (16 + i * 6) for i in range(3)]  # 릴마다 다른 회전량
    stop_f = [int(frames * s) for s in (0.45, 0.62, 0.8)]  # 순차 정지

    images = []
    win_start = max(stop_f) + 1
    for f in range(frames):
        img = Image.new("RGB", (W, H), bg)
        d = ImageDraw.Draw(img)
        # 릴 배경 패널
        for i in range(3):
            d.rounded_rectangle(
                [reel_x[i], 6, reel_x[i] + reel_w, H - 6], radius=12,
                fill=(20, 24, 34), outline=(70, 80, 100), width=2,
            )
        # 각 릴 심볼
        for i in range(3):
            prog = min(f / stop_f[i], 1.0) if stop_f[i] else 1.0
            eased = ease_out_cubic(prog)
            p = (1 - eased) * spin_dist[i] + target[i] * CELL
            base = int(p // CELL)
            frac = p - base * CELL
            cx = reel_x[i] + reel_w / 2
            for k in range(-1, 3):
                cy = k * CELL - frac + CELL / 2 + 6
                sym = strips[i][(base + k) % len(strips[i])]
                if -CELL < cy < H + CELL:
                    centered(d, cx, cy, sym, sym_fnt, SYM_COLOR.get(sym, (230, 230, 230)))
        # 중앙 당첨라인
        d.line([(8, H / 2 + 6), (W - 8, H / 2 + 6)], fill=(255, 215, 0, 120), width=1)

        # BIG WIN 연출 (잭팟, 정지 후 깜빡임)
        if jackpot and f >= win_start:
            on = ((f - win_start) // 2) % 2 == 0
            if on:
                d.rounded_rectangle([4, 4, W - 4, H - 4], radius=14,
                                    outline=(255, 215, 0), width=8)
                banner_y = H / 2 + 6
                d.rounded_rectangle([W / 2 - 130, banner_y - 34, W / 2 + 130, banner_y + 34],
                                    radius=16, fill=(200, 30, 40))
                centered(d, W / 2, banner_y, "BIG WIN!", big_fnt, (255, 240, 180))
        images.append(img.convert("P", palette=Image.ADAPTIVE, colors=128))

    dur = int(1000 / fps)
    # 마지막 프레임 잠깐 유지
    images[-1].info["duration"] = dur * 6
    images[0].save(
        os.path.join(OUT, filename), save_all=True, append_images=images[1:],
        duration=dur, loop=0, optimize=True, disposal=2,
    )
    print("wrote", filename, os.path.getsize(os.path.join(OUT, filename)) // 1024, "KB")


def render_odds_board(filename):
    img = Image.new("RGB", (W, H), (12, 16, 26))
    d = ImageDraw.Draw(img)
    title_fnt = font(20, bold=True)
    row_fnt = font(18, bold=False)
    odd_fnt = font(19, bold=True)
    d.rectangle([0, 0, W, 38], fill=(20, 80, 60))
    centered(d, W / 2, 19, "LIVE  베팅 배당률", title_fnt, (235, 245, 240))
    games = [
        ("FC 서울", "전북", "2.10", "3.30", "3.05"),
        ("두산", "LG", "1.85", "—", "1.95"),
        ("KIA", "삼성", "2.40", "3.10", "2.70"),
        ("맨시티", "리버풀", "1.95", "3.50", "3.80"),
    ]
    y = 50
    for home, away, o1, ox, o2 in games:
        d.rounded_rectangle([10, y, W - 10, y + 44], radius=8, fill=(22, 28, 40))
        centered(d, 95, y + 22, f"{home}", row_fnt, (225, 230, 240))
        centered(d, 175, y + 22, "vs", row_fnt, (130, 140, 160))
        centered(d, 255, y + 22, f"{away}", row_fnt, (225, 230, 240))
        for cx, o, col in ((330, o1, (80, 200, 130)), (385, ox, (240, 210, 90)), (440, o2, (90, 160, 230))):
            d.rounded_rectangle([cx - 24, y + 8, cx + 24, y + 36], radius=6, fill=(15, 20, 30))
            centered(d, cx, y + 22, o, odd_fnt, col)
        y += 52
    img.save(os.path.join(OUT, filename))
    print("wrote", filename, os.path.getsize(os.path.join(OUT, filename)) // 1024, "KB")


def render_win_wav(filename):
    sr = 22050
    notes = [523, 659, 784, 1047, 1319]  # C5 E5 G5 C6 E6 상승
    seg = 0.22
    audio = np.zeros(0, dtype=np.float32)
    for i, fr in enumerate(notes):
        t = np.linspace(0, seg, int(sr * seg), endpoint=False)
        env = np.exp(-4 * t)
        tone = 0.5 * np.sin(2 * np.pi * fr * t) + 0.2 * np.sin(2 * np.pi * 2 * fr * t)
        audio = np.concatenate([audio, (tone * env).astype(np.float32)])
    # 코인 클링크(고주파 짧은 블립) 몇 개
    for _ in range(8):
        seg2 = 0.05
        t = np.linspace(0, seg2, int(sr * seg2), endpoint=False)
        fr = random.choice([1800, 2200, 2600, 3000])
        env = np.exp(-30 * t)
        blip = 0.25 * np.sin(2 * np.pi * fr * t) * env
        pad = np.zeros(int(sr * random.uniform(0.02, 0.08)), dtype=np.float32)
        audio = np.concatenate([audio, blip.astype(np.float32), pad])
    audio = np.clip(audio, -1, 1)
    pcm = (audio * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, filename), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())
    print("wrote", filename, os.path.getsize(os.path.join(OUT, filename)) // 1024, "KB")


if __name__ == "__main__":
    random.seed(7)
    render_slot("slot_jackpot.gif", jackpot=True, frames=46, fps=14,
                bg=(8, 10, 18), jitter_win=True)
    render_slot("slot_soft.gif", jackpot=False, frames=40, fps=10,
                bg=(18, 22, 32), jitter_win=False)
    render_odds_board("odds_board.png")
    render_win_wav("win_jingle.wav")
    print("done.")
