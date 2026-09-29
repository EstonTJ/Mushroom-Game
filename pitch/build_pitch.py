from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph
from reportlab.lib.utils import ImageReader


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "output" / "Mushroom_Moon_game_pitch.pdf"
DAY = ROOT / "assets" / "hut-day-concept.png"
NIGHT = ROOT / "assets" / "hut-night-concept.png"
W, H = 792, 612

pdfmetrics.registerFont(TTFont("Georgia", "/System/Library/Fonts/Supplemental/Georgia.ttf"))
pdfmetrics.registerFont(TTFont("Georgia-Bold", "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"))
pdfmetrics.registerFont(TTFont("HelveticaNeue", "/System/Library/Fonts/HelveticaNeue.ttc", subfontIndex=0))

INK = colors.HexColor("#26332C")
MOSS = colors.HexColor("#405C48")
CREAM = colors.HexColor("#F7F2E8")
PALE = colors.HexColor("#E7E8D6")
AMBER = colors.HexColor("#DB9D51")
PLUM = colors.HexColor("#5F4A73")
TEAL = colors.HexColor("#76C7C4")


def rect(c, x, y, w, h, fill, radius=0, stroke=None):
    c.setFillColor(fill)
    c.setStrokeColor(stroke or fill)
    if radius:
        c.roundRect(x, y, w, h, radius, fill=1, stroke=int(stroke is not None))
    else:
        c.rect(x, y, w, h, fill=1, stroke=int(stroke is not None))


def label(c, x, y, text, size=10, color=INK, font="HelveticaNeue"):
    c.setFillColor(color)
    c.setFont(font, size)
    c.drawString(x, y, text)


def paragraph(c, text, x, top, width, size=12, leading=None, color=INK, font="HelveticaNeue"):
    style = ParagraphStyle(
        "body", fontName=font, fontSize=size, leading=leading or size * 1.42,
        textColor=color, alignment=TA_LEFT, spaceAfter=0,
    )
    p = Paragraph(text, style)
    _, height = p.wrap(width, 1000)
    p.drawOn(c, x, top - height)
    return top - height


def image_cover(c, path, x, y, w, h):
    im = ImageReader(str(path))
    iw, ih = im.getSize()
    scale = max(w / iw, h / ih)
    sw, sh = iw * scale, ih * scale
    c.saveState()
    p = c.beginPath()
    p.rect(x, y, w, h)
    c.clipPath(p, stroke=0)
    c.drawImage(im, x + (w - sw) / 2, y + (h - sh) / 2, sw, sh)
    c.restoreState()


def page_num(c, number, dark=False):
    color = colors.white if dark else MOSS
    label(c, 39, 27, "ESTON + SIMON  /  GAME CONCEPT", 8, color)
    label(c, 739, 27, f"0{number}", 8, color)


c = canvas.Canvas(str(OUT), pagesize=(W, H), pageCompression=1)
c.setTitle("Mushroom Moon | Game Concept")
c.setAuthor("Eston and Simon")

# 1 | Cover
image_cover(c, DAY, 0, 0, W, H)
rect(c, 0, 0, 355, H, colors.Color(0.08, 0.13, 0.10, alpha=0.77))
label(c, 40, 540, "A WORKING GAME CONCEPT", 11, colors.HexColor("#EBCB9C"))
label(c, 38, 411, "Mushroom", 39, colors.white, "Georgia-Bold")
label(c, 38, 361, "Moon", 45, colors.white, "Georgia-Bold")
rect(c, 40, 329, 54, 3, AMBER)
paragraph(c, "Forage by day. Brew your defenses.<br/>Protect the witch's hut by night.", 40, 302, 263, 17, 25, colors.white, "Georgia")
label(c, 40, 79, "A mobile game idea by Eston and Simon", 11, colors.white)
label(c, 40, 57, "Cozy magic  /  hands-on brewing  /  night defense", 9, colors.HexColor("#EBCB9C"))
c.showPage()

# 2 | Core loop
rect(c, 0, 0, W, H, CREAM)
label(c, 40, 562, "THE IDEA", 10, MOSS)
label(c, 40, 510, "Every potion has a purpose.", 28, INK, "Georgia-Bold")
paragraph(c, "The player lives in a woodland hut. Each day brings a short foraging trip and time at the cauldron. At night, creatures emerge from the forest. The potions made that day become traps, wards, and last-second throws.", 40, 483, 700, 13, 19)

steps = [
    ("01", "FORAGE", "Find mushrooms, herbs, and rare ingredients in the woods."),
    ("02", "BREW", "Crush, steep, and combine ingredients to discover useful effects."),
    ("03", "FORTIFY", "Place bottled brews along the paths leading to the hut."),
    ("04", "DEFEND", "Use spare potions as the night attack unfolds."),
]
xs = [40, 223, 406, 589]
for x, (num, title, body) in zip(xs, steps):
    rect(c, x, 235, 163, 166, colors.white, 13)
    label(c, x + 16, 365, num, 18, AMBER, "Georgia-Bold")
    label(c, x + 16, 338, title, 10, MOSS)
    paragraph(c, body, x + 16, 319, 133, 11, 15)

rect(c, 40, 82, 712, 124, PALE, 12)
label(c, 58, 175, "THE CENTRAL CHOICE", 10, MOSS)
paragraph(c, "A rare glowing mushroom could become a powerful path trap, a potion held for an emergency, or an experiment that unlocks tomorrow's recipe.", 58, 156, 661, 16, 23, INK, "Georgia")
page_num(c, 2)
c.showPage()

# 3 | Gameplay and night art
rect(c, 0, 0, W, H, CREAM)
image_cover(c, NIGHT, 0, 220, W, 392)
rect(c, 0, 220, W, 41, colors.Color(0.10, 0.12, 0.19, alpha=0.80))
label(c, 40, 235, "ONE HUT. TWO PATHS. A DIFFERENT BREWING PLAN EACH NIGHT.", 12, colors.white)
label(c, 40, 184, "Brewing drives the defense", 22, INK, "Georgia-Bold")
paragraph(c, "Potion effects become easy-to-read tools: spore clouds slow a crowd, sticky syrup holds a path, and a moonlit ward protects the hut. The player chooses where to place each brew before nightfall, then throws saved bottles at key moments.", 40, 164, 712, 12, 17)
page_num(c, 3)
c.showPage()

# 4 | Art direction and first playable
rect(c, 0, 0, W, H, CREAM)
label(c, 40, 560, "LOOK + FEEL", 10, MOSS)
label(c, 40, 511, "A cozy forest with a little bite.", 27, INK, "Georgia-Bold")
paragraph(c, "Warm storybook textures and oversized mushrooms make the world inviting. Night shifts the palette to violet and deep blue, while potion effects glow clearly against the paths. The creatures can be mischievous and strange without becoming frightening.", 40, 485, 710, 12, 18)

palette = [(MOSS, "MOSS"), (CREAM, "PARCHMENT"), (AMBER, "LANTERN"), (PLUM, "TWILIGHT"), (TEAL, "MAGIC")]
for i, (color, name) in enumerate(palette):
    x = 40 + i * 143
    rect(c, x, 307, 127, 65, color, 9, colors.HexColor("#C9CDBD") if name == "PARCHMENT" else None)
    label(c, x, 291, name, 9, MOSS)

rect(c, 40, 75, 341, 179, colors.white, 12)
label(c, 58, 224, "FIRST PLAYABLE VERSION", 10, MOSS)
paragraph(c, "<b>1 hut</b> with two approach paths<br/><b>5 ingredients</b> to gather<br/><b>4 potion effects</b> to discover<br/><b>3 nights</b> of increasing pressure", 58, 205, 304, 13, 26)

rect(c, 399, 75, 353, 179, PALE, 12)
label(c, 417, 224, "THE QUESTION TO TEST", 10, MOSS)
paragraph(c, "Is making a potion satisfying on its own - and does seeing that same potion save the hut make the next brew even more exciting?", 417, 205, 316, 15, 22, INK, "Georgia")

page_num(c, 4)
c.save()
print(OUT)
