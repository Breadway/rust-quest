import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'course_screen.dart';
import 'lesson_screen.dart';
import 'quiz_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppState get state => widget.state;

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

  void _openSearch() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => SearchScreen(state: state)));
  }

  void _openCourse() {
    final last = state.lastLessonId;
    final lesson = last == null ? null : state.curriculum.lessonById[last];
    if (lesson != null) {
      var target = lesson;
      if (state.isLessonCompleted(lesson.id)) {
        final lessons = lesson.course?.allLessons ?? const <Lesson>[];
        final index = lessons.indexOf(lesson);
        if (index >= 0 &&
            index + 1 < lessons.length &&
            state.isLessonUnlocked(lessons[index + 1])) {
          target = lessons[index + 1];
        }
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LessonScreen(state: state, lesson: target),
        ),
      );
      return;
    }
    final course = state.curriculum.courses.firstWhere(
      state.isCourseUnlocked,
      orElse: () => state.curriculum.courses.first,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseScreen(state: state, course: course),
      ),
    );
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _openCourse();
      return true;
    }
    if (key == LogicalKeyboardKey.slash) {
      _openSearch();
      return true;
    }
    if (key == LogicalKeyboardKey.keyR && state.reviewAvailable) {
      _openReview(context);
      return true;
    }
    if (key == LogicalKeyboardKey.keyP) {
      _openPractice(context);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final courses = state.curriculum.courses;
        final lastLesson = state.lastLessonId == null
            ? null
            : state.curriculum.lessonById[state.lastLessonId!];
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: ListView(
                primary: false,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                children: [
                  _header(context),
                  const SizedBox(height: 18),
                  _levelCard(),
                  if (lastLesson != null) ...[
                    const SizedBox(height: 12),
                    _resumeCard(context, lastLesson),
                  ],
                  const SizedBox(height: 12),
                  _reviewCard(context),
                  const SizedBox(height: 12),
                  _goalCard(),
                  const SizedBox(height: 12),
                  _practiceCard(context),
                  const SizedBox(height: 24),
                  const Text(
                    'Topics',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1000
                          ? 4
                          : constraints.maxWidth >= 720
                          ? 3
                          : 2;
                      return GridView.builder(
                        primary: false,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: courses.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 200,
                        ),
                        itemBuilder: (context, i) =>
                            _CourseCard(state: state, course: courses[i]),
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  Center(
                    child: Text(
                      '${state.curriculum.lessonCount} lessons · '
                      '${state.curriculum.moduleCount} modules · '
                      '${state.curriculum.questionCount} questions\n'
                      'Curriculum lives in assets/curriculum.json',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kMuted,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Rust Quest',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 6),
        const Text('🦀', style: TextStyle(fontSize: 24)),
        const Spacer(),
        IconButton(
          tooltip: 'Search',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => SearchScreen(state: state))),
          icon: const Icon(Icons.search, color: kMuted),
        ),
        _StatChip(icon: '🔥', value: '${state.streak}'),
        const SizedBox(width: 8),
        _StatChip(icon: '🪙', value: '${state.coins}'),
      ],
    );
  }

  Widget _resumeCard(BuildContext context, Lesson lesson) {
    final done = state.isLessonCompleted(lesson.id);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonScreen(state: state, lesson: lesson),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kGood.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.play_circle_fill, color: kPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done ? 'Review this lesson' : 'Continue where you left off',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lesson.title,
                    style: const TextStyle(color: kMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kMuted),
          ],
        ),
      ),
    );
  }

  Widget _goalCard() {
    final progress = state.goalProgress;
    final done = state.todayQuestions >= state.dailyGoal;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kSurfaceAlt),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.flag_outlined,
            color: done ? kGood : kGold,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Today's goal",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${state.todayQuestions} / ${state.dailyGoal}',
                      style: const TextStyle(color: kMuted, fontSize: 11.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: kSurfaceAlt,
                    color: done ? kGood : kGold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _practiceCard(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openPractice(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kSurfaceAlt),
        ),
        child: Row(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practice',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Timed mixed questions, or drill your weak spots',
                    style: TextStyle(color: kMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kMuted),
          ],
        ),
      ),
    );
  }

  Future<void> _openPractice(BuildContext context) async {
    var count = 10;
    var weakOnly = false;
    final start = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: kSurface,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Practice',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'No XP, but answers feed your spaced repetition and mastery stats.',
                style: TextStyle(color: kMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'Questions',
                style: TextStyle(color: kMuted, fontSize: 11.5),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final n in [10, 20])
                    ChoiceChip(
                      label: Text('$n'),
                      selected: count == n,
                      onSelected: (_) => setSt(() => count = n),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Weak spots only'),
                subtitle: Text(
                  '${state.weakQuestions(limit: 500).length} questions answered wrong',
                  style: const TextStyle(color: kMuted, fontSize: 11),
                ),
                value: weakOnly,
                onChanged: (v) => setSt(() => weakOnly = v),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Start $count questions · ${count == 20 ? '10' : '5'} min',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (start != true || !context.mounted) return;
    final questions = state.practiceQuestions(count: count, weakOnly: weakOnly);
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No questions available yet')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          title: 'Practice',
          subtitle: weakOnly ? 'weak spots' : 'all topics',
          questions: questions,
          timeLimit: Duration(minutes: count == 20 ? 10 : 5),
          onSubmit: (correct, total, results) =>
              state.submitPractice(questions, correct, total, results),
        ),
      ),
    );
  }

  Widget _levelCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Level ${state.level}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${state.xp} XP total',
                style: const TextStyle(color: kMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: state.xpIntoLevel / 100,
              minHeight: 11,
              backgroundColor: kSurfaceAlt,
              color: kGold,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${state.xpIntoLevel} / 100 XP to next level',
            style: const TextStyle(color: kMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(BuildContext context) {
    final available = state.reviewAvailable;
    final hasHistory = state.completedLessons.isNotEmpty;
    return Opacity(
      opacity: available ? 1 : .55,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: available ? () => _openReview(context) : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: available ? kPrimary.withValues(alpha: .55) : kSurfaceAlt,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('🔁', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Review',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      available
                          ? '5 quick questions · +25 XP · +15 coins · keeps your streak'
                          : hasHistory
                          ? 'Done for today. Come back tomorrow to keep the streak.'
                          : 'Finish your first lesson to unlock reviews.',
                      style: const TextStyle(color: kMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (available)
                const Icon(Icons.play_arrow_rounded, color: kPrimary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReview(BuildContext context) async {
    final questions = state.reviewQuestions();
    if (questions.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          title: 'Daily Review',
          subtitle: '${questions.length} questions',
          questions: questions,
          onSubmit: (correct, total, results) =>
              state.submitReview(questions, correct, total, results),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value});

  final String icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kSurfaceAlt),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.state, required this.course});

  final AppState state;
  final Course course;

  @override
  Widget build(BuildContext context) {
    final unlocked = state.isCourseUnlocked(course);
    final complete = state.isCourseComplete(course);
    final done = state.completedInCourse(course);
    final progress = course.lessonCount == 0 ? 0.0 : done / course.lessonCount;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        if (!unlocked) {
          final index = state.curriculum.courses.indexOf(course);
          final previous = index > 0
              ? state.curriculum.courses[index - 1]
              : null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                previous == null
                    ? 'Course locked'
                    : 'Finish ${previous.title} to unlock this course',
              ),
            ),
          );
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseScreen(state: state, course: course),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: complete ? kGood.withValues(alpha: .5) : kSurfaceAlt,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kSurfaceAlt,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(
                      course.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const Spacer(),
                if (complete)
                  const Icon(Icons.verified_rounded, color: kGood, size: 20)
                else if (!unlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kGold.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kGold.withValues(alpha: .5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock, size: 11, color: kGold),
                        SizedBox(width: 4),
                        Text(
                          'Locked',
                          style: TextStyle(color: kGold, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              course.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: kSurfaceAlt,
                color: complete ? kGood : kPrimary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              unlocked
                  ? '$done / ${course.lessonCount} lessons'
                  : 'Keep learning to unlock',
              style: TextStyle(
                color: unlocked ? kMuted : kGold.withValues(alpha: .8),
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
