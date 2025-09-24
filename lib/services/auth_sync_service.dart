import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Small opt-in service to synchronize Supabase auth state to the
/// SharedPreferences `current_driver` key used by the app for driver login.
///
/// Usage: call `AuthSyncService.start()` during app init (opt-in) and
/// `AuthSyncService.stop()` on dispose. Behavior is conservative:
/// - On sign-in: attempts to infer a driver name from session.user.email
///   (local part) and writes it to `current_driver`.
/// - On sign-out: clears `current_driver` only if it matches inferred value
///   to avoid clearing manual local logins.
class AuthSyncService {
  static StreamSubscription? _sub;
  static Future<void> start({String? Function(Session?)? inferDriver}) async {
    // Default inference: use user.email local part
    inferDriver ??= (s) {
      if (s == null) return null;
      try {
        final String? email = s.user.email;
        if (email == null || email.isEmpty) return null;
        return email.split('@').first;
      } catch (_) {
        return null;
      }
    };

    // Guard: if already started, do nothing
    if (_sub != null) return;

    try {
      _sub = Supabase.instance.client.auth.onAuthStateChange
          .listen((dynamic payload) async {
        try {
          // payload shape may vary across versions
          dynamic session;
          String payloadStr = payload.toString();

          if (payload is Map) {
            session =
                payload['session'] ?? payload['data'] ?? payload['payload'];
            payloadStr = payload.toString();
          } else {
            // Some supabase versions deliver an AuthState object
            try {
              session = payload.session;
            } catch (_) {
              session = null;
            }
            payloadStr = payload.toString();
          }

          final driverFn = inferDriver;
          final inferred = driverFn?.call(session as Session?);
          final prefs = await SharedPreferences.getInstance();

          // If we have an inferred driver and session exists -> set it
          if (session != null && inferred != null && inferred.isNotEmpty) {
            await prefs.setString('current_driver', inferred);
          }

          // If signed out, clear only if matches inferred value to avoid
          // clearing manual local logins.
          final lower = payloadStr.toLowerCase();
          if (lower.contains('signout') ||
              lower.contains('signed_out') ||
              lower.contains('signedout')) {
            final curr = prefs.getString('current_driver');
            if (curr != null && inferred != null && curr == inferred) {
              await prefs.remove('current_driver');
            }
          }
        } catch (_) {
          // swallow errors — sync is best-effort
        }
      });
    } catch (_) {
      // best-effort: Supabase API may differ; ignore if not available
    }
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
