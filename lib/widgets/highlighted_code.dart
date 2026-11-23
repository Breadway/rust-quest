import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Dark token theme tuned to sit on the app's warm code block background.
final Map<String, TextStyle> _codeTheme = () {
  final theme = Map<String, TextStyle>.from(atomOneDarkTheme);
  theme['root'] = const TextStyle(
    color: Color(0xFFE6E1D8),
    backgroundColor: Colors.transparent,
  );
  return theme;
}();

/// Syntax-highlighted code for lessons, projects and quiz questions.
class HighlightedCode extends StatelessWidget {
  const HighlightedCode({
    super.key,
    required this.code,
    this.language = 'rust',
  });

  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    return HighlightView(
      code.trimRight(),
      language: language,
      theme: _codeTheme,
      padding: EdgeInsets.zero,
      textStyle: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13.5,
        height: 1.5,
      ),
    );
  }
}

/// Replaces fenced code blocks in markdown with [HighlightedCode].
///
/// The language comes from the fence info string (` ```rust `), defaulting to
/// Rust because every code sample in this curriculum is Rust.
class HighlightedCodeBuilder extends MarkdownElementBuilder {
  String _language = 'rust';

  @override
  bool isBlockElement() => true;

  @override
  void visitElementBefore(md.Element element) {
    _language = 'rust';
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == 'code') {
        final cls = child.attributes['class'];
        if (cls != null && cls.startsWith('language-')) {
          _language = _normalize(cls.substring('language-'.length));
        }
        break;
      }
    }
  }

  @override
  Widget? visitText(md.Text text, TextStyle? preferredStyle) {
    final source = text.textContent;
    if (source.trim().isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: HighlightedCode(code: source, language: _language),
      ),
    );
  }

  static String _normalize(String language) {
    switch (language.toLowerCase()) {
      case '':
        return 'rust';
      case 'rs':
        return 'rust';
      case 'text':
      case 'txt':
      case 'plain':
        return 'plaintext';
      case 'sh':
      case 'shell':
      case 'zsh':
        return 'bash';
      default:
        return language.toLowerCase();
    }
  }
}
