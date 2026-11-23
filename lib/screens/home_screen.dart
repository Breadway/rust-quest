import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'course_screen.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final courses = state.curriculum.courses;
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: ListView(
                primary: false,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                children: [
                  _header(),
                  const SizedBox(height: 18),
                  _levelCard(),
                  const SizedBox(height: 12),
                  _reviewCard(context),
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

  Widget _header() {
    return Row(
      children: [
        const Text(
          'Rust Quest',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 6),
        const Text('🦀', style: TextStyle(fontSize: 24)),
        const Spacer(),
        _StatChip(icon: '🔥', value: '${state.streak}'),
        const SizedBox(width: 8),
        _StatChip(icon: '🪙', value: '${state.coins}'),
      ],
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
          onSubmit: state.submitReview,
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
