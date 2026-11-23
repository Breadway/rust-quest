import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

const kBg = Color(0xFF100E0C);
const kSurface = Color(0xFF1D1713);
const kSurfaceAlt = Color(0xFF2A221B);
const kPrimary = Color(0xFFF2703C);
const kGold = Color(0xFFFFC24B);
const kGood = Color(0xFF7ED957);
const kMuted = Color(0xFFB9A99B);
const kText = Color(0xFFF6EEE7);

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: kPrimary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: kPrimary,
        secondary: kGold,
        surface: kSurface,
        onSurface: kText,
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: kText,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: kSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: const Color(0xFF1A0F08),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kText,
        side: const BorderSide(color: kSurfaceAlt, width: 1.5),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kSurfaceAlt,
      contentTextStyle: TextStyle(color: kText),
      behavior: SnackBarBehavior.floating,
    ),
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: kText, displayColor: kText)
        .copyWith(
          bodyMedium: base.textTheme.bodyMedium!.copyWith(
            color: kText,
            height: 1.45,
            fontSize: 14,
          ),
          bodySmall: base.textTheme.bodySmall!.copyWith(
            color: kMuted,
            fontSize: 12,
          ),
        ),
  );
}

MarkdownStyleSheet markdownStyleSheet() {
  final base = MarkdownStyleSheet.fromTheme(buildTheme());
  return base.copyWith(
    p: const TextStyle(fontSize: 16, height: 1.55, color: kText),
    h1: const TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      color: kText,
      height: 1.3,
    ),
    h2: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: kText,
      height: 1.3,
    ),
    h3: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: kText,
      height: 1.3,
    ),
    strong: const TextStyle(fontWeight: FontWeight.w800, color: kText),
    em: const TextStyle(fontStyle: FontStyle.italic, color: kText),
    a: const TextStyle(color: kPrimary, decoration: TextDecoration.underline),
    code: const TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      color: kGold,
      backgroundColor: kSurfaceAlt,
    ),
    codeblockPadding: const EdgeInsets.all(14),
    codeblockDecoration: BoxDecoration(
      color: const Color(0xFF17120E),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF322820)),
    ),
    blockSpacing: 14,
    listBullet: const TextStyle(fontSize: 16, color: kPrimary),
    horizontalRuleDecoration: const BoxDecoration(
      border: Border(top: BorderSide(color: kSurfaceAlt)),
    ),
  );
}
