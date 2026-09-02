#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def inside(root: Path, path: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def tracked(root: Path, path: Path) -> bool:
    rel = os.path.relpath(path, root)
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--error-unmatch", "--", rel],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.returncode == 0


def normalize_delete(root: Path, raw: str) -> tuple[Path, Path]:
    absolute = Path(os.path.abspath(raw))
    lexical = absolute.parent.resolve() / absolute.name
    if not inside(root, lexical) or lexical == root:
        raise ValueError(f"repository内のファイルではない: {raw}")
    if lexical.parts[: len((root / ".git").parts)] == (root / ".git").parts:
        raise ValueError(f".git配下は削除できない: {raw}")
    parent = lexical.parent
    if not inside(root, parent):
        raise ValueError(f"親directoryがrepository外を指す: {raw}")
    resolved = lexical if lexical.is_symlink() else lexical.resolve(strict=False)
    return lexical, resolved


def inspect(args: argparse.Namespace) -> tuple[dict, list[str]]:
    root = Path(args.repo_root).resolve()
    if not root.is_dir() or not (root / ".git").exists():
        return {}, [f"Git repositoryではない: {root}"]
    if not args.delete or not args.keep:
        return {}, ["--deleteと--keepはそれぞれ1件以上必要"]

    errors: list[str] = []
    keeps: list[Path] = []
    for raw in args.keep:
        path = Path(os.path.abspath(raw))
        if not path.exists() or path.is_dir():
            errors.append(f"保持するファイルが存在しない: {raw}")
        else:
            keeps.append(path.resolve())

    deletable: list[str] = []
    missing: list[str] = []
    seen: set[str] = set()
    for raw in args.delete:
        try:
            lexical, resolved = normalize_delete(root, raw)
        except ValueError as exc:
            errors.append(str(exc))
            continue
        key = str(lexical)
        if key in seen:
            continue
        seen.add(key)
        if resolved in keeps or lexical.resolve(strict=False) in keeps:
            errors.append(f"保持対象と一致する: {lexical}")
        elif not lexical.exists() and not lexical.is_symlink():
            missing.append(key)
        elif lexical.is_dir():
            errors.append(f"directoryは削除できない: {lexical}")
        elif tracked(root, lexical):
            errors.append(f"Git追跡中のファイルは削除できない: {lexical}")
        else:
            deletable.append(key)

    report = {
        "repository": str(root),
        "deletable": deletable,
        "missing": missing,
        "preserved": [str(path) for path in keeps],
    }
    return report, errors


def prune(root: Path, start: Path) -> None:
    current = start
    while current != root and inside(root, current):
        try:
            current.rmdir()
        except OSError:
            break
        current = current.parent


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("check", "delete"))
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--delete", action="append", default=[])
    parser.add_argument("--keep", action="append", default=[])
    args = parser.parse_args()

    report, errors = inspect(args)
    if errors:
        print(json.dumps({"status": "rejected", "errors": errors}, ensure_ascii=False))
        return 2
    if args.action == "check":
        print(json.dumps({"status": "checked", **report}, ensure_ascii=False))
        return 0

    deleted: list[str] = []
    root = Path(report["repository"])
    for raw in report["deletable"]:
        path = Path(raw)
        path.unlink()
        deleted.append(raw)
        prune(root, path.parent)
    print(json.dumps({"status": "deleted", "deleted": deleted, "missing": report["missing"], "preserved": report["preserved"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
