#!/usr/bin/env python3
import pathlib

ROOT = pathlib.Path(__file__).parent
SRC = ROOT / "src"

SB = (
    '<div class="sb"><span>9:41</span><span class="sb-icons">'
    '<svg viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1"/>'
    '<rect x="5" y="6" width="3" height="6" rx="1"/><rect x="10" y="3.5" width="3" height="8.5" rx="1"/>'
    '<rect x="15" y="1" width="3" height="11" rx="1"/></svg>'
    '<svg viewBox="0 0 16 12"><path d="M8 11l2.2-2.6a3.4 3.4 0 0 0-4.4 0L8 11z"/>'
    '<path d="M8 5.6c1.7 0 3.3.6 4.6 1.7l1.3-1.6A9.5 9.5 0 0 0 8 3.4c-2.2 0-4.3.8-5.9 2.3l1.3 1.6A7 7 0 0 1 8 5.6z" opacity=".9"/></svg>'
    '<svg class="battery" viewBox="0 0 26 12"><rect x=".5" y="1" width="21" height="10" rx="3" fill="none" stroke="currentColor"/>'
    '<rect x="2.5" y="3" width="17" height="6" rx="1.6"/><path d="M23.5 4.6v2.8c1-.4 1.5-1 1.5-1.4s-.5-1-1.5-1.4z"/></svg>'
    "</span></div>"
)

TAB_ITEMS = [
    ("bill", "i-bill", "账单"),
    ("analysis", "i-chart", "分析"),
    ("add", "", ""),
    ("assets", "i-bank", "资产"),
    ("settings", "i-set", "设置"),
]

ALIAS = {"payroll": "assets", "deposit": "assets"}


def tabs(active: str) -> str:
    active = ALIAS.get(active, active)
    items = []
    for key, icon, label in TAB_ITEMS:
        if key == "add":
            items.append(
                '<div class="tab add"><span class="plus"><svg class="ico"><use href="#i-plus"/></svg></span></div>'
            )
            continue
        on = " on" if key == active else ""
        items.append(
            f'<div class="tab{on}"><svg class="ico"><use href="#{icon}"/></svg><span>{label}</span></div>'
        )
    return '<div class="tabbar">' + "".join(items) + '<div class="homebar"></div></div>'


def main():
    layout = (SRC / "layout.html").read_text(encoding="utf-8")
    html = layout.replace("{{STYLE}}", (SRC / "style.css").read_text(encoding="utf-8"))
    for name in ["bill", "analysis", "payroll", "deposit", "settings", "decisions"]:
        part = (SRC / f"part-{name}.html").read_text(encoding="utf-8")
        html = html.replace("{{" + name.upper() + "}}", part)
    html = html.replace("{{SB}}", SB)
    for key, _, _ in TAB_ITEMS:
        html = html.replace("{{TABS:" + key + "}}", tabs(key))
    for key in ALIAS:
        html = html.replace("{{TABS:" + key + "}}", tabs(key))
    out = ROOT / "index.html"
    out.write_text(html, encoding="utf-8")
    print(f"built {out} ({len(html)} bytes)")


if __name__ == "__main__":
    main()
