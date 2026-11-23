import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'lesson_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<SearchHit> _hits = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() {
      _hits = widget.state.curriculum.search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search lessons')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Search titles, lessons and questions',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              _search('');
                            },
                          ),
                    filled: true,
                    fillColor: kSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _controller.text.trim().isEmpty
                    ? _suggestions()
                    : _hits.isEmpty
                    ? const Center(
                        child: Text(
                          'No matches',
                          style: TextStyle(color: kMuted),
                        ),
                      )
                    : ListView.builder(
                        primary: false,
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                        itemCount: _hits.length,
                        itemBuilder: (context, i) => _hitTile(_hits[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestions() {
    const words = [
      'ownership',
      'lifetime',
      'async',
      'trait',
      'unsafe',
      'bread',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Try a topic',
            style: TextStyle(color: kMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in words)
                ActionChip(
                  label: Text(word),
                  backgroundColor: kSurface,
                  side: const BorderSide(color: kSurfaceAlt),
                  onPressed: () {
                    _controller.text = word;
                    _search(word);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hitTile(SearchHit hit) {
    final lesson = hit.lesson;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LessonScreen(state: widget.state, lesson: lesson),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kSurfaceAlt),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lesson.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${lesson.course?.icon ?? ''} ${lesson.course?.title ?? ''}'
                ' · ${lesson.module?.title ?? ''}',
                style: const TextStyle(color: kMuted, fontSize: 11),
              ),
              if (hit.snippet.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  hit.snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kMuted, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
