#!/usr/bin/env python3
"""システム設計4型の公開契約、記載例、配布時の自己完結性を検査する。"""

from __future__ import annotations

import json
import re
import shutil
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CT = ROOT / "plugins/skills/authoring/content-types"
ASSETS = CT / "assets"
CATALOG = CT / "references/catalog.md"
DETAIL = CT / "references/detail/system-design.md"
AUDIT = ROOT / "docs/evidence/system-design-content-types-audit.md"
REGRESSION_CASES = ROOT / "tests/fixtures/system-design-content-types/regression-cases.json"
SLUGS = (
    "requirements-discovery",
    "workload-model",
    "quality-requirements",
    "cloud-architecture",
)
EXPECTED_TITLES = {
    "requirements-discovery": "要求発見正本",
    "workload-model": "利用・負荷モデル",
    "quality-requirements": "品質要求正本",
    "cloud-architecture": "クラウドアーキテクチャ",
}
SOCIAL_TOPICS = ("X/Twitter", "Twitter", "Instagram", "SNS投稿")
NAKED_ENGLISH = (
    "actor", "action", "event", "payload", "latency", "throughput",
    "availability", "consistency", "durability", "recovery", "security",
    "privacy", "operability", "cost", "provider", "failure",
    "degradation", "node", "burst", "trade-off", "region", "application",
)
UNRESOLVED_PLACEHOLDER = re.compile(
    r"<(?!br\s*/?>)(?:[A-Za-z][A-Za-z0-9_-]*|[^<>\n]*(?:未入力|未記入|未確定|要確認|保留)[^<>\n]*)>"
    r"|＜[^＜＞\n]*(?:未入力|未記入|未確定|要確認|保留)[^＜＞\n]*＞",
    re.IGNORECASE,
)
failures: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def read_pairs(root: Path = CT) -> dict[str, dict[str, str]]:
    pairs: dict[str, dict[str, str]] = {}
    slug: str | None = None
    path = root / "assets/template-examples.yml"
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^  ([a-z0-9-]+):\s*$", line)
        if match:
            slug = match.group(1)
            pairs[slug] = {}
            continue
        match = re.match(r"^    (template|example):\s*(\S+)\s*$", line)
        if match and slug:
            pairs[slug][match.group(1)] = match.group(2)
    return pairs


def human_text(text: str) -> str:
    """コード、URL、機械IDを除き、人が読む文章だけを近似して返す。"""
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"`[^`]+`", "", text)
    text = re.sub(r"https?://\S+", "", text)
    text = re.sub(r"\b(?:REQ|WL|QR|ADR|NODE|SRC|CON|FAIL|ARC)-[A-Z0-9_-]+\b", "", text)
    return text


def heading_anchors(text: str) -> set[str]:
    anchors: set[str] = set()
    for heading in re.findall(r"(?m)^#{1,6}\s+(.+?)\s*$", text):
        plain = re.sub(r"`([^`]+)`", r"\1", heading).strip().lower()
        plain = re.sub(r"[^\w\-\sぁ-んァ-ヶ一-龯]", "", plain)
        anchors.add(re.sub(r"\s+", "-", plain))
    return anchors


def display_violations(text: str) -> list[str]:
    problems: list[str] = []
    if UNRESOLVED_PLACEHOLDER.search(text):
        problems.append("未置換placeholder")
    anchors = heading_anchors(text)
    for target in re.findall(r"\[[^]]+\]\((#[^)\s]+)\)", text):
        if target[1:] not in anchors:
            problems.append("壊れたMarkdown節anchor")
    for block in re.findall(r"```mermaid\s*\n(.*?)\n```", text, re.S):
        labels = re.findall(r'\["([^"\n]+)"\]|\|([^|\n]+)\|', block)
        visible = " ".join(left or right for left, right in labels)
        visible = re.sub(r"<br\s*/?>", " ", visible, flags=re.I)
        visible = re.sub(r"\b(?:REQ|WL|QR|ADR|NODE|SRC|CON|FAIL|ARC)[-_][A-Z0-9_-]+\b", "", visible)
        for token in NAKED_ENGLISH:
            if re.search(rf"(?<![A-Za-z0-9_-]){re.escape(token)}(?![A-Za-z0-9_-])", visible, re.I):
                problems.append(f"裸の英語図label: {token}")
    return problems


def check_public_registration(pairs: dict[str, dict[str, str]]) -> None:
    for slug in SLUGS:
        if slug not in pairs:
            fail(f"対応表に専用型が無い: {slug}")
            continue
        for kind in ("template", "example"):
            relative = pairs[slug].get(kind)
            if not relative or not (CT / relative).is_file():
                fail(f"{slug}: {kind}を解決できない")
    for runtime in ("codex", "claude"):
        manifest = json.loads(
            (ROOT / f"plugins/.{runtime}-plugin/plugin.json").read_text(encoding="utf-8")
        )
        types = manifest["metadata"]["harness"]["implements"][0]["types"]
        for slug in SLUGS:
            if types.count(slug) != 1:
                fail(f"{runtime} metadataで型が一意でない: {slug}")
    codex = json.loads((ROOT / "plugins/.codex-plugin/plugin.json").read_text())
    claude = json.loads((ROOT / "plugins/.claude-plugin/plugin.json").read_text())
    if codex["metadata"]["harness"]["implements"] != claude["metadata"]["harness"]["implements"]:
        fail("Codex/Claude metadataの公開型が一致しない")


def check_templates_and_examples(pairs: dict[str, dict[str, str]]) -> None:
    for slug in SLUGS:
        if slug not in pairs:
            continue
        template = (CT / pairs[slug]["template"]).read_text(encoding="utf-8")
        example = (CT / pairs[slug]["example"]).read_text(encoding="utf-8")
        title = EXPECTED_TITLES[slug]
        if title not in template or title not in example:
            fail(f"{slug}: 日本語の型名が無い")
        if "予約サービス" not in example:
            fail(f"{slug}: 記載例が予約サービスへ統一されていない")
        for label, text in (("template", template), ("example", example)):
            for problem in display_violations(text):
                fail(f"{slug}/{label}: {problem}")
        for term in SOCIAL_TOPICS:
            if term in example:
                fail(f"{slug}: 予約サービス以外の題材が混入: {term}")
        for token in ("status", "open_questions", "handoff.ready", "blocked_by"):
            if token not in template or token not in example:
                fail(f"{slug}: 状態・引き継ぎ項目が不足: {token}")
        if "`unresolved`" not in example or "`false`" not in example:
            fail(f"{slug}: 未解決の保存例またはhandoff.ready=falseが無い")
        sections = re.split(r"(?m)^## ", template)[1:]
        for section in sections:
            heading = section.splitlines()[0]
            first_body = "\n".join(section.splitlines()[1:5])
            if "<!--" not in first_body or "書く:" not in first_body or "書かない:" not in first_body:
                fail(f"{slug}: 節の書く/書かない境界が無い: {heading}")


def check_traceability(pairs: dict[str, dict[str, str]]) -> None:
    examples = {
        slug: (CT / pairs[slug]["example"]).read_text(encoding="utf-8")
        for slug in SLUGS
    }
    requirements = examples["requirements-discovery"]
    workload = examples["workload-model"]
    quality = examples["quality-requirements"]
    cloud = examples["cloud-architecture"]
    for req in ("REQ-001", "REQ-002", "REQ-003", "REQ-004"):
        if req not in requirements or req not in workload or req not in cloud:
            fail(f"要求IDを要求・負荷・クラウド文書で追跡できない: {req}")
    for workload_id in ("WL-001", "WL-002", "WL-003", "WL-004"):
        if workload_id not in workload or workload_id not in quality or workload_id not in cloud:
            fail(f"負荷IDを負荷・品質・クラウド文書で追跡できない: {workload_id}")
    for quality_id in ("QR-001", "QR-002", "QR-003", "QR-004", "QR-005"):
        if quality_id not in quality or quality_id not in cloud:
            fail(f"品質要求IDを品質・クラウド文書で追跡できない: {quality_id}")
    for token in ("ADR-001", "NODE-API", "NODE-DB", "NODE-QUEUE", "NODE-NOTIFY"):
        if token not in cloud:
            fail(f"クラウド文書に設計追跡IDが無い: {token}")
    all_text = "\n".join(examples.values())
    for state in ("fact", "agreed_decision", "hypothesis", "open_question"):
        if f"`{state}`" not in all_text:
            fail(f"根拠状態の記載例が無い: {state}")
    for action in ("予約枠", "検索", "予約", "変更", "取消", "通知"):
        if action not in all_text:
            fail(f"予約サービスの共通操作が記載例に無い: {action}")
    if "```mermaid" not in cloud or not re.search(r'NODE_[A-Z]+\[.+[ぁ-んァ-ヶ一-龯]', cloud):
        fail("クラウド構成図に日本語ラベル付きノードが無い")
    required_rows = (
        (requirements, r"\| REQ-001 \|[^\n]*WL-004[^\n]*QR-005[^\n]*ADR-001[^\n]*NODE-API[^\n]*NODE-DB"),
        (workload, r"\| WL-004 \| REQ-001 \| QR-005 \|[^\n]*ADR-001[^\n]*NODE-API[^\n]*NODE-DB"),
        (quality, r"\| QR-005 \| REQ-001 \| WL-004 \|[^\n]*ADR-001[^\n]*NODE-API[^\n]*NODE-DB"),
        (cloud, r"\| REQ-001 \| WL-004 \| QR-005 \| ADR-001 \| NODE-API、NODE-DB \|"),
    )
    for text, pattern in required_rows:
        if re.search(pattern, text) is None:
            fail("REQ-001→WL-004→QR-005→ADR-001→表示ノード→検証の実行行が不足")
    for label, text in (("負荷", workload), ("品質", quality), ("クラウド", cloud)):
        if re.search(r"\| REQ-OQ-001 \| `open_question` \|[^\n]*(継続|上流)", text) is None:
            fail(f"{label}文書でREQ-OQ-001の未決状態が継続されていない")
    for token in (
        "月間活動時間100,000秒", "24万新規+3万変更+3万取消=月30万操作",
        "30万状態変更×2配送=月60万配送", "新規60万配送レコード/月、定常180万件",
        "5万操作÷100,000秒=0.5イベント/秒",
    ):
        if token not in workload:
            fail(f"利用・負荷例を同一前提で再計算できない: {token}")


def check_japanese_and_responsibility(pairs: dict[str, dict[str, str]]) -> None:
    targets = [DETAIL, CATALOG, ROOT / "README.md"]
    for slug in SLUGS:
        targets.extend((CT / pairs[slug]["template"], CT / pairs[slug]["example"]))
    for path in targets:
        text = path.read_text(encoding="utf-8")
        for relative in re.findall(r"(?<!!)\[[^]]*\]\(([^)#\s]+)(?:#[^)\s]*)?\)", text):
            if not relative.startswith(("http://", "https://", "mailto:")) and not (path.parent / relative).exists():
                fail(f"相対リンクの参照先が無い: {path}: {relative}")
        prose = human_text(text)
        for token in NAKED_ENGLISH:
            if re.search(rf"(?<![A-Za-z0-9_-]){re.escape(token)}(?![A-Za-z0-9_-])", prose, re.I):
                fail(f"日本語化対象の裸の英語が残存: {path}: {token}")
        conventional_headings = {"Write Doc", "Codex", "Claude Code", "ADR"}
        for heading in re.findall(r"(?m)^#{1,4}\s+(.+)$", prose):
            if heading.strip() not in conventional_headings and not re.search(r"[ぁ-んァ-ヶ一-龯]", heading):
                fail(f"人間向け見出しが日本語でない: {path}: {heading}")
    detail = DETAIL.read_text(encoding="utf-8")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    if "現在構成を説明する" not in detail or "将来構成を比較・選定する" not in detail:
        fail("architectureとcloud-architectureの責務差がdetailに無い")
    if "現在構成" not in readme or "将来構成" not in readme:
        fail("architectureとcloud-architectureの責務差がREADMEに無い")
    audit = AUDIT.read_text(encoding="utf-8") if AUDIT.is_file() else ""
    for category in ("機械互換", "英語が通例", "日本語化", "判断保留"):
        if category not in audit:
            fail(f"日本語監査報告に分類が無い: {category}")


def check_distribution_copy() -> None:
    with tempfile.TemporaryDirectory(prefix="write-doc-content-types-") as temporary:
        copied = Path(temporary) / "content-types"
        shutil.copytree(CT, copied)
        pairs = read_pairs(copied)
        for slug in SLUGS:
            for kind in ("template", "example"):
                relative = pairs.get(slug, {}).get(kind)
                if not relative or not (copied / relative).is_file():
                    fail(f"配布コピーで型を解決できない: {slug}/{kind}")
        architecture = copied / pairs["architecture"]["template"]
        if "現在" not in architecture.read_text(encoding="utf-8"):
            fail("既存architecture型の現在構成契約が回帰した")


def check_regression_cases() -> None:
    value = json.loads(REGRESSION_CASES.read_text(encoding="utf-8"))
    for case in value["cases"]:
        actual = "reject" if display_violations(case["text"]) else "accept"
        if actual != case["expected"]:
            fail(f"表示回帰fixtureの判定不一致: {case['id']} expected={case['expected']} actual={actual}")


def main() -> int:
    pairs = read_pairs()
    check_public_registration(pairs)
    check_templates_and_examples(pairs)
    check_traceability(pairs)
    check_japanese_and_responsibility(pairs)
    check_distribution_copy()
    check_regression_cases()
    for message in failures:
        print(f"  - {message}", file=sys.stderr)
    if not failures:
        print("System-design content types: passed (4 types, Japanese, traceability, copied package)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
