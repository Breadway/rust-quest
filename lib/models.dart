import 'dart:convert';

/// Data model for the curriculum stored in `assets/curriculum.json`.
///
/// The JSON is the single source of truth: adding a lesson means appending an
/// object to a module's `lessons` list. Nothing in the app is generated from
/// the lesson ids, so new content works without code changes.

class Question {
  final String type;
  final String prompt;
  final String explanation;
  final List<String> options;
  final int answerIndex;
  final bool answerBool;
  final List<String> answers;
  final List<String> lines;
  final String code;

  const Question({
    required this.type,
    required this.prompt,
    required this.explanation,
    this.options = const [],
    this.answerIndex = 0,
    this.answerBool = false,
    this.answers = const [],
    this.lines = const [],
    this.code = '',
  });

  factory Question.fromJson(Map<String, dynamic> j) {
    final type = j['type'] as String? ?? 'multipleChoice';
    final rawAnswer = j['answer'];
    final isIndex = type == 'multipleChoice' || type == 'codeOutput';
    return Question(
      type: type,
      prompt: j['prompt'] as String? ?? '',
      explanation: j['explanation'] as String? ?? '',
      options: (j['options'] as List?)?.cast<String>() ?? const [],
      answerIndex: isIndex && rawAnswer is num ? rawAnswer.toInt() : 0,
      answerBool: type == 'trueFalse' && rawAnswer == true,
      answers: (j['answers'] as List?)?.cast<String>() ?? const [],
      lines: (j['lines'] as List?)?.cast<String>() ?? const [],
      code: j['code'] as String? ?? '',
    );
  }

  bool get hasOptions => options.isNotEmpty;

  /// True when [input] is an accepted answer for a fillBlank question.
  bool accepts(String input) {
    final normalized = _normalize(input);
    return answers.any((a) => _normalize(a) == normalized);
  }

  static String _normalize(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll('`', '')
      .replaceAll('"', '')
      .replaceAll("'", '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

class MiniProject {
  final String title;
  final String description;
  final String starterCode;

  const MiniProject({
    required this.title,
    required this.description,
    required this.starterCode,
  });

  factory MiniProject.fromJson(Map<String, dynamic> j) => MiniProject(
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    starterCode: j['starterCode'] as String? ?? '',
  );
}

class Lesson {
  final String id;
  final String title;
  final String body;
  final int xp;
  final int coins;
  final MiniProject? project;
  final List<Question> questions;

  Module? module;
  Course? course;

  Lesson({
    required this.id,
    required this.title,
    required this.body,
    required this.xp,
    required this.coins,
    required this.project,
    required this.questions,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String? ?? '',
    xp: (j['xp'] as num?)?.toInt() ?? 30,
    coins: (j['coins'] as num?)?.toInt() ?? 25,
    project: j['project'] == null
        ? null
        : MiniProject.fromJson((j['project'] as Map).cast<String, dynamic>()),
    questions: ((j['questions'] as List?) ?? const [])
        .map((q) => Question.fromJson((q as Map).cast<String, dynamic>()))
        .toList(),
  );

  /// Position of this lesson inside its course (0-based), used for unlocking.
  int get courseIndex => course?.allLessons.indexOf(this) ?? 0;
}

class Module {
  final String id;
  final String title;
  final String icon;
  final List<Lesson> lessons;

  Course? course;

  Module({
    required this.id,
    required this.title,
    required this.icon,
    required this.lessons,
  });

  factory Module.fromJson(Map<String, dynamic> j) => Module(
    id: j['id'] as String,
    title: j['title'] as String,
    icon: j['icon'] as String? ?? '',
    lessons: ((j['lessons'] as List?) ?? const [])
        .map((l) => Lesson.fromJson((l as Map).cast<String, dynamic>()))
        .toList(),
  );

  /// Identifier used for checkpoint progress, unique across courses.
  String get checkpointKey => '${course?.id ?? '?'}/$id';

  List<Question> get questions => [for (final l in lessons) ...l.questions];
}

class Course {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final bool unlockedByDefault;
  final List<Module> modules;

  Course({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.unlockedByDefault,
    required this.modules,
  });

  factory Course.fromJson(Map<String, dynamic> j) => Course(
    id: j['id'] as String,
    title: j['title'] as String,
    subtitle: j['subtitle'] as String? ?? '',
    icon: j['icon'] as String? ?? '',
    unlockedByDefault: j['unlockedByDefault'] as bool? ?? false,
    modules: ((j['modules'] as List?) ?? const [])
        .map((m) => Module.fromJson((m as Map).cast<String, dynamic>()))
        .toList(),
  );

  List<Lesson> get allLessons => [for (final m in modules) ...m.lessons];

  int get lessonCount => allLessons.length;
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String? ?? '',
    icon: j['icon'] as String? ?? '🏆',
  );
}

class Curriculum {
  final List<Course> courses;
  final List<Achievement> achievements;
  final Map<String, Lesson> lessonById = {};
  final Map<String, Module> moduleById = {};
  final Map<String, Course> courseById = {};

  Curriculum({required this.courses, required this.achievements}) {
    for (final c in courses) {
      courseById[c.id] = c;
      for (final m in c.modules) {
        m.course = c;
        moduleById['${c.id}/${m.id}'] = m;
        for (final l in m.lessons) {
          l.module = m;
          l.course = c;
          lessonById[l.id] = l;
        }
      }
    }
  }

  factory Curriculum.fromJsonString(String source) {
    final root = (jsonDecode(source) as Map).cast<String, dynamic>();
    final courses = ((root['courses'] as List?) ?? const [])
        .map((c) => Course.fromJson((c as Map).cast<String, dynamic>()))
        .toList();
    final achievements = ((root['achievements'] as List?) ?? const [])
        .map((a) => Achievement.fromJson((a as Map).cast<String, dynamic>()))
        .toList();
    return Curriculum(courses: courses, achievements: achievements);
  }

  int get moduleCount => courses.fold(0, (n, c) => n + c.modules.length);
  int get lessonCount => courses.fold(0, (n, c) => n + c.lessonCount);
  int get questionCount => courses.fold(
    0,
    (n, c) =>
        n +
        c.modules.fold(
          0,
          (m, mod) =>
              m + mod.lessons.fold(0, (l, les) => l + les.questions.length),
        ),
  );
}
