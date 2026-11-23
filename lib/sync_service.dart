import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_state.dart';

/// Two-way progress sync over WebDAV (Nextcloud on Hestia).
///
/// The save file is plain JSON. Conflicts are resolved last-write-wins using
/// the `updatedAt` field each save carries, so the newer device wins instead of
/// merging half-finished state.
class SyncService extends ChangeNotifier {
  SyncService(this.state) {
    state.addListener(_onLocalChange);
  }

  final AppState state;
  Timer? _debounce;
  bool _syncing = false;
  bool _adopting = false;

  String? status;
  String? error;
  DateTime? lastSync;

  bool get busy => _syncing;

  void disposeService() {
    _debounce?.cancel();
    state.removeListener(_onLocalChange);
    super.dispose();
  }

  void _onLocalChange() {
    if (_adopting || _syncing || !state.syncConfigured) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () => syncNow());
  }

  Future<void> syncNow() async {
    if (!state.syncConfigured || _syncing) return;
    _syncing = true;
    error = null;
    notifyListeners();
    try {
      final remote = await _get();
      if (remote != null) {
        final decoded = jsonDecode(remote);
        final remoteTime = decoded is Map
            ? DateTime.tryParse(decoded['updatedAt'] as String? ?? '')
            : null;
        final local = state.updatedAt;
        final remoteIsNewer =
            remoteTime != null && (local == null || remoteTime.isAfter(local));
        if (remoteIsNewer) {
          _adopting = true;
          final ok = await state.adoptRemote(remote);
          _adopting = false;
          if (ok) {
            status = 'Pulled the latest from Hestia';
            lastSync = DateTime.now();
            notifyListeners();
            return;
          }
        }
      }
      await _put(state.snapshotJson());
      status = remote == null ? 'Uploaded to Hestia' : 'Synced with Hestia';
      lastSync = DateTime.now();
    } catch (e) {
      error = _describe(e);
      status = 'Sync failed';
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Uri get _fileUri {
    final raw = state.syncUrl.trim();
    return Uri.parse(raw.endsWith('/') ? '${raw}progress.json' : raw);
  }

  Map<String, String> get _authHeaders => {
    'Authorization':
        'Basic '
        '${base64Encode(utf8.encode('${state.syncUser}:${state.syncPassword}'))}',
  };

  Future<String?> _get() async {
    final response = await http
        .get(_fileUri, headers: _authHeaders)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 404) return null;
    if (response.statusCode >= 300) {
      throw HttpException(
        'GET ${response.statusCode} ${response.reasonPhrase}',
      );
    }
    return utf8.decode(response.bodyBytes);
  }

  Future<void> _put(String body) async {
    await _ensureParent();
    final response = await http
        .put(
          _fileUri,
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
          body: utf8.encode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 300) {
      throw HttpException(
        'PUT ${response.statusCode} ${response.reasonPhrase}',
      );
    }
  }

  Future<void> _ensureParent() async {
    final path = _fileUri.path;
    final cut = path.lastIndexOf('/');
    if (cut <= 0) return;
    final folder = _fileUri.replace(path: path.substring(0, cut + 1));
    final request = http.Request('MKCOL', folder)..headers.addAll(_authHeaders);
    final response = await http.Client()
        .send(request)
        .timeout(const Duration(seconds: 20));
    // 201 created, 405 already exists, 409 parent missing (reported by PUT).
    if (response.statusCode >= 300 &&
        response.statusCode != 405 &&
        response.statusCode != 409) {
      throw HttpException('MKCOL ${response.statusCode}');
    }
  }

  static String _describe(Object e) {
    if (e is TimeoutException) return 'Timed out talking to Hestia';
    if (e is SocketException) return 'No network connection';
    if (e is HttpException) {
      if (e.message.contains('401')) return 'Wrong username or app password';
      if (e.message.contains('403')) return 'Not allowed to write that folder';
      if (e.message.contains('404')) return 'Folder not found';
      return e.message;
    }
    return e.toString();
  }
}
