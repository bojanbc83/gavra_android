import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Example helper showing how to subscribe/unsubscribe using existing
/// `RealtimeService` patterns already present in the project.
class SupabaseRealtimeExample {
  final SupabaseClient client = Supabase.instance.client;
  StreamSubscription? _sub;

  Future<void> subscribeToDailyPassengers(
      void Function(List<Map<String, dynamic>>) onRows) async {
    // `from(...).stream()` returns a broadcast stream of row arrays
    _sub = client.from('daily_passengers').stream(primaryKey: ['id']).listen(
      (data) {
        try {
          final rows = (data as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          onRows(rows);
        } catch (e) {
          // ignore
        }
      },
      onError: (e) => debugPrint('Realtime error: $e'),
    );
  }

  Future<void> unsubscribe() async {
    try {
      await _sub?.cancel();
      _sub = null;
    } catch (_) {}
  }
}
