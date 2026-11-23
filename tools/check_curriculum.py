#!/usr/bin/env python3
"""Validate assets/curriculum.json before building.

Usage: python3 tools/check_curriculum.py [path]

Exits non-zero with line-by-line problems when the content is malformed, so a
bad lesson fails fast instead of crashing the app on a user's phone.
"""

import json
import sys

TYPES = {"multipleChoice", "trueFalse", "fillBlank", "codeOrder", "codeOutput"}


def main(path="assets/curriculum.json"):
    data = json.load(open(path))
    errors = []
    warnings = []

    course_ids = set()
    lesson_ids = set()
    modules = lessons = questions = 0

    for c in data.get("courses", []):
        cid = c.get("id")
        if not cid:
            errors.append("course without id")
            continue
        if cid in course_ids:
            errors.append(f"duplicate course id: {cid}")
        course_ids.add(cid)
        if not c.get("title"):
            errors.append(f"course {cid}: missing title")
        module_ids = set()
        for m in c.get("modules", []):
            modules += 1
            mid = m.get("id")
            if not mid:
                errors.append(f"course {cid}: module without id")
            elif mid in module_ids:
                errors.append(f"course {cid}: duplicate module id {mid}")
            module_ids.add(mid)
            if not m.get("title"):
                errors.append(f"course {cid} module {mid}: missing title")
            if not m.get("lessons"):
                warnings.append(f"course {cid} module {mid}: no lessons")
            for l in m.get("lessons", []):
                lessons += 1
                lid = l.get("id")
                where = f"course {cid} module {mid} lesson {lid}"
                if not lid:
                    errors.append(f"course {cid} module {mid}: lesson without id")
                    continue
                if lid in lesson_ids:
                    errors.append(f"duplicate lesson id: {lid}")
                lesson_ids.add(lid)
                if not l.get("title"):
                    errors.append(f"{where}: missing title")
                if not (l.get("body") or "").strip():
                    warnings.append(f"{where}: empty body")
                if not isinstance(l.get("xp"), int) or l["xp"] < 0:
                    errors.append(f"{where}: xp must be a non-negative int")
                if not isinstance(l.get("coins"), int) or l["coins"] < 0:
                    errors.append(f"{where}: coins must be a non-negative int")
                if not l.get("questions"):
                    warnings.append(f"{where}: no questions")
                for i, q in enumerate(l.get("questions", [])):
                    questions += 1
                    qw = f"{where} question {i + 1}"
                    t = q.get("type")
                    if t not in TYPES:
                        errors.append(f"{qw}: unknown type {t!r}")
                        continue
                    if not (q.get("prompt") or "").strip():
                        errors.append(f"{qw}: missing prompt")
                    if not (q.get("explanation") or "").strip():
                        warnings.append(f"{qw}: missing explanation")
                    if t in ("multipleChoice", "codeOutput"):
                        options = q.get("options") or []
                        if len(options) < 2:
                            errors.append(f"{qw}: needs at least 2 options")
                        answer = q.get("answer")
                        if not isinstance(answer, int) or not 0 <= answer < len(
                            options
                        ):
                            errors.append(f"{qw}: answer index out of range")
                    elif t == "trueFalse":
                        if not isinstance(q.get("answer"), bool):
                            errors.append(f"{qw}: answer must be true or false")
                    elif t == "fillBlank":
                        answers = q.get("answers") or []
                        if not answers or not all(
                            isinstance(a, str) and a.strip() for a in answers
                        ):
                            errors.append(
                                f"{qw}: needs at least one non-empty accepted answer"
                            )
                    elif t == "codeOrder":
                        lines = q.get("lines") or []
                        if len(lines) < 2:
                            errors.append(f"{qw}: needs at least 2 lines")

    for a in data.get("achievements", []):
        if not a.get("id") or not a.get("title"):
            errors.append("achievement missing id or title")

    print(
        f"courses={len(course_ids)} modules={modules} lessons={lessons} questions={questions}"
    )
    for w in warnings:
        print(f"warning: {w}")
    for e in errors:
        print(f"error: {e}")
    if errors:
        print(f"\n{len(errors)} error(s)")
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
