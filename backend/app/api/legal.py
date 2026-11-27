"""Public privacy policy and terms (Google Play needs a public privacy-policy URL).

The documents live in docs/legal/ as Markdown and are served as simple, readable HTML pages.
"""

import html
import re
from functools import cache
from pathlib import Path

from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["legal"])

# backend/app/api/legal.py → <repo>/docs/legal (locally) or /srv/docs/legal (in the image)
LEGAL_DIR = Path(__file__).resolve().parents[3] / "docs" / "legal"

DOCUMENTS = {
    "privacy": ("privacy-policy.bn.md", "bn", "গোপনীয়তা নীতি"),
    "privacy/en": ("privacy-policy.md", "en", "Privacy policy"),
    "terms": ("terms.md", "en", "Terms of use"),
}

_STYLE = """
body{font-family:'Hind Siliguri','Noto Sans Bengali',system-ui,sans-serif;max-width:760px;
margin:0 auto;padding:16px;line-height:1.6;color:#1b1c1b;background:#f6fbf8}
h1,h2,h3{color:#176b55;line-height:1.3}table{border-collapse:collapse;width:100%;margin:12px 0}
td,th{border:1px solid #c4ccc8;padding:6px 8px;vertical-align:top;text-align:left}
blockquote{margin:12px 0;padding:8px 12px;background:#fff4d6;border-left:4px solid #e0b000}
a{color:#176b55}@media (prefers-color-scheme:dark){body{background:#101412;color:#e1e3e0}
h1,h2,h3,a{color:#8fd5bd}blockquote{background:#3a3220}td,th{border-color:#444}}
"""


def _inline(text: str) -> str:
    text = html.escape(text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    return re.sub(
        r"\[([^\]]+)\]\((https?://[^)\s]+)\)", r'<a href="\2" rel="noopener">\1</a>', text
    )


def markdown_to_html(md: str) -> str:
    """The subset of Markdown the legal documents use: headings, paragraphs, lists, tables,
    block quotes, bold, code and links. Everything else is escaped."""
    out: list[str] = []
    lines = md.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].rstrip()
        if not line.strip():
            i += 1
            continue
        if m := re.match(r"^(#{1,4})\s+(.*)", line):
            level = len(m.group(1))
            out.append(f"<h{level}>{_inline(m.group(2))}</h{level}>")
            i += 1
        elif line.lstrip().startswith("|"):
            rows = []
            while i < len(lines) and lines[i].lstrip().startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-{3,}:?", c) for c in cells):
                    rows.append(cells)
                i += 1
            head, *body = rows
            out.append("<table><tr>" + "".join(f"<th>{_inline(c)}</th>" for c in head) + "</tr>")
            for r in body:
                out.append("<tr>" + "".join(f"<td>{_inline(c)}</td>" for c in r) + "</tr>")
            out.append("</table>")
        elif line.startswith(">"):
            quote = []
            while i < len(lines) and lines[i].startswith(">"):
                quote.append(lines[i].lstrip(">").strip())
                i += 1
            out.append(f"<blockquote>{_inline(' '.join(quote))}</blockquote>")
        elif re.match(r"^\s*([-*]|\d+[.)])\s+", line):
            ordered = bool(re.match(r"^\s*\d", line))
            tag = "ol" if ordered else "ul"
            items = []
            while i < len(lines) and re.match(r"^\s*([-*]|\d+[.)])\s+", lines[i]):
                items.append(re.sub(r"^\s*([-*]|\d+[.)])\s+", "", lines[i]))
                i += 1
            out.append(f"<{tag}>" + "".join(f"<li>{_inline(t)}</li>" for t in items) + f"</{tag}>")
        else:
            para = []
            while (
                i < len(lines)
                and lines[i].strip()
                and not re.match(r"^(#|\||>|\s*([-*]|\d+[.)])\s)", lines[i])
            ):
                para.append(lines[i].strip())
                i += 1
            out.append(f"<p>{_inline(' '.join(para))}</p>")
    return "\n".join(out)


@cache
def _page(key: str) -> str:
    filename, lang, title = DOCUMENTS[key]
    body = markdown_to_html((LEGAL_DIR / filename).read_text(encoding="utf-8"))
    return (
        f'<!doctype html><html lang="{lang}"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        f"<title>{html.escape(title)} · Oshudh Reminder</title><style>{_STYLE}</style></head>"
        f"<body>{body}</body></html>"
    )


@router.get("/privacy", response_class=HTMLResponse, include_in_schema=False)
def privacy_bn() -> str:
    return _serve("privacy")


@router.get("/privacy/en", response_class=HTMLResponse, include_in_schema=False)
def privacy_en() -> str:
    return _serve("privacy/en")


@router.get("/terms", response_class=HTMLResponse, include_in_schema=False)
def terms() -> str:
    return _serve("terms")


def _serve(key: str) -> str:
    try:
        return _page(key)
    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail="Document not available") from e
