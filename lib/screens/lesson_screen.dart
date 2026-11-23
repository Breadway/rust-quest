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

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key, required this.state, required this.lesson});

  final AppState state;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final done = state.isLessonCompleted(lesson.id);
        final best = state.bestScore(lesson.id);
        return Scaffold(
          appBar: AppBar(title: Text(lesson.module?.title ?? 'Lesson')),
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
                  child: FilledButton(
                    onPressed: () => _startQuiz(context),
                    child: Text(done ? 'Retake quiz' : 'Start quiz'),
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

  Future<void> _startQuiz(BuildContext context) async {
    if (lesson.questions.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          title: 'Quiz',
          subtitle: lesson.title,
          questions: lesson.questions,
          onSubmit: (correct, total) =>
              state.submitLesson(lesson, correct, total),
        ),
      ),
    );
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
