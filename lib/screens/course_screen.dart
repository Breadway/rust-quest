import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'lesson_screen.dart';
import 'quiz_screen.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key, required this.state, required this.course});

  final AppState state;
  final Course course;

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  AppState get state => widget.state;
  Course get course => widget.course;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final done = state.completedInCourse(course);
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Text(course.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    course.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: MediaQuery.sizeOf(context).width < 900
              ? null
              : const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Enter continue · N next lesson · P previous · Esc back',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kMuted, fontSize: 11),
                    ),
                  ),
                ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                primary: false,
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                children: [
                  _header(done),
                  const SizedBox(height: 22),
                  for (final module in course.modules)
                    ..._module(context, module),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(int done) {
    final progress = course.lessonCount == 0 ? 0.0 : done / course.lessonCount;
    final complete = state.isCourseComplete(course);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.subtitle,
            style: const TextStyle(color: kMuted, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: kSurfaceAlt,
              color: complete ? kGood : kPrimary,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            complete
                ? 'Course complete · $done / ${course.lessonCount} lessons'
                : '$done / ${course.lessonCount} lessons · ${(progress * 100).round()}% complete',
            style: const TextStyle(color: kMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  List<Widget> _module(BuildContext context, Module module) {
    final moduleDone = module.lessons
        .where((l) => state.isLessonCompleted(l.id))
        .length;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Row(
          children: [
            Text(module.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                module.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$moduleDone / ${module.lessons.length}',
              style: const TextStyle(color: kMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      for (final lesson in module.lessons) _lessonTile(context, lesson),
      _checkpointTile(context, module),
      const SizedBox(height: 18),
    ];
  }

  Widget _lessonTile(BuildContext context, Lesson lesson) {
    final done = state.isLessonCompleted(lesson.id);
    final unlocked = state.isLessonUnlocked(lesson);
    final best = state.bestScore(lesson.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!unlocked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Finish the earlier lessons first')),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LessonScreen(state: state, lesson: lesson),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: done ? kGood.withValues(alpha: .35) : kSurfaceAlt,
            ),
          ),
          child: Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : (unlocked
                          ? Icons.play_circle_fill_rounded
                          : Icons.lock_rounded),
                color: done
                    ? kGood
                    : (unlocked ? kPrimary : kMuted.withValues(alpha: .6)),
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: unlocked || done ? kText : kMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unlocked || done
                          ? '+${lesson.xp} XP · +${lesson.coins} 🪙'
                                '${lesson.project != null ? ' · 🔧 project' : ''}'
                          : 'Locked',
                      style: TextStyle(
                        color: unlocked
                            ? kMuted
                            : kMuted.withValues(alpha: .55),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (done)
                Text(
                  '$best%',
                  style: TextStyle(
                    color: best == 100 ? kGold : kMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkpointTile(BuildContext context, Module module) {
    final passed = state.isCheckpointPassed(module);
    final unlocked = state.isCheckpointUnlocked(module);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: unlocked ? () => _openCheckpoint(context, module) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: passed
                  ? kGood.withValues(alpha: .35)
                  : (unlocked ? kGold.withValues(alpha: .45) : kSurfaceAlt),
            ),
          ),
          child: Row(
            children: [
              Icon(
                passed
                    ? Icons.verified_rounded
                    : (unlocked ? Icons.flag_rounded : Icons.lock_rounded),
                color: passed
                    ? kGood
                    : (unlocked ? kGold : kMuted.withValues(alpha: .6)),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checkpoint: ${module.title}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: passed || unlocked ? kText : kMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      passed
                          ? 'Passed'
                          : (unlocked
                                ? '10 mixed questions · 80% to pass · +50 XP · +40 🪙'
                                : 'Finish all lessons in this module to unlock'),
                      style: const TextStyle(color: kMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (unlocked && !passed)
                const Icon(Icons.chevron_right_rounded, color: kMuted),
            ],
          ),
        ),
      ),
    );
  }

  Lesson? _currentLesson() {
    final last = state.lastLessonId;
    if (last == null) return null;
    for (final lesson in course.allLessons) {
      if (lesson.id == last) return lesson;
    }
    return null;
  }

  Lesson _continueLesson() {
    final current = _currentLesson();
    if (current != null && state.isLessonUnlocked(current)) {
      if (!state.isLessonCompleted(current.id)) return current;
      final lessons = course.allLessons;
      final index = lessons.indexOf(current);
      if (index >= 0 && index + 1 < lessons.length) {
        final next = lessons[index + 1];
        if (state.isLessonUnlocked(next)) return next;
      }
      return current;
    }
    for (final lesson in course.allLessons) {
      if (state.isLessonUnlocked(lesson) &&
          !state.isLessonCompleted(lesson.id)) {
        return lesson;
      }
    }
    return course.allLessons.firstWhere(
      state.isLessonUnlocked,
      orElse: () => course.allLessons.first,
    );
  }

  void _openLesson(Lesson lesson) {
    if (!state.isLessonUnlocked(lesson)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finish the earlier lessons first')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonScreen(state: state, lesson: lesson),
      ),
    );
  }

  void _goRelative(int delta) {
    final lessons = course.allLessons;
    final current = _currentLesson();
    var index = current == null
        ? (delta > 0 ? -1 : lessons.length)
        : lessons.indexOf(current);
    index += delta;
    if (index < 0 || index >= lessons.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delta > 0 ? 'No next lesson in this course' : 'No previous lesson',
          ),
        ),
      );
      return;
    }
    _openLesson(lessons[index]);
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return true;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _openLesson(_continueLesson());
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
    return false;
  }

  Future<void> _openCheckpoint(BuildContext context, Module module) async {
    final questions = state.checkpointQuestions(module);
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This module has no questions yet')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          title: 'Checkpoint',
          subtitle: '${module.title} · 80% to pass',
          questions: questions,
          onSubmit: (correct, total, results) => state.submitCheckpoint(
            module,
            questions,
            correct,
            total,
            results,
          ),
        ),
      ),
    );
  }
}
