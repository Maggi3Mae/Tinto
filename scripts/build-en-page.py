#!/usr/bin/env python3
"""
Generates docs/en/index.html from docs/index.html (Spanish source).
Genera docs/en/index.html a partir de docs/index.html (fuente en español).

The English text comes from the `en` strings inside the page's script, so the
English page is fully rendered in HTML for search engines.
Run after editing the page:  python3 scripts/build-en-page.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "docs" / "index.html"
OUT = ROOT / "docs" / "en" / "index.html"
BASE = "https://maggi3mae.github.io/tinto/"

html = SRC.read_text(encoding="utf-8")

# 1. English strings from the page script
start = html.index("    en: {") + len("    en: ")
end = html.index("\n    }\n  };", start) + len("\n    }")
en = json.loads(html[start:end])


def fill(source: str, attr: str, key_map) -> str:
    """Replace the inner content of every element carrying attr="key"."""
    pattern = re.compile(
        r'(<(?P<tag>[a-z0-9]+)\b[^>]*\b' + attr + r'="(?P<key>[^"]+)"[^>]*>)(?P<body>.*?)(</(?P=tag)>)',
        re.S,
    )
    return pattern.sub(lambda m: m.group(1) + key_map(m.group("key"), m.group("body")) + m.group(5), source)


out = html
out = fill(out, "data-i18n", lambda k, body: en.get(k, body).replace("&", "&amp;").replace("<", "&lt;"))
out = fill(out, "data-i18n-html", lambda k, body: en.get(k, body))

# Dynamic texts: initial (inactive) state
initial = {
    "data-state-text": "hero.off",
    "data-state-menu": "m.off",
    "data-toggle-label": "remote.btnOff",
    "data-status": "remote.away",
    "data-status-note": "remote.noteOff",
}
for attr, key in initial.items():
    out = re.sub(r'(<[a-z]+\b[^>]*\b' + attr + r'\b[^>]*>)(.*?)(</[a-z]+>)',
                 lambda m, k=key: m.group(1) + en[k] + m.group(3), out, flags=re.S)

# Attributes
out = re.sub(r'(data-i18n-alt="([^"]+)"[^>]*?\salt=")[^"]*(")',
             lambda m: m.group(1) + en[m.group(2)].replace('"', "&quot;") + m.group(3), out)
out = re.sub(r'(data-i18n-label="([^"]+)" aria-label=")[^"]*(")',
             lambda m: m.group(1) + en[m.group(2)] + m.group(3), out)


def swap(old: str, new: str) -> None:
    global out
    if old not in out:
        raise SystemExit(f"Not found in docs/index.html: {old[:70]}")
    out = out.replace(old, new)


# Head
swap('<html lang="es">', '<html lang="en">')
swap(re.search(r"<title>.*?</title>", out).group(0), f"<title>{en['title']}</title>")
desc = ("Free macOS menu bar app that keeps your Mac awake, even with the lid closed, "
        "and stops Teams and Slack from showing you as Away. An Amphetamine alternative.")
out = re.sub(r'<meta name="description" content="[^"]*">', f'<meta name="description" content="{desc}">', out)
swap(f'<link rel="canonical" href="{BASE}">', f'<link rel="canonical" href="{BASE}en/">')
swap('<meta property="og:locale" content="es_CO">\n<meta property="og:locale:alternate" content="en_US">',
     '<meta property="og:locale" content="en_US">\n<meta property="og:locale:alternate" content="es_CO">')
out = re.sub(r'<meta property="og:title" content="[^"]*">', f'<meta property="og:title" content="{en["title"]}">', out)
out = re.sub(r'<meta property="og:description" content="[^"]*">',
             '<meta property="og:description" content="Free menu bar app for macOS. No account, no App Store.">', out)
swap(f'<meta property="og:url" content="{BASE}">', f'<meta property="og:url" content="{BASE}en/">')
out = re.sub(r'"url": "' + re.escape(BASE) + r'",', f'"url": "{BASE}en/",', out, count=1)
out = re.sub(r'"description": "App gratis[^"]*",',
             '"description": "Free macOS menu bar app that keeps your Mac awake, even with the lid closed, '
             'and stops Teams and Slack from showing you as Away.",', out)
swap('"inLanguage": "es"', '"inLanguage": "en"')
swap('"operatingSystem": "macOS 14 o posterior"', '"operatingSystem": "macOS 14 or later"')
swap('<nav aria-label="Enlaces">', '<nav aria-label="Links">')

# Language switch and relative paths
swap('<a class="lang" href="en/" hreflang="en" lang="en" aria-label="English">EN</a>',
     '<a class="lang" href="../" hreflang="es" lang="es" aria-label="Español">ES</a>')
for path in ('href="icon.svg"', 'href="img/og.png"', 'src="img/'):
    out = out.replace(path, path.replace('"', '"../', 1))

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(out, encoding="utf-8")
print(f"Wrote {OUT.relative_to(ROOT)}")
