import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SupabaseRealtimeService
/// Small singleton wrapper to subscribe/unsubscribe to Supabase table streams.
/// Each subscription restarts on error with exponential backoff.
class SupabaseRealtimeService {
  SupabaseRealtimeService._internal();
  static final SupabaseRealtimeService instance =
      SupabaseRealtimeService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final Map<String, _SubscriptionController> _controllers = {};

  /// Subscribe to realtime updates for `table`.
  /// `onRows` receives parsed rows whenever the stream emits.
  /// Returns a `key` that can be used to unsubscribe.
  Future<String> subscribeToTable(
    String table,
    void Function(List<Map<String, dynamic>> rows) onRows, {
    Duration initialBackoff = const Duration(seconds: 1),
    Duration maxBackoff = const Duration(seconds: 30),
  }) async {
    final key = '${table}_${DateTime.now().millisecondsSinceEpoch}';
    final controller = _SubscriptionController(
      client: _client,
      table: table,
      onRows: onRows,
      initialBackoff: initialBackoff,
      maxBackoff: maxBackoff,
    );
    _controllers[key] = controller;
    controller.start();
    return key;
  }

  Future<void> unsubscribe(String key) async {
    final c = _controllers.remove(key);
    if (c != null) await c.cancel();
  }

  Future<void> unsubscribeAll() async {
    final keys = _controllers.keys.toList();
    for (final k in keys) {
      await unsubscribe(k);
    }
  }
}

class _SubscriptionController {
  _SubscriptionController({
    required this.client,
    required this.table,
    required this.onRows,
    required this.initialBackoff,
    required this.maxBackoff,
  });

  final SupabaseClient client;
  final String table;
  final void Function(List<Map<String, dynamic>> rows) onRows;
  final Duration initialBackoff;
  final Duration maxBackoff;

  StreamSubscription<dynamic>? _sub;
  int _attempt = 0;
  bool _cancelled = false;

  void start() {
    _cancelled = false;
    _attempt = 0;
    _createSub();
  }

  void _createSub() {
    if (_cancelled) return;
    try {
      _sub = client.from(table).stream(primaryKey: ['id']).listen(
        (data) {
          try {
            final rows = (data as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            onRows(rows);
          } catch (e, st) {
            debugPrint('SupabaseRealtimeService parse error: $e\n$st');
          }
        },
        onError: (e) async {
          debugPrint('SupabaseRealtimeService stream error: $e');
          await _scheduleRestart();
        },
        onDone: () async {
          debugPrint('SupabaseRealtimeService stream done for $table');
          await _scheduleRestart();
        },
      );
    } catch (e) {
      debugPrint('SupabaseRealtimeService subscribe failed: $e');
      _scheduleRestart();
    }
  }

  Future<void> _scheduleRestart() async {
    if (_cancelled) return;
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
    _attempt++;
    final backoffMs = min(
      maxBackoff.inMilliseconds,
      (initialBackoff.inMilliseconds * pow(2, _attempt)).toInt(),
    );
    await Future.delayed(Duration(milliseconds: backoffMs));
    if (_cancelled) return;
    _createSub();
  }

  Future<void> cancel() async {
    _cancelled = true;
    try {
      await _sub?.cancel();
    } catch (_) {}
    _sub = null;
  }
}
