import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust_quest/app_state.dart';
import 'package:rust_quest/models.dart';
import 'package:rust_quest/screens/lesson_screen.dart';
import 'package:rust_quest/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Curriculum> loadCurriculum() async {
  final source = await rootBundle.loadString('assets/curriculum.json');
  return Curriculum.fromJsonString(source);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Curriculum sharedCurriculum;
  setUpAll(() async {
    sharedCurriculum = await loadCurriculum();
  });

  test('curriculum parses with unique ids and complete lessons', () async {
    final curriculum = await loadCurriculum();
    expect(curriculum.courses.length, 12);
    expect(curriculum.courses.first.id, 'basics');
    expect(curriculum.courses[1].id, 'ownership');
    expect(curriculum.moduleCount, greaterThanOrEqualTo(34));
    expect(curriculum.lessonCount, greaterThanOrEqualTo(139));
    expect(curriculum.questionCount, greaterThanOrEqualTo(891));

    final lessonIds = <String>{};
    for (final course in curriculum.courses) {
      expect(course.modules, isNotEmpty);
      for (final module in course.modules) {
        expect(module.lessons, isNotEmpty);
        for (final lesson in module.lessons) {
          expect(lessonIds.add(lesson.id), isTrue, reason: 'duplicate ${lesson.id}');
          expect(lesson.body, isNotEmpty);
          expect(lesson.questions, isNotEmpty);
          expect(lesson.xp, greaterThan(0));
          for (final q in lesson.questions) {
            expect(q.prompt, isNotEmpty);
            switch (q.type) {
              case 'multipleChoice':
              case 'codeOutput':
                expect(q.options.length, greaterThan(1));
                expect(q.answerIndex, inInclusiveRange(0, q.options.length - 1));
              case 'fillBlank':
                expect(q.answers, isNotEmpty);
              case 'codeOrder':
                expect(q.lines.length, greaterThan(1));
            }
          }
        }
      }
    }
  });

  test('course unlocking follows completion of the previous course', () async {
    SharedPreferences.setMockInitialValues({});
    final curriculum = await loadCurriculum();
    final state = await AppState.load(curriculum);

    final basics = curriculum.courses.first;
    final second = curriculum.courses[1];
    expect(state.isCourseUnlocked(basics), isTrue);
    expect(state.isCourseUnlocked(second), isFalse);
    final bread = curriculum.courseById['bread']!;
    expect(bread.unlockedByDefault, isTrue);
    expect(state.isCourseUnlocked(bread), isTrue);

    for (final lesson in basics.allLessons) {
      await state.submitLesson(lesson, lesson.questions.length, lesson.questions.length);
    }
    for (final module in basics.modules) {
      await state.submitCheckpoint(module, 10, 10);
    }

    expect(state.isCourseComplete(basics), isTrue);
    expect(state.isCourseUnlocked(second), isTrue);
  });

  test('lesson rewards are granted once and unlock the next lesson', () async {
    SharedPreferences.setMockInitialValues({});
    final curriculum = await loadCurriculum();
    final state = await AppState.load(curriculum);
    final lessons = curriculum.courses.first.allLessons;
    final first = lessons[0];
    final second = lessons[1];

    expect(state.isLessonUnlocked(second), isFalse);
    final result = await state.submitLesson(first, first.questions.length, first.questions.length);
    expect(result.firstCompletion, isTrue);
    expect(state.xp, first.xp);
    expect(state.coins, first.coins);
    expect(state.isLessonUnlocked(second), isTrue);

    final retake = await state.submitLesson(first, 0, first.questions.length);
    expect(retake.firstCompletion, isFalse);
    expect(state.xp, first.xp, reason: 'retakes must not award XP again');
  });

  test('progress survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load(sharedCurriculum);
    final lesson = sharedCurriculum.courses.first.allLessons.first;
    await state.submitLesson(lesson, lesson.questions.length, lesson.questions.length);

    final reloaded = await AppState.load(sharedCurriculum);
    expect(reloaded.completedLessons, contains(lesson.id));
    expect(reloaded.xp, lesson.xp);
  });

  testWidgets('lesson screen renders markdown and the quiz button',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load(sharedCurriculum);
    final lesson = sharedCurriculum.courses.first.allLessons.first;

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: LessonScreen(state: state, lesson: lesson),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text(lesson.title), findsOneWidget);
    expect(find.text('Start quiz'), findsOneWidget);
    expect(find.byType(HighlightView), findsWidgets);
  });
}
