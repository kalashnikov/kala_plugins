#!/usr/bin/env python3
"""Wrap an HTML body fragment in the ste-html template, lint its prose, write one file.

Usage:
    build.py --in body.html --title "T" [--subtitle S] [--meta M] [--lang en|zh-Hant]
             [--out PATH] [--strict] [--no-open]
    build.py --in body.html --lint-only

Reads the body (panels, lead, components) from --in FILE, or stdin if --in is absent. Lints visible text only:
code, pre, svg, del, and elements with class "bad" or "no-lint" are skipped.
English sentences go through ste-lint.py. Chinese sentences get a short CJK
rule set (sentence length, empty verbs, stacked 的, buzzwords, semicolons).

Prints the output path, then lint findings. Exit 1 only with --strict and hard
findings (the page is not written in that case). Stdlib only, no network.
"""
import datetime
import html
import importlib.util
import os
import re
import subprocess
import sys
from html.parser import HTMLParser

sys.dont_write_bytecode = True  # keep __pycache__ out of the plugin directory

HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(HERE, "..", "assets", "template.html")
OUT_DIR = os.path.expanduser("~/.ste-html/pages")

_spec = importlib.util.spec_from_file_location("ste_lint", os.path.join(HERE, "ste-lint.py"))
ste_lint = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ste_lint)

SKIP_TAGS = {"code", "pre", "svg", "del", "s", "script", "style"}
SKIP_CLASSES = {"bad", "no-lint"}
BLOCK_TAGS = {"p", "li", "td", "th", "h1", "h2", "h3", "h4", "dt", "dd", "div",
              "figcaption", "blockquote", "summary", "small", "br", "tr"}
VOID_TAGS = {"br", "hr", "img", "input", "meta", "link", "wbr", "col", "source"}


class TextBlocks(HTMLParser):
    """Collect visible prose as one line per block element."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []  # (tag, skipping)
        self.lines = [""]

    def _skipping(self):
        return bool(self.stack) and self.stack[-1][1]

    def handle_starttag(self, tag, attrs):
        if tag in BLOCK_TAGS:
            self.lines.append("")
        if tag in VOID_TAGS:
            return
        classes = set((dict(attrs).get("class") or "").split())
        skip = self._skipping() or tag in SKIP_TAGS or bool(classes & SKIP_CLASSES)
        self.stack.append((tag, skip))

    def handle_endtag(self, tag):
        if tag in VOID_TAGS:
            return
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                break
        if tag in BLOCK_TAGS:
            self.lines.append("")

    def handle_data(self, data):
        if not self._skipping():
            self.lines[-1] += data

    def text(self):
        out = [re.sub(r"\s+", " ", l).strip() for l in self.lines]
        return [l for l in out if l]


CJK = re.compile(r"[㐀-鿿]")
ZH_SENT = re.compile(r"[^。！？!?]+[。！？!?]?")
ZH_RULES = [
    ("zh-semicolon", re.compile(r"；"), "STE bans the semicolon. Split into separate sentences."),
    ("zh-empty-verb", re.compile(r"(進行|进行|加以|予以|作出)(?=[一-鿿])"),
     "Empty verb. Use the real verb (進行優化 → 優化)."),
    ("zh-stacked-de", re.compile(r"的[^，。、；！？,]{1,8}的[^，。、；！？,]{1,8}的"),
     "Three or more 的 in one clause. Split or restructure."),
    ("zh-buzzword", re.compile(r"賦能|赋能|閉環|闭环|抓手|至關重要|至关重要|無縫|无缝|顛覆性|颠覆性|一站式|全方位|打通"),
     "Buzzword. Delete it, or state the concrete fact."),
]
ZH_MAX = 45  # CJK chars per sentence (descriptions)


def lint_zh(lines):
    findings = []
    for n, line in enumerate(lines, 1):
        if not CJK.search(line):
            continue
        for rule, pat, msg in ZH_RULES:
            for m in pat.finditer(line):
                findings.append({"line": n, "rule": rule, "match": m.group(0), "message": msg})
        for sent in ZH_SENT.findall(line):
            count = len(CJK.findall(sent))
            if count > ZH_MAX:
                findings.append({"line": n, "rule": "zh-long-sentence", "match": f"{count} chars",
                                 "message": f"Sentence has {count} CJK chars (cap {ZH_MAX}). Split it."})
    return findings


def lint_body(body):
    p = TextBlocks()
    p.feed(body)
    lines = p.text()
    en, _ = ste_lint.lint("\n".join(lines), filename="page")
    findings = [dict(f, hard=f["level"] == "advisory-free") for f in en]
    findings += [dict(f, hard=True) for f in lint_zh(lines)]
    findings.sort(key=lambda f: f["line"])
    for f in findings:
        f["text"] = lines[f["line"] - 1][:90]
    return findings


def slug(title):
    s = re.sub(r"[^\w㐀-鿿]+", "-", title.lower()).strip("-")
    return s[:40] or "page"


def arg(argv, name, default=None):
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default


def main(argv):
    src = arg(argv, "--in")
    if src:
        with open(src, encoding="utf-8") as fh:
            body = fh.read()
    else:
        body = sys.stdin.read()
    findings = lint_body(body)
    hard = [f for f in findings if f["hard"]]

    def report():
        for f in findings:
            tag = "" if f["hard"] else " (advisory)"
            print(f"STE {f['rule']}{tag}: {f['message']} [{f['match']}] in: \"{f['text']}\"")
        print(f"STE: {len(hard)} hard, {len(findings) - len(hard)} advisory")

    if "--lint-only" in argv:
        report()
        return 1 if hard else 0
    if "--strict" in argv and hard:
        report()
        print("✗ not written (--strict and hard STE findings)")
        return 1

    title = arg(argv, "--title", "Answer")
    lang = arg(argv, "--lang") or ("zh-Hant" if CJK.search(title + body[:2000]) else "en")
    sub, meta = arg(argv, "--subtitle"), arg(argv, "--meta")
    head = ['<header class="page">',
            f'<button id="theme-toggle" type="button">{"深淺" if lang.startswith("zh") else "theme"}</button>',
            f"<h1>{html.escape(title)}</h1>"]
    if sub:
        head.append(f'<p class="sub">{html.escape(sub)}</p>')
    if meta:
        head.append(f'<div class="meta">{html.escape(meta)}</div>')
    head.append("</header>")
    now = datetime.datetime.now()
    footer = f"ste-html · {now:%Y-%m-%d %H:%M} · STE {len(hard)} hard / {len(findings) - len(hard)} advisory"

    with open(TEMPLATE, encoding="utf-8") as fh:
        page = fh.read()
    for key, val in (("{{LANG}}", lang), ("{{TITLE}}", html.escape(title)),
                     ("{{FOOTER}}", footer), ("{{BODY}}", "\n".join(head) + "\n" + body)):
        page = page.replace(key, val, 1)

    out = arg(argv, "--out") or os.path.join(OUT_DIR, f"{now:%Y%m%d-%H%M%S}-{slug(title)}.html")
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(page)
    print(f"✓ {os.path.abspath(out)}")
    report()
    if "--no-open" not in argv and sys.platform == "darwin":
        subprocess.run(["open", out], check=False)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
