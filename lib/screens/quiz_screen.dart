import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/code_block.dart';

/// Generic quiz runner used for lessons, checkpoints and the daily review.
///
/// The screen owns only presentation and scoring; rewards, pass thresholds and
/// achievement checks live in [AppState] behind [onSubmit].
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.questions,
    required this.onSubmit,
    this.timeLimit,
  });

  final String title;
  final String subtitle;
  final List<Question> questions;
  final Future<QuizResult> Function(int correct, int total, List<bool> results)
  onSubmit;
  final Duration? timeLimit;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _textFocus = FocusNode();
  final List<bool> _results = [];
  Timer? _timer;
  Duration? _remaining;
  int _index = 0;
  int _correct = 0;
  int? _selected;
  bool? _boolSelected;
  List<int> _order = [];
  List<int> _shuffled = [];
  bool _checked = false;
  bool? _lastCorrect;
  QuizResult? _result;
  bool _submitting = false;

  Question get _q => widget.questions[_index];

  @override
  void initState() {
    super.initState();
    _resetQuestion();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusInput());
    if (widget.timeLimit != null) {
      _remaining = widget.timeLimit;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _result != null) return;
        final left = _remaining! - const Duration(seconds: 1);
        if (left <= Duration.zero) {
          setState(() => _remaining = Duration.zero);
          _finish();
        } else {
          setState(() => _remaining = left);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    _text.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  void _resetQuestion() {
    _selected = null;
    _boolSelected = null;
    _text.clear();
    _checked = false;
    _lastCorrect = null;
    _order = [];
    _shuffled = List.generate(_q.lines.length, (i) => i)..shuffle();
  }

  bool get _hasAnswer {
    switch (_q.type) {
      case 'trueFalse':
        return _boolSelected != null;
      case 'fillBlank':
        return _text.text.trim().isNotEmpty;
      case 'codeOrder':
        return _order.length == _q.lines.length;
      default:
        return _selected != null;
    }
  }

  bool _evaluate() {
    switch (_q.type) {
      case 'trueFalse':
        return _boolSelected == _q.answerBool;
      case 'fillBlank':
        return _q.accepts(_text.text);
      case 'codeOrder':
        return _order.join(',') ==
            List.generate(_q.lines.length, (i) => i).join(',');
      default:
        return _selected == _q.answerIndex;
    }
  }

  Future<void> _next() async {
    if (_index + 1 < widget.questions.length) {
      setState(() {
        _index += 1;
        _resetQuestion();
      });
      _focusInput();
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_submitting) return;
    _timer?.cancel();
    setState(() => _submitting = true);
    final result = await widget.onSubmit(
      _correct,
      widget.questions.length,
      List.of(_results),
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _submitting = false;
    });
  }

  void _check() {
    if (!_hasAnswer || _checked) return;
    final ok = _evaluate();
    setState(() {
      _checked = true;
      _lastCorrect = ok;
      _results.add(ok);
      if (ok) _correct += 1;
    });
    _focusInput();
  }

  /// Fill-in questions should accept typing immediately, without a click.
  void _focusInput() {
    if (_checked || _q.type != 'fillBlank') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_checked && _q.type == 'fillBlank') {
        _textFocus.requestFocus();
      }
    });
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
    if (_result != null) return false;

    // Let the text field own Enter while it is focused (onSubmitted handles
    // submit); once it is disabled, Enter reaches this handler to advance.
    if (_textFocus.hasFocus) return false;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      if (_checked) {
        _next();
      } else if (_hasAnswer) {
        _check();
      }
      return true;
    }

    final option = _optionForKey(key);
    if (option != null && !_checked) {
      if (_q.type == 'trueFalse') {
        if (option < 2) {
          setState(() => _boolSelected = option == 0);
          return true;
        }
      } else if (option < _q.options.length) {
        setState(() => _selected = option);
        return true;
      }
    }
    return false;
  }

  int? _optionForKey(LogicalKeyboardKey key) {
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
    ];
    const numpad = [
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
    ];
    final digit = digits.indexOf(key);
    if (digit >= 0) return digit;
    final pad = numpad.indexOf(key);
    if (pad >= 0) return pad;
    const letters = [
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyB,
      LogicalKeyboardKey.keyC,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyE,
      LogicalKeyboardKey.keyF,
    ];
    final letter = letters.indexOf(key);
    if (letter >= 0) return letter;
    if (key == LogicalKeyboardKey.keyT) return 0;
    if (key == LogicalKeyboardKey.keyF) return 1;
    return null;
  }

  void _restart() {
    setState(() {
      _index = 0;
      _correct = 0;
      _results.clear();
      _result = null;
      _remaining = widget.timeLimit;
      _resetQuestion();
    });
    _focusInput();
    if (widget.timeLimit != null) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _result != null) return;
        final left = _remaining! - const Duration(seconds: 1);
        if (left <= Duration.zero) {
          setState(() => _remaining = Duration.zero);
          _finish();
        } else {
          setState(() => _remaining = left);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: _result != null ? _buildResult(_result!) : _buildQuestion(),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- result

  Widget _buildResult(QuizResult result) {
    return ListView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Center(
          child: Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: result.passed ? kGood.withValues(alpha: .12) : kSurface,
              border: Border.all(
                color: result.passed ? kGood : kSurfaceAlt,
                width: 3,
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${result.percent}%',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${result.correct}/${result.total} correct',
                      style: const TextStyle(color: kMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          result.passed
              ? (result.percent == 100 ? 'Flawless!' : 'Nice work!')
              : 'Not quite there',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          result.firstCompletion
              ? 'Rewards added to your profile.'
              : 'Already counted, but practice still helps.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kMuted),
        ),
        if (result.firstCompletion) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RewardChip(label: '+${result.xpAwarded} XP', icon: '⭐'),
              const SizedBox(width: 10),
              _RewardChip(label: '+${result.coinsAwarded}', icon: '🪙'),
            ],
          ),
        ],
        if (result.unlocked.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Text(
            'Achievements unlocked',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final a in result.unlocked)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(a.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${a.title} · ${a.description}',
                      style: const TextStyle(color: kGold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 26),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(result),
          child: const Text('Done'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () {
            _restart();
            _focusInput();
          },
          child: const Text('Try again'),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- question

  Widget _buildQuestion() {
    final q = _q;
    final total = widget.questions.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Question ${_index + 1} of $total',
                    style: const TextStyle(color: kMuted, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    _remaining == null
                        ? widget.subtitle
                        : '${_format(_remaining!)} left',
                    style: TextStyle(
                      color:
                          _remaining != null &&
                              _remaining! < const Duration(seconds: 30)
                          ? Colors.redAccent
                          : kMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (_index + (_checked ? 1 : 0)) / total,
                  minHeight: 7,
                  backgroundColor: kSurfaceAlt,
                  color: kPrimary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            primary: false,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            children: [
              _typeBadge(q.type),
              const SizedBox(height: 10),
              MarkdownBody(
                data: q.prompt,
                softLineBreak: true,
                styleSheet: markdownStyleSheet().copyWith(
                  p: const TextStyle(fontSize: 19, height: 1.4, color: kText),
                ),
              ),
              if (q.code.isNotEmpty) ...[
                const SizedBox(height: 12),
                CodeBlock(code: q.code),
              ],
              const SizedBox(height: 16),
              ..._answerWidgets(q),
              if (_checked) ...[const SizedBox(height: 16), _feedback()],
            ],
          ),
        ),
        if (MediaQuery.sizeOf(context).width >= 900 && !_checked)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Keys: 1-6 / A-F answer · Enter check and next',
              style: TextStyle(color: kMuted, fontSize: 11),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: FilledButton(
            onPressed: _submitting
                ? null
                : (_checked ? _next : (_hasAnswer ? _check : null)),
            child: Text(
              _submitting
                  ? 'Checking...'
                  : (_checked
                        ? (_index + 1 < total ? 'Next question' : 'See results')
                        : 'Check answer'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _typeBadge(String type) {
    final (label, icon) = switch (type) {
      'trueFalse' => ('True or false', Icons.rule),
      'fillBlank' => ('Fill the blank', Icons.edit_note),
      'codeOrder' => ('Order the code', Icons.reorder),
      'codeOutput' => ('Code output', Icons.terminal),
      _ => ('Multiple choice', Icons.checklist),
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: kPrimary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: kPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
      ],
    );
  }

  List<Widget> _answerWidgets(Question q) {
    switch (q.type) {
      case 'trueFalse':
        return [
          for (final value in [true, false])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _optionTile(
                selected: _boolSelected == value,
                correct: _checked ? q.answerBool == value : null,
                onTap: _checked
                    ? null
                    : () => setState(() => _boolSelected = value),
                child: Text(
                  value ? 'True' : 'False',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ];
      case 'fillBlank':
        return [
          TextField(
            controller: _text,
            focusNode: _textFocus,
            enabled: !_checked,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (_checked) {
                _next();
              } else {
                _check();
              }
            },
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 17),
            decoration: InputDecoration(
              hintText: 'Type the missing code',
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kSurfaceAlt),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kSurfaceAlt),
              ),
            ),
          ),
        ];
      case 'codeOrder':
        return [
          const Text(
            'Tap the lines in the right order',
            style: TextStyle(color: kMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _checked
                    ? (_lastCorrect! ? kGood : Colors.redAccent)
                    : kSurfaceAlt,
              ),
            ),
            child: _order.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: Text(
                      'Your answer appears here',
                      style: TextStyle(color: kMuted, fontSize: 13),
                    ),
                  )
                : Column(
                    children: [
                      for (var pos = 0; pos < _order.length; pos++)
                        _codeLineRow(
                          q.lines[_order[pos]],
                          number: pos + 1,
                          trailing: _checked ? null : Icons.close,
                          onTap: _checked
                              ? null
                              : () => setState(() => _order.removeAt(pos)),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          Column(
            children: [
              for (final i in _shuffled)
                if (!_order.contains(i))
                  _codeLineRow(
                    q.lines[i],
                    onTap: _checked
                        ? null
                        : () => setState(() => _order.add(i)),
                  ),
            ],
          ),
          if (!_checked && _order.isNotEmpty)
            TextButton(
              onPressed: () => setState(_order.clear),
              child: const Text('Reset order'),
            ),
        ];
      default:
        final options = q.options;
        return [
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _optionTile(
                selected: _selected == i,
                correct: _checked ? q.answerIndex == i : null,
                onTap: _checked ? null : () => setState(() => _selected = i),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      String.fromCharCode(65 + i),
                      style: const TextStyle(
                        color: kMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: options[i].contains('\n')
                          ? SelectableText(
                              options[i],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13.5,
                                height: 1.45,
                                color: kText,
                              ),
                            )
                          : MarkdownBody(
                              data: options[i],
                              styleSheet: markdownStyleSheet().copyWith(
                                p: const TextStyle(fontSize: 16, color: kText),
                                blockSpacing: 0,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ];
    }
  }

  /// One code line, always on its own full-width row. Ordering questions are
  /// about vertical order, so two short lines must never sit side by side.
  Widget _codeLineRow(
    String text, {
    int? number,
    IconData? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      canRequestFocus: false,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: kSurfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (number != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: kMuted,
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(trailing, size: 14, color: kMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required bool selected,
    required bool? correct,
    required VoidCallback? onTap,
    required Widget child,
  }) {
    var border = kSurfaceAlt;
    var fill = kSurface;
    if (correct == true) {
      border = kGood;
      fill = kGood.withValues(alpha: .08);
    } else if (correct == false && selected) {
      border = Colors.redAccent;
      fill = Colors.redAccent.withValues(alpha: .08);
    } else if (selected) {
      border = kPrimary;
      fill = kPrimary.withValues(alpha: .10);
    }
    return InkWell(
      onTap: onTap,
      canRequestFocus: false,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.5),
        ),
        child: child,
      ),
    );
  }

  Widget _feedback() {
    final ok = _lastCorrect ?? false;
    final q = _q;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (ok ? kGood : Colors.redAccent).withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (ok ? kGood : Colors.redAccent).withValues(alpha: .6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: ok ? kGood : Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Text(
                ok ? 'Correct' : 'Not quite',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: ok ? kGood : Colors.redAccent,
                ),
              ),
            ],
          ),
          if (!ok) ...[
            const SizedBox(height: 6),
            Text(
              _correctAnswerText(q),
              style: const TextStyle(fontSize: 13, color: kText),
            ),
          ],
          if (q.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            MarkdownBody(
              data: q.explanation,
              styleSheet: markdownStyleSheet().copyWith(
                p: const TextStyle(fontSize: 14, color: kMuted, height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _correctAnswerText(Question q) {
    switch (q.type) {
      case 'trueFalse':
        return 'Answer: ${q.answerBool ? 'True' : 'False'}';
      case 'fillBlank':
        return 'Answer: ${q.answers.join(' or ')}';
      case 'codeOrder':
        return 'Correct order:\n${q.lines.join('\n')}';
      default:
        final i = q.answerIndex;
        return 'Answer: ${i >= 0 && i < q.options.length ? q.options[i] : '?'}';
    }
  }
}

String _format(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.label, required this.icon});

  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kSurfaceAlt),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
