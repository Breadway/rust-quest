import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../app_state.dart';
import '../sync_service.dart';
import '../theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state, required this.sync});

  final AppState state;
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final achievements = state.achievements;
        final unlocked = achievements.where(
          (a) => state.unlockedAchievements.contains(a.id),
        );
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                primary: false,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text('🦀', style: TextStyle(fontSize: 28)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Level ${state.level}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${state.xp} XP · ${state.coins} coins',
                                style: const TextStyle(
                                  color: kMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '🔥 ${state.streak}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'day streak',
                              style: TextStyle(
                                color: kMuted.withValues(alpha: .9),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stat(
                        'Lessons',
                        '${state.lessonsCompleted}/${state.totalLessons}',
                      ),
                      const SizedBox(width: 10),
                      _stat(
                        'Courses',
                        '${state.completedCourses.length}/${state.curriculum.courses.length}',
                      ),
                      const SizedBox(width: 10),
                      _stat('Checkpoints', '${state.passedCheckpoints.length}'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'Achievements',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${unlocked.length} / ${achievements.length}',
                        style: const TextStyle(color: kMuted, fontSize: 12.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final a in achievements)
                    _achievementTile(a.id, a.icon, a.title, a.description),
                  const SizedBox(height: 18),
                  const Text(
                    'About',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rust Quest 1.0.0',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'A data-driven rebuild of the Learn Rust Easily curriculum: '
                          '${state.curriculum.courses.length} courses, '
                          '${state.curriculum.moduleCount} modules, '
                          '${state.curriculum.lessonCount} lessons and '
                          '${state.curriculum.questionCount} questions.\n\n'
                          'Lessons are loaded from assets/curriculum.json. Add a new '
                          'lesson by appending it to a module and rebuilding; no code '
                          'changes are needed.',
                          style: const TextStyle(
                            color: kMuted,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SyncCard(state: state, sync: sync),
                  const SizedBox(height: 12),
                  _BackupCard(state: state),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _confirmReset(context),
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Reset progress'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _achievementTile(
    String id,
    String icon,
    String title,
    String description,
  ) {
    final done = state.unlockedAchievements.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: done ? kGold.withValues(alpha: .45) : kSurfaceAlt,
        ),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: done ? 1 : .35,
            child: Text(icon, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: done ? kText : kMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(color: kMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Icon(
            done ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
            size: 18,
            color: done ? kGold : kMuted.withValues(alpha: .5),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Reset progress?'),
        content: const Text(
          'XP, coins, streak, completed lessons and achievements will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await state.resetProgress();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Progress reset')));
      }
    }
  }
}

class _SyncCard extends StatefulWidget {
  const _SyncCard({required this.state, required this.sync});

  final AppState state;
  final SyncService sync;

  @override
  State<_SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends State<_SyncCard> {
  static const _defaultUrl =
      'https://nextcloud.breadway.dev/remote.php/dav/files/breadway/RustQuest/';

  late final TextEditingController _url = TextEditingController(
    text: widget.state.syncUrl.isEmpty ? _defaultUrl : widget.state.syncUrl,
  );
  late final TextEditingController _user = TextEditingController(
    text: widget.state.syncUser.isEmpty ? 'breadway' : widget.state.syncUser,
  );
  late final TextEditingController _pass = TextEditingController(
    text: widget.state.syncPassword,
  );
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _editing = !widget.state.syncConfigured;
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _saveAndSync() async {
    if (_url.text.trim().isEmpty ||
        _user.text.trim().isEmpty ||
        _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fill in the WebDAV URL, username and app password'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await widget.state.saveSyncConfig(_url.text, _user.text, _pass.text);
    await widget.sync.syncNow();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.sync,
      builder: (context, _) {
        final configured = widget.state.syncConfigured;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('☁️', style: TextStyle(fontSize: 17)),
                  const SizedBox(width: 8),
                  const Text(
                    'Sync with Hestia',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (configured && !_editing)
                    TextButton(
                      onPressed: () => setState(() => _editing = true),
                      child: const Text('Edit'),
                    ),
                ],
              ),
              if (_editing) ...[
                const SizedBox(height: 4),
                _field(
                  _url,
                  'WebDAV folder URL',
                  hint: _defaultUrl,
                  keyboard: TextInputType.url,
                ),
                const SizedBox(height: 8),
                _field(_user, 'Nextcloud user'),
                const SizedBox(height: 8),
                _field(_pass, 'App password', obscure: true),
                const SizedBox(height: 4),
                const Text(
                  'Create an app password in Nextcloud, Settings, Security. '
                  'It is stored only in this app\'s private preferences.',
                  style: TextStyle(color: kMuted, fontSize: 11, height: 1.4),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveAndSync,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(_saving ? 'Syncing...' : 'Save and sync'),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  widget.sync.status ?? 'Not synced yet',
                  style: const TextStyle(color: kMuted, fontSize: 12.5),
                ),
                if (widget.sync.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      widget.sync.error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                if (widget.sync.lastSync != null)
                  Text(
                    'Last sync ${_time(widget.sync.lastSync!)}',
                    style: const TextStyle(color: kMuted, fontSize: 11),
                  ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: widget.sync.busy
                      ? null
                      : () => widget.sync.syncNow(),
                  icon: const Icon(Icons.sync, size: 18),
                  label: Text(widget.sync.busy ? 'Syncing...' : 'Sync now'),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Progress uploads automatically a few seconds after each change, '
                  'and newer remote progress is pulled on launch.',
                  style: TextStyle(color: kMuted, fontSize: 11, height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: kSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static String _time(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

class _BackupCard extends StatelessWidget {
  const _BackupCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💾', style: TextStyle(fontSize: 17)),
              const SizedBox(width: 8),
              const Text(
                'Progress backup',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'The app keeps the previous save locally and falls back to it if the '
            'current one is ever unreadable. You can also copy the whole save as '
            'JSON and paste it back later.',
            style: TextStyle(color: kMuted, fontSize: 11.5, height: 1.45),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: state.snapshotJson()),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Progress JSON copied to clipboard'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    final raw = data?.text;
                    final ok = raw == null
                        ? false
                        : await state.importJson(raw);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Progress restored from clipboard'
                                : 'Clipboard does not contain a valid save',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.restore_rounded, size: 16),
                  label: const Text('Restore'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
