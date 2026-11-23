import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'lesson_screen.dart';
import 'quiz_screen.dart';

class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key, required this.state, required this.course});

  final AppState state;
  final Course course;

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
          onSubmit: (correct, total) =>
              state.submitCheckpoint(module, correct, total),
        ),
      ),
    );
  }
}
