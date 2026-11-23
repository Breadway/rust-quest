import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rust_quest/app_state.dart';
import 'package:rust_quest/models.dart';
import 'package:rust_quest/screens/lesson_screen.dart';
import 'package:rust_quest/screens/quiz_screen.dart';
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
    expect(curriculum.courses.length, 13);
    expect(curriculum.courses.first.id, 'basics');
    expect(curriculum.courses[1].id, 'ownership');
    expect(curriculum.moduleCount, greaterThanOrEqualTo(34));
    expect(curriculum.lessonCount, greaterThanOrEqualTo(153));
    expect(curriculum.questionCount, greaterThanOrEqualTo(961));

    final lessonIds = <String>{};
    for (final course in curriculum.courses) {
      expect(course.modules, isNotEmpty);
      for (final module in course.modules) {
        expect(module.lessons, isNotEmpty);
        for (final lesson in module.lessons) {
          expect(
            lessonIds.add(lesson.id),
            isTrue,
            reason: 'duplicate ${lesson.id}',
          );
          expect(lesson.body, isNotEmpty);
          expect(lesson.questions, isNotEmpty);
          expect(lesson.xp, greaterThan(0));
          for (final q in lesson.questions) {
            expect(q.prompt, isNotEmpty);
            switch (q.type) {
              case 'multipleChoice':
              case 'codeOutput':
                expect(q.options.length, greaterThan(1));
                expect(
                  q.answerIndex,
                  inInclusiveRange(0, q.options.length - 1),
                );
              case 'fillBlank':
                expect(q.answers, isNotEmpty);
              case 'codeOrder':
                expect(q.lines.length, greaterThan(1));
              case 'codeOutput':
                expect(q.code, isNotEmpty);
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
    final advanced = curriculum.courseById['advanced']!;
    expect(advanced.unlockedByDefault, isTrue);
    expect(state.isCourseUnlocked(advanced), isTrue);

    for (final lesson in basics.allLessons) {
      final n = lesson.questions.length;
      await state.submitLesson(lesson, n, n, List.filled(n, true));
    }
    for (final module in basics.modules) {
      final n = module.questions.length;
      await state.submitCheckpoint(
        module,
        module.questions,
        n,
        n,
        List.filled(n, true),
      );
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
    final n = first.questions.length;
    final result = await state.submitLesson(first, n, n, List.filled(n, true));
    expect(result.firstCompletion, isTrue);
    expect(state.xp, first.xp);
    expect(state.coins, first.coins);
    expect(state.isLessonUnlocked(second), isTrue);

    final retake = await state.submitLesson(
      first,
      0,
      first.questions.length,
      List.filled(first.questions.length, false),
    );
    expect(retake.firstCompletion, isFalse);
    expect(state.xp, first.xp, reason: 'retakes must not award XP again');
  });

  test('progress survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load(sharedCurriculum);
    final lesson = sharedCurriculum.courses.first.allLessons.first;
    final n = lesson.questions.length;
    await state.submitLesson(lesson, n, n, List.filled(n, true));

    final reloaded = await AppState.load(sharedCurriculum);
    expect(reloaded.completedLessons, contains(lesson.id));
    expect(reloaded.xp, lesson.xp);
  });

  testWidgets('code ordering puts every line on its own row', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final c = Curriculum.fromJsonString(
      '{"courses":[{"id":"c","title":"C","modules":[{"id":"m","title":"M","lessons":[{"id":"l","title":"L","body":"x","xp":1,"coins":1,"questions":[{"type":"codeOrder","prompt":"Order","lines":["first line","second line"],"explanation":"e"}]}]}]}],"achievements":[]}',
    );
    final state = await AppState.load(c);
    final question = c.courses.first.allLessons.first.questions.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: QuizScreen(
          title: 'Quiz',
          subtitle: 'test',
          questions: [question],
          onSubmit: (correct, total, results) async => const QuizResult(
            correct: 0,
            total: 1,
            passed: false,
            xpAwarded: 0,
            coinsAwarded: 0,
            firstCompletion: false,
            unlocked: [],
          ),
        ),
      ),
    );
    await tester.pump();

    final first = tester.getTopLeft(find.text('first line'));
    final second = tester.getTopLeft(find.text('second line'));
    expect(
      first.dy,
      isNot(second.dy),
      reason: 'code lines must stack vertically, not sit side by side',
    );
  });

  testWidgets('multiple choice options keep newlines', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final c = Curriculum.fromJsonString(
      '{"courses":[{"id":"c","title":"C","modules":[{"id":"m","title":"M","lessons":[{"id":"l","title":"L","body":"x","xp":1,"coins":1,"questions":[{"type":"multipleChoice","prompt":"Which prints two lines?","options":["println! only","print!\\nprint!"],"answer":0,"explanation":"e"}]}]}]}],"achievements":[]}',
    );
    final state = await AppState.load(c);
    final question = c.courses.first.allLessons.first.questions.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: QuizScreen(
          title: 'Quiz',
          subtitle: 'test',
          questions: [question],
          onSubmit: (correct, total, results) async => const QuizResult(
            correct: 0,
            total: 1,
            passed: false,
            xpAwarded: 0,
            coinsAwarded: 0,
            firstCompletion: false,
            unlocked: [],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('print!\nprint!'), findsOneWidget);
  });

  test('question keys are unique and book references load', () async {
    final curriculum = await loadCurriculum();
    final keys = <String>{};
    for (final lesson in curriculum.allLessons) {
      for (final q in lesson.questions) {
        expect(q.key, isNotEmpty);
        expect(keys.add(q.key), isTrue, reason: 'duplicate ${q.key}');
      }
    }
    final ref = curriculum.bookRefFor('basics_hello');
    expect(ref, isNotNull);
    expect(ref!.title, isNotEmpty);
    expect(ref.url, startsWith('http'));
  });

  test('answers feed spaced repetition and daily stats', () async {
    SharedPreferences.setMockInitialValues({});
    final curriculum = await loadCurriculum();
    final state = await AppState.load(curriculum);
    final lesson = curriculum.courses.first.allLessons.first;
    final n = lesson.questions.length;

    final results = List<bool>.filled(n, true)..[0] = false;
    await state.submitLesson(lesson, n - 1, n, results);

    final firstKey = lesson.questions.first.key;
    expect(state.questionStats[firstKey]!.wrong, 1);
    expect(
      state.questionStats[firstKey]!.due!.isAfter(DateTime.now().toUtc()),
      isFalse,
    );
    expect(state.todayQuestions, n);
    expect(state.dueQuestions(limit: 10), isNotEmpty);

    // Answer it correctly on the next attempt: the stage advances.
    await state.submitLesson(lesson, n, n, List.filled(n, true));
    expect(state.questionStats[firstKey]!.correct, greaterThan(0));
    expect(
      state.questionStats[firstKey]!.due!.isAfter(DateTime.now().toUtc()),
      isTrue,
    );
    expect(state.weakQuestions(limit: 10), isNotEmpty); // still has one wrong
  });

  test('notes, bookmarks and resume persist', () async {
    SharedPreferences.setMockInitialValues({});
    final curriculum = await loadCurriculum();
    final state = await AppState.load(curriculum);
    final lesson = curriculum.courses.first.allLessons.first;

    await state.setNote(lesson.id, 'remember the semicolon');
    await state.toggleBookmark(lesson.id);
    await state.setLastLesson(lesson.id);

    final reloaded = await AppState.load(curriculum);
    expect(reloaded.notes[lesson.id], 'remember the semicolon');
    expect(reloaded.bookmarks, contains(lesson.id));
    expect(reloaded.lastLessonId, lesson.id);
  });

  test('search finds titles and bodies', () async {
    final curriculum = await loadCurriculum();
    expect(curriculum.search('ownership'), isNotEmpty);
    expect(curriculum.search('async'), isNotEmpty);
    expect(curriculum.search('zzzz-not-a-topic'), isEmpty);
  });

  testWidgets('lesson screen renders markdown and the quiz button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load(sharedCurriculum);
    final lesson = sharedCurriculum.courses.first.allLessons.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: LessonScreen(state: state, lesson: lesson),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text(lesson.title), findsOneWidget);
    expect(find.text('Start quiz'), findsOneWidget);
    expect(find.byType(HighlightView), findsWidgets);
  });

  testWidgets('fill blank is focused and Enter submits then advances', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final c = Curriculum.fromJsonString(
      '{"courses":[{"id":"c","title":"C","modules":[{"id":"m","title":"M","lessons":[{"id":"l","title":"L","body":"x","xp":1,"coins":1,"questions":[{"type":"fillBlank","prompt":"fn ____()","answers":["main"],"explanation":"e"}]}]}]}],"achievements":[]}',
    );
    final state = await AppState.load(c);
    final question = c.courses.first.allLessons.first.questions.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: QuizScreen(
          title: 'Quiz',
          subtitle: 'test',
          questions: [question],
          onSubmit: (correct, total, results) async => const QuizResult(
            correct: 1,
            total: 1,
            passed: true,
            xpAwarded: 0,
            coinsAwarded: 0,
            firstCompletion: false,
            unlocked: [],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    expect(
      tester.widget<TextField>(field).focusNode!.hasFocus,
      isTrue,
      reason: 'the field should be ready for typing without a click',
    );

    await tester.enterText(field, 'main');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Done'), findsOneWidget);
  });
}
