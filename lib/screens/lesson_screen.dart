import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/code_block.dart';
import '../widgets/highlighted_code.dart';
import 'quiz_screen.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.state, required this.lesson});

  final AppState state;
  final Lesson lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  AppState get state => widget.state;
  Lesson get lesson => widget.lesson;

  final TextEditingController _notes = TextEditingController();
  final FocusNode _notesFocus = FocusNode();
  Timer? _notesTimer;

  @override
  void initState() {
    super.initState();
    _notes.text = state.notes[lesson.id] ?? '';
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) state.setLastLesson(lesson.id);
    });
  }

  @override
  void dispose() {
    _notesTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    if (_notes.text != (state.notes[lesson.id] ?? '')) {
      state.setNote(lesson.id, _notes.text);
    }
    _notes.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  void _onNotesChanged(String value) {
    _notesTimer?.cancel();
    _notesTimer = Timer(const Duration(milliseconds: 700), () {
      state.setNote(lesson.id, value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final done = state.isLessonCompleted(lesson.id);
        final best = state.bestScore(lesson.id);
        return Scaffold(
          appBar: AppBar(
            title: Text(lesson.module?.title ?? 'Lesson'),
            actions: [
              IconButton(
                tooltip: state.bookmarks.contains(lesson.id)
                    ? 'Remove bookmark'
                    : 'Bookmark this lesson',
                icon: Icon(
                  state.bookmarks.contains(lesson.id)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                ),
                onPressed: () => state.toggleBookmark(lesson.id),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                primary: false,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Row(
                    children: [
                      if (lesson.course != null)
                        Text(
                          '${lesson.course!.icon} ${lesson.course!.title}',
                          style: const TextStyle(color: kMuted, fontSize: 12),
                        ),
                      const Spacer(),
                      if (done)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: kGood.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: kGood.withValues(alpha: .5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 12,
                                color: kGood,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Completed · $best%',
                                style: const TextStyle(
                                  color: kGood,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    lesson.title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '+${lesson.xp} XP · +${lesson.coins} 🪙',
                    style: const TextStyle(color: kMuted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 18),
                  MarkdownBody(
                    data: lesson.body,
                    styleSheet: markdownStyleSheet(),
                    selectable: true,
                    builders: {'pre': HighlightedCodeBuilder()},
                  ),
                  if (lesson.project != null) ...[
                    const SizedBox(height: 22),
                    _projectCard(context, lesson.project!),
                  ],
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final extra = constraints.maxWidth > 820
                    ? (constraints.maxWidth - 820) / 2
                    : 0.0;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: extra),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (constraints.maxWidth >= 900)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            'Enter quiz · N next lesson · P previous · B bookmark · Esc back',
                            style: TextStyle(color: kMuted, fontSize: 11),
                          ),
                        ),
                      FilledButton(
                        onPressed: () => _startQuiz(context),
                        child: Text(done ? 'Retake quiz' : 'Start quiz'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _projectCard(BuildContext context, MiniProject project) {
    final projectDone = state.isProjectDone(lesson.id);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kGold.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔧', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Mini project',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (projectDone)
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: kGood),
                    SizedBox(width: 4),
                    Text('Done', style: TextStyle(color: kGood, fontSize: 11)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            project.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            project.description,
            style: const TextStyle(color: kMuted, fontSize: 13.5, height: 1.45),
          ),
          if (project.starterCode.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            CodeBlock(code: project.starterCode, copyable: true),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openPlayground(context, project),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open playground'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: projectDone
                      ? null
                      : () async {
                          final unlocked = await state.completeProject(lesson);
                          if (!context.mounted) return;
                          _showUnlocked(
                            context,
                            unlocked,
                            fallback: 'Project marked as done',
                          );
                        },
                  icon: const Icon(Icons.done_all, size: 16),
                  label: Text(projectDone ? 'Completed' : 'Mark done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPlayground(
    BuildContext context,
    MiniProject project,
  ) async {
    await Clipboard.setData(ClipboardData(text: project.starterCode));
    final unlocked = await state.markPlaygroundOpened();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starter code copied. Paste it in the playground.'),
      ),
    );
    _showUnlocked(context, unlocked);
    final uri = Uri.https('play.rust-lang.org', '/', {
      'version': 'stable',
      'mode': 'debug',
      'edition': '2021',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the playground')),
        );
      }
    }
  }

  Widget _bookCard(LessonBook book) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kGold.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📚', style: TextStyle(fontSize: 17)),
              const SizedBox(width: 8),
              const Text(
                'Further reading',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Open the reference',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: () => _openBook(context, book),
                icon: const Icon(Icons.open_in_new, color: kMuted),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(book.title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            book.chapter,
            style: const TextStyle(color: kMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Future<void> _openBook(BuildContext context, LessonBook book) async {
    final uri = Uri.tryParse(book.url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link')),
        );
      }
    }
  }

  Widget _notesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kSurfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, size: 18, color: kPrimary),
              const SizedBox(width: 8),
              const Text(
                'Your notes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              const Text(
                'Saved automatically',
                style: TextStyle(color: kMuted, fontSize: 10.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            focusNode: _notesFocus,
            onChanged: _onNotesChanged,
            minLines: 3,
            maxLines: 8,
            style: const TextStyle(fontSize: 13.5, height: 1.45),
            decoration: InputDecoration(
              hintText: 'Write anything you want to remember about this lesson',
              filled: true,
              fillColor: kSurfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Lesson? get _nextLesson {
    final lessons = lesson.course?.allLessons ?? const <Lesson>[];
    final index = lessons.indexOf(lesson);
    if (index < 0 || index + 1 >= lessons.length) return null;
    return lessons[index + 1];
  }

  Lesson? get _previousLesson {
    final lessons = lesson.course?.allLessons ?? const <Lesson>[];
    final index = lessons.indexOf(lesson);
    if (index <= 0) return null;
    return lessons[index - 1];
  }

  void _openLesson(Lesson target, {bool replace = false}) {
    if (!state.isLessonUnlocked(target)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish the earlier lessons first')),
      );
      return;
    }
    final route = MaterialPageRoute<void>(
      builder: (_) => LessonScreen(state: state, lesson: target),
    );
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void _goRelative(int delta) {
    final target = delta > 0 ? _nextLesson : _previousLesson;
    if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delta > 0 ? 'This is the last lesson' : 'This is the first lesson',
          ),
        ),
      );
      return;
    }
    _openLesson(target, replace: true);
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final key = event.logicalKey;
    if (_notesFocus.hasFocus) {
      if (key == LogicalKeyboardKey.escape) {
        _notesFocus.unfocus();
        return true;
      }
      return false;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return true;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _startQuiz(context);
      return true;
    }
    if (key == LogicalKeyboardKey.keyN) {
      _goRelative(1);
      return true;
    }
    if (key == LogicalKeyboardKey.keyP) {
      _goRelative(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.keyB) {
      state.toggleBookmark(lesson.id);
      return true;
    }
    return false;
  }

  Future<void> _startQuiz(BuildContext context) async {
    if (lesson.questions.isEmpty) return;
    final next = _nextLesson;
    final action = await Navigator.of(context).push<QuizExit>(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          title: 'Quiz',
          subtitle: lesson.title,
          questions: lesson.questions,
          nextLessonTitle: next?.title,
          onSubmit: (correct, total, results) =>
              state.submitLesson(lesson, correct, total, results),
        ),
      ),
    );
    if (!mounted || action != QuizExit.nextLesson || next == null) return;
    _openLesson(next, replace: true);
  }

  void _showUnlocked(
    BuildContext context,
    List<Achievement> unlocked, {
    String? fallback,
  }) {
    if (!context.mounted) return;
    if (unlocked.isEmpty) {
      if (fallback != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(fallback)));
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Achievement: ${unlocked.map((a) => a.title).join(', ')}',
        ),
      ),
    );
  }
}
