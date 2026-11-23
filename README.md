# Rust Quest

A data-driven rebuild of the Learn Rust Easily curriculum, plus a Bread
Ecosystem course and an Advanced Rust course. Lessons live in
`assets/curriculum.json`; adding more is an edit to that file, not a code
change.

Current content: 13 courses, 49 modules, 153 lessons, 961 questions.

## Features

- Markdown lessons with syntax-highlighted Rust, quiz explanations, and a
  "further reading" reference per lesson where the original data had one.
- Quizzes: multiple choice, true/false, fill-in-the-blank, code output and
  code ordering. Ordering questions put every line on its own row; options
  with newlines keep them.
- XP, coins, levels, daily streak, daily review, module checkpoints and
  achievements.
- **Spaced repetition.** Every answer schedules the question again (1, 3, 7,
  16, 35 days; a wrong answer resets it). Daily Review pulls due questions
  first, and the mistake notebook lists the most-missed ones.
- **Practice and exam mode.** Timed mixed quizzes (10 questions in 5 minutes,
  20 in 10) across all topics or only weak spots. Practice feeds the same
  stats but awards no XP.
- **Mastery analytics.** Overall accuracy, per-course accuracy, answers
  counted, a seven-day activity chart, and questions still shaky.
- **Search, resume, notes, bookmarks.** Full-text search over titles, bodies
  and questions; a continue card; per-lesson notes; bookmarked lessons.
- **Daily goal and reminder.** A questions-per-day target, an Android local
  notification scheduled daily, and a Linux notification while the app is
  open.
- **Progress safety.** Previous-save backup, corrupt-save recovery, clipboard
  export/import, and two-way sync to Hestia over WebDAV.
- Adaptive layout: bottom navigation on phones, a navigation rail and a
  four-column grid on desktop.
- Keyboard flow for the whole path, no mouse needed to move through lessons:
  - Home: `Enter` continue, `/` search, `R` daily review, `P` practice.
  - Course: `Enter` continue, `N` next lesson, `P` previous, `Esc` back.
  - Lesson: `Enter` quiz, `N` next lesson, `P` previous, `B` bookmark,
    `Esc` back.
  - Quiz: `1-6` or `A-F` answer, `Enter` check and next; on the result screen
    `Enter` opens the next lesson. Fill-in fields autofocus, Enter submits,
    and Enter again moves on.
  - A question report button copies the prompt, type and options for filing a
    content bug.

## Layout

```
lib/models.dart           JSON model, parent links, search, book refs
lib/app_state.dart        progress, spaced repetition, analytics, notes, goals
lib/sync_service.dart     WebDAV sync, last-write-wins
lib/reminder_service.dart local notifications
lib/screens/              home, course, lesson, quiz, profile, search
lib/widgets/              code block, syntax highlighting, markdown pre builder
assets/curriculum.json    the content
tools/check_curriculum.py schema/consistency checker
tools/check_lesson_code.py compiles lesson examples
```

## Adding lessons

Append an object to a module's `lessons` list in `assets/curriculum.json`:

```json
{
  "id": "bread_unique_id",
  "title": "A new lesson",
  "xp": 50,
  "coins": 40,
  "body": "Markdown, including ```rust fences```.",
  "project": null,
  "questions": [
    {"type": "multipleChoice", "prompt": "...", "options": ["a", "b"],
     "answer": 1, "explanation": "..."},
    {"type": "trueFalse", "prompt": "...", "answer": true, "explanation": "..."},
    {"type": "fillBlank", "prompt": "Type `____`", "answers": ["word"],
     "explanation": "..."},
    {"type": "codeOutput", "prompt": "...", "code": "fn main() {}",
     "options": ["a", "b"], "answer": 0, "explanation": "..."},
    {"type": "codeOrder", "prompt": "...", "lines": ["one", "two"],
     "explanation": "..."}
  ]
}
```

Then:

```bash
python3 tools/check_curriculum.py
python3 tools/check_lesson_code.py --strict
flutter test
```

Course order in the file is display order. A course unlocks when the previous
course is complete unless it sets `"unlockedByDefault": true` (Bread Ecosystem
and Advanced Rust do).

`check_lesson_code.py` compiles every complete program and item-only snippet,
skipping deliberate error examples, and fails `--strict` on a broken program.
Fragments that depend on lesson context are reported as warnings.

## Build

Android release (signed with `~/.keystores/rustquest-release.jks` via the
git-ignored `android/key.properties`):

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Linux desktop (GTK3 headers, clang, cmake, ninja):

```bash
flutter build linux --release
./build/linux/x64/release/bundle/rust_quest
```

## Progress and sync

The save is one JSON document: completed lessons, scores, projects,
checkpoints, XP, coins, streak, reviews, achievements, per-question stats,
daily stats, notes, bookmarks, resume position, daily goal, reminder settings
and `updatedAt`. It is stored through `shared_preferences`:

- Android: private app preferences.
- Linux: `~/.local/share/dev.breadway.rust_quest/shared_preferences.json`.

Safety:

- Every save keeps the previous good save; loading falls back to it, and a
  corrupt save is preserved for inspection.
- Profile has **Copy** and **Restore** for the whole save as JSON.
- Sync uploads a second copy to Hestia.

Sync uses Nextcloud WebDAV (already running on Hestia):

- URL: `https://nextcloud.breadway.dev/remote.php/dav/files/breadway/RustQuest/`
- User: `breadway`, password: a Nextcloud app password (Settings, Security).
  It is stored only in the app's private preferences and can be revoked.
- File: `RustQuest/progress.json`.

Behaviour: pulls newer remote progress on launch, pushes a few seconds after a
change, last-write-wins by `updatedAt`.

## Reminders

Profile, Study settings: set a daily question goal, enable the reminder and
pick a time.

- Android: the plugin schedules a repeating local notification (inexact, so no
  exact-alarm permission is needed). The first enable asks for notification
  permission.
- Linux: the plugin has no scheduler, so a timer checks while the app runs and
  shows a desktop notification after the reminder time if the goal is unmet.

## Tests

```bash
flutter test
flutter analyze
```

Tests cover curriculum integrity, question keys, book refs, unlocks, rewards,
spaced repetition scheduling, persistence of progress/notes/bookmarks, search,
code-order layout, multiline options, fill-blank autofocus and Enter flow, and
lesson rendering.

## Provenance and differences

The base curriculum was extracted from the 1.1.0 AOT snapshot of
`com.minthihakyaw.learnrust` (11 courses, 34 modules, 123 lessons, 810
questions). This app adds one bonus lesson, a 15-lesson Bread Ecosystem
course, and a 14-lesson Advanced Rust course.

Deliberate differences from the original: no farm, energy or in-app purchases;
checkpoints are generated from a module's questions (10 mixed, 80% to pass);
the farm-only achievements are omitted; and the learning features above
(spaced repetition, analytics, search, notes) are new.
