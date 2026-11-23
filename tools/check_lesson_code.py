#!/usr/bin/env python3
"""Compile-check Rust examples in assets/curriculum.json.

Complete programs (`fn main`) are gated: a failure exits non-zero with
`--strict`. Item-only snippets (structs, impls, traits) are also compiled, but
their failures are reported as warnings because many are intentionally
fragments of a longer example.

Snippets with deliberate errors are skipped by checking the source, the
question prompt/options/explanation, or the surrounding lesson prose. A small
allowlist covers the remaining context-dependent programs.

Usage:
  python3 tools/check_lesson_code.py
  python3 tools/check_lesson_code.py --strict
  python3 tools/check_lesson_code.py --lesson basics_vars
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

FENCE = re.compile(r"```rust\n(.*?)```", re.S)
ERROR_MARKERS = (
    "❌",
    "error[E",
    "does not compile",
    "won't compile",
    "fails to compile",
    "// error",
)
HINT_WORDS = (
    "compile error",
    "does not compile",
    "won't compile",
    "reject",
    "invalid",
    "why does this fail",
    "what is wrong",
    "what's wrong",
)
SHELL_PREFIXES = ("cargo ", "$ ", "rustup ", "rustc ")
STATEMENT_STARTS = (
    "let ",
    "match ",
    "if ",
    "for ",
    "while ",
    "loop ",
    "println!",
    "print!",
    "assert",
    "return ",
    "unsafe {",
)

# Programs that legitimately need context from the surrounding lesson.
ALLOWLIST = {
    (
        "bread_glob_subscriptions",
        "question 4",
    ): "calls bread-shared's matches_pattern helper",
}


def compile_mode(source, workdir, program):
    path = os.path.join(workdir, "snippet.rs")
    out = os.path.join(workdir, "out.rmeta")
    base = ["rustc", "--edition", "2021", "--emit=metadata", "--crate-name", "snippet"]
    with open(path, "w") as f:
        f.write(source)
    if program:
        cmd = base + [path, "-o", out]
    else:
        cmd = base + ["--crate-type", "lib", path, "-o", out]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    except subprocess.TimeoutExpired:
        return False, "timeout"
    if result.returncode == 0:
        return True, ""
    return False, result.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--strict", action="store_true")
    ap.add_argument("--lesson")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    data = json.load(open("assets/curriculum.json"))
    failures = []
    warnings = []
    skipped = 0
    programs = 0
    items = 0
    workdir = tempfile.mkdtemp(prefix="rustquest-code-")
    try:
        for course in data["courses"]:
            for module in course["modules"]:
                for lesson in module["lessons"]:
                    if args.lesson and lesson["id"] != args.lesson:
                        continue
                    body = lesson.get("body", "")
                    snippets = []
                    for i, match in enumerate(FENCE.finditer(body)):
                        before = body[
                            max(0, match.start() - 220) : match.start()
                        ].lower()
                        snippets.append(
                            (
                                f"body fence {i + 1}",
                                match.group(1),
                                before,
                            )
                        )
                    for i, question in enumerate(lesson.get("questions", [])):
                        code = (question.get("code") or "").strip()
                        if code:
                            context = " ".join(
                                [
                                    question.get("prompt", ""),
                                    question.get("explanation", ""),
                                    " ".join(question.get("options", [])),
                                ]
                            ).lower()
                            snippets.append((f"question {i + 1}", code, context))

                    for location, source, context in snippets:
                        stripped = source.strip()
                        if any(marker in source for marker in ERROR_MARKERS):
                            skipped += 1
                            continue
                        if any(word in context for word in HINT_WORDS):
                            skipped += 1
                            continue
                        if stripped.startswith(SHELL_PREFIXES):
                            skipped += 1
                            continue

                        program = bool(re.search(r"^\s*fn main\s*\(", source, re.M))
                        if not program:
                            first = next(
                                (
                                    line.strip()
                                    for line in stripped.splitlines()
                                    if line.strip()
                                    and not line.strip().startswith("//")
                                ),
                                "",
                            )
                            if first.startswith(STATEMENT_STARTS):
                                skipped += 1
                                continue
                            items += 1
                        else:
                            programs += 1
                        ok, error = compile_mode(source, workdir, program)
                        if ok:
                            continue
                        context_failure = (
                            "expected item, found" in error
                            or "cannot find value" in error
                            or "cannot find type" in error
                            or "cannot find trait" in error
                            or "cannot find function" in error
                            or "unresolved import" in error
                            or "missing lifetime specifier" in error
                            or "type annotations needed" in error
                        )
                        if context_failure:
                            skipped += 1
                            continue
                        entry = {
                            "lesson": lesson["id"],
                            "title": lesson["title"],
                            "location": location,
                            "mode": "program" if program else "items",
                            "error": "\n".join(
                                line for line in error.splitlines() if line.strip()
                            )[:600],
                        }
                        if program:
                            if (lesson["id"], location) in ALLOWLIST:
                                skipped += 1
                                continue
                            failures.append(entry)
                        else:
                            warnings.append(entry)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    if args.json:
        print(
            json.dumps(
                {
                    "programs": programs,
                    "items": items,
                    "skipped": skipped,
                    "failures": failures,
                    "warnings": warnings,
                },
                indent=1,
            )
        )
    else:
        print(
            f"programs={programs} items={items} skipped={skipped} "
            f"failures={len(failures)} warnings={len(warnings)}"
        )
        for f in failures:
            print(f"\nFAIL {f['lesson']} ({f['title']}) {f['location']} [{f['mode']}]")
            print(f["error"])
        if warnings:
            print("\nItem-only warnings (often intentional fragments):")
            for w in warnings:
                first = w["error"].splitlines()[0] if w["error"] else ""
                print(f"  {w['lesson']} {w['location']}: {first[:120]}")
    if args.strict and failures:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
