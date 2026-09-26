#!/usr/bin/env python3
"""
cards.py -- renders the static/typed title cards for the CRATE demo video,
in the style of demo/ref/ref1.mp4 (warm cream bg, black serif headlines,
a small kicker pill, restraint). ffmpeg here has no drawtext/libass, so
every card is rendered as a PNG (or, for the typed-on line, a short PNG
sequence muxed into a video) with Pillow.

Run directly to (re)generate everything into demo/cards/:
  python cards.py                  # all cards
  python cards.py --only title     # just one (title|chapters|end_typed|end_card)

Produces:
  demo/cards/title.png             1920x1080  "Your crates, instantly."
  demo/cards/chapter_01..04.png    1920x1080  one line each
  demo/cards/end_typed.mov         1920x1080@30, ~2.5s, silent PCM audio
  demo/cards/end_card.png          1920x1080  CRATE wordmark + 2 lines
"""
import argparse
import os
import shutil
import sys
import tempfile

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vidcommon as vc

W, H = vc.CANVAS_W, vc.CANVAS_H
MARGIN_X = 400          # left margin for title/chapter cards, ~= ref's 21% of width
KICKER = "AI sampler for iPhone Duo"
TITLE = "CRATE"
TAGLINE = "Type a vibe. Get a beat. Fold the phone to drop it."
CHAPTERS = [
    "Say the vibe.",
    "It digs your own sample packs.",
    "Two screens. One instrument.",
    "The hinge is the punch-in FX.",
]
CLOSING_LINE = "Type a sound, get a pad."
END_LINE_1 = "Type a sound, get a pad."
END_LINE_2 = "Built at Bitrig Hacks · iPhone Duo Edition"


def canvas():
    return Image.new("RGB", (W, H), vc.CREAM)


def fit_size(draw, text, weight, max_w, start, min_size=28, step=2):
    size = start
    while size > min_size:
        f = vc.serif_font(size, weight)
        if draw.textlength(text, font=f) <= max_w:
            return f, size
        size -= step
    return vc.serif_font(min_size, weight), min_size


def rounded_pill(draw, xy, text, font, fg, border, pad_x=22, pad_y=12):
    x, y = xy
    tw = draw.textlength(text, font=font)
    asc, desc = font.getmetrics()
    th = asc + desc
    box = [x, y, x + tw + pad_x * 2, y + th + pad_y * 2]
    r = (box[3] - box[1]) / 2
    draw.rounded_rectangle(box, radius=r, outline=border, width=2)
    draw.text((x + pad_x, y + pad_y), text, font=font, fill=fg)
    return box


# --------------------------------------------------------------- (a) title --
def render_title(out_path):
    img = canvas()
    d = ImageDraw.Draw(img)
    kicker_font = vc.sans_font(28)
    pill_box = rounded_pill(d, (MARGIN_X, 150), KICKER, kicker_font, vc.GREY, (216, 209, 199))

    headline_font = vc.serif_font(132, "Regular")
    y = pill_box[3] + 56
    d.text((MARGIN_X, y), TITLE, font=headline_font, fill=vc.INK)
    asc, desc = headline_font.getmetrics()
    d.text((MARGIN_X, y + asc + desc + 28), TAGLINE, font=vc.serif_font(54, "Regular"), fill=vc.GREY)
    img.save(out_path)
    return out_path


# ---------------------------------------------------------- (b) chapters ---
def render_chapter(text, out_path):
    img = canvas()
    d = ImageDraw.Draw(img)
    max_w = W - 2 * MARGIN_X
    font, _ = fit_size(d, text, "Regular", max_w, 92)
    asc, desc = font.getmetrics()
    th = asc + desc
    y = (H - th) / 2
    d.text((MARGIN_X, y), text, font=font, fill=vc.INK)
    img.save(out_path)
    return out_path


# --------------------------------------------------- (c) typed closing line --
def render_end_typed(out_path, dur=2.5, fps=vc.FPS, type_frac=0.62):
    tmpdir = tempfile.mkdtemp(prefix="end_typed_")
    try:
        nframes = round(dur * fps)
        type_frames = max(1, round(nframes * type_frac))
        hold_frames = nframes - type_frames
        n_chars = len(CLOSING_LINE)

        font = vc.serif_font(112, "Regular")
        probe = ImageDraw.Draw(canvas())
        full_w = probe.textlength(CLOSING_LINE, font=font)
        asc, desc = font.getmetrics()
        th = asc + desc
        x0 = (W - full_w) / 2
        y0 = (H - th) / 2
        cursor_w = max(4, round(112 * 0.045))
        blink_on, blink_off = 9, 9

        for i in range(nframes):
            if i < type_frames:
                chars = min(n_chars, int(i / type_frames * n_chars) + 1)
                cursor_visible = True
            else:
                chars = n_chars
                j = i - type_frames
                cursor_visible = (j % (blink_on + blink_off)) < blink_on
            shown = CLOSING_LINE[:chars]
            img = canvas()
            d = ImageDraw.Draw(img)
            d.text((x0, y0), shown, font=font, fill=vc.INK)
            cx = x0 + probe.textlength(shown, font=font) + 6
            if cursor_visible:
                d.rectangle([cx, y0 + 4, cx + cursor_w, y0 + th - 4], fill=vc.ORANGE)
            img.save(os.path.join(tmpdir, f"f_{i:04d}.png"))

        vc.sh([
            "ffmpeg", "-v", "error", "-y",
            "-framerate", str(fps), "-i", os.path.join(tmpdir, "f_%04d.png"),
        ] + vc.silent_audio_args(dur) + [
            "-r", str(fps),
        ] + vc.VCODEC_MOV + vc.ACODEC_PCM + ["-shortest", out_path])
        return out_path
    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)


# -------------------------------------------------------------- (c) end card --
def render_end_card(out_path):
    img = canvas()
    d = ImageDraw.Draw(img)

    word_font = vc.doto_font(168)
    tw = d.textlength("CRATE", font=word_font)
    asc, desc = word_font.getmetrics()
    word_h = asc + desc

    l1_font = vc.sans_font(30)
    l2_font = vc.sans_font(26)
    l1_w = d.textlength(END_LINE_1, font=l1_font)
    l2_w = d.textlength(END_LINE_2, font=l2_font)

    gap1, gap2 = 46, 20
    total_h = word_h + gap1 + (l1_font.getmetrics()[0] + l1_font.getmetrics()[1]) + gap2 + (l2_font.getmetrics()[0] + l2_font.getmetrics()[1])
    y = (H - total_h) / 2

    d.text(((W - tw) / 2, y), "CRATE", font=word_font, fill=vc.ORANGE)
    y += word_h + gap1
    d.text(((W - l1_w) / 2, y), END_LINE_1, font=l1_font, fill=vc.INK)
    y += l1_font.getmetrics()[0] + l1_font.getmetrics()[1] + gap2
    d.text(((W - l2_w) / 2, y), END_LINE_2, font=l2_font, fill=vc.GREY)

    img.save(out_path)
    return out_path


def render_caption(text, out_path, y=None, size=38, sub=None):
    """transparent 1920x1080 PNG: one serif line (ink) centred in the bottom
    cream margin of a big flat shot (box 0.84 leaves ~86 px); optional grey
    second line."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = vc.serif_font(size, "Regular")
    tw = d.textlength(text, font=f)
    asc, desc = f.getmetrics()
    yy = y if y is not None else H - 22 - (asc + desc)
    d.text(((W - tw) / 2, yy), text, font=f, fill=vc.INK + (255,))
    if sub:
        fs = vc.sans_font(24)
        sw = d.textlength(sub, font=fs)
        d.text(((W - sw) / 2, yy - 34), sub, font=fs, fill=vc.GREY + (255,))
    img.save(out_path)
    return out_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["title", "chapters", "end_typed", "end_card"], default=None)
    ap.add_argument("--outdir", default=vc.CARDS_DIR)
    args = ap.parse_args()
    os.makedirs(args.outdir, exist_ok=True)

    todo = [args.only] if args.only else ["title", "chapters", "end_typed", "end_card"]
    if "title" in todo:
        p = render_title(os.path.join(args.outdir, "title.png"))
        print("wrote", p)
    if "chapters" in todo:
        for i, line in enumerate(CHAPTERS, 1):
            p = render_chapter(line, os.path.join(args.outdir, f"chapter_{i:02d}.png"))
            print("wrote", p)
    if "end_typed" in todo:
        p = render_end_typed(os.path.join(args.outdir, "end_typed.mov"))
        print("wrote", p)
    if "end_card" in todo:
        p = render_end_card(os.path.join(args.outdir, "end_card.png"))
        print("wrote", p)


if __name__ == "__main__":
    main()
