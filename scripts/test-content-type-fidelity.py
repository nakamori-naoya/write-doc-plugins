#!/usr/bin/env python3
"""テンプレートと記載例の対応が崩れていないかを機械的に検査する。

人手のレビューでしか見つからなかった欠陥を、次に持ち込ませないための検査である。
検査するのは対応と存在であり、文章の意味は評価しない。
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CT = ROOT / "plugins/skills/authoring/content-types"
CATALOG = CT / "references/catalog.md"
ASSETS = CT / "assets"
PAIRS = ASSETS / "template-examples.yml"

HEADING = re.compile(r"^(#{1,4})\s+(.+?)\s*$", re.M)
COMMENT = re.compile(r"<!--(.*?)-->", re.S)
MD_LINK = re.compile(r"(?<!!)\[[^\]]*\]\(([^)#\s]+)(?:#[^)\s]*)?\)")
IMG_LINK = re.compile(r"!\[[^\]]*\]\(([^)#\s]+)\)")
PY_TOOL = re.compile(r"`?([A-Za-z_][A-Za-z0-9_]*\.py)\s+\w+")
PLACEHOLDER = re.compile(r"[<＜][^>＞]*[>＞]")

failures: list[str] = []


def fail(msg: str) -> None:
    failures.append(msg)


def read_pairs() -> dict[str, dict[str, str]]:
    """template-examples.yml を最小限の構文で読む（yq に依存しない）。"""
    pairs: dict[str, dict[str, str]] = {}
    slug = None
    for line in PAIRS.read_text().splitlines():
        m = re.match(r"^  ([A-Za-z0-9-]+):\s*$", line)
        if m:
            slug = m.group(1)
            pairs[slug] = {}
            continue
        m = re.match(r"^    (template|example):\s*(\S+)\s*$", line)
        if m and slug:
            pairs[slug][m.group(1)] = m.group(2)
    return pairs


def fixed_headings(text: str) -> list[str]:
    """プレースホルダーを含まない見出しだけを返す。例側で名前が変わらないもの。"""
    out = []
    for level, title in HEADING.findall(text):
        if len(level) == 1:
            # H1は文書ごとの題名になる。テンプレートと一致する必要はない。
            continue
        if PLACEHOLDER.search(title):
            continue
        out.append(f"{level} {title}")
    return out


def check_pairs(pairs: dict[str, dict[str, str]]) -> None:
    if len(pairs) != 28:
        fail(f"対応表の件数が28でない: {len(pairs)}")
    for slug, files in sorted(pairs.items()):
        for kind in ("template", "example"):
            rel = files.get(kind)
            if not rel:
                fail(f"{slug}: {kind} の指定が無い")
                continue
            path = CT / rel
            if not path.is_file():
                fail(f"{slug}: {kind} のファイルが無い: {rel}")
                continue
            if slug not in Path(rel).name:
                fail(f"{slug}: {kind} のファイル名が slug と対応しない: {rel}")


# カタログの「固定見出しを持つ型」表に載っている型だけが、構成を固定される。
# それ以外の型では、記載例の節の集合はその題材での一例にすぎない。
CATALOG_TYPE_TO_SLUG = {
    "業務知識・コアドメイン": "domain-rule",
    "ユーザー目的達成BDD": "user-journey-bdd",
    "RDB論理設計": "rdb-logical-data-modeling",
    "RDB物理設計": "rdb-physical-design",
    "Product North Star": "north-star",
    "Product Strategy": "strategy",
    "実装解説（PR）": "pr-walkthrough",
    "コード地図（マクロ）": "code-map",
    "コードリーディング": "code-reading",
}


def fixed_structure_slugs() -> set[str]:
    """カタログの「固定見出しを持つ型」表を読み、対象slugを返す。"""
    text = CATALOG.read_text()
    start = text.find("### 固定見出しを持つ型")
    if start < 0:
        fail("catalog.md に「固定見出しを持つ型」の節が無い")
        return set()
    section = text[start:text.find("###", start + 10)]
    slugs = set()
    for line in section.splitlines():
        if not line.startswith("| ") or line.startswith("| 型 ") or set(line) <= set("|- "):
            continue
        name = line.split("|")[1].strip()
        slug = CATALOG_TYPE_TO_SLUG.get(name)
        if slug is None:
            fail(f"catalog.md の固定見出し表に未知の型がある: {name!r}")
        else:
            slugs.add(slug)
    return slugs


def check_heading_alignment(pairs: dict[str, dict[str, str]]) -> None:
    """固定見出しを持つ型だけ、テンプレートの見出しが記載例にも現れること。"""
    fixed = fixed_structure_slugs()
    for slug in sorted(fixed):
        files = pairs.get(slug)
        if not files:
            fail(f"固定見出し表の型が対応表に無い: {slug}")
            continue
        tpl = CT / files["template"]
        ex = CT / files["example"]
        if not (tpl.is_file() and ex.is_file()):
            continue
        ex_headings = set(fixed_headings(ex.read_text()))
        for h in fixed_headings(tpl.read_text()):
            if h not in ex_headings:
                fail(f"{slug}: 固定見出しが記載例に無い: {h!r}")


def check_examples_are_not_frames(pairs: dict[str, dict[str, str]]) -> None:
    """記載例が「テンプレートの写し」と自己定義していないこと。"""
    for slug, files in sorted(pairs.items()):
        ex = CT / files["example"]
        if not ex.is_file():
            continue
        text = ex.read_text()
        if "../templates/" in text:
            fail(f"{slug}: 記載例がテンプレートへリンクしている。構成の正本と誤読される")
        if "構成の正本ではなく" not in text:
            fail(f"{slug}: 記載例に「構成の正本ではなく、粒度と具体性の見本」の宣言が無い")
        if PLACEHOLDER.search(text.replace("&nbsp;", "")) and slug not in ("landing-page",):
            pass  # プレースホルダーの混入検査は型ごとの記法差が大きいため、ここでは行わない


def check_personas() -> None:
    """ペルソナが5人揃い、3段階を持つこと。追加も削除もされていないこと。"""
    expected = {"pm-1", "pm-3", "backend-1", "backend-5", "product-user"}
    persona_dir = CT / "assets/personas"
    found = {p.stem for p in persona_dir.glob("*.md")} if persona_dir.is_dir() else set()
    if found != expected:
        fail(f"ペルソナは5人で固定である。過不足: 余分={sorted(found - expected)} 欠落={sorted(expected - found)}")
    for name in sorted(found & expected):
        text = (persona_dir / f"{name}.md").read_text()
        for level in ("## 実務で使える", "## 言われれば分かる", "## 知らない"):
            if level not in text:
                fail(f"ペルソナ {name}: 知識の段階 {level!r} が無い")
    guide = CT / "references/personas.md"
    if not guide.is_file():
        fail("references/personas.md が無い")


def check_section_comments(pairs: dict[str, dict[str, str]]) -> None:
    """「書く:」を持つ節コメントは「書かない:」も持ち、同じ節へ二重に置かない。"""
    for slug, files in sorted(pairs.items()):
        tpl = CT / files["template"]
        if not tpl.is_file():
            continue
        text = tpl.read_text()
        blocks = [b for b in COMMENT.findall(text) if "書く:" in b]
        for b in blocks:
            if "書かない:" not in b:
                fail(f"{slug}: 「書く:」だけで「書かない:」が無い節コメントがある")
        # 同じ節へ同じ内容の「書く/書かない」を重ねて置いていないこと。
        # 一つの節が表と図のように別の成果物を含むとき、それぞれに境界を置くのは正しい。
        heads = re.findall(r"^#{1,4}\s+.+$", text, flags=re.M)
        parts = re.split(r"^#{1,4}\s+.+$", text, flags=re.M)
        for i, part in enumerate(parts):
            seen: set[str] = set()
            for b in COMMENT.findall(part):
                if "書く:" not in b:
                    continue
                key = re.sub(r"\s+", "", b.split("書く:", 1)[1].split("書かない:", 1)[0])
                head = heads[i - 1] if 0 < i <= len(heads) else "(冒頭)"
                if key in seen:
                    fail(f"{slug}: 同じ節に同じ「書く:」を二重に置いている: {head}")
                seen.add(key)


def check_links(pairs: dict[str, dict[str, str]]) -> None:
    """相対リンクと画像参照の実在を確かめる。"""
    targets = []
    for files in pairs.values():
        targets += [CT / files["template"], CT / files["example"]]
    for path in targets:
        if not path.is_file():
            continue
        text = path.read_text()
        for rel in MD_LINK.findall(text) + IMG_LINK.findall(text):
            if rel.startswith(("http://", "https://", "mailto:")):
                continue
            if PLACEHOLDER.search(rel) or rel.startswith("..."):
                continue
            if not (path.parent / rel).exists():
                fail(f"{path.name}: 参照先が無い: {rel}")


def check_missing_tools(pairs: dict[str, dict[str, str]]) -> None:
    """テンプレートが、このリポジトリに無いツールの実行を求めていないこと。"""
    for slug, files in sorted(pairs.items()):
        tpl = CT / files["template"]
        if not tpl.is_file():
            continue
        for name in set(PY_TOOL.findall(tpl.read_text())):
            if not list(ROOT.rglob(name)):
                fail(f"{slug}: テンプレートが存在しないツールを指している: {name}")


def check_bdd_rules(pairs: dict[str, dict[str, str]]) -> None:
    """拒否シナリオを持つBDD型の記載例が、規則参照を実演していること。"""
    for slug in ("domain-rule", "rdb-logical-data-modeling", "user-journey-bdd"):
        files = pairs.get(slug)
        if not files:
            continue
        ex = CT / files["example"]
        if not ex.is_file():
            continue
        text = ex.read_text()
        if "```gherkin" not in text:
            continue
        if "NOTE: Rule:" not in text:
            fail(f"{slug}: 記載例に `NOTE: Rule:` が1件も無い")
        if "NOTE: Rule:" in text and "Reason:" not in text:
            fail(f"{slug}: `NOTE: Rule:` に対応する `Reason:` が無い")
        if re.search(r"^### Scenario BDD-", text, re.M):
            fail(f"{slug}: BDD見出しが `### [BDD-nnn]` 形式でない")


def check_logical_types(pairs: dict[str, dict[str, str]]) -> None:
    """論理設計にDBMS固有の型名を書いていないこと。"""
    banned = ("timestamptz", "bigint", "uuid ", "serial", "varchar")
    for kind in ("template", "example"):
        files = pairs.get("rdb-logical-data-modeling")
        if not files:
            return
        path = CT / files[kind]
        if not path.is_file():
            continue
        text = COMMENT.sub("", path.read_text())  # 執筆指示の禁止例は対象外
        for word in banned:
            if word in text:
                fail(f"rdb-logical-data-modeling({kind}): DBMS固有の型名がある: {word.strip()!r}")


def main() -> int:
    pairs = read_pairs()
    check_pairs(pairs)
    check_heading_alignment(pairs)
    check_section_comments(pairs)
    check_links(pairs)
    check_missing_tools(pairs)
    check_bdd_rules(pairs)
    check_logical_types(pairs)
    check_examples_are_not_frames(pairs)
    check_personas()
    for msg in failures:
        print(f"  - {msg}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
