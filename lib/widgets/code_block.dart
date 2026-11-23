import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'highlighted_code.dart';

class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.code, this.copyable = false});

  final String code;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final text = code.trimRight();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF17120E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF322820)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (copyable)
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Copy code',
                iconSize: 18,
                color: kMuted,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, copyable ? 0 : 14, 14, 14),
            child: SelectionArea(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: HighlightedCode(code: text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
