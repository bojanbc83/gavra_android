import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/putnik.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/slot_utils.dart';

typedef RealtimePayloadHandler = void Function(Map<String, dynamic> payload);

/// Centralized RealtimeService for Supabase realtime subscriptions.
/// Exposes broadcast streams for raw table rows and a combined `Putnik` stream
/// which UI code can subscribe to (optionally filtered by `isoDate`, `grad`, `vreme`).
class RealtimeService {
  RealtimeService._internal();
  static final RealtimeService instance = RealtimeService._internal();

  // Raw controllers for commonly used tables
  final StreamController<List<Map<String, dynamic>>> _dailyCheckinsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _putovanjaController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  // Combined Putnik stream controller
  final StreamController<List<Putnik>> _combinedPutniciController =
      StreamController<List<Putnik>>.broadcast();

  Stream<List<Map<String, dynamic>>> get dailyCheckinsStream =>
      _dailyCheckinsController.stream;

  Stream<List<Map<String, dynamic>>> get putovanjaStream =>
      _putovanjaController.stream;

  Stream<List<Putnik>> get combinedPutniciStream =>
      _combinedPutniciController.stream;

  StreamSubscription<dynamic>? _dailySub;
  StreamSubscription<dynamic>? _putovanjaSub;

  // Keep last known rows so we can emit combined payloads
  List<Map<String, dynamic>> _lastDailyRows = [];
  List<Map<String, dynamic>> _lastPutovanjaRows = [];

  // Parametric subscriptions: per-filter controllers and state
  final Map<String, StreamController<List<Putnik>>> _paramControllers = {};
  final Map<String, List<Map<String, dynamic>>> _paramLastDaily = {};
  final Map<String, List<Map<String, dynamic>>> _paramLastPutovanja = {};
  final Map<String, List<StreamSubscription<dynamic>>> _paramSubscriptions = {};

  String _paramKey({String? isoDate, String? grad, String? vreme}) {
    return '${isoDate ?? ''}|${grad ?? ''}|${vreme ?? ''}';
  }

  /// Vrati stream za tabelu. Pozivaoci mogu sami da se pretplate i obrade evente.
  Stream<dynamic> tableStream(String table) {
    final client = Supabase.instance.client;
    return client.from(table).stream(primaryKey: ['id']);
  }

  /// Pomo─çna metoda: pretplati se na tabelu i vrati StreamSubscription.
  StreamSubscription<dynamic> subscribe(
      String table, void Function(dynamic) onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    final stream = tableStream(table);
    return stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  Future<void> unsubscribeAll() async {
    try {
      await _dailySub?.cancel();
    } catch (_) {}
    try {
      await _putovanjaSub?.cancel();
    } catch (_) {}
    // Clear controllers
    if (!_dailyCheckinsController.isClosed) {
      _dailyCheckinsController.add([]);
    }
    if (!_putovanjaController.isClosed) {
      _putovanjaController.add([]);
    }
    if (!_combinedPutniciController.isClosed) {
      _combinedPutniciController.add([]);
    }
  }

  /// Start centralized realtime subscriptions for commonly used tables.
  /// If `vozac` is provided, daily_checkins events will be filtered by driver
  /// in the handler before adding to the controller.
  void startForDriver(String? vozac) {
    final client = Supabase.instance.client;

    // daily_checkins
    _dailySub = client
        .from('daily_checkins')
        .stream(primaryKey: ['id']).listen((List<dynamic> data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in data) {
          if (r is Map) {
            if (vozac == null || r['vozac'] == vozac) {
              rows.add(Map<String, dynamic>.from(r));
            }
          }
        }
        _lastDailyRows = rows;
        if (!_dailyCheckinsController.isClosed) {
          _dailyCheckinsController.add(rows);
        }
        _emitCombinedPutnici();
      } catch (e) {
        // ignore parsing errors
      }
    });

    // daily_passengers
    _putovanjaSub = client
        .from('daily_passengers')
        .stream(primaryKey: ['id']).listen((List<dynamic> data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in data) {
          if (r is Map) {
            rows.add(Map<String, dynamic>.from(r));
          }
        }
        _lastPutovanjaRows = rows;
        if (!_putovanjaController.isClosed) {
          _putovanjaController.add(rows);
        }
        _emitCombinedPutnici();
      } catch (e) {
        // ignore
      }
    });
  }

  /// Stop any centralized subscriptions started with [startForDriver]
  Future<void> stopForDriver() async {
    try {
      await _dailySub?.cancel();
      _dailySub = null;
    } catch (_) {}
    try {
      await _putovanjaSub?.cancel();
      _putovanjaSub = null;
    } catch (_) {}
  }

  void _emitCombinedPutnici() {
    try {
      final combined = <Putnik>[];
      // Convert putovanja rows
      for (final r in _lastPutovanjaRows) {
        try {
          combined.add(Putnik.fromMap(r));
        } catch (_) {}
      }
      // Convert monthly rows as they appear in mesecni_putnici (if any present in daily rows)
      for (final r in _lastDailyRows) {
        try {
          combined.add(Putnik.fromMap(r));
        } catch (_) {}
      }

      if (!_combinedPutniciController.isClosed) {
        _combinedPutniciController.add(combined);
      }
    } catch (e) {
      // ignore
    }
  }

  /// Expose a filtered stream for a specific isoDate. This applies client-side filter
  /// currently; later we will parametrize server queries for efficiency.
  Stream<List<Putnik>> streamKombinovaniPutnici(
      {String? isoDate, String? grad, String? vreme}) {
    if (isoDate == null && grad == null && vreme == null) {
      return combinedPutniciStream;
    }

    return combinedPutniciStream.map((list) {
      Iterable<Putnik> filtered = list;
      if (isoDate != null) {
        final targetDayAbbr = SlotUtils.isoDateToDayAbbr(isoDate);
        filtered = filtered.where((p) =>
            (p.datum != null && p.datum == isoDate) ||
            (p.datum == null &&
                GradAdresaValidator.normalizeString(p.dan).contains(
                    GradAdresaValidator.normalizeString(targetDayAbbr))));
      }
      if (grad != null) {
        filtered = filtered.where(
            (p) => GradAdresaValidator.isGradMatch(p.grad, p.adresa, grad));
      }
      if (vreme != null) {
        filtered = filtered.where((p) =>
            GradAdresaValidator.normalizeTime(p.polazak) ==
            GradAdresaValidator.normalizeTime(vreme));
      }
      return filtered.toList();
    });
  }

  /// Parametric combined stream: creates per-filter realtime subscriptions
  /// and emits only Putnik lists relevant for the given filter key.
  Stream<List<Putnik>> streamKombinovaniPutniciParametric(
      {String? isoDate, String? grad, String? vreme}) {
    if (isoDate == null && grad == null && vreme == null) {
      return combinedPutniciStream;
    }

    final key = _paramKey(isoDate: isoDate, grad: grad, vreme: vreme);
    if (_paramControllers.containsKey(key)) {
      return _paramControllers[key]!.stream;
    }

    final controller = StreamController<List<Putnik>>.broadcast();
    _paramControllers[key] = controller;
    _paramLastDaily[key] = [];
    _paramLastPutovanja[key] = [];

    final client = Supabase.instance.client;

    // Helper to emit combined for this key
    void emitForKey() {
      try {
        final combined = <Putnik>[];
        for (final r in _paramLastPutovanja[key] ?? []) {
          try {
            combined.add(Putnik.fromMap(r));
          } catch (_) {}
        }
        for (final r in _paramLastDaily[key] ?? []) {
          try {
            combined.add(Putnik.fromMap(r));
          } catch (_) {}
        }
        if (!controller.isClosed) controller.add(combined);
      } catch (_) {}
    }

    // Subscribe to daily_checkins and daily_passengers; filter incoming rows
    final dailySub = client
        .from('daily_checkins')
        .stream(primaryKey: ['id']).listen((List<dynamic> data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in data) {
          if (r is Map<String, dynamic>) {
            // Apply client-side match by isoDate/grad/vreme
            if (isoDate != null) {
              if ((r['datum']?.toString() ?? '') != isoDate) {
                continue;
              }
            }
            if (grad != null) {
              final putnikGrad = (r['grad'] ?? '').toString();
              final putnikAdresa = (r['adresa'] ?? '').toString();
              if (!GradAdresaValidator.isGradMatch(
                  putnikGrad, putnikAdresa, grad)) {
                continue;
              }
            }
            if (vreme != null) {
              final pVreme = (r['polazak'] ?? r['vreme'] ?? '').toString();
              if (GradAdresaValidator.normalizeTime(pVreme) !=
                  GradAdresaValidator.normalizeTime(vreme)) {
                continue;
              }
            }

            rows.add(Map<String, dynamic>.from(r));
          }
        }
        _paramLastDaily[key] = rows;
        emitForKey();
      } catch (_) {}
    });

    final putovanjaSub = client
        .from('daily_passengers')
        .stream(primaryKey: ['id']).listen((List<dynamic> data) {
      try {
        final rows = <Map<String, dynamic>>[];
        for (final r in data) {
          if (r is Map<String, dynamic>) {
            if (isoDate != null) {
              // match by datum if present, otherwise accept and rely on PutnikService filtering
              if ((r['datum']?.toString() ?? '') != isoDate) {
                continue;
              }
            }
            if (grad != null) {
              final putnikGrad = (r['grad'] ?? '').toString();
              final putnikAdresa = (r['adresa'] ?? '').toString();
              if (!GradAdresaValidator.isGradMatch(
                  putnikGrad, putnikAdresa, grad)) {
                continue;
              }
            }
            if (vreme != null) {
              final pVreme = (r['polazak'] ?? r['vreme'] ?? '').toString();
              if (GradAdresaValidator.normalizeTime(pVreme) !=
                  GradAdresaValidator.normalizeTime(vreme)) {
                continue;
              }
            }
            rows.add(Map<String, dynamic>.from(r));
          }
        }
        _paramLastPutovanja[key] = rows;
        emitForKey();
      } catch (_) {}
    });

    _paramSubscriptions[key] = [dailySub, putovanjaSub];

    controller.onCancel = () async {
      try {
        for (final s in _paramSubscriptions[key] ?? []) {
          await s.cancel();
        }
      } catch (_) {}
      _paramSubscriptions.remove(key);
      _paramControllers.remove(key);
      _paramLastDaily.remove(key);
      _paramLastPutovanja.remove(key);
    };

    return controller.stream;
  }

  /// Trigger a one-off refresh (useful after resets) which will make the service re-query
  /// and emit the latest combined set.
  Future<void> refreshNow() async {
    try {
      final client = Supabase.instance.client;
      final putovanja = await client.from('daily_passengers').select();
      final daily = await client.from('daily_checkins').select();

      _lastPutovanjaRows = (putovanja as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _lastDailyRows = (daily as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      _emitCombinedPutnici();
    } catch (e) {
      // ignore
    }
  }
}


