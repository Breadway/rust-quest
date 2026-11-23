# Rust Quest

A data-driven rebuild of the Learn Rust Easily curriculum, plus a course written
for the bread ecosystem. Lessons live in `assets/curriculum.json`; adding more is
an edit to that file, not a code change.

Current content: 12 courses, 43 modules, 139 lessons, 891 questions.

## Features

- Lessons rendered as Markdown with syntax-highlighted Rust code.
- Quizzes with multiple choice, true/false, fill-in-the-blank, code output and
  code ordering questions, plus an explanation after each answer.
- XP, coins, levels, daily streak, daily review, per-module checkpoints and
  achievements.
- Adaptive layout: bottom navigation on phones, navigation rail and a four-column
  grid on desktop.
- Progress hardening: previous-save backup, corrupt-save recovery, clipboard
  export/import, and two-way sync to Hestia over WebDAV.
- Bread Ecosystem course, always unlocked: 8 modules and 15 lessons covering
  events and serde wire types, glob subscriptions, shared state, supervised
  tokio tasks, error context, socket IPC, Lua hosting, workspaces and CLIs, axum
  and sqlx services, diagnostics and scrubbing, release channels, and BOS/Lua.

## Layout

```
lib/models.dart          JSON model, parent links, lesson lookup
lib/app_state.dart       progress, rewards, unlocks, achievements, backup, sync config
lib/sync_service.dart    WebDAV sync, last-write-wins
lib/theme.dart           palette and markdown styles
lib/screens/             home, course, lesson, quiz, profile
lib/widgets/             code block, syntax highlighting, markdown pre builder
assets/curriculum.json   the content
tools/check_curriculum.py schema/consistency checker
```

## Adding lessons

1. Append an object to a module's `lessons` list in
   `assets/curriculum.json`:

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

2. Validate and test:

```bash
python3 tools/check_curriculum.py
flutter test
```

3. Build and install.

Course order in the file is display order. A course unlocks when the previous
course is complete, unless it sets `"unlockedByDefault": true` (the Bread
Ecosystem course does).

## Build

Android release (signed with `~/.keystores/rustquest-release.jks` via the
git-ignored `android/key.properties`):

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Linux desktop (needs GTK3 development headers, clang, cmake, ninja):

```bash
flutter build linux --release
./build/linux/x64/release/bundle/rust_quest
```

## Progress and sync

The save is one JSON document containing completed lessons, best scores,
projects, checkpoints, XP, coins, streak, reviews, achievements and
`updatedAt`. It is stored through `shared_preferences`:

- Android: private app preferences.
- Linux: `~/.local/share/dev.breadway.rust_quest/shared_preferences.json`.

Safety:

- Every save keeps the previous good save under a backup key; loading falls back
  to it if the current save is unreadable, and a corrupt copy is preserved for
  inspection.
- Profile has **Copy** and **Restore** for the whole save as JSON.
- Sync uploads a second copy to Hestia.

Sync uses Nextcloud WebDAV (Nextcloud already runs on Hestia, so no new service
or port):

- URL: `https://nextcloud.breadway.dev/remote.php/dav/files/breadway/RustQuest/`
- User: `breadway`
- Password: a Nextcloud app password (Settings, Security). It is stored in the
  app's private preferences only and can be revoked there.
- File: `RustQuest/progress.json`.

Configure it in Profile, **Sync with Hestia**. Behaviour:

- Pulls newer remote progress on launch.
- Pushes a few seconds after any change.
- Conflicts are last-write-wins by `updatedAt`, so finish a session on one device
  before switching if both were offline.

The current progress was reset to zero and that reset was synced, so both the
phone and the desktop start clean.

## Tests

```bash
flutter test      # curriculum integrity, unlocks, rewards, reload, lesson render
flutter analyze
```

## Provenance and differences

The base curriculum was extracted from the 1.1.0 AOT snapshot of
`com.minthihakyaw.learnrust` (11 courses, 34 modules, 123 lessons, 810
questions). This app adds one bonus lesson and the Bread Ecosystem course.

Deliberate differences from the original: no farm, energy or in-app purchases;
checkpoints are generated from a module's questions (10 mixed, 80% to pass);
course unlocks follow the previous course; and the farm-only achievements are
omitted.
