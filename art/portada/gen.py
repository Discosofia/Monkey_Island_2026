"""Generator for the "Primal Banana Islands" cover art.

Writes portada.svg (1920x1080) and icono.svg (512x512). All shapes are
hand-authored vectors; the only embedded asset is a subset of the Inter Display
Black font (SIL OFL) used for the logo lettering.

    python3 gen.py && python3 render.py
"""
import base64
import math
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
FONT_B64 = base64.b64encode(open(os.path.join(HERE, 'title-font.woff2'), 'rb').read()).decode()

DEFS = []          # collected <defs> children
_ids = {}


def uid(prefix):
    _ids[prefix] = _ids.get(prefix, 0) + 1
    return f'{prefix}{_ids[prefix]}'


# ---------------------------------------------------------------- colour utils
def hx(c):
    c = c.lstrip('#')
    return tuple(int(c[i:i + 2], 16) for i in (0, 2, 4))


def rgb(t):
    return '#%02x%02x%02x' % tuple(max(0, min(255, int(round(v)))) for v in t)


def mix(a, b, t):
    a, b = hx(a), hx(b)
    return rgb(tuple(a[i] + (b[i] - a[i]) * t for i in range(3)))


def shade(a, f):
    return rgb(tuple(v * f for v in hx(a)))


def lin(stops, x1=0, y1=0, x2=1, y2=0, units=None, gid=None):
    gid = gid or uid('g')
    u = f' gradientUnits="{units}"' if units else ''
    s = ''.join(
        f'<stop offset="{o}" stop-color="{c}"' + (f' stop-opacity="{op}"' if op is not None else '') + '/>'
        for o, c, op in [(st + (None,))[:3] for st in stops])
    DEFS.append(f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}"{u}>{s}</linearGradient>')
    return f'url(#{gid})'


def rad(stops, cx=.5, cy=.5, r=.5, fx=None, fy=None, units=None, gid=None):
    gid = gid or uid('r')
    u = f' gradientUnits="{units}"' if units else ''
    f = (f' fx="{fx}"' if fx is not None else '') + (f' fy="{fy}"' if fy is not None else '')
    s = ''.join(
        f'<stop offset="{o}" stop-color="{c}"' + (f' stop-opacity="{op}"' if op is not None else '') + '/>'
        for o, c, op in [(st + (None,))[:3] for st in stops])
    DEFS.append(f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}"{f}{u}>{s}</radialGradient>')
    return f'url(#{gid})'


def base_defs():
    DEFS.append(f'''
<style>
@font-face {{ font-family: 'PBI Title'; font-weight: 900;
  src: url(data:font/woff2;base64,{FONT_B64}) format('woff2'); }}
.logo {{ font-family: 'PBI Title', 'Inter Display', 'Inter', 'DejaVu Sans', sans-serif; font-weight: 900; }}
</style>
<filter id="glow4" x="-50%" y="-50%" width="200%" height="200%">
  <feGaussianBlur stdDeviation="4" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
<filter id="glow10" x="-50%" y="-50%" width="200%" height="200%">
  <feGaussianBlur stdDeviation="10" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
<filter id="blur3" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="3"/></filter>
<filter id="blur8" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="8"/></filter>
<filter id="blur18" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="18"/></filter>
<filter id="blur40" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="40"/></filter>
<filter id="billow" x="-20%" y="-20%" width="140%" height="140%">
  <feTurbulence type="fractalNoise" baseFrequency="0.011" numOctaves="3" seed="7" result="n"/>
  <feDisplacementMap in="SourceGraphic" in2="n" scale="70" xChannelSelector="R" yChannelSelector="G"/></filter>
<filter id="rough" x="-10%" y="-10%" width="120%" height="120%">
  <feTurbulence type="fractalNoise" baseFrequency="0.04" numOctaves="2" seed="3" result="n"/>
  <feDisplacementMap in="SourceGraphic" in2="n" scale="10" xChannelSelector="R" yChannelSelector="G"/></filter>
<filter id="titleShadow" x="-10%" y="-10%" width="130%" height="140%">
  <feDropShadow dx="0" dy="12" stdDeviation="7" flood-color="#14020a" flood-opacity="0.75"/></filter>
<filter id="haze" x="-10%" y="-10%" width="120%" height="120%" color-interpolation-filters="sRGB">
  <feColorMatrix type="matrix" values="0.84 0.04 0 0 0.035  0.02 0.80 0.02 0 0.01  0.02 0.03 0.84 0 0.04  0 0 0 1 0"/></filter>
<filter id="charShadow" x="-20%" y="-20%" width="140%" height="140%">
  <feDropShadow dx="0" dy="0" stdDeviation="6" flood-color="#ff7a2a" flood-opacity="0.55"/></filter>
''')


# ------------------------------------------------------------------ primitives
def rrect(x, y, w, h, r, fill, extra=''):
    return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r}" fill="{fill}" {extra}/>'


def pts(p):
    return ' '.join(f'{x:.1f},{y:.1f}' for x, y in p)


def poly(p, fill, extra=''):
    return f'<polygon points="{pts(p)}" fill="{fill}" {extra}/>'


def rot(px, py, ang, L):
    a = math.radians(ang)
    return px - L * math.sin(a), py + L * math.cos(a)


def bez2(p0, p1, p2, t):
    return ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])


def ribbon(p0, p1, p2, w0, w1, n=24, notch=0.0):
    """Tapered filled shape along a quadratic bezier (palm trunks, fronds, tails)."""
    L, R = [], []
    for i in range(n + 1):
        t = i / n
        x, y = bez2(p0, p1, p2, t)
        x2, y2 = bez2(p0, p1, p2, min(1, t + 1e-3))
        x1, y1 = bez2(p0, p1, p2, max(0, t - 1e-3))
        dx, dy = x2 - x1, y2 - y1
        d = math.hypot(dx, dy) or 1
        nx, ny = -dy / d, dx / d
        w = (w0 + (w1 - w0) * t) / 2
        if notch and 0 < i < n:
            w *= (1.0 if i % 2 else 1 - notch)
        L.append((x + nx * w, y + ny * w))
        R.append((x - nx * w, y - ny * w))
    return L + R[::-1]


# ======================================================================== SKY
def sky(W=1920, H=1080):
    g = lin([(0, '#14062e'), (.22, '#33105a'), (.42, '#7a1c6e'), (.58, '#c42c62'),
             (.70, '#f2543e'), (.80, '#ff8a3a'), (.88, '#ffbe5a'), (1, '#ffd88a')],
            0, 0, 0, 1)
    out = [f'<rect x="0" y="0" width="{W}" height="{H}" fill="{g}"/>']
    # horizon glow
    hg = rad([(0, '#fff0b0', .95), (.35, '#ffb05a', .55), (1, '#ff5a3a', 0)], units='userSpaceOnUse',
             cx=620, cy=760, r=760)
    out.append(f'<rect x="0" y="0" width="{W}" height="{H}" fill="{hg}"/>')
    # stars in the high purple
    rnd = random.Random(4)
    for _ in range(70):
        x, y = rnd.uniform(0, W), rnd.uniform(0, 260)
        out.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{rnd.uniform(.8, 2.2):.1f}" fill="#ffe9ff" opacity="{rnd.uniform(.25, .8):.2f}"/>')
    # wispy sunset cloud streaks lit magenta/orange from below
    rnd = random.Random(11)
    for i in range(9):
        y = rnd.uniform(330, 640)
        x = rnd.uniform(-200, 1100)
        w = rnd.uniform(300, 700)
        c = mix('#ff5f8a', '#ffb070', (y - 330) / 310)
        out.append(f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="{w:.0f}" ry="{rnd.uniform(8, 18):.0f}" fill="{c}" opacity=".45" filter="url(#blur8)"/>')
        out.append(f'<ellipse cx="{x + 20:.0f}" cy="{y - 6:.0f}" rx="{w * .8:.0f}" ry="{rnd.uniform(6, 10):.0f}" fill="#5a1a5e" opacity=".35" filter="url(#blur3)"/>')
    return '\n'.join(out)


def sea():
    g = lin([(0, '#ff9d55'), (.15, '#d8507a'), (.55, '#5c1e5c'), (1, '#2a0c36')], 0, 0, 0, 1)
    out = [f'<rect x="0" y="742" width="1920" height="340" fill="{g}"/>']
    rnd = random.Random(5)
    for _ in range(40):
        y = rnd.uniform(748, 860)
        x = rnd.uniform(250, 1000)
        out.append(f'<rect x="{x:.0f}" y="{y:.0f}" width="{rnd.uniform(20, 120):.0f}" height="2.5" rx="1" fill="#ffd48a" opacity="{rnd.uniform(.25, .7):.2f}"/>')
    # distant islets
    out.append('<path d="M 0 748 Q 60 700 140 712 Q 200 690 260 735 L 300 748 Z" fill="#6a2464" opacity=".85"/>')
    out.append('<path d="M 430 748 Q 480 728 540 738 L 570 748 Z" fill="#7a2a66" opacity=".8"/>')
    return '\n'.join(out)


# ==================================================================== VOLCANO
CRATER = (1290, 332)


def volcano():
    out = []
    body = lin([(0, '#55203a'), (.25, '#3a1430'), (.7, '#240c26'), (1, '#170718')], 0, 0, 0, 1)
    d = ('M 430 820 C 720 780, 960 660, 1110 490 C 1170 420, 1205 365, 1222 334 '
         'Q 1290 356 1360 330 C 1385 365, 1430 430, 1500 505 C 1640 650, 1800 735, 2000 775 '
         'L 2000 960 L 430 960 Z')
    out.append(f'<path d="{d}" fill="{body}"/>')
    # sunset light on the left flank, darker right flank
    side = lin([(0, '#ff6a5a', .28), (.45, '#ff6a5a', .05), (.55, '#000000', 0), (1, '#0a0012', .45)], 430, 0, 2000, 0,
               units='userSpaceOnUse')
    out.append(f'<path d="{d}" fill="{side}"/>')
    # gullies / ridges
    for gd, op in [('M 1235 360 C 1200 470, 1120 560, 1000 680', .5), ('M 1320 360 C 1330 470, 1300 600, 1260 760', .45),
                   ('M 1360 350 C 1450 470, 1560 600, 1700 700', .45), ('M 1180 430 C 1100 540, 920 650, 760 740', .35)]:
        out.append(f'<path d="{gd}" stroke="#12040f" stroke-width="10" fill="none" opacity="{op}" stroke-linecap="round"/>')
    # lava rivers
    rivers = [
        ('M 1252 348 C 1236 420, 1192 470, 1172 540 S 1102 650, 1060 730', 1.0),
        ('M 1172 540 C 1142 590, 1152 645, 1120 720', .7),
        ('M 1300 352 C 1312 430, 1352 485, 1342 565 S 1382 680, 1430 770', 1.0),
        ('M 1345 342 C 1405 402, 1485 470, 1532 560 S 1652 690, 1740 760', .9),
        ('M 1532 560 C 1570 600, 1600 620, 1640 690', .6),
    ]
    for rd, k in rivers:
        out.append(f'<path d="{rd}" stroke="#ff2a00" stroke-width="{34 * k:.0f}" fill="none" opacity=".55" filter="url(#blur8)" stroke-linecap="round"/>')
        out.append(f'<path d="{rd}" stroke="#ff5a00" stroke-width="{14 * k:.0f}" fill="none" stroke-linecap="round"/>')
        out.append(f'<path d="{rd}" stroke="#ffd23a" stroke-width="{5 * k:.1f}" fill="none" stroke-linecap="round"/>')
    # crater rim glow
    cg = rad([(0, '#fff6c0'), (.25, '#ffcf40'), (.6, '#ff6a10', .7), (1, '#ff3000', 0)])
    out.append(f'<ellipse cx="{CRATER[0]}" cy="{CRATER[1] + 4}" rx="95" ry="26" fill="{cg}"/>')
    return '\n'.join(out)


def plume():
    rnd = random.Random(21)
    cx, cy = CRATER
    out = []
    grads = [
        rad([(0, '#ffb070'), (.45, '#e0603a'), (1, '#7a2e3a')], cx=.5, cy=.8, r=.7),
        rad([(0, '#f08a5a'), (.5, '#a8484a'), (1, '#4e2440')], cx=.5, cy=.8, r=.7),
        rad([(0, '#c4707a'), (.55, '#7a3c58'), (1, '#3a1c3a')], cx=.45, cy=.75, r=.75),
        rad([(0, '#9a6080'), (.55, '#5a3050'), (1, '#2a1430')], cx=.4, cy=.7, r=.8),
    ]
    hl = rad([(0, '#ffb0c0', .55), (1, '#ff90b0', 0)])
    blobs = []
    for i in range(80):
        t = i / 79
        x = cx + 460 * t ** 1.5 + rnd.uniform(-40, 40) * (0.3 + t)
        y = cy - 40 - 600 * t + rnd.uniform(-20, 20)
        r = 50 + 250 * t ** 0.9 + rnd.uniform(-15, 25)
        blobs.append((t, x, y, r))
        if t > .4:  # mushroom spreading
            blobs.append((t, x - rnd.uniform(160, 460) * t, y + rnd.uniform(-30, 70), r * rnd.uniform(.6, .9)))
            blobs.append((t, x + rnd.uniform(140, 380) * t, y + rnd.uniform(-40, 80), r * rnd.uniform(.6, .95)))
    blobs.sort(key=lambda b: -b[0])
    inner = []
    for t, x, y, r in blobs:
        gi = min(3, int(t * 4.0))
        inner.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r:.0f}" fill="{grads[gi]}"/>')
        if t > .25 and rnd.random() < .5:
            inner.append(f'<circle cx="{x - r * .3:.0f}" cy="{y - r * .3:.0f}" r="{r * .55:.0f}" fill="{hl}"/>')
    out.append(f'<g filter="url(#billow)">{"".join(inner)}</g>')
    # under-lighting from the eruption
    ug = rad([(0, '#ffb04a', .85), (.5, '#ff6a20', .35), (1, '#ff3000', 0)], units='userSpaceOnUse', cx=cx, cy=cy - 40, r=380)
    out.append(f'<ellipse cx="{cx}" cy="{cy - 80}" rx="380" ry="330" fill="{ug}"/>')
    # lightning in the ash cloud
    out.append(f'<path d="M {cx + 210} {cy - 330} l -30 50 l 26 6 l -40 70 l 22 4 l -30 60" stroke="#fff2ff" stroke-width="4" fill="none" '
               f'stroke-linejoin="round" filter="url(#glow10)" opacity=".9"/>')
    return '\n'.join(out)


def fountain():
    cx, cy = CRATER
    rnd = random.Random(8)
    out = []
    jet = lin([(0, '#fff8c8'), (.35, '#ffd23a'), (.75, '#ff6a00', .9), (1, '#ff3a00', 0)], 0, 1, 0, 0)
    jets = []
    for a in (-34, -22, -12, -4, 4, 13, 24, 36):
        L = rnd.uniform(110, 210) * (1.15 - abs(a) / 80)
        w = rnd.uniform(16, 28)
        jets.append(f'<path d="M {-w / 2:.0f} 0 Q {-w * .7:.0f} {-L * .5:.0f} 0 {-L:.0f} Q {w * .7:.0f} {-L * .5:.0f} {w / 2:.0f} 0 Z" '
                    f'fill="{jet}" transform="translate({cx + a * 1.2:.0f},{cy + 4}) rotate({a})"/>')
    out.append(f'<g filter="url(#glow10)">{"".join(jets)}</g>')
    sparks = []
    for _ in range(90):
        a = math.radians(rnd.uniform(-50, 50))
        dist = rnd.uniform(20, 300) ** 1.0
        x = cx + math.sin(a) * dist * 1.1
        y = cy - math.cos(a) * dist
        r = rnd.uniform(1.5, 5.5) * (1.2 - dist / 400)
        c = rnd.choice(['#fff2a0', '#ffd23a', '#ff9a1a', '#ff6a00'])
        sparks.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{max(r, 1):.1f}" fill="{c}"/>')
    out.append(f'<g filter="url(#glow4)">{"".join(sparks)}</g>')
    # big crater glow
    bg = rad([(0, '#ffe58a', .9), (.3, '#ff8a1a', .45), (1, '#ff3000', 0)])
    out.append(f'<ellipse cx="{cx}" cy="{cy - 20}" rx="260" ry="200" fill="{bg}" style="mix-blend-mode:screen"/>')
    return '\n'.join(out)


def bombs():
    cx, cy = CRATER
    out = []
    ends = [(990, 175, 15), (1110, 70, 11), (1580, 120, 16), (1740, 300, 12), (880, 380, 10), (1460, 40, 10),
            (1680, 450, 9), (1050, 300, 8)]
    for ex, ey, r in ends:
        ctrl = ((cx + ex) / 2, min(cy, ey) - 170)
        p = [bez2((cx, cy), ctrl, (ex, ey), 0.4 + 0.6 * i / 24) for i in range(25)]
        L, R = [], []
        for i, (x, y) in enumerate(p):
            j = min(i + 1, len(p) - 1); k = max(i - 1, 0)
            dx, dy = p[j][0] - p[k][0], p[j][1] - p[k][1]
            d = math.hypot(dx, dy) or 1
            w = r * .9 * (i / 24) ** 1.3
            L.append((x - dy / d * w, y + dx / d * w)); R.append((x + dy / d * w, y - dx / d * w))
        tg = lin([(0, '#ff3a00', 0), (.5, '#ff6a00', .6), (1, '#ffe27a', 1)], p[0][0], p[0][1], ex, ey, units='userSpaceOnUse')
        out.append(poly(L + R[::-1], tg, 'filter="url(#glow4)"'))
        out.append(f'<circle cx="{ex}" cy="{ey}" r="{r}" fill="#ffcf4a" filter="url(#glow10)"/>')
        out.append(f'<circle cx="{ex + r * .25:.1f}" cy="{ey + r * .2:.1f}" r="{r * .5:.1f}" fill="#8a2a08" opacity=".65"/>')
    return '\n'.join(out)


# ===================================================================== JUNGLE
def palm(x, y, h, lean, s, fill, rim, seed=0):
    rnd = random.Random(seed)
    top = (x + lean, y - h)
    trunk = ribbon((x, y), (x + lean * .1, y - h * .55), top, 26 * s, 13 * s, 20)
    out = [poly([(px + 3 * s, py - 2 * s) for px, py in trunk], rim), poly(trunk, fill)]
    # trunk rings
    for i in range(1, 9):
        t = i / 9
        px, py = bez2((x, y), (x + lean * .1, y - h * .55), top, t)
        w = (26 + (13 - 26) * t) * s / 2
        out.append(f'<line x1="{px - w:.1f}" y1="{py:.1f}" x2="{px + w:.1f}" y2="{py - 3 * s:.1f}" stroke="{rim}" stroke-width="{1.4 * s:.1f}" opacity=".35"/>')
    angs = [-170, -140, -110, -70, -35, -5, 25, 160, -90]
    for a in angs:
        a += rnd.uniform(-8, 8)
        L = rnd.uniform(120, 170) * s
        ar = math.radians(a)
        end = (top[0] + math.cos(ar) * L, top[1] + math.sin(ar) * L * .55 + L * .45)
        ctrl = (top[0] + math.cos(ar) * L * .55, top[1] + math.sin(ar) * L * .55 - 40 * s)
        fr = ribbon(top, ctrl, end, 46 * s, 3 * s, 22, notch=.55)
        out.append(poly([(px + 2 * s, py - 3 * s) for px, py in fr], rim, 'opacity=".85"'))
        out.append(poly(fr, fill))
    out.append(f'<circle cx="{top[0]:.0f}" cy="{top[1] + 6 * s:.0f}" r="{10 * s:.1f}" fill="{fill}"/>')
    return '\n'.join(out)


def canopy(y0, amp, rmin, rmax, fill, rim, seed, x0=-60, x1=1980, bottom=1080):
    rnd = random.Random(seed)
    circles = []
    x = x0
    while x < x1:
        r = rnd.uniform(rmin, rmax)
        circles.append((x, y0 + rnd.uniform(-amp, amp), r))
        x += r * rnd.uniform(.9, 1.4)
    rims = ''.join(f'<circle cx="{cx + 4:.0f}" cy="{cy - 5:.0f}" r="{r:.0f}"/>' for cx, cy, r in circles)
    body = ''.join(f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="{r:.0f}"/>' for cx, cy, r in circles)
    return (f'<g fill="{rim}">{rims}</g><g fill="{fill}">{body}'
            f'<rect x="{x0}" y="{y0}" width="{x1 - x0}" height="{bottom - y0}"/></g>')


def jungle():
    out = []
    # far hazy canopy at the foot of the volcano
    out.append(canopy(770, 18, 26, 55, '#4a1846', '#c0506a', 31, bottom=1080))
    for x, h, lean, s, seed in [(980, 300, -30, .9, 1), (1600, 330, 40, 1.0, 2), (1880, 290, 20, .85, 3), (90, 250, 30, .8, 4),
                                (640, 240, -20, .75, 5), (300, 210, 25, .7, 6), (1180, 230, -10, .7, 7)]:
        out.append(palm(x, 820, h, lean, s, '#2c0c30', '#ff7a4a', seed))
    # haze between palms and bosses
    hz = lin([(0, '#ff7a5a', 0), (.45, '#ff8a5a', .35), (1, '#8a2a6a', .15)], 0, 0, 0, 1)
    out.append(f'<rect x="0" y="640" width="1920" height="300" fill="{hz}"/>')
    # nearer canopy band
    out.append(canopy(840, 14, 30, 60, '#2a0b2c', '#ff6a3a', 41))
    # boss ground: dark clearing with lit far edge
    gg = lin([(0, '#3a1236'), (.4, '#220a22'), (1, '#12050f')], 0, 0, 0, 1)
    out.append(f'<path d="M -10 880 Q 400 858 960 870 T 1930 868 L 1930 1090 L -10 1090 Z" fill="{gg}"/>')
    out.append('<path d="M -10 880 Q 400 858 960 870 T 1930 868" stroke="#ff8a4a" stroke-width="3" fill="none" opacity=".55"/>')
    return '\n'.join(out)


# ===================================================================== BOSSES
def fur_grad(fur, shadow, rim):
    return lin([(0, shadow), (.3, mix(shadow, fur, .55)), (.68, fur), (.88, mix(fur, rim, .18)), (.955, rim), (1, rim)])


def limb(px, py, ang, L, w, fill, extra='', r=None, stroke='#12060f'):
    r = w * .38 if r is None else r
    return (f'<g transform="translate({px:.1f},{py:.1f}) rotate({ang:.1f})">'
            f'<rect x="{-w / 2:.1f}" y="{-w * .15:.1f}" width="{w:.1f}" height="{L + w * .3:.1f}" rx="{r:.1f}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="3"/>{extra}</g>')


def arm(px, py, a1, l1, w1, a2, l2, w2, fill, fist_fill, extra1='', extra2='', fist_w=None):
    ex, ey = rot(px, py, a1, l1)
    hx_, hy_ = rot(ex, ey, a2, l2)
    fw = fist_w or w2 * 1.05
    s = limb(px, py, a1, l1, w1, fill, extra1)
    s += limb(ex, ey, a2, l2, w2, fill, extra2)
    s += f'<circle cx="{ex:.1f}" cy="{ey:.1f}" r="{min(w1, w2) * .5 - 1:.1f}" fill="{fill}"/>'
    s += (f'<g transform="translate({hx_:.1f},{hy_:.1f}) rotate({a2:.1f})">'
          f'<rect x="{-fw / 2:.1f}" y="{-fw * .35:.1f}" width="{fw:.1f}" height="{fw * .8:.1f}" rx="{fw * .3:.1f}" fill="{fist_fill}" stroke="#12060f" stroke-width="3"/>'
          f'<path d="M {-fw * .3:.1f} {fw * .12:.1f} h {fw * .6:.1f}" stroke="#12060f" stroke-width="2.5" opacity=".5"/></g>')
    return s, (ex, ey), (hx_, hy_)


def eyes(y, dx, w, h, color, angry=6):
    l = [(-dx - w, y - angry), (-dx, y), (-dx, y + h), (-dx - w, y + h - angry * .3)]
    r = [(dx + w, y - angry), (dx, y), (dx, y + h), (dx + w, y + h - angry * .3)]

    def core(p):
        cx = sum(x for x, _ in p) / 4
        cy = sum(y_ for _, y_ in p) / 4
        return [(cx + (x - cx) * .5, cy + (y_ - cy) * .45) for x, y_ in p]
    return (f'<g filter="url(#glow10)">{poly(l, color)}{poly(r, color)}</g>'
            f'{poly(core(l), "#fffbe0")}{poly(core(r), "#fffbe0")}')


def gorilla_head(fur_fill, face, face_shade, eye_col, mouth='roar', crest=True, glow_face=False):
    out = []
    head = ('M -74 -418 L -80 -478 Q -76 -520 -36 -532 Q 0 -' + ('566' if crest else '546') +
            ' 36 -532 Q 76 -520 80 -478 L 74 -418 Q 62 -392 0 -388 Q -62 -392 -74 -418 Z')
    out.append(f'<path d="{head}" fill="{fur_fill}" stroke="#12060f" stroke-width="3"/>')
    fg = lin([(0, face_shade), (.6, face), (1, mix(face, '#ffd0a0', .3))])
    out.append(f'<path d="M -58 -474 L 58 -474 Q 70 -430 54 -404 Q 0 -386 -54 -404 Q -70 -430 -58 -474 Z" fill="{fg}" '
               f'stroke="#12060f" stroke-width="3" {"filter=\"url(#glow4)\"" if glow_face else ""}/>')
    # brow ridge
    out.append(f'<path d="M -68 -478 Q -34 -500 0 -484 Q 34 -500 68 -478 L 64 -462 Q 32 -474 0 -466 Q -32 -474 -64 -462 Z" fill="{shade(face_shade, .45)}" stroke="#12060f" stroke-width="3"/>')
    out.append(eyes(-462, 10, 30, 11, eye_col))
    out.append(f'<ellipse cx="-12" cy="-438" rx="7" ry="4.5" fill="#1a0806"/><ellipse cx="12" cy="-438" rx="7" ry="4.5" fill="#1a0806"/>')
    if mouth == 'roar':
        out.append('<path d="M -36 -426 Q 0 -436 36 -426 Q 40 -404 0 -392 Q -40 -404 -36 -426 Z" fill="#3a0402" stroke="#12060f" stroke-width="3"/>')
        out.append('<ellipse cx="0" cy="-404" rx="22" ry="8" fill="#ff5a10" opacity=".85" filter="url(#glow4)"/>')
        out.append('<path d="M -30 -426 l 7 15 l 6 -14 Z M 30 -426 l -7 15 l -6 -14 Z M -26 -398 l 6 -12 l 6 11 Z M 26 -398 l -6 -12 l -6 11 Z" fill="#fff6e0"/>')
    else:  # snarl
        out.append('<path d="M -34 -416 Q 0 -428 34 -416 L 30 -404 Q 0 -398 -30 -404 Z" fill="#2a0404" stroke="#12060f" stroke-width="2.5"/>')
        out.append('<path d="M -28 -415 l 5 10 l 5 -11 Z M 28 -415 l -5 10 l -5 -11 Z M -14 -419 h 28 v 4 h -28 Z" fill="#fff6e0"/>')
    return '\n'.join(out)


def torso_path(sx=1.0):
    def X(v):
        return v * sx
    return (f'M {X(-130)} -150 C {X(-150)} -230, {X(-212)} -300, {X(-206)} -362 C {X(-200)} -414, {X(-150)} -434, 0 -436 '
            f'C {X(150)} -434, {X(200)} -414, {X(206)} -362 C {X(212)} -300, {X(150)} -230, {X(130)} -150 Z')


def cracks(paths, w=5):
    s = ''.join(f'<path d="{d}"/>' for d in paths)
    return (f'<g fill="none" stroke-linecap="round" stroke-linejoin="round">'
            f'<g stroke="#ff4a00" stroke-width="{w * 2.6}" opacity=".55" filter="url(#blur3)">{s}</g>'
            f'<g stroke="#ff8a1a" stroke-width="{w}">{s}</g><g stroke="#ffe27a" stroke-width="{w * .4}">{s}</g></g>')


def ash_gorilla():
    fur = fur_grad('#3c3737', '#141016', '#ff9a40')
    furd = '#3c3737'
    face, face_sh = '#ff6e28', '#c03a10'
    out = []
    # legs + feet
    out.append(rrect(-122, -180, 100, 178, 26, fur, 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(22, -180, 100, 178, 26, fur, 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(-138, -42, 124, 42, 16, shade(furd, .7), 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(14, -42, 124, 42, 16, shade(furd, .7), 'stroke="#12060f" stroke-width="3"'))
    out.append(cracks(['M -90 -170 l 18 40 l -10 30 l 16 40', 'M 60 -160 l -10 34 l 20 26 l -6 40', 'M 100 -120 l -14 20']))
    # raised (viewer-right) arm behind torso
    a_r, _, fist_r = arm(186, -392, -128, 170, 100, -172, 165, 110, fur, '#2a2224',
                         extra1=cracks(['M -20 20 l 14 40 l -10 40 l 12 40'], 4),
                         extra2=cracks(['M 10 10 l -14 50 l 12 40 l -6 40'], 4))
    out.append(a_r)
    # torso
    out.append(f'<path d="{torso_path()}" fill="{fur}" stroke="#12060f" stroke-width="3"/>')
    out.append(rrect(-128, -232, 256, 100, 44, fur, 'stroke="#12060f" stroke-width="3"'))
    # chest plates (dark leathery, glowing seams)
    cp = lin([(0, '#2a2226'), (.7, '#4a3e40'), (1, '#ff8a4a')])
    out.append(f'<path d="M -6 -400 Q -70 -408 -118 -380 Q -128 -320 -90 -296 Q -40 -284 -6 -306 Z" fill="{cp}" stroke="#12060f" stroke-width="3"/>')
    out.append(f'<path d="M 6 -400 Q 70 -408 118 -380 Q 128 -320 90 -296 Q 40 -284 6 -306 Z" fill="{cp}" stroke="#12060f" stroke-width="3"/>')
    out.append(cracks(['M -60 -390 l 14 30 l -18 24 l 16 30', 'M 70 -396 l -16 34 l 22 26 l -10 30',
                       'M 0 -296 l -14 30 l 16 26 l -8 40 l 20 30', 'M -160 -330 l 24 20 l -6 30',
                       'M 150 -320 l -20 26 l 10 26', 'M -40 -240 l 20 14 l 30 -6']))
    # head
    out.append(gorilla_head(fur, face, face_sh, '#ffe24a', 'roar', glow_face=True))
    out.append(cracks(['M -40 -540 l 10 18 l -8 14', 'M 30 -548 l -6 20 l 10 12'], 3.5))
    # chest-beating (viewer-left) arm in front
    a_l, _, _ = arm(-186, -392, 38, 165, 100, -104, 150, 110, fur, '#2a2224',
                    extra1=cracks(['M 10 20 l -14 40 l 10 40 l -8 40'], 4),
                    extra2=cracks(['M -10 14 l 14 40 l -10 40'], 4))
    out.append(a_l)
    # embers rising off the boss
    rnd = random.Random(3)
    emb = ''.join(f'<circle cx="{rnd.uniform(-220, 260):.0f}" cy="{rnd.uniform(-720, -120):.0f}" r="{rnd.uniform(1.5, 4):.1f}" fill="#ffb03a"/>' for _ in range(26))
    out.append(f'<g filter="url(#glow4)">{emb}</g>')
    return '\n'.join(out)


def albino_gorilla():
    fur = fur_grad('#ebebf0', '#8c86a4', '#ffcf98')
    face, face_sh = '#968c8c', '#5e5458'
    out = []
    out.append(rrect(-118, -170, 96, 168, 26, fur, 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(22, -170, 96, 168, 26, fur, 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(-132, -40, 118, 40, 16, face_sh, 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(14, -40, 118, 40, 16, face_sh, 'stroke="#12060f" stroke-width="3"'))
    out.append(f'<path d="{torso_path()}" fill="{fur}" stroke="#12060f" stroke-width="3"/>')
    out.append(rrect(-126, -228, 252, 96, 44, fur, 'stroke="#12060f" stroke-width="3"'))
    cp = lin([(0, '#6a6066'), (.7, '#9a9094'), (1, '#e8b090')])
    out.append(f'<path d="M -6 -400 Q -70 -408 -116 -380 Q -126 -322 -88 -298 Q -40 -286 -6 -308 Z" fill="{cp}" stroke="#12060f" stroke-width="3"/>')
    out.append(f'<path d="M 6 -400 Q 70 -408 116 -380 Q 126 -322 88 -298 Q 40 -286 6 -308 Z" fill="{cp}" stroke="#12060f" stroke-width="3"/>')
    # knuckle-walking arms planted wide
    for side in (-1, 1):
        s, _, _ = arm(side * 190, -392, side * 14, 175, 100, side * 6, 175, 112, fur, face_sh)
        out.append(s)
    # scars
    out.append('<path d="M 40 -380 l 50 40 M 52 -392 l 50 40" stroke="#b03030" stroke-width="5" stroke-linecap="round" opacity=".8"/>')
    out.append(gorilla_head(fur, face, face_sh, '#ff1a1a', 'snarl'))
    return '\n'.join(out)


def chimp_chief():
    fur = fur_grad('#1e1a18', '#060406', '#ff8a3a')
    face, face_sh = '#c8aa8c', '#8a6a52'
    out = []
    # spear held upright on viewer-left
    out.append('<path d="M -232 30 L -238 -700" stroke="#12060f" stroke-width="24" stroke-linecap="round"/>')
    out.append('<path d="M -232 30 L -238 -700" stroke="#6a3a1a" stroke-width="16" stroke-linecap="round"/>')
    out.append('<path d="M -232 30 L -238 -700" stroke="#8a5a2a" stroke-width="6" stroke-linecap="round" transform="translate(5,0)"/>')
    out.append('<path d="M -238 -700 l -24 -10 l 22 -86 l 26 84 Z" fill="#efe6cc" stroke="#12060f" stroke-width="3"/>')
    out.append('<path d="M -250 -640 l -30 40 M -226 -640 l 26 44" stroke="#c22a1a" stroke-width="7"/>')
    out.append('<path d="M -248 -660 h 22" stroke="#3a1c0c" stroke-width="12"/>')
    sx = .82
    out.append(rrect(-100, -180, 80, 178, 24, fur, 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(20, -180, 80, 178, 24, fur, 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(-112, -36, 98, 36, 14, face_sh, 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(14, -36, 98, 36, 14, face_sh, 'stroke="#12060f" stroke-width="3"'))
    # viewer-right arm hanging menacingly, fingers to knee
    s, _, _ = arm(160, -392, -16, 165, 80, -6, 160, 86, fur, face_sh)
    out.append(s)
    out.append(f'<path d="{torso_path(sx)}" fill="{fur}" stroke="#12060f" stroke-width="3"/>')
    out.append(rrect(-104, -230, 208, 96, 40, fur, 'stroke="#12060f" stroke-width="3"'))
    # bone necklace
    out.append('<path d="M -90 -410 Q 0 -330 90 -410" stroke="#5a2a10" stroke-width="5" fill="none"/>')
    for i, t in enumerate([.12, .28, .42, .58, .72, .88]):
        bx, by = bez2((-90, -410), (0, -330), (90, -410), t)
        out.append(f'<path d="M {bx:.0f} {by:.0f} l -6 22 l 6 6 l 6 -6 Z" fill="#f2ead2" stroke="#12060f" stroke-width="2"/>')
    # spear arm (viewer-left), forearm up holding spear
    s, _, _ = arm(-160, -392, 24, 150, 80, -6, 120, 86, fur, face_sh)
    out.append(s)
    # head: big ears, pale face, protruding muzzle
    out.append(f'<ellipse cx="-80" cy="-470" rx="30" ry="36" fill="{face}" stroke="#12060f" stroke-width="3"/>')
    out.append(f'<ellipse cx="80" cy="-470" rx="30" ry="36" fill="{face}" stroke="#12060f" stroke-width="3"/>')
    out.append(f'<ellipse cx="-80" cy="-470" rx="14" ry="19" fill="{face_sh}"/><ellipse cx="80" cy="-470" rx="14" ry="19" fill="{face_sh}"/>')
    out.append(f'<path d="M -66 -420 L -70 -488 Q -60 -540 0 -544 Q 60 -540 70 -488 L 66 -420 Q 50 -392 0 -390 Q -50 -392 -66 -420 Z" fill="{fur}" stroke="#12060f" stroke-width="3"/>')
    fg = lin([(0, face_sh), (.6, face), (1, '#ffe0c0')])
    out.append(f'<path d="M -54 -496 Q 0 -512 54 -496 Q 62 -450 46 -430 Q 56 -404 0 -392 Q -56 -404 -46 -430 Q -62 -450 -54 -496 Z" fill="{fg}" stroke="#12060f" stroke-width="3"/>')
    out.append(f'<path d="M -56 -472 Q -28 -490 0 -476 Q 28 -490 56 -472 L 52 -460 Q 28 -470 0 -462 Q -28 -470 -52 -460 Z" fill="{face_sh}" stroke="#12060f" stroke-width="2.5"/>')
    out.append(eyes(-460, 9, 26, 10, '#ffd21a'))
    # war paint
    out.append('<path d="M -44 -446 l 14 16 M -34 -448 l 14 16 M 44 -446 l -14 16 M 34 -448 l -14 16" stroke="#d01e1e" stroke-width="5" stroke-linecap="round"/>')
    out.append('<path d="M -30 -414 Q 0 -404 30 -414 L 26 -402 Q 0 -396 -26 -402 Z" fill="#2a0404" stroke="#12060f" stroke-width="2"/>')
    out.append('<path d="M -22 -413 l 4 9 l 4 -9 Z M 22 -413 l -4 9 l -4 -9 Z" fill="#fff6e0"/>')
    out.append('<ellipse cx="-9" cy="-430" rx="5" ry="3" fill="#2a1408"/><ellipse cx="9" cy="-430" rx="5" ry="3" fill="#2a1408"/>')
    # war-chief headband with bone + feathers
    for fx, fa, col in [(-34, -24, '#d8261e'), (0, 0, '#f4f0e6'), (34, 22, '#ffb21a'), (-14, -10, '#2a8a4a'), (16, 10, '#d8261e')]:
        out.append(f'<g transform="translate({fx},-520) rotate({fa})"><path d="M 0 0 Q -16 -60 0 -118 Q 16 -60 0 0 Z" fill="{col}" stroke="#12060f" stroke-width="3"/>'
                   f'<path d="M 0 -6 V -110" stroke="#12060f" stroke-width="2" opacity=".6"/></g>')
    out.append('<path d="M -70 -528 Q 0 -548 70 -528 L 70 -508 Q 0 -526 -70 -508 Z" fill="#b01a14" stroke="#12060f" stroke-width="3"/>')
    out.append('<g transform="translate(0,-524)"><rect x="-30" y="-6" width="60" height="12" rx="6" fill="#f4ecd4" stroke="#12060f" stroke-width="2.5"/>'
               '<circle cx="-30" cy="-6" r="8" fill="#f4ecd4" stroke="#12060f" stroke-width="2.5"/><circle cx="-30" cy="6" r="8" fill="#f4ecd4" stroke="#12060f" stroke-width="2.5"/>'
               '<circle cx="30" cy="-6" r="8" fill="#f4ecd4" stroke="#12060f" stroke-width="2.5"/><circle cx="30" cy="6" r="8" fill="#f4ecd4" stroke="#12060f" stroke-width="2.5"/>'
               '<rect x="-30" y="-6" width="60" height="12" fill="#f4ecd4"/></g>')
    return '\n'.join(out)


def orangutan():
    fur = fur_grad('#b44a1a', '#4a1a0c', '#ffbe6a')
    face, face_sh = '#5a3c2d', '#3a2418'
    out = []
    rnd = random.Random(9)

    def hair(x0, y0, x1, y1, n, ln, side):
        s = ''
        for i in range(n):
            t = i / max(1, n - 1)
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            s += f'<path d="M {x:.0f} {y - 14:.0f} q {side * ln * .6:.0f} {ln * .5:.0f} {side * ln * rnd.uniform(.3, .6):.0f} {ln * rnd.uniform(.9, 1.3):.0f} L {x - side * 10:.0f} {y + 10:.0f} Z" fill="{fur}" stroke="#12060f" stroke-width="2"/>'
        return s
    # short bowed legs
    out.append(rrect(-110, -150, 92, 148, 26, fur, 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(18, -150, 92, 148, 26, fur, 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(-128, -36, 112, 36, 14, face_sh, 'stroke="#12060f" stroke-width="3"'))
    out.append(rrect(16, -36, 112, 36, 14, face_sh, 'stroke="#12060f" stroke-width="3"'))
    # long arms hanging wide to the ground, shaggy hair
    for side in (-1, 1):
        ex, ey = rot(side * 175, -380, side * 30, 190)
        hx2, hy2 = rot(ex, ey, side * 8, 190)
        out.append(hair(side * 175, -370, ex, ey, 6, 46, side))
        out.append(hair(ex, ey, hx2, hy2, 6, 52, side))
        s, _, _ = arm(side * 175, -380, side * 30, 190, 86, side * 8, 190, 90, fur, face_sh)
        out.append(s)
    # pear-shaped body
    out.append(f'<path d="M -150 -150 C -190 -230, -196 -320, -170 -372 C -150 -414, -90 -426, 0 -428 C 90 -426, 150 -414, 170 -372 '
               f'C 196 -320, 190 -230, 150 -150 Q 0 -112 -150 -150 Z" fill="{fur}" stroke="#12060f" stroke-width="3"/>')
    bg_ = lin([(0, '#6a2a14'), (.7, '#c06030'), (1, '#ffb070')])
    out.append(f'<ellipse cx="0" cy="-260" rx="96" ry="92" fill="{bg_}" opacity=".85"/>')
    # shaggy hair mantle around the head
    mant = []
    for i in range(23):
        a = math.radians(-200 + i * 220 / 22)
        r0 = 150 + rnd.uniform(-10, 20)
        mant.append((math.cos(a) * r0, -480 + math.sin(a) * r0 * .9))
        a2 = math.radians(-200 + (i + .5) * 220 / 22)
        mant.append((math.cos(a2) * (r0 - 34), -480 + math.sin(a2) * (r0 - 34) * .9))
    mant = mant[:-1] + [(150, -330), (120, -360), (90, -330), (60, -370), (-60, -370), (-90, -330), (-120, -360), (-150, -330)]
    out.append(poly(mant, fur, 'stroke="#12060f" stroke-width="3" stroke-linejoin="round"'))
    # throat sac
    out.append(f'<ellipse cx="0" cy="-384" rx="70" ry="42" fill="{lin([(0, "#3a2418"), (.7, "#6a4a38"), (1, "#c08060")])}" stroke="#12060f" stroke-width="3"/>')
    # cheek pads (flanges)
    cpg = lin([(0, '#2e1c12'), (.4, '#5a3c2d'), (.8, '#7a5844'), (.94, '#d08a5a'), (1, '#ffb070')])
    for side in (-1, 1):
        out.append(f'<ellipse cx="{side * 96}" cy="-466" rx="62" ry="80" fill="{cpg}" stroke="#12060f" stroke-width="4" transform="rotate({side * -8} {side * 96} -466)"/>')
        out.append(f'<ellipse cx="{side * 96}" cy="-466" rx="40" ry="58" fill="none" stroke="#2a1810" stroke-width="3" opacity=".55" transform="rotate({side * -8} {side * 96} -466)"/>')
    # head dome + tuft
    out.append(f'<path d="M -58 -420 L -62 -506 Q -52 -560 0 -564 Q 52 -560 62 -506 L 58 -420 Z" fill="{fur}" stroke="#12060f" stroke-width="3"/>')
    out.append(hair(-46, -562, 46, -562, 6, 30, 1))
    fg = lin([(0, face_sh), (.6, face), (1, '#a07050')])
    out.append(f'<path d="M -50 -506 Q 0 -520 50 -506 Q 62 -440 42 -404 Q 0 -390 -42 -404 Q -62 -440 -50 -506 Z" fill="{fg}" stroke="#12060f" stroke-width="3"/>')
    out.append('<ellipse cx="0" cy="-424" rx="36" ry="22" fill="#8a6450"/>')
    out.append(f'<path d="M -50 -488 Q -24 -502 0 -490 Q 24 -502 50 -488 L 46 -476 Q 24 -484 0 -478 Q -24 -484 -46 -476 Z" fill="{shade(face_sh, .6)}"/>')
    out.append(eyes(-474, 8, 24, 10, '#7aff3a'))
    out.append('<ellipse cx="-8" cy="-446" rx="5" ry="3.5" fill="#1a0806"/><ellipse cx="8" cy="-446" rx="5" ry="3.5" fill="#1a0806"/>')
    out.append('<path d="M -30 -424 Q 0 -434 30 -424 L 26 -410 Q 0 -403 -26 -410 Z" fill="#2a0404" stroke="#12060f" stroke-width="2"/>')
    out.append('<path d="M -22 -423 l 5 9 l 5 -10 Z M 22 -423 l -5 9 l -5 -10 Z" fill="#fff6e0"/>')
    return '\n'.join(out)


def boss(fn, x, y, s, flip=False, haze=True):
    sh = f'<ellipse cx="{x}" cy="{y + 4}" rx="{260 * s:.0f}" ry="{26 * s:.0f}" fill="#0a0208" opacity=".55" filter="url(#blur8)"/>'
    sc = f'scale({-s if flip else s},{s})'
    return f'{sh}<g transform="translate({x},{y}) {sc}"{' filter="url(#haze)"' if haze else ''}>{fn()}</g>'


# ===================================================================== PLAYER
SKIN, SKIN_SH = '#f0b488', '#a8603e'
SHIRT, SHIRT_SH = '#f1e6c8', '#9c8a8a'
BLUE, BLUE_SH = '#2f6ee0', '#17306e'
RIM = '#ffb24a'


def part_grad(base, sh):
    return lin([(0, mix(sh, '#3a1a5a', .25)), (.12, mix(sh, base, .55)), (.45, base), (.86, mix(base, '#ffd6a0', .25)), (.95, RIM), (1, RIM)])


def jag(x0, x1, y, amp, n, seed):
    rnd = random.Random(seed)
    p = []
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        p.append((x, y + (amp if i % 2 else 0) + rnd.uniform(-amp * .3, amp * .3)))
    return p


def player_leg(px, py, ang, seed):
    L, w = 212, 92
    shorts = part_grad(BLUE, BLUE_SH)
    skin = part_grad(SKIN, SKIN_SH)
    cuff = part_grad('#6aa2ff', '#2a4c9c')
    inner = []
    inner.append(rrect(-w / 2, 0, w, L, 6, skin, 'stroke="#14060f" stroke-width="3.5"'))
    inner.append(rrect(-w / 2, 0, w, 98, 4, shorts))
    inner.append(rrect(-w / 2 - 3, 88, w + 6, 26, 6, cuff, 'stroke="#14060f" stroke-width="3"'))
    inner.append(f'<path d="M {-w / 2 + 6} 100 h {w - 12}" stroke="#ffffff" stroke-width="2" stroke-dasharray="6 5" opacity=".6"/>')
    # knee shading / scratches
    inner.append(f'<path d="M -20 140 l 14 10 M -10 132 l 12 9" stroke="#b0482e" stroke-width="2.5" opacity=".7"/>')
    # sandal
    inner.append(rrect(-w / 2 - 4, L - 26, w + 8, 30, 7, part_grad('#7a4422', '#3a1a0c'), 'stroke="#14060f" stroke-width="3"'))
    inner.append(f'<path d="M {-w / 2 + 4} {L - 40} l {w / 2 - 4} 16 l {w / 2 - 4} -16" stroke="#5a2a12" stroke-width="6" fill="none"/>')
    inner.append(rrect(-w / 2, 0, w, L, 6, 'none', 'stroke="#14060f" stroke-width="3.5"'))
    return f'<g transform="translate({px},{py}) rotate({ang})">{"".join(inner)}</g>'


def player_arm(px, py, ang, inner_extra='', sleeve_seed=1):
    L, w = 205, 90
    skin = part_grad(SKIN, SKIN_SH)
    sleeve = part_grad(SHIRT, SHIRT_SH)
    inner = [rrect(-w / 2, -6, w, L + 6, 8, skin, 'stroke="#14060f" stroke-width="3.5"')]
    sl = [(-w / 2, -6), (w / 2, -6)] + list(reversed(jag(-w / 2, w / 2, 62, 14, 6, sleeve_seed)))
    inner.append(poly(sl, sleeve, 'stroke="#14060f" stroke-width="3" stroke-linejoin="round"'))
    inner.append(f'<path d="M {-w / 2 + 8} 158 h {w - 16}" stroke="{SKIN_SH}" stroke-width="3" opacity=".5"/>')
    inner.append(f'<path d="M -14 104 l 18 -8" stroke="#b0482e" stroke-width="2.5" opacity=".6"/>')
    inner.append(inner_extra)
    return f'<g transform="translate({px},{py}) rotate({ang})">{"".join(inner)}</g>'


def club():
    """Wooden club with bone fangs. Origin = grip, extends along -y (up in its own frame)."""
    wood = lin([(0, '#3a1a08'), (.25, '#6a3414'), (.6, '#9a5626'), (.88, '#c87a3a'), (1, '#ffb050')])
    out = []
    fang = lin([(0, '#b8ab8c'), (.5, '#fbf4e0'), (1, '#ffffff')])

    def F(x, y, a, L, w):
        return (f'<g transform="translate({x},{y}) rotate({a})"><path d="M {-w / 2} 0 C {-w * .5} {-L * .5}, {-w * .1} {-L * .85}, {w * .45} {-L} C {w * .05} {-L * .7}, {w * .4} {-L * .35}, {w / 2} 0 Z" '
                f'fill="{fang}" stroke="#14060f" stroke-width="3" stroke-linejoin="round"/></g>')
    fangs_back = [F(-50, -250, -70, 62, 26), F(52, -290, 72, 66, 28), F(-44, -190, -80, 52, 24),
                  F(46, -210, 80, 56, 24), F(-36, -320, -40, 58, 26), F(36, -332, 36, 60, 26), F(0, -345, 4, 56, 26),
                  F(-30, -135, -86, 40, 20), F(34, -150, 84, 42, 20)]
    out.extend(fangs_back)
    d = 'M -16 40 L 16 40 L 19 -90 C 40 -150, 58 -230, 56 -290 Q 50 -348 0 -350 Q -50 -348 -56 -290 C -58 -230, -40 -150, -19 -90 Z'
    out.append(f'<path d="{d}" fill="{wood}" stroke="#14060f" stroke-width="4" stroke-linejoin="round"/>')
    # grain + knots
    out.append('<path d="M -8 -110 C -20 -170, -30 -230, -22 -300 M 10 -120 C 18 -190, 30 -240, 26 -310 M -36 -230 q 8 -20 0 -40" '
               'stroke="#3a1a08" stroke-width="3" fill="none" opacity=".6"/>')
    out.append('<ellipse cx="18" cy="-240" rx="9" ry="13" fill="#4a220c" stroke="#2a1006" stroke-width="2"/>')
    # rope grip
    for i in range(6):
        y = 30 - i * 16
        out.append(f'<path d="M -19 {y} L 19 {y - 10}" stroke="#d8b878" stroke-width="7" stroke-linecap="round"/>'
                   f'<path d="M -19 {y} L 19 {y - 10}" stroke="#6a4a1a" stroke-width="2" stroke-linecap="round" transform="translate(0,4)"/>')
    # rim highlight on lava side
    out.append('<path d="M 22 -100 C 44 -160, 58 -230, 54 -296" stroke="#ffcf6a" stroke-width="4" fill="none" stroke-linecap="round" opacity=".9"/>')
    return '\n'.join(out)


def torch_flame(x, y, s=1.0):
    fo = lin([(0, '#ff3a00', 0), (.25, '#ff4a00'), (.7, '#ffa21a'), (1, '#ffe27a')], 0, 0, 0, 1)
    fi = lin([(0, '#ffd23a', 0), (.4, '#ffe27a'), (1, '#fffbe0')], 0, 0, 0, 1)
    out = [f'<circle cx="{x}" cy="{y - 40 * s}" r="{120 * s}" fill="{rad([(0, "#ffb040", .55), (1, "#ff6a00", 0)])}"/>']
    out.append(f'<g transform="translate({x},{y}) scale({s})" filter="url(#glow10)">'
               f'<path d="M -34 0 C -46 -40, -20 -70, -24 -110 C -6 -86, 0 -100, 4 -140 C 20 -100, 44 -84, 30 -40 C 46 -50, 44 -30, 34 0 Q 0 16 -34 0 Z" fill="{fo}"/>'
               f'<path d="M -18 0 C -24 -30, -6 -46, -6 -76 C 8 -56, 22 -44, 16 -16 Q 18 -6 14 0 Q 0 8 -18 0 Z" fill="{fi}"/></g>')
    return '\n'.join(out)


def player():
    out = []
    # torch stick (behind hand) held in the viewer-left hand
    hx_, hy_ = rot(-146, -425, 24, 190)
    tx0, ty0 = hx_ + 18, hy_ + 40
    tx1, ty1 = hx_ - 70, hy_ - 210
    out.append(f'<line x1="{tx0:.0f}" y1="{ty0:.0f}" x2="{tx1:.0f}" y2="{ty1:.0f}" stroke="#14060f" stroke-width="26" stroke-linecap="round"/>')
    out.append(f'<line x1="{tx0:.0f}" y1="{ty0:.0f}" x2="{tx1:.0f}" y2="{ty1:.0f}" stroke="#7a4220" stroke-width="18" stroke-linecap="round"/>')
    out.append(f'<line x1="{tx0 + 5:.0f}" y1="{ty0:.0f}" x2="{tx1 + 5:.0f}" y2="{ty1:.0f}" stroke="#c07a3a" stroke-width="4" stroke-linecap="round"/>')
    # wrapped cloth head of torch
    ang_t = math.degrees(math.atan2(tx1 - tx0, -(ty1 - ty0)))
    out.append(f'<g transform="translate({tx1:.0f},{ty1:.0f}) rotate({ang_t:.0f})"><rect x="-20" y="-6" width="40" height="44" rx="8" fill="#5a3a2a" stroke="#14060f" stroke-width="3"/>'
               f'<path d="M -20 6 L 20 0 M -20 20 L 20 14 M -20 32 L 20 26" stroke="#2a160c" stroke-width="3"/></g>')
    torch_tip = (tx1, ty1 - 2)

    # club arm (viewer-right) raised, behind the torso
    club_g = f'<g transform="translate(0,182) rotate(180) rotate(-14)">{club()}</g>'
    # (club is drawn inside the arm group so it follows the arm; hand drawn over the grip)
    out.append(player_arm(140, -418, -150, club_g + rrect(-45, 150, 90, 55, 8, part_grad(SKIN, SKIN_SH), 'stroke="#14060f" stroke-width="3.5"'), 5))

    # legs
    out.append(player_leg(-48, -210, 7, 1))
    out.append(player_leg(48, -210, -6, 2))
    # pelvis / shorts
    out.append(rrect(-102, -248, 204, 56, 6, part_grad(BLUE, BLUE_SH), 'stroke="#14060f" stroke-width="3.5"'))
    out.append('<path d="M 0 -236 v 40" stroke="#17306e" stroke-width="3"/>')
    # torso side + top faces (camera slightly left/above)
    out.append(poly([(-102, -432), (-122, -446), (-122, -262), (-102, -248)], mix(SHIRT_SH, '#3a1a5a', .35), 'stroke="#14060f" stroke-width="3"'))
    out.append(poly([(-102, -432), (-122, -446), (82, -446), (102, -432)], mix(SHIRT, '#ffcf9a', .4), 'stroke="#14060f" stroke-width="3"'))
    # shirt front with torn hem
    hem = jag(102, -102, -244, 16, 10, 7)
    shirt = [(-102, -432), (102, -432)] + hem
    out.append(poly(shirt, part_grad(SHIRT, SHIRT_SH), 'stroke="#14060f" stroke-width="3.5" stroke-linejoin="round"'))
    # skin peeking through V-neck and tears
    sk = part_grad(SKIN, SKIN_SH)
    out.append(poly([(-34, -432), (34, -432), (14, -398), (4, -404), (0, -376), (-8, -396), (-18, -392)], sk, 'stroke="#14060f" stroke-width="3" stroke-linejoin="round"'))
    out.append(poly([(40, -330), (66, -346), (60, -318), (74, -300), (46, -306)], sk, 'stroke="#14060f" stroke-width="2.5" stroke-linejoin="round"'))
    out.append(poly([(-70, -296), (-46, -308), (-40, -286), (-58, -272)], sk, 'stroke="#14060f" stroke-width="2.5" stroke-linejoin="round"'))
    # dirt & folds
    out.append('<path d="M -80 -360 q 20 30 10 60 M 70 -400 q -10 30 6 50 M -20 -300 q 30 10 50 -6" stroke="#b8a488" stroke-width="3" fill="none" opacity=".7"/>')
    out.append('<ellipse cx="-60" cy="-380" rx="16" ry="9" fill="#a88a68" opacity=".35"/><ellipse cx="30" cy="-270" rx="20" ry="8" fill="#a88a68" opacity=".35"/>')
    # leather strap + pouch
    out.append('<path d="M 70 -432 L -96 -262" stroke="#14060f" stroke-width="22" stroke-linecap="butt"/>')
    out.append('<path d="M 70 -432 L -96 -262" stroke="#7a3e1a" stroke-width="16"/>')
    out.append('<path d="M 70 -432 L -96 -262" stroke="#b06a32" stroke-width="3" transform="translate(4,-4)"/>')
    out.append(rrect(-110, -290, 46, 52, 10, '#6a3418', 'stroke="#14060f" stroke-width="3"'))
    out.append(rrect(-110, -290, 46, 18, 8, '#8a4a22', 'stroke="#14060f" stroke-width="2.5"'))
    # rope belt with knot
    out.append('<path d="M -102 -246 L 102 -246" stroke="#14060f" stroke-width="16"/>')
    out.append('<path d="M -102 -246 L 102 -246" stroke="#c8a060" stroke-width="10"/>')
    out.append('<path d="M -96 -246 h 192" stroke="#7a5a22" stroke-width="2.5" stroke-dasharray="9 7"/>')
    out.append('<path d="M 30 -246 q -6 26 -14 40 M 38 -246 q 4 26 12 36" stroke="#c8a060" stroke-width="7" fill="none" stroke-linecap="round"/>')

    # torch arm (viewer-left), in front
    hand = rrect(-45, 150, 90, 55, 8, part_grad(SKIN, SKIN_SH), 'stroke="#14060f" stroke-width="3.5"')
    out.append(player_arm(-146, -425, 24, hand, 2))

    # head
    out.append(poly([(-66, -440), (-84, -452), (-84, -560), (-66, -572)], mix(SKIN_SH, '#3a1a5a', .3), 'stroke="#14060f" stroke-width="3"'))
    out.append(rrect(-66, -572, 132, 132, 26, part_grad(SKIN, SKIN_SH), 'stroke="#14060f" stroke-width="3.5"'))
    # face: classic smile, determined brows
    out.append('<ellipse cx="-24" cy="-506" rx="9" ry="14" fill="#14060f"/><ellipse cx="24" cy="-506" rx="9" ry="14" fill="#14060f"/>')
    out.append('<circle cx="-21" cy="-511" r="3.2" fill="#fff"/><circle cx="27" cy="-511" r="3.2" fill="#fff"/>')
    out.append('<path d="M -40 -532 L -12 -524 M 40 -532 L 12 -524" stroke="#14060f" stroke-width="7" stroke-linecap="round"/>')
    out.append('<path d="M -32 -482 Q 0 -456 32 -482" stroke="#14060f" stroke-width="6.5" fill="none" stroke-linecap="round"/>')
    out.append('<path d="M 30 -470 l 14 6 M 34 -478 l 10 10" stroke="#b0482e" stroke-width="2.5" opacity=".7"/>')
    out.append('<ellipse cx="-40" cy="-470" rx="12" ry="6" fill="#e0785a" opacity=".45"/><ellipse cx="42" cy="-470" rx="12" ry="6" fill="#e0785a" opacity=".45"/>')
    # bandana: cap + fold + tails flying right
    red = part_grad('#e0222e', '#7a0c1c')
    out.append(f'<path d="M 60 -540 Q 110 -560 150 -538 Q 128 -532 140 -510 Q 104 -528 64 -522 Z" fill="{red}" stroke="#14060f" stroke-width="3" stroke-linejoin="round"/>')
    out.append(f'<path d="M 62 -530 Q 120 -520 146 -486 Q 120 -492 112 -474 Q 96 -500 60 -514 Z" fill="{red}" stroke="#14060f" stroke-width="3" stroke-linejoin="round"/>')
    out.append(f'<path d="M -68 -540 Q -70 -584 -30 -588 L 30 -588 Q 70 -584 68 -540 Z" fill="{red}" stroke="#14060f" stroke-width="3.5"/>')
    out.append(f'<path d="M -86 -552 L -68 -540 L 68 -540 L 68 -550 L -86 -562 Z" fill="#8a0c1a" stroke="#14060f" stroke-width="3"/>')
    out.append(f'<path d="M -70 -548 Q 0 -560 70 -548 L 70 -532 Q 0 -544 -70 -532 Z" fill="#b8121e" stroke="#14060f" stroke-width="3"/>')
    for dx, dy in [(-40, -568), (-8, -574), (26, -568), (50, -558), (-52, -554), (10, -556), (118, -540), (124, -506)]:
        out.append(f'<circle cx="{dx}" cy="{dy}" r="4" fill="#fff4f0" opacity=".9"/>')
    out.append(f'<circle cx="66" cy="-532" r="12" fill="#b8121e" stroke="#14060f" stroke-width="3"/>')

    # torch flame on top of everything
    out.append(torch_flame(torch_tip[0], torch_tip[1], 1.35))
    return '\n'.join(out)


# ================================================================= FOREGROUND
def fern(x, y, ang, L, s, fill='#12040f', rim='#ff7a3a', seed=0, droop=.35):
    a = math.radians(ang)
    end = (x + math.sin(a) * L, y - math.cos(a) * L)
    ctrl = (x + math.sin(a) * L * .55 + math.cos(a) * L * droop, y - math.cos(a) * L * .55 + math.sin(a) * L * droop * .2)
    out = []
    n = 22
    leaflets = []
    for i in range(1, n):
        t = i / n
        p = bez2((x, y), ctrl, end, t)
        p2 = bez2((x, y), ctrl, end, min(1, t + .02))
        dx, dy = p2[0] - p[0], p2[1] - p[1]
        d = math.hypot(dx, dy) or 1
        nx, ny = -dy / d, dx / d
        ll = 95 * s * (1 - t) ** .5 * (.5 + t * 1.7 if t < .3 else 1)
        for side in (-1, 1):
            tip = (p[0] + nx * ll * side + dx / d * ll * .5, p[1] + ny * ll * side + dy / d * ll * .5 + ll * .12)
            w = 22 * s * (1 - t * .5)
            m = ((p[0] + tip[0]) / 2, (p[1] + tip[1]) / 2)
            leaflets.append([(p[0] - dx / d * w * .4, p[1] - dy / d * w * .4),
                             (m[0] - dx / d * w, m[1] - dy / d * w), tip,
                             (m[0] + dx / d * w * .6, m[1] + dy / d * w * .6), (p[0] + dx / d * w * .4, p[1] + dy / d * w * .4)])
    stem = ribbon((x, y), ctrl, end, 9 * s, 2 * s, 16)
    out.append('<g opacity=".55">' + ''.join(poly([(px + 2, py - 2) for px, py in lf], rim) for lf in leaflets) + '</g>')
    out.append(''.join(poly(lf, fill if k % 2 else shade(fill, 1.35)) for k, lf in enumerate(leaflets)))
    out.append(poly(stem, fill))
    return '\n'.join(out)


def banana_leaf(x, y, ang, L, W, fill, rim, seed=0, bend=.3):
    """Big tropical leaf silhouette with torn slits (cut with a mask)."""
    rnd = random.Random(seed)
    a = math.radians(ang)
    end = (x + math.sin(a) * L, y - math.cos(a) * L)
    ctrl = (x + math.sin(a) * L * .6 + math.cos(a) * L * bend, y - math.cos(a) * L * .6 + math.sin(a) * L * bend)
    n = 30
    Lp, Rp = [], []
    for i in range(n + 1):
        t = i / n
        p = bez2((x, y), ctrl, end, t)
        p2 = bez2((x, y), ctrl, end, min(1, t + .01))
        p1 = bez2((x, y), ctrl, end, max(0, t - .01))
        dx, dy = p2[0] - p1[0], p2[1] - p1[1]
        d = math.hypot(dx, dy) or 1
        w = W * (math.sin(math.pi * min(1, t)) ** .6) * (1 if t > .05 else t / .05)
        Lp.append((p[0] - dy / d * w, p[1] + dx / d * w))
        Rp.append((p[0] + dy / d * w, p[1] - dx / d * w))
    shape = Lp + Rp[::-1]
    mid = uid('leafm')
    slits = ''
    for side in (-1, 1):
        t = .18 + rnd.uniform(0, .06)
        while t < .9:
            p = bez2((x, y), ctrl, end, t)
            p2 = bez2((x, y), ctrl, end, t + .01)
            dx, dy = p2[0] - p[0], p2[1] - p[1]
            d = math.hypot(dx, dy) or 1
            ux, uy = dx / d, dy / d
            nx, ny = -uy * side, ux * side
            a0 = (p[0] + nx * W * .15, p[1] + ny * W * .15)
            a1 = (p[0] + nx * W * 1.3 + ux * W * .7, p[1] + ny * W * 1.3 + uy * W * .7)
            slits += f'<line x1="{a0[0]:.0f}" y1="{a0[1]:.0f}" x2="{a1[0]:.0f}" y2="{a1[1]:.0f}" stroke="#000" stroke-width="{rnd.uniform(3, 7):.1f}"/>'
            t += rnd.uniform(.1, .2)
    DEFS.append(f'<mask id="{mid}" maskUnits="userSpaceOnUse" x="-200" y="-200" width="2400" height="1500">'
                f'{poly(shape, "#fff")}{slits}</mask>')
    rib = ribbon((x, y), ctrl, end, 10, 2, n)
    vg = lin([(0, shade(fill, .7)), (1, shade(fill, 1.6))], x, y, end[0], end[1], units='userSpaceOnUse')
    return (f'<g mask="url(#{mid})"><g transform="translate(5,-5)">{poly(shape, rim)}</g>{poly(shape, vg)}</g>'
            + poly(rib, shade(fill, 1.9)))


def ground():
    out = []
    rock = lin([(0, '#6a2a3a'), (.25, '#3a1426'), (1, '#140610')], 0, 0, 0, 1)
    out.append(f'<path d="M 420 1090 Q 470 1020 560 1012 Q 700 990 860 1000 Q 1010 994 1120 1018 Q 1200 1040 1240 1090 Z" fill="{rock}"/>')
    out.append('<path d="M 470 1036 Q 560 1008 700 1000 Q 860 992 1010 998 Q 1110 1006 1170 1036" stroke="#ffb066" stroke-width="5" fill="none" opacity=".75"/>')
    sand = lin([(0, '#e8a060'), (1, '#8a4a3a', 0)], 0, 0, 0, 1)
    out.append(f'<ellipse cx="870" cy="1012" rx="300" ry="26" fill="{sand}" opacity=".5"/>')
    out.append('<ellipse cx="870" cy="1046" rx="200" ry="16" fill="#0a0208" opacity=".55" filter="url(#blur8)"/>')
    out.append('<ellipse cx="680" cy="1010" rx="260" ry="60" fill="#ff9a3a" opacity=".22" filter="url(#blur18)"/>')
    for px, py, r in [(560, 1030, 14), (1110, 1030, 18), (640, 1056, 10), (1060, 1060, 12)]:
        out.append(f'<ellipse cx="{px}" cy="{py}" rx="{r * 1.4}" ry="{r}" fill="#2a0c1c"/><path d="M {px - r} {py - r * .4} q {r} -{r * .8} {r * 2} 0" stroke="#ff9a5a" stroke-width="2.5" fill="none" opacity=".7"/>')
    return '\n'.join(out)


def foreground_plants():
    out = []
    R = '#ff9a4a'
    # bottom-left cluster (back to front)
    for x, y, a, L, W, col, seed, b in [(-60, 1120, 62, 430, 70, '#0c2416', 11, .2), (-40, 1110, 34, 540, 84, '#12301c', 1, .25),
                                         (150, 1130, 6, 360, 60, '#0f2818', 2, .35), (60, 1140, 22, 300, 58, '#163a22', 5, .3)]:
        out.append(banana_leaf(x, y, a, L, W, col, R, seed, bend=b))
    # bottom-right cluster
    for x, y, a, L, W, col, seed, b in [(1980, 1120, -62, 430, 70, '#0c2416', 12, -.2), (1960, 1110, -34, 540, 84, '#12301c', 3, -.25),
                                         (1770, 1130, -6, 360, 60, '#0f2818', 4, -.35), (1860, 1140, -22, 300, 58, '#163a22', 6, -.3)]:
        out.append(banana_leaf(x, y, a, L, W, col, R, seed, bend=b))
    return '\n'.join(out)


# ====================================================================== TITLE
def banana(x, y, ang, s):
    bg_ = lin([(0, '#fff27a'), (.5, '#ffd21a'), (1, '#e08a00')], 0, 0, 0, 1)
    return (f'<g transform="translate({x},{y}) rotate({ang}) scale({s})">'
            f'<path d="M -70 -10 Q 0 60 80 -20 Q 70 -4 74 6 Q 0 90 -78 0 Z" fill="{bg_}" stroke="#3a1a04" stroke-width="5" stroke-linejoin="round"/>'
            f'<path d="M -60 4 Q 0 56 70 -6" stroke="#fff8c0" stroke-width="5" fill="none" stroke-linecap="round" opacity=".8"/>'
            f'<path d="M 80 -20 l 10 -16 l 8 4 l -8 18 Z" fill="#5a3a10" stroke="#3a1a04" stroke-width="4"/>'
            f'<circle cx="-76" cy="-4" r="6" fill="#3a1a04"/></g>')


def banana_bunch(x, y, s, ang=0):
    """Hanging bunch: bananas fanned from one crown, all curving the same way."""
    out = [f'<g transform="translate({x},{y}) rotate({ang}) scale({s})">']
    yb = lin([(0, '#fff6a0'), (.45, '#ffd81a'), (.85, '#f0a000'), (1, '#b86a00')], 0, 0, 1, 0)
    for a in (-38, -19, 0, 19, 38, -28, -9, 10, 29):
        out.append(f'<g transform="rotate({a})"><path d="M -12 0 C -30 50, -26 110, 10 150 C 18 158, 30 150, 26 140 '
                   f'C 8 104, 6 54, 14 0 Z" fill="{yb}" stroke="#3a1a04" stroke-width="5" stroke-linejoin="round"/>'
                   f'<path d="M 2 10 C -4 54, 0 100, 18 136" stroke="#fffbd0" stroke-width="4" fill="none" opacity=".7" stroke-linecap="round"/>'
                   f'<circle cx="18" cy="146" r="5" fill="#3a1a04"/></g>')
    out.append('<path d="M -20 4 Q 0 -10 20 4 L 14 -26 Q 0 -34 -14 -26 Z" fill="#6a8a1a" stroke="#3a1a04" stroke-width="5" stroke-linejoin="round"/>')
    out.append('<path d="M 0 -26 Q 4 -60 -8 -80" stroke="#3a1a04" stroke-width="18" fill="none" stroke-linecap="round"/>'
               '<path d="M 0 -26 Q 4 -60 -8 -80" stroke="#7a9a2a" stroke-width="9" fill="none" stroke-linecap="round"/>')
    out.append('</g>')
    return ''.join(out)


def logo_text(txt, x, y, size, fill, outline='#3a1404', ow=None, shadow=True, spacing=0, inner=None, tl=None):
    ow = ow or size * .2
    ls = f' letter-spacing="{spacing}"' if spacing else ''
    tlen = f' textLength="{tl}" lengthAdjust="spacingAndGlyphs"' if tl else ''
    base = f'class="logo" x="{x}" y="{y}" font-size="{size}" text-anchor="middle"{ls}{tlen}'
    out = []
    if shadow:
        out.append(f'<text {base} fill="#1e0604" stroke="#1e0604" stroke-width="{ow}" stroke-linejoin="round" transform="translate(0,{size * .09:.0f})">{txt}</text>')
    out.append(f'<text {base} fill="{outline}" stroke="{outline}" stroke-width="{ow}" stroke-linejoin="round">{txt}</text>')
    if inner:
        out.append(f'<text {base} fill="{inner}" stroke="{inner}" stroke-width="{size * .06:.1f}" stroke-linejoin="round">{txt}</text>')
    out.append(f'<text {base} fill="{fill}">{txt}</text>')
    # top gloss
    gl = lin([(0, '#ffffff', .55), (.45, '#ffffff', .1), (.5, '#ffffff', 0), (1, '#ffffff', 0)], 0, 0, 0, 1)
    out.append(f'<text {base} fill="{gl}">{txt}</text>')
    return '\n'.join(out)


def title(cx, top, scale=1.0, sub=True, bunch=True, sub_text='MONKEY SURVIVAL'):
    yel = lin([(0, '#fff48a'), (.35, '#ffd21a'), (.7, '#ffa000'), (1, '#ff6a00')], 0, 0, 0, 1)
    out = [f'<g transform="translate({cx},{top}) scale({scale}) rotate(-3)" filter="url(#titleShadow)">']
    if bunch:
        out.append(banana_bunch(380, 46, .74, -24))
    out.append(logo_text('PRIMAL', 0, 108, 122, yel, inner='#fff2b0', tl=500))
    out.append(logo_text('BANANA', 0, 252, 158, yel, inner='#fff2b0', tl=690))
    out.append(logo_text('ISLANDS', 0, 372, 122, yel, inner='#fff2b0', tl=580))
    if sub:
        out.append(f'<path d="M -300 400 L 300 400 L 286 470 L -286 470 Z" fill="#5a1a0c" stroke="#1e0604" stroke-width="7" stroke-linejoin="round"/>')
        out.append(f'<path d="M -292 408 L 292 408" stroke="#a8401a" stroke-width="4"/>')
        # El ancho del texto crece con las letras hasta llenar la cinta (520 = "MONKEY SURVIVAL").
        out.append(logo_text(sub_text, 0, 452, 50, '#ffffff', outline='#1e0604', ow=12, shadow=False, spacing=3,
                             tl=min(520, 36 * len(sub_text))))
    out.append('</g>')
    return '\n'.join(out)


# ===================================================================== FRAMES
def embers(W, H, n, seed):
    rnd = random.Random(seed)
    e = ''.join(f'<circle cx="{rnd.uniform(0, W):.0f}" cy="{rnd.uniform(H * .3, H):.0f}" r="{rnd.uniform(1.5, 3.8):.1f}" '
                f'fill="{rnd.choice(["#ffd23a", "#ff9a1a", "#ffb84a"])}" opacity="{rnd.uniform(.5, 1):.2f}"/>' for _ in range(n))
    return f'<g filter="url(#glow4)">{e}</g>'


def vignette(W, H):
    v = rad([(0, '#000000', 0), (.62, '#000000', 0), (1, '#0a0018', .7)], r=.75)
    return f'<rect x="0" y="0" width="{W}" height="{H}" fill="{v}"/>'


def background():
    return '\n'.join([sky(), sea(), plume(), volcano(), fountain(), bombs(), jungle()])


def svg_doc(W, H, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
            f'<defs>{"".join(DEFS)}</defs>\n{body}\n</svg>\n')


def build_portada():
    DEFS.clear()
    base_defs()
    W, H = 1920, 1080
    layers = [
        '<!-- BACKGROUND: sunset, sea, eruption, jungle -->', background(),
        '<!-- MIDGROUND: the four island bosses -->',
        boss(orangutan, 165, 940, .76),
        boss(chimp_chief, 405, 915, .72),
        boss(albino_gorilla, 1690, 930, .8),
        boss(ash_gorilla, 1330, 905, .98),
        f'<ellipse cx="960" cy="905" rx="1100" ry="55" fill="#ff8a6a" opacity=".22" filter="url(#blur18)"/>',
        # atmospheric haze between bosses and player
        f'<rect x="0" y="500" width="{W}" height="580" fill="{lin([(0, "#ff7a5a", 0), (.6, "#c03a6a", .07), (1, "#2a0a2a", .22)], 0, 0, 0, 1)}"/>',
        '<!-- FOREGROUND: player -->', ground(),
        f'<g transform="translate(870,1040) scale(1.0)" filter="url(#charShadow)">{player()}</g>',
        foreground_plants(),
        embers(W, H, 40, 5),
        vignette(W, H),
        '<!-- TITLE -->', title(420, 50, .86),
    ]
    return svg_doc(W, H, '\n'.join(layers))


def build_icon():
    DEFS.clear()
    base_defs()
    W = H = 512
    bgs = background()
    layers = [
        f'<g transform="translate(-600,-104) scale(.6)">{bgs}</g>',
        boss(ash_gorilla, 372, 520, .66, haze=False),
        f'<rect x="0" y="200" width="512" height="312" fill="{lin([(0, "#ff7a5a", 0), (1, "#2a0a2a", .35)], 0, 0, 0, 1)}"/>',
        f'<g transform="translate(160,548) scale(.57)" filter="url(#charShadow)">{player()}</g>',
        f'<rect x="0" y="300" width="512" height="212" fill="{lin([(0, "#14020a", 0), (1, "#14020a", .75)], 0, 0, 0, 1)}"/>',
        vignette(W, H),
        title(256, 296, .5, sub=False, bunch=False),
    ]
    return svg_doc(W, H, '\n'.join(layers))


if __name__ == '__main__':
    open(os.path.join(HERE, 'portada.svg'), 'w').write(build_portada())
    open(os.path.join(HERE, 'icono.svg'), 'w').write(build_icon())
    print('ok')
