#!/usr/bin/env python3
"""資料の末尾に載る静的情報を、媒体の表現へ写す。

**中身が何を意味するかは知らない。** 期間・参加者・ラベルという JSON を受け取り、
Markdown の表と、機械が読み戻すためのコメント内 JSON へ写すだけ。
どんな情報を載せるかを決めるのは、この JSON を作る側である。

  render-meta.py --meta <json|path> [--format markdown]
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
    p.add_argument("--format", choices=["markdown"], default="markdown")
    a = p.parse_args()
    m = load_json(a.meta)
    print(render_markdown(m))


if __name__ == "__main__":
    main()
