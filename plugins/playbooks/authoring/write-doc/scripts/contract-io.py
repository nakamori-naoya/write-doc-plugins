#!/usr/bin/env python3
"""write-doc/write-doc 契約 v1 の入力を読み、出力を書く。**提供側だけが持つ変換層である。**

呼び出し元は CONTRACT.md の語（document_type / material / output_format /
output_directory + name / update_target / references / output_to）しか知らない。
下段の工程は別の語で動く。**その差をここで吸収する。**
外へ出すのは契約の語だけ、内へ渡すのは内部の語だけにする。

  contract-io.py check --input <入力YAMLの絶対path>
      -> **入口の hook**。scripts/validate-input.sh 経由で resolve.sh が呼ぶ。
         解決済みYAMLはまだ無いので、自分のmanifestからカタログと配布物rootを引く。
         違反はすべて [error:input-schema] へ寄せて exit 2 する。

  contract-io.py read  --config <解決済みYAML>
      -> .input を契約 schema で検査し、内部へ渡す形をJSONで出す。
         --input が渡されていない実行では {"present": false} を出して exit 0。

  contract-io.py types --config <解決済みYAML>
      -> この配布物が実装している文書型slugを1行1件で出す（カタログが正本）。

  contract-io.py write --config <解決済みYAML> --result <JSONファイル>
      -> 結果を契約 schema へ正規化し、.input.output_to の絶対pathへYAMLで書く。

失敗は [error:<code>] key=value を stderr へ出して exit 2。
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

CONTRACT = "write-doc/write-doc"
VERSION = 1
INPUT_KEYS = {
    "contract", "version", "document_type", "material", "output_format",
    "output_directory", "name", "update_target", "references", "output_to",
}
OUTPUT_FORMATS = ("markdown", "html")
TYPE_SLUG = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
CATALOG_ROW = re.compile(r"^\| \*\*[^|]+\*\* \| `([a-z0-9-]+)`", re.M)
# カタログのある内部pluginの論理名。**外部からは見えない内部の作りである。**
CATALOG_PLUGIN = "content-types"
CATALOG_RELATIVE = "references/catalog.md"


# 入口hookでは、契約固有の違反をすべて input-schema へ寄せる。
# resolve.sh は非0を一律拒否とし、診断は stderr の [error:...] key=value を読む。
STRICT_CODE = None


def fail(code, **fields):
    if STRICT_CODE is not None:
        fields.setdefault("code", code)
        code = STRICT_CODE
    detail = " ".join("{}={}".format(key, value) for key, value in sorted(fields.items()))
    print("[error:{}] {}".format(code, detail).rstrip(), file=sys.stderr)
    raise SystemExit(2)


def yq(args, stdin=None):
    try:
        result = subprocess.run(["yq", *args], input=stdin, text=True, capture_output=True, timeout=30)
    except OSError as exc:
        fail("input-invalid", reason="yq-unavailable", detail=str(exc))
    if result.returncode != 0:
        fail("input-invalid", reason="yq-failed", detail=result.stderr.strip()[:200])
    return result.stdout


def load_config(path):
    resolved = Path(path)
    if not resolved.is_absolute() or resolved.is_symlink() or not resolved.is_file():
        fail("input-file-unsafe", reason="config-path", path=str(path))
    return json.loads(yq(["-o=json", "-I=0", ".", str(resolved)]))


def text(value, code, **fields):
    if not isinstance(value, str) or not value.strip() or any(ord(ch) < 32 for ch in value):
        fail(code, **fields)
    return value


def absolute(value, code, **fields):
    """絶対pathであることだけを見て realpath へ正規化する（存在は呼び出し側で見る）。

    **祖先やfile自身の symlink は拒否しない。** 呼び出し元は入力を一時領域へ書くので、
    macOS 既定の TMPDIR（/var/folders/... は /private/var への symlink）を拒否すると、
    素直に書いた入力が必ず落ちる。resolver の入力path正規化と同じ扱いに揃える。
    """
    if not isinstance(value, str) or not value:
        fail(code, **fields)
    if not Path(value).is_absolute() or Path(value).name in {"", ".", ".."}:
        fail(code, **fields)
    return os.path.realpath(value)


def absolute_file(value, code, **fields):
    path = absolute(value, code, **fields)
    if not Path(path).is_file():
        fail(code, **fields)
    return path


def owning_package(start):
    """この配布物のpackage root。playbook自身のcomponent manifestは飛ばす。"""
    for candidate in [Path(start), *Path(start).parents]:
        for runtime in (".claude-plugin", ".codex-plugin"):
            manifest = candidate / runtime / "plugin.json"
            if not manifest.is_file():
                continue
            try:
                data = json.loads(manifest.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            harness = (data.get("metadata") or {}).get("harness") or {}
            if isinstance(harness.get("playbooks"), dict) and harness["playbooks"]:
                return candidate, harness
    return None, {}


def read_catalog(catalog):
    if not catalog.is_file():
        fail("input-invalid", reason="catalog-missing", path=str(catalog))
    slugs = CATALOG_ROW.findall(catalog.read_text(encoding="utf-8"))
    if not slugs or len(slugs) != len(set(slugs)):
        fail("input-invalid", reason="catalog-invalid", path=str(catalog))
    return slugs


def context_from_config(config):
    """解決済みYAMLがあるとき。カタログと配布物rootは deps から引く。"""
    playbook_root = config.get("playbook_root")
    if not isinstance(playbook_root, str) or not playbook_root:
        fail("input-invalid", reason="playbook-root-unknown")
    package, _ = owning_package(Path(playbook_root).parent)
    roots = {package or Path(playbook_root)}
    for dependency in (config.get("deps") or {}).values():
        if not isinstance(dependency, dict):
            continue
        for key in ("package_root", "root"):
            value = dependency.get(key)
            if isinstance(value, str) and value:
                roots.add(Path(value))
    dependency = (config.get("deps") or {}).get(CATALOG_PLUGIN)
    if not isinstance(dependency, dict) or not isinstance(dependency.get("root"), str):
        fail("input-invalid", reason="catalog-unresolved")
    return {"types": read_catalog(Path(dependency["root"]) / CATALOG_RELATIVE), "roots": roots}


def context_from_package():
    """入口hookのとき。解決済みYAMLはまだ無いので、自分のmanifestから引く。"""
    plugin_root = Path(__file__).resolve().parent.parent
    package, harness = owning_package(plugin_root.parent)
    if package is None:
        fail("input-invalid", reason="owning-package-unresolved", path=str(plugin_root))
    relative = (harness.get("internalPlugins") or {}).get(CATALOG_PLUGIN)
    if not isinstance(relative, str) or not relative:
        fail("input-invalid", reason="catalog-unresolved", package=str(package))
    return {"types": read_catalog(package / relative / CATALOG_RELATIVE), "roots": {package}}


def check_document_type(value, types):
    if not isinstance(value, str) or not TYPE_SLUG.fullmatch(value):
        fail("input-schema", field="document_type", reason="型slugの形ではない")
    if value not in types:
        fail("input-capability-unsupported", capability="types", value=value, contract=CONTRACT)
    return value


def read_input(config):
    block = config.get("input")
    if block is None:
        return {"present": False}
    return validate_payload(block, context_from_config(config))


def validate_payload(block, context):
    types = context["types"]
    if not isinstance(block, dict):
        fail("input-invalid", reason="not-mapping")
    unknown = sorted(set(block) - INPUT_KEYS)
    if unknown:
        fail("input-schema", reason="unknown-keys", keys=",".join(unknown))
    if block.get("contract") != CONTRACT or block.get("version") != VERSION:
        fail("input-contract-mismatch", contract=str(block.get("contract")),
             version=str(block.get("version")))

    document_type = None
    if "document_type" in block:
        document_type = check_document_type(block["document_type"], types)

    material = block.get("material")
    if not isinstance(material, list) or not material:
        fail("input-schema", field="material", reason="1つ以上の絶対pathの配列")
    material = [absolute_file(item, "input-schema", field="material[{}]".format(index))
                for index, item in enumerate(material)]

    output_format = block.get("output_format")
    if output_format is not None and output_format not in OUTPUT_FORMATS:
        fail("input-schema", field="output_format", reason="markdown / html")

    # 保存先は排他。新規作成は name が必須で、output_directory は任意。
    # **directory を渡さない新規作成は、利用者が設定した保存先へ保存する。**
    has_create = "name" in block or "output_directory" in block
    has_update = "update_target" in block
    if has_create and has_update:
        fail("input-schema", field="update_target",
             reason="新規作成（name）とupdate_targetは排他")
    if not has_create and not has_update:
        fail("input-schema", field="name",
             reason="nameまたはupdate_targetのどちらかが要る")

    output_directory = None
    name = None
    update_target = None
    if has_create:
        if "name" not in block:
            fail("input-schema", field="name", reason="output_directoryを渡すならnameも要る")
        name = text(block["name"], "input-schema", field="name")
        if name != os.path.basename(name) or name in {".", ".."} or "/" in name:
            fail("input-schema", field="name", reason="path区切りを含まないファイル名")
        if "output_directory" in block:
            output_directory = absolute(block["output_directory"], "input-schema", field="output_directory")
            if not Path(output_directory).is_dir():
                fail("input-schema", field="output_directory", reason="directoryが無い")
    else:
        update_target = absolute_file(block["update_target"], "input-schema", field="update_target")

    references = block.get("references", [])
    if not isinstance(references, list):
        fail("input-schema", field="references", reason="絶対pathの配列")
    forbidden = context["roots"]
    normalized_references = []
    for index, item in enumerate(references):
        field = "references[{}]".format(index)
        reference = absolute_file(item, "input-schema", field=field)
        resolved = Path(os.path.realpath(reference))
        for root in forbidden:
            boundary = Path(os.path.realpath(root))
            if resolved == boundary or boundary in resolved.parents:
                fail("input-schema", field=field,
                     reason="write-doc自身の配布物内のpathは追加指示に渡せない")
        normalized_references.append(reference)

    output_to = block.get("output_to")
    if not isinstance(output_to, str) or not output_to \
            or not Path(output_to).is_absolute() or Path(output_to).name in {"", ".", ".."}:
        fail("input-output-unwritable", reason="not-absolute", path=str(output_to))
    parent = Path(os.path.realpath(os.fspath(Path(output_to).parent)))
    if not parent.is_dir() or not os.access(parent, os.W_OK):
        fail("input-output-unwritable", reason="parent-unwritable", path=str(output_to))
    output_to = str(parent / Path(output_to).name)

    return {
        "present": True,
        "document_type": document_type,
        "material": material,
        "output_format": output_format,
        "output_directory": output_directory,
        "name": name,
        "update_target": update_target,
        "references": normalized_references,
        "output_to": output_to,
    }


def normalize_result(raw, resolved, types):
    if not isinstance(raw, dict):
        fail("output-schema", reason="not-mapping")
    status = raw.get("status")
    if status not in {"completed", "failed"}:
        fail("output-schema", field="status", reason="completed / failed")
    if status == "failed":
        return {"contract": CONTRACT, "version": VERSION, "status": "failed",
                "reason": text(raw.get("reason"), "output-schema", field="reason")}

    path = absolute_file(raw.get("path"), "output-schema", field="path")
    if resolved["update_target"] is not None and path != resolved["update_target"]:
        fail("output-schema", field="path", reason="update_targetと違うpathへ保存した")
    if resolved["name"] is not None:
        # directory は routes 設定で決まることがあるが、ファイル名は呼び出し元のものである。
        if os.path.basename(path) != resolved["name"]:
            fail("output-schema", field="path", reason="nameと違うファイル名で保存した")
        if resolved["output_directory"] is not None \
                and path != os.path.join(resolved["output_directory"], resolved["name"]):
            fail("output-schema", field="path", reason="output_directoryの外へ保存した")

    document_type = check_document_type(raw.get("document_type"), types)
    if resolved["document_type"] is not None and document_type != resolved["document_type"]:
        fail("output-schema", field="document_type", reason="指定された型を選び直した")

    output_format = raw.get("output_format")
    if output_format not in OUTPUT_FORMATS:
        fail("output-schema", field="output_format", reason="markdown / html")
    if resolved["output_format"] is not None and output_format != resolved["output_format"]:
        fail("output-schema", field="output_format", reason="指定された媒体を使わなかった")

    return {"contract": CONTRACT, "version": VERSION, "status": "completed",
            "path": path, "document_type": document_type, "output_format": output_format}


def check_input_file(path):
    """入口hook。入力YAMLだけを見て、契約固有のschemaを検査する。"""
    global STRICT_CODE
    STRICT_CODE = "input-schema"
    resolved = Path(path)
    if not resolved.is_absolute():
        fail("input-file", reason="not-absolute", path=str(path))
    resolved = Path(os.path.realpath(os.fspath(resolved)))
    if not resolved.is_file():
        fail("input-file", reason="not-file", path=str(path))
    payload = json.loads(yq(["-o=json", "-I=0", ".", str(resolved)]))
    validate_payload(payload, context_from_package())
    return 0


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    checker = sub.add_parser("check")
    checker.add_argument("--input", required=True)
    reader = sub.add_parser("read")
    reader.add_argument("--config", required=True)
    lister = sub.add_parser("types")
    lister.add_argument("--config", required=True)
    writer = sub.add_parser("write")
    writer.add_argument("--config", required=True)
    writer.add_argument("--result", required=True)
    args = parser.parse_args()

    if args.command == "check":
        return check_input_file(args.input)

    config = load_config(args.config)
    if args.command == "types":
        for slug in context_from_config(config)["types"]:
            print(slug)
        return 0
    if args.command == "read":
        print(json.dumps(read_input(config), ensure_ascii=False))
        return 0

    resolved = read_input(config)
    if not resolved["present"]:
        fail("input-invalid", reason="output_to-unknown")
    result_path = Path(args.result)
    if not result_path.is_absolute() or result_path.is_symlink() or not result_path.is_file():
        fail("input-file-unsafe", reason="result-path", path=args.result)
    payload = normalize_result(json.loads(result_path.read_text(encoding="utf-8")),
                               resolved, context_from_config(config)["types"])
    target = Path(resolved["output_to"])
    document = yq(["-P"], stdin=json.dumps(payload, ensure_ascii=False))
    handle = os.open(str(target), os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(handle, "w", encoding="utf-8") as stream:
        stream.write(document)
    print(str(target))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print("[error:output-schema] detail={}".format(exc), file=sys.stderr)
        raise SystemExit(2)
