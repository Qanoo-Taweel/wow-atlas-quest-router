"""Builds docs/diagrams/AtlasQuestRouter-diagrams.pdf: every diagram on readable A4 landscape pages.

    python3 tools/make_print_pdf.py [--chrome /path/to/chrome]

The full class diagram is too large for one sheet, so it is split into one page per package,
using the `%% ===== Section =====` blocks of docs/diagrams/class-diagram-full.mmd (single source).
Needs mermaid-cli (`mmdc`) and Chrome / Chromium.
"""
import argparse
import html
import json
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIAG = ROOT / "docs" / "diagrams"
OUT = DIAG / "AtlasQuestRouter-diagrams.pdf"
AUTHORS = "Qunoo A K Taweel (23291712) · Zeynep Arıcan (24290319)"


def split_full(src: str) -> list[tuple[str, str]]:
    body = src.split("classDiagram", 1)[1]
    parts = re.split(r"^%% =+ (.*?) =+\s*$", body, flags=re.M)
    sections = [(parts[i].strip(), parts[i + 1]) for i in range(1, len(parts), 2)]
    rel = re.compile(r"^\s*\w+\s*(?:\"[^\"]*\"\s*)?(?:<\|--|<\|\.\.|-->|\.\.>|o--|\*--|--)")
    out = []
    for name, block in sections:
        if name == "Facade":  # show the facade together with everything it holds
            block += "\n" + "\n".join(l for l in body.splitlines()
                                      if rel.match(l) and l.strip().startswith("AtlasQuestRouter "))
        # 16 member-less commands side by side would be unreadable: stack them instead
        direction = "LR" if name.startswith("Commands") else "TB"
        out.append((name, "classDiagram\ndirection %s\n" % direction + block))
    return out


def render(code: str, tmp: Path, name: str, mmdc_cfg: Path) -> str:
    src, svg = tmp / (name + ".mmd"), tmp / (name + ".svg")
    src.write_text(code)
    subprocess.run(["mmdc", "-p", str(mmdc_cfg), "-b", "white", "-i", str(src), "-o", str(svg)],
                   check=True, capture_output=True)
    s = svg.read_text()
    w, h = map(float, re.search(r'viewBox="[-\d.]+ [-\d.]+ ([\d.]+) ([\d.]+)"', s).groups())
    portrait = min(194 / w, 262 / h) > min(281 / w, 178 / h)  # pick the orientation with bigger text
    return re.sub(r'<svg id="my-svg" width="100%"', '<svg id="my-svg"', s, count=1), portrait


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--chrome", default="google-chrome")
    a = ap.parse_args()
    full = (DIAG / "class-diagram-full.mmd").read_text()
    pages = [("Simplified class diagram (12 central classes)", (DIAG / "class-diagram-simplified.mmd").read_text())]
    pages += [("Full class diagram — %s" % n, c) for n, c in split_full(full)]
    pages += [("Sequence diagram: /aqr plan", (DIAG / "sequence-plan.mmd").read_text()),
              ("Layers / packages", (DIAG / "packages.mmd").read_text()),
              ("ATLAS flowchart", (DIAG / "atlas-flow.mmd").read_text())]
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        cfg = tmp / "pp.json"
        cfg.write_text(json.dumps({"executablePath": a.chrome if "/" in a.chrome else
                                   subprocess.run(["which", a.chrome], capture_output=True, text=True).stdout.strip(),
                                   "args": ["--no-sandbox"]}))
        secs = []
        for i, (title, code) in enumerate(pages, 1):
            code = re.sub(r"^---\n.*?\n---\n", "", code, flags=re.S)  # page header carries the title
            svg, portrait = render(code, tmp, "p%02d" % i, cfg)
            secs.append('<section class="%s"><header>' % ("port" if portrait else "land") + '<b>%s</b></header><div class="d">%s</div>'
                        '<footer><span>Atlas Quest Router · UML diagrams</span><span>%s · page %d / %d</span></footer></section>'
                        % (html.escape(title), svg, html.escape(AUTHORS), i, len(pages)))
        cover = ('<section class="cover"><div><h1>Atlas Quest Router</h1><p>UML diagrams</p>'
                 '<p class="who">Qunoo A K Taweel — 23291712<br>Zeynep Arıcan — 24290319</p>'
                 '<p class="src">Source: github.com/Qanoo-Taweel/wow-atlas-quest-router · diagrams generated from '
                 'docs/diagrams/*.mmd</p></div></section>')
        doc = """<!doctype html><html><head><meta charset="utf-8"><title>Atlas Quest Router diagrams</title><style>
@page{size:A4 landscape;margin:8mm} @page port{size:A4 portrait;margin:8mm}
body{margin:0;font-family:Helvetica,Arial,sans-serif;color:#111}
section{width:281mm;height:193mm;display:flex;flex-direction:column;page-break-after:always;overflow:hidden}
header{font-size:14px;padding-bottom:3px;border-bottom:1px solid #ccc}
footer{display:flex;justify-content:space-between;font-size:9px;color:#555;border-top:1px solid #ccc;padding-top:2px}
.d{flex:1;min-height:0;display:flex;align-items:center;justify-content:center;padding:3mm 0}
.d svg{width:100%%!important;height:100%%!important;max-width:none!important}
section.port{page:port;width:194mm;height:280mm}
.cover{align-items:center;justify-content:center;text-align:center}
.cover h1{font-size:34px;margin:0 0 6px}.cover p{font-size:16px;margin:4px}.cover .who{font-size:18px;margin-top:28px;line-height:1.6}
.cover .src{font-size:11px;color:#555;margin-top:30px}
</style></head><body>%s%s</body></html>""" % (cover, "".join(secs))
        page = tmp / "print.html"
        page.write_text(doc)
        subprocess.run([a.chrome, "--headless=new", "--no-sandbox", "--disable-gpu", "--no-pdf-header-footer",
                        "--print-to-pdf=%s" % OUT, page.as_uri()], check=True, capture_output=True)
    print("wrote", OUT, "(%d pages)" % (len(pages) + 1))


if __name__ == "__main__":
    main()
