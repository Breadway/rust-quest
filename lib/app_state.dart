import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Achievements the rebuilt app can actually track. The farm-based ones
/// (`harvest_25`, `first_harvest`) are filtered out because there is no farm.
const supportedAchievements = <String>{
  'first_lesson',
  'perfect_quiz',
  'xp_500',
  'xp_2000',
  'coins_500',
  'course_basics',
  'module_complete',
  'first_checkpoint',
  'checkpoints_5',
  'first_project',
  'projects_5',
  'streak_3',
  'streak_7',
  'first_review',
  'reviews_7',
  'playground_run',
};

class QuestionStat {
  QuestionStat();

  int seen = 0;
  int correct = 0;
  int wrong = 0;
  int stage = 0;
  DateTime? due;
  DateTime? last;

  Map<String, dynamic> toJson() => {
    'seen': seen,
    'correct': correct,
    'wrong': wrong,
    'stage': stage,
    'due': due?.toIso8601String(),
    'last': last?.toIso8601String(),
  };

  factory QuestionStat.fromJson(Map<String, dynamic> j) => QuestionStat()
    ..seen = (j['seen'] as num?)?.toInt() ?? 0
    ..correct = (j['correct'] as num?)?.toInt() ?? 0
    ..wrong = (j['wrong'] as num?)?.toInt() ?? 0
    ..stage = (j['stage'] as num?)?.toInt() ?? 0
    ..due = DateTime.tryParse(j['due'] as String? ?? '')
    ..last = DateTime.tryParse(j['last'] as String? ?? '');
}

class DayStat {
  DayStat();

  int questions = 0;
  int correct = 0;
  int seconds = 0;

  Map<String, dynamic> toJson() => {
    'questions': questions,
    'correct': correct,
    'seconds': seconds,
  };

  factory DayStat.fromJson(Map<String, dynamic> j) => DayStat()
    ..questions = (j['questions'] as num?)?.toInt() ?? 0
    ..correct = (j['correct'] as num?)?.toInt() ?? 0
    ..seconds = (j['seconds'] as num?)?.toInt() ?? 0;
}

class QuizResult {
  final int correct;
  final int total;
  final bool passed;
  final int xpAwarded;
  final int coinsAwarded;
  final bool firstCompletion;
  final List<Achievement> unlocked;

  const QuizResult({
    required this.correct,
    required this.total,
    required this.passed,
    required this.xpAwarded,
    required this.coinsAwarded,
    required this.firstCompletion,
    required this.unlocked,
  });

  int get percent => total == 0 ? 0 : ((correct / total) * 100).round();
}

class AppState extends ChangeNotifier {
  static const _storageKey = 'rust_quest_progress_v1';
  static const _backupKey = 'rust_quest_progress_backup_v1';
  static const _corruptKey = 'rust_quest_progress_corrupt';
  static const _syncUrlKey = 'rust_quest_sync_url';
  static const _syncUserKey = 'rust_quest_sync_user';
  static const _syncPassKey = 'rust_quest_sync_pass';

  final Curriculum curriculum;
  final SharedPreferences prefs;

  final Set<String> completedLessons = {};
  final Set<String> perfectLessons = {};
  final Set<String> completedProjects = {};
  final Set<String> passedCheckpoints = {};
  final Set<String> unlockedAchievements = {};
  final Map<String, int> lessonScores = {};

  int xp = 0;
  int coins = 0;
  int streak = 0;
  int reviewsDone = 0;
  String? lastActiveDay;
  String? lastReviewDay;
  bool playgroundOpened = false;
  DateTime? updatedAt;

  /// Spaced repetition and analytics.
  final Map<String, QuestionStat> questionStats = {};
  final Map<String, DayStat> dailyStats = {};

  /// User content that survives a progress reset.
  final Map<String, String> notes = {};
  final Set<String> bookmarks = {};

  String? lastLessonId;
  int dailyGoal = 10;
  bool remindersEnabled = false;
  String reminderTime = '19:00';
  String? lastReminderDay;

  AppState({required this.curriculum, required this.prefs});

  static Future<AppState> load(Curriculum curriculum) async {
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(curriculum: curriculum, prefs: prefs);
    for (final key in [_storageKey, _backupKey]) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        state._restore(jsonDecode(raw) as Map<String, dynamic>);
        break;
      } catch (_) {
        if (key == _storageKey) {
          await prefs.setString(_corruptKey, raw);
        }
      }
    }
    return state;
  }

  /// JSON snapshot used for backups and sync.
  String snapshotJson() => jsonEncode(_toJson());

  /// Restores a pasted or downloaded snapshot. Returns false when it is not a
  /// valid save, so the caller can show an error instead of wiping progress.
  Future<bool> importJson(String raw) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;
      if (decoded['completedLessons'] is! List) return false;
      _restore(decoded);
      await _save();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Adopts a remote snapshot when it is strictly newer than the local one.
  Future<bool> adoptRemote(String raw) async {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      if (decoded['completedLessons'] is! List) return false;
      final remote = DateTime.tryParse(decoded['updatedAt'] as String? ?? '');
      if (updatedAt != null && remote != null && !remote.isAfter(updatedAt!)) {
        return false;
      }
      _restore(decoded);
      await _save(bumpTimestamp: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------- derived

  int get level => 1 + xp ~/ 100;
  int get xpIntoLevel => xp % 100;

  int get lessonsCompleted => completedLessons.length;
  int get totalLessons => curriculum.lessonCount;

  List<Achievement> get achievements => curriculum.achievements
      .where((a) => supportedAchievements.contains(a.id))
      .toList();

  bool isLessonCompleted(String id) => completedLessons.contains(id);

  int bestScore(String lessonId) => lessonScores[lessonId] ?? 0;

  bool isProjectDone(String lessonId) => completedProjects.contains(lessonId);

  bool isModuleCompleted(Module module) =>
      module.lessons.isNotEmpty &&
      module.lessons.every((l) => completedLessons.contains(l.id));

  bool isCheckpointPassed(Module module) =>
      passedCheckpoints.contains(module.checkpointKey);

  bool isCheckpointUnlocked(Module module) => isModuleCompleted(module);

  int completedInCourse(Course course) =>
      course.allLessons.where((l) => completedLessons.contains(l.id)).length;

  bool isCourseComplete(Course course) =>
      course.allLessons.isNotEmpty &&
      course.allLessons.every((l) => completedLessons.contains(l.id)) &&
      course.modules.every(isCheckpointPassed);

  List<Course> get completedCourses =>
      curriculum.courses.where(isCourseComplete).toList();

  bool isCourseUnlocked(Course course) {
    if (course.unlockedByDefault) return true;
    final index = curriculum.courses.indexOf(course);
    if (index <= 0) return true;
    return isCourseComplete(curriculum.courses[index - 1]);
  }

  bool isLessonUnlocked(Lesson lesson) {
    final course = lesson.course;
    if (course == null || !isCourseUnlocked(course)) return false;
    final lessons = course.allLessons;
    final index = lessons.indexOf(lesson);
    for (var i = 0; i < index; i++) {
      if (!completedLessons.contains(lessons[i].id)) return false;
    }
    return true;
  }

  bool get reviewAvailable =>
      completedLessons.isNotEmpty && lastReviewDay != _today();

  int get questionsAnswered =>
      questionStats.values.fold(0, (n, s) => n + s.seen);

  double get overallAccuracy {
    var correct = 0;
    var wrong = 0;
    for (final s in questionStats.values) {
      correct += s.correct;
      wrong += s.wrong;
    }
    final total = correct + wrong;
    return total == 0 ? 0 : correct / total;
  }

  double accuracyForCourse(Course course) {
    var correct = 0;
    var wrong = 0;
    for (final lesson in course.allLessons) {
      for (final q in lesson.questions) {
        final s = questionStats[q.key];
        if (s == null) continue;
        correct += s.correct;
        wrong += s.wrong;
      }
    }
    final total = correct + wrong;
    return total == 0 ? 0 : correct / total;
  }

  int attemptsForCourse(Course course) {
    var attempts = 0;
    for (final lesson in course.allLessons) {
      for (final q in lesson.questions) {
        attempts += questionStats[q.key]?.seen ?? 0;
      }
    }
    return attempts;
  }

  DayStat get todayStat => dailyStats[_today()] ?? DayStat();

  int get todayQuestions => todayStat.questions;

  double get goalProgress =>
      dailyGoal <= 0 ? 0 : (todayQuestions / dailyGoal).clamp(0.0, 1.0);

  List<DayStat> lastDays(int count) => [
    for (var i = count - 1; i >= 0; i--)
      dailyStats[_dayOffset(-i)] ?? DayStat(),
  ];

  /// Questions whose spaced-repetition date has passed.
  List<Question> dueQuestions({int limit = 5}) {
    final now = DateTime.now().toUtc();
    final due = <MapEntry<String, QuestionStat>>[];
    for (final entry in questionStats.entries) {
      final dueAt = entry.value.due;
      if (dueAt != null && !dueAt.isAfter(now)) due.add(entry);
    }
    due.sort((a, b) => a.value.due!.compareTo(b.value.due!));
    return due
        .map((e) => curriculum.questionByKey[e.key])
        .whereType<Question>()
        .take(limit)
        .toList();
  }

  /// Questions answered wrong, most-missed first.
  List<Question> weakQuestions({int limit = 10}) {
    final entries =
        questionStats.entries.where((e) => e.value.wrong > 0).toList()
          ..sort((a, b) {
            final byWrong = b.value.wrong.compareTo(a.value.wrong);
            if (byWrong != 0) return byWrong;
            return (b.value.last ?? DateTime(1970)).compareTo(
              a.value.last ?? DateTime(1970),
            );
          });
    return entries
        .take(limit)
        .map((e) => curriculum.questionByKey[e.key])
        .whereType<Question>()
        .toList();
  }

  List<Question> practiceQuestions({
    int count = 10,
    bool weakOnly = false,
    Random? random,
  }) {
    final pool = weakOnly
        ? weakQuestions(limit: 500)
        : [for (final l in curriculum.allLessons) ...l.questions];
    pool.shuffle(random ?? Random());
    return pool.take(count).toList();
  }

  List<Question> reviewQuestions([Random? random]) {
    final due = dueQuestions(limit: 5);
    final seen = {for (final q in due) q.key};
    final pool = <Question>[
      for (final course in curriculum.courses)
        for (final module in course.modules)
          for (final lesson in module.lessons)
            if (completedLessons.contains(lesson.id))
              for (final q in lesson.questions)
                if (!seen.contains(q.key)) q,
    ];
    pool.shuffle(random ?? Random());
    return [...due, ...pool.take(5 - due.length)];
  }

  List<Question> checkpointQuestions(Module module, [Random? random]) {
    final pool = module.questions;
    pool.shuffle(random ?? Random());
    return pool.take(10).toList();
  }

  // ---------------------------------------------------------------- actions

  void _recordAnswers(List<Question> questions, List<bool> results) {
    for (var i = 0; i < results.length && i < questions.length; i++) {
      _recordAnswer(questions[i], results[i]);
    }
  }

  void _recordAnswer(Question question, bool correct) {
    if (question.key.isEmpty) return;
    final day = dailyStats.putIfAbsent(_today(), () => DayStat());
    day.questions += 1;
    if (correct) day.correct += 1;

    final stat = questionStats.putIfAbsent(question.key, () => QuestionStat());
    stat.seen += 1;
    stat.last = DateTime.now().toUtc();
    if (correct) {
      stat.correct += 1;
      stat.stage = (stat.stage + 1).clamp(0, reviewIntervals.length - 1);
      stat.due = DateTime.now().toUtc().add(
        Duration(days: reviewIntervals[stat.stage]),
      );
    } else {
      stat.wrong += 1;
      stat.stage = 0;
      stat.due = DateTime.now().toUtc();
    }
  }

  static const reviewIntervals = [1, 3, 7, 16, 35];

  Future<QuizResult> submitLesson(
    Lesson lesson,
    int correct,
    int total,
    List<bool> results,
  ) async {
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();
    final passed = percent >= 60;
    final first = passed && completedLessons.add(lesson.id);
    var gainedXp = 0;
    var gainedCoins = 0;

    _recordAnswers(lesson.questions, results);
    if (passed && correct == total) perfectLessons.add(lesson.id);
    lessonScores[lesson.id] = max(bestScore(lesson.id), percent);

    if (first) {
      gainedXp = lesson.xp;
      gainedCoins = lesson.coins;
      xp += gainedXp;
      coins += gainedCoins;
      _touchStreak();
    }
    final unlocked = _evaluateAchievements();
    await _save();
    return QuizResult(
      correct: correct,
      total: total,
      passed: passed,
      xpAwarded: gainedXp,
      coinsAwarded: gainedCoins,
      firstCompletion: first,
      unlocked: unlocked,
    );
  }

  Future<QuizResult> submitCheckpoint(
    Module module,
    List<Question> questions,
    int correct,
    int total,
    List<bool> results,
  ) async {
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();
    final passed = percent >= 80;
    final first = passed && passedCheckpoints.add(module.checkpointKey);
    var gainedXp = 0;
    var gainedCoins = 0;
    _recordAnswers(questions, results);
    if (first) {
      gainedXp = 50;
      gainedCoins = 40;
      xp += gainedXp;
      coins += gainedCoins;
      _touchStreak();
    }
    final unlocked = _evaluateAchievements();
    await _save();
    return QuizResult(
      correct: correct,
      total: total,
      passed: passed,
      xpAwarded: gainedXp,
      coinsAwarded: gainedCoins,
      firstCompletion: first,
      unlocked: unlocked,
    );
  }

  Future<QuizResult> submitReview(
    List<Question> questions,
    int correct,
    int total,
    List<bool> results,
  ) async {
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();
    final first = lastReviewDay != _today();
    var gainedXp = 0;
    var gainedCoins = 0;
    _recordAnswers(questions, results);
    if (first) {
      gainedXp = 25;
      gainedCoins = 15;
      xp += gainedXp;
      coins += gainedCoins;
      reviewsDone += 1;
      lastReviewDay = _today();
      _touchStreak();
    }
    final unlocked = _evaluateAchievements();
    await _save();
    return QuizResult(
      correct: correct,
      total: total,
      passed: percent >= 60,
      xpAwarded: gainedXp,
      coinsAwarded: gainedCoins,
      firstCompletion: first,
      unlocked: unlocked,
    );
  }

  Future<QuizResult> submitPractice(
    List<Question> questions,
    int correct,
    int total,
    List<bool> results,
  ) async {
    final percent = total == 0 ? 0 : ((correct / total) * 100).round();
    _recordAnswers(questions, results);
    _touchStreak();
    final unlocked = _evaluateAchievements();
    await _save();
    return QuizResult(
      correct: correct,
      total: total,
      passed: percent >= 60,
      xpAwarded: 0,
      coinsAwarded: 0,
      firstCompletion: false,
      unlocked: unlocked,
    );
  }

  Future<List<Achievement>> completeProject(Lesson lesson) async {
    if (!completedProjects.add(lesson.id)) return const [];
    final unlocked = _evaluateAchievements();
    await _save();
    return unlocked;
  }

  Future<List<Achievement>> markPlaygroundOpened() async {
    if (playgroundOpened) return const [];
    playgroundOpened = true;
    final unlocked = _evaluateAchievements();
    await _save();
    return unlocked;
  }

  Future<void> resetProgress() async {
    _clear();
    await _save();
    notifyListeners();
  }

  void _clear() {
    completedLessons.clear();
    perfectLessons.clear();
    completedProjects.clear();
    passedCheckpoints.clear();
    unlockedAchievements.clear();
    lessonScores.clear();
    xp = 0;
    coins = 0;
    streak = 0;
    reviewsDone = 0;
    lastActiveDay = null;
    lastReviewDay = null;
    playgroundOpened = false;
    questionStats.clear();
    dailyStats.clear();
    lastLessonId = null;
    lastReminderDay = null;
    updatedAt = null;
  }

  // --------------------------------------------------------------- internal

  Future<void> setLastLesson(String lessonId) async {
    if (lastLessonId == lessonId) return;
    lastLessonId = lessonId;
    await _save();
  }

  Future<void> setNote(String lessonId, String text) async {
    if (text.trim().isEmpty) {
      notes.remove(lessonId);
    } else {
      notes[lessonId] = text;
    }
    await _save();
  }

  Future<void> toggleBookmark(String lessonId) async {
    if (!bookmarks.add(lessonId)) bookmarks.remove(lessonId);
    await _save();
  }

  Future<void> setDailyGoal(int goal) async {
    dailyGoal = goal.clamp(1, 200);
    await _save();
  }

  Future<void> setReminder({
    required bool enabled,
    required String time,
  }) async {
    remindersEnabled = enabled;
    reminderTime = time;
    lastReminderDay = null;
    await _save();
  }

  Future<void> markReminderShown() async {
    lastReminderDay = _today();
    await _save();
  }

  List<Achievement> _evaluateAchievements() {
    final newly = <Achievement>[];
    final modulesComplete = curriculum.courses
        .expand((c) => c.modules)
        .where(isModuleCompleted)
        .length;
    final basics = curriculum.courseById['basics'];

    bool shouldUnlock(String id) {
      switch (id) {
        case 'first_lesson':
          return completedLessons.isNotEmpty;
        case 'perfect_quiz':
          return perfectLessons.isNotEmpty;
        case 'xp_500':
          return xp >= 500;
        case 'xp_2000':
          return xp >= 2000;
        case 'coins_500':
          return coins >= 500;
        case 'course_basics':
          return basics != null && isCourseComplete(basics);
        case 'module_complete':
          return modulesComplete > 0;
        case 'first_checkpoint':
          return passedCheckpoints.isNotEmpty;
        case 'checkpoints_5':
          return passedCheckpoints.length >= 5;
        case 'first_project':
          return completedProjects.isNotEmpty;
        case 'projects_5':
          return completedProjects.length >= 5;
        case 'streak_3':
          return streak >= 3;
        case 'streak_7':
          return streak >= 7;
        case 'first_review':
          return reviewsDone >= 1;
        case 'reviews_7':
          return reviewsDone >= 7;
        case 'playground_run':
          return playgroundOpened;
      }
      return false;
    }

    for (final achievement in achievements) {
      if (unlockedAchievements.contains(achievement.id)) continue;
      if (shouldUnlock(achievement.id)) {
        unlockedAchievements.add(achievement.id);
        newly.add(achievement);
      }
    }
    return newly;
  }

  void _touchStreak() {
    final today = _today();
    if (lastActiveDay == today) return;
    final yesterday = _dayOffset(-1);
    streak = lastActiveDay == yesterday ? streak + 1 : 1;
    lastActiveDay = today;
  }

  static String _today() => _dayString(DateTime.now());

  static String _dayOffset(int days) =>
      _dayString(DateTime.now().add(Duration(days: days)));

  static String _dayString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _toJson() => {
    'updatedAt': (updatedAt ?? DateTime.now().toUtc()).toIso8601String(),
    'completedLessons': completedLessons.toList(),
    'perfectLessons': perfectLessons.toList(),
    'completedProjects': completedProjects.toList(),
    'passedCheckpoints': passedCheckpoints.toList(),
    'unlockedAchievements': unlockedAchievements.toList(),
    'questionStats': questionStats.map((k, v) => MapEntry(k, v.toJson())),
    'dailyStats': dailyStats.map((k, v) => MapEntry(k, v.toJson())),
    'notes': notes,
    'bookmarks': bookmarks.toList(),
    'lastLessonId': lastLessonId,
    'dailyGoal': dailyGoal,
    'remindersEnabled': remindersEnabled,
    'reminderTime': reminderTime,
    'lastReminderDay': lastReminderDay,
    'lessonScores': lessonScores,
    'xp': xp,
    'coins': coins,
    'streak': streak,
    'reviewsDone': reviewsDone,
    'lastActiveDay': lastActiveDay,
    'lastReviewDay': lastReviewDay,
    'playgroundOpened': playgroundOpened,
  };

  Future<void> _save({bool bumpTimestamp = true}) async {
    if (bumpTimestamp) updatedAt = DateTime.now().toUtc();
    final encoded = jsonEncode(_toJson());
    final previous = prefs.getString(_storageKey);
    if (previous != null && _isValidSave(previous)) {
      // Keep the last good save so a bad write can never lose progress.
      await prefs.setString(_backupKey, previous);
    }
    await prefs.setString(_storageKey, encoded);
    notifyListeners();
  }

  static bool _isValidSave(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> &&
          decoded['completedLessons'] is List;
    } catch (_) {
      return false;
    }
  }

  void _restore(Map<String, dynamic> json) {
    _clear();
    List<String> list(String key) =>
        ((json[key] as List?) ?? const []).cast<String>().toList();
    completedLessons.addAll(list('completedLessons'));
    perfectLessons.addAll(list('perfectLessons'));
    completedProjects.addAll(list('completedProjects'));
    passedCheckpoints.addAll(list('passedCheckpoints'));
    unlockedAchievements.addAll(list('unlockedAchievements'));
    (json['lessonScores'] as Map?)?.forEach((k, v) {
      lessonScores[k as String] = (v as num).toInt();
    });
    xp = (json['xp'] as num?)?.toInt() ?? 0;
    coins = (json['coins'] as num?)?.toInt() ?? 0;
    streak = (json['streak'] as num?)?.toInt() ?? 0;
    reviewsDone = (json['reviewsDone'] as num?)?.toInt() ?? 0;
    lastActiveDay = json['lastActiveDay'] as String?;
    lastReviewDay = json['lastReviewDay'] as String?;
    playgroundOpened = json['playgroundOpened'] as bool? ?? false;
    (json['questionStats'] as Map?)?.forEach((k, v) {
      questionStats[k as String] = QuestionStat.fromJson(
        (v as Map).cast<String, dynamic>(),
      );
    });
    (json['dailyStats'] as Map?)?.forEach((k, v) {
      dailyStats[k as String] = DayStat.fromJson(
        (v as Map).cast<String, dynamic>(),
      );
    });
    (json['notes'] as Map?)?.forEach((k, v) {
      notes[k as String] = v as String;
    });
    bookmarks.addAll(list('bookmarks'));
    lastLessonId = json['lastLessonId'] as String?;
    dailyGoal = (json['dailyGoal'] as num?)?.toInt() ?? 10;
    remindersEnabled = json['remindersEnabled'] as bool? ?? false;
    reminderTime = json['reminderTime'] as String? ?? '19:00';
    lastReminderDay = json['lastReminderDay'] as String?;
    updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
  }

  // ------------------------------------------------------------ sync config

  String get syncUrl => prefs.getString(_syncUrlKey) ?? '';
  String get syncUser => prefs.getString(_syncUserKey) ?? '';
  String get syncPassword => prefs.getString(_syncPassKey) ?? '';

  bool get syncConfigured =>
      syncUrl.isNotEmpty && syncUser.isNotEmpty && syncPassword.isNotEmpty;

  Future<void> saveSyncConfig(String url, String user, String password) async {
    await prefs.setString(_syncUrlKey, url.trim());
    await prefs.setString(_syncUserKey, user.trim());
    await prefs.setString(_syncPassKey, password);
    notifyListeners();
  }

  Future<void> clearSyncConfig() async {
    await prefs.remove(_syncUrlKey);
    await prefs.remove(_syncUserKey);
    await prefs.remove(_syncPassKey);
    notifyListeners();
  }
}
