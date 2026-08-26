#!/usr/bin/env python3
"""資料の末尾に載る静的情報を、媒体の表現へ写す。

**中身が何を意味するかは知らない。** 期間・参加者・ラベルという JSON を受け取り、
HTML なら script タグと表、Markdown なら HTML コメントと表へ写すだけ。
どんな情報を載せるかを決めるのは、この JSON を作る側である。

  render-meta.py --meta <json|path> --format html|markdown
"""

import argparse
import json
import sys

BEGIN = "doc-meta:begin"
END = "doc-meta:end"


def fail(msg, code=2):
    print(json.dumps({"error": msg}, ensure_ascii=False))
    sys.exit(code)


def load_json(raw):
    raw = (raw or "").strip()
    if raw.startswith("{"):
        return json.loads(raw)
    try:
        with open(raw, encoding="utf-8") as f:
            return json.load(f)
    except OSError as e:
        fail("読めない: {}".format(e))


def render_html(m):
    p = m.get("period") or {}
    rows = [
        ("期間", "{} 〜 {}（{}）".format(p.get("from", ""), p.get("to", ""), p.get("label", ""))),
        ("作成", m.get("generated_at", "")),
        ("種別", "{} / {}".format(m.get("producer", ""), m.get("type", ""))),
    ]
    parts = m.get("participants") or []
    rows.append(("参加者", "、".join(parts) if parts
                 else (m.get("participants_note") or "記録なし")))
    mats = m.get("materials") or []
    rows.append(("素材", "{}件".format(len(mats)) if mats else "なし"))

    def esc(s):
        return (str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))

    tr = "\n".join("    <tr><th>{}</th><td>{}</td></tr>".format(esc(k), esc(v)) for k, v in rows)
    chips = " ".join('<span class="label">{}</span>'.format(esc(x)) for x in m.get("labels") or [])
    return """<section class="doc-meta">
  <h2>この資料について</h2>
  <table class="doc-meta-table">
{tr}
    <tr><th>ラベル</th><td class="labels">{chips}</td></tr>
  </table>
  <!-- {begin} -->
  <script type="application/json" class="doc-meta-json">
{js}
  </script>
  <!-- {end} -->
</section>""".format(tr=tr, chips=chips, begin=BEGIN, end=END,
                     js=json.dumps(m, ensure_ascii=False, indent=2)
                     # </script> がそのまま出ると script ブロックが途中で閉じ、
                     # 残りがページ本文として表示される。JSON としては同値。
                     .replace("</", "<\\/"))



def md_cell(s):
    """表のセルへ入れる値を逃がす。

    ラベルは利用者が自由に付けるので | が入りうる。
    そのまま置くと列が増えて表が崩れる。
    """
    return str(s).replace("|", "\\|")


def render_markdown(m):
    p = m.get("period") or {}
    parts = m.get("participants") or []
    mats = m.get("materials") or []
    lines = [
        "## この資料について",
        "",
        "| | |",
        "|---|---|",
        "| 期間 | {} 〜 {}（{}） |".format(p.get("from", ""), p.get("to", ""), p.get("label", "")),
        "| 作成 | {} |".format(m.get("generated_at", "")),
        "| 種別 | {} / {} |".format(m.get("producer", ""), m.get("type", "")),
        "| 参加者 | {} |".format(md_cell("、".join(parts)) if parts
                                else (m.get("participants_note") or "記録なし")),
        "| 素材 | {} |".format("{}件".format(len(mats)) if mats else "なし"),
        "| ラベル | {} |".format(" ".join("`{}`".format(md_cell(x)) for x in m.get("labels") or [])),
        "",
        "<!-- {}".format(BEGIN),
        json.dumps(m, ensure_ascii=False, indent=2),
        "{} -->".format(END),
    ]
    return "\n".join(lines)



def main():
    p = argparse.ArgumentParser()
    p.add_argument("--meta", required=True)
    p.add_argument("--format", choices=["html", "markdown"], default="html")
    a = p.parse_args()
    m = load_json(a.meta)
    print(render_html(m) if a.format == "html" else render_markdown(m))


if __name__ == "__main__":
    main()
