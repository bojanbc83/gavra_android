import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/putnik.dart';
import 'timer_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';

/// 🚀 OPTIMIZOVANI SUPABASE REALTIME SERVICE - Sa cache i batch operacijama
class OptimizedSupabaseRealtimeService {
  static final SupabaseClient _client = Supabase.instance.client;
  static final Logger _logger = Logger();
  // static RealtimeChannel? _channel; // UKLONJENO - putnici tabela ne postoji
  static RealtimeChannel? _dnevniPutniciChannel;
  static RealtimeChannel? _mesecniPutniciChannel;
  static bool _isListening = false;
  static final List<VoidCallback> _onDataChangeCallbacks = [];

  // 🔄 BATCH NOTIFIKACIJE - Grupni događaji za performanse
  static final List<Map<String, dynamic>> _pendingNotifications = [];
  static const Duration _notificationBatchDelay = Duration(seconds: 3);

  // 📊 REALTIME DATA CACHE - grupisano po gradu, danu, vremenu
  static final Map<String, List<Map<String, dynamic>>> _realtimeDataCache = {};
  static final List<Function(Map<String, List<Map<String, dynamic>>>)>
      _dataStreamListeners = [];

  static bool _isPutnikZaDanas(Map<String, dynamic> data) {
    final today = DateTime.now();
    final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
    final todayName = dayNames[today.weekday - 1];
    return data['dan'] == todayName;
  }

  /// 🔄 GRUPIŠI PUTNIKE PO GRADU, DANU I VREMENU (ISPRAVLJEN ZA MESEČNE PUTNIKE)
  static String _getGroupKey(Map<String, dynamic> data) {
    // MESEČNI PUTNICI - detektuj na osnovu postojanja adresa kolona
    if (data.containsKey('stalno_vreme_bela_crkva') ||
        data.containsKey('stalno_vreme_vrsac') ||
        data.containsKey('adresa_bela_crkva') ||
        data.containsKey('adresa_vrsac')) {
      String grad = '';
      String vreme = '';

      // ISPRAVNO MAPIRANJE - daj prioritet adresama koje nisu prazne
      if (data['adresa_bela_crkva'] != null &&
          data['adresa_bela_crkva'].toString().trim().isNotEmpty) {
        grad = 'bela crkva';
        vreme = data['stalno_vreme_bela_crkva']?.toString().trim() ?? '';
      } else if (data['adresa_vrsac'] != null &&
          data['adresa_vrsac'].toString().trim().isNotEmpty) {
        grad = 'vrsac';
        vreme = data['stalno_vreme_vrsac']?.toString().trim() ?? '';
      } else if (data['stalno_vreme_bela_crkva'] != null) {
        // Fallback ako nema adrese ali ima vreme
        grad = 'bela crkva';
        vreme = data['stalno_vreme_bela_crkva'].toString().trim();
      } else if (data['stalno_vreme_vrsac'] != null) {
        grad = 'vrsac';
        vreme = data['stalno_vreme_vrsac'].toString().trim();
      }

      return '$grad|mesecni|$vreme';
    }

    // OBIČNI/DNEVNI PUTNICI - standardni pristup sa normalizacijom
    final grad = _normalizeString(data['grad']);
    final dan = _normalizeString(data['dan']);
    final polazak = (data['polazak'] ?? '').toString().trim();
    return '$grad|$dan|$polazak';
  }

  /// 🔍 POBOLJŠANE FILTER FUNKCIJE + NORMALIZACIJA SRPSKIH KARAKTERA
  static String _normalizeString(String? input) {
    if (input == null) return '';

    String normalized = input.toString().trim().toLowerCase();

    // 🔤 NORMALIZUJ SRPSKE KARAKTERE - ukloni kvačice za konzistentnost
    normalized = normalized
        .replaceAll('š', 's')
        .replaceAll('đ', 'd')
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('ž', 'z')
        .replaceAll('vršac', 'vrsac') // eksplicitno za glavni grad
        .replaceAll('vr?ac', 'vrsac') // terminal encoding problem
        .replaceAll('četvrtak', 'cetvrtak')
        .replaceAll('čet', 'cet');

    return normalized;
  }

  static Future<void> initialize() async {
    if (_isListening) return;

    try {
      _logger.i('🔄 Initializing optimized realtime service...');

      // 🔄 PUTNICI CHANNEL - UKLONJENO! Koristi samo putovanja_istorija i mesecni_putnici

      // 📅 PUTOVANJA ISTORIJA CHANNEL (dnevni putnici)
      _dnevniPutniciChannel = _client.channel('putovanja_istorija_realtime')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'putovanja_istorija',
          callback: _handleDnevniPutniciChange,
        )
        ..subscribe((status, [error]) {
          _logger.i('📡 Putovanja istorija channel status: $status');
          if (error != null) _logger.e('❌ Putovanja istorija error: $error');
        });

      // 📊 MESEČNI PUTNICI CHANNEL
      _mesecniPutniciChannel = _client.channel('mesecni_putnici_realtime')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mesecni_putnici',
          callback: _handleMesecniPutniciChange,
        )
        ..subscribe((status, [error]) {
          _logger.i('📡 Mesečni putnici channel status: $status');
          if (error != null) _logger.e('❌ Mesečni putnici error: $error');
        });

      _isListening = true;

      _logger.i(
          '✅ Optimized realtime service initialized with 2 channels (putovanja_istorija + mesecni_putnici)');

      // 📋 Učitaj početne podatke iz svih tabela
      await _loadInitialData();
    } catch (e) {
      _logger.e('❌ Realtime service initialization failed: $e');
    }
  }

  /// 📋 UČITAJ POČETNE PODATKE IZ SVIH TABELA
  static Future<void> _loadInitialData() async {
    try {
      _logger.i('📋 Učitavam početne podatke iz svih tabela...');

      // Očisti cache
      _realtimeDataCache.clear();

      // 1. Učitaj sve putovanja_istorija (dnevni putnici) - UKLONJENO putnici tabela

      final dnevniResponse = await _client
          .from('putovanja_istorija')
          .select()
          .eq('tip_putnika', 'dnevni');

      for (var data in dnevniResponse) {
        _addToRealtimeCache(data);
      }

      // 2. Učitaj sve mesecni_putnici

      final mesecniResponse = await _client.from('mesecni_putnici').select();

      for (var data in mesecniResponse) {
        _addToRealtimeCache(data);
      }

      final totalCount = _realtimeDataCache.values
          .fold<int>(0, (sum, lista) => sum + lista.length);
      final groupCount = _realtimeDataCache.length;

      // Debug: Cache loaded

      _logger.i(
          '✅ Učitano $totalCount putnika u $groupCount grupa (grad|dan|vreme) iz putovanja_istorija i mesecni_putnici tabela');

      // Obavesti listenere o početnim podacima
      _notifyDataStreamListeners();
    } catch (e) {
      _logger.e('❌ Greška pri učitavanju početnih podataka: $e');
    }
  }

  /// 🔄 OPTIMIZOVANI DATABASE CHANGE HANDLER - UKLONJENO jer putnici tabela ne postoji
  // static void _handleDatabaseChangeOptimized(PostgresChangePayload payload) {...}

  /// 🗑️ CACHE INVALIDATION za putnici
  static void _invalidatePutniciCache() {
    // Ukloni cache putnika kada se nešto promeni
    TimerManager.debounce(
        'cache_invalidation_putnici', const Duration(milliseconds: 500), () {
      // Memory cache se automatski invalidira
      _logger.d('🗑️ Putnici cache invalidated');
    });
  }

  /// ⚡ BATCH NOTIFIKACIJE - Grupiše promene da ne spamuje UI
  static void _scheduleDataChangeNotification() {
    TimerManager.debounce(
        'data_change_notification', const Duration(milliseconds: 300), () {
      _notifyDataChange();
    });
  }

  static void _handleNewPutnikOptimized(Map<String, dynamic> data) {
    if (kDebugMode) {
      _logger.d(
          '➕ Novi putnik: ${data['ime']} (${data['grad']} ${data['dan']} ${data['polazak']})');
    }

    // Dodaj u cache po gradu/danu/vremenu
    _addToRealtimeCache(data);

    // Pošalji notifikaciju samo za današnji dan
    if (_isPutnikZaDanas(data)) {
      _queueNotification('novi_putnik', data);
    }

    // Obavesti sve listenere o promeni podataka
    _notifyDataStreamListeners();
  }

  static void _handleUpdatedPutnikOptimized(
      Map<String, dynamic> newData, Map<String, dynamic> oldData) {
    if (kDebugMode) {
      _logger.d(
          '🔄 Ažuriran putnik: ${newData['ime']} (${newData['grad']} ${newData['dan']} ${newData['polazak']})');
    }

    // Ukloni stare podatke iz cache-a
    _removeFromRealtimeCache(oldData);

    // Dodaj nove podatke u cache
    _addToRealtimeCache(newData);

    // Pošalji notifikacije samo za današnji dan
    if (_isPutnikZaDanas(newData)) {
      // Proveri specifične promene
      final statusChanged = newData['status'] != oldData['status'];

      if (statusChanged && newData['status'] == 'Otkazano') {
        _queueNotification('otkazan_putnik', newData);
      }
      // Uklonjen 'prebacen_putnik' - funkcionalnost nije potrebna
    }

    // Obavesti sve listenere o promeni podataka
    _notifyDataStreamListeners();
  }

  static void _handleDeletedPutnikOptimized(Map<String, dynamic> data) {
    if (kDebugMode) {
      _logger.d(
          '🗑️ Obrisan putnik: ${data['ime']} (${data['grad']} ${data['dan']} ${data['polazak']})');
    }

    // Ukloni iz cache-a
    _removeFromRealtimeCache(data);

    // Obavesti sve listenere o promeni podataka
    _notifyDataStreamListeners();
  }

  /// 📊 CACHE MANAGEMENT METODE
  static void _addToRealtimeCache(Map<String, dynamic> data) {
    final key = _getGroupKey(data);

    // Debug log za mesečne putnike
    if (key.contains('mesecni')) {}

    if (!_realtimeDataCache.containsKey(key)) {
      _realtimeDataCache[key] = [];
    }

    // Proveri da li već postoji (update scenario)
    final existingIndex =
        _realtimeDataCache[key]!.indexWhere((item) => item['id'] == data['id']);

    if (existingIndex >= 0) {
      _realtimeDataCache[key]![existingIndex] = data;
    } else {
      _realtimeDataCache[key]!.add(data);
    }

    // Sortiraj po imenu
    _realtimeDataCache[key]!.sort((a, b) =>
        (a['ime'] ?? '').toString().compareTo((b['ime'] ?? '').toString()));
  }

  static void _removeFromRealtimeCache(Map<String, dynamic> data) {
    final key = _getGroupKey(data);
    if (_realtimeDataCache.containsKey(key)) {
      _realtimeDataCache[key]!.removeWhere((item) => item['id'] == data['id']);

      // Ukloni prazan ključ
      if (_realtimeDataCache[key]!.isEmpty) {
        _realtimeDataCache.remove(key);
      }
    }
  }

  static void _notifyDataStreamListeners() {
    for (final listener in _dataStreamListeners) {
      try {
        listener(Map.from(_realtimeDataCache));
      } catch (e) {
        _logger.e('❌ Data stream listener error: $e');
      }
    }
  }

  /// 📡 PUBLIC API ZA REALTIME DATA
  static Map<String, List<Map<String, dynamic>>> getCurrentRealtimeData() {
    return Map.from(_realtimeDataCache);
  }

  static void addDataStreamListener(
      Function(Map<String, List<Map<String, dynamic>>>) listener) {
    _dataStreamListeners.add(listener);
  }

  static void removeDataStreamListener(
      Function(Map<String, List<Map<String, dynamic>>>) listener) {
    _dataStreamListeners.remove(listener);
  }

  /// 🔍 FILTRIRANJE PO KRITERIJUMIMA
  static List<Map<String, dynamic>> getPutniciByGradDanVreme(
      String grad, String dan, String vreme) {
    final normalizedGrad = _normalizeString(grad);
    final normalizedDan = _normalizeString(dan);
    final normalizedVreme = vreme.trim();
    final key = '$normalizedGrad|$normalizedDan|$normalizedVreme';
    return _realtimeDataCache[key] ?? [];
  }

  static List<Map<String, dynamic>> getPutniciByGrad(String grad) {
    final normalizedGrad = _normalizeString(grad);
    final result = <Map<String, dynamic>>[];
    _realtimeDataCache.forEach((key, putnici) {
      if (key.startsWith('$normalizedGrad|')) {
        result.addAll(putnici);
      }
    });
    return result;
  }

  static List<Map<String, dynamic>> getPutniciByDan(String dan) {
    final normalizedDan = _normalizeString(dan);
    final result = <Map<String, dynamic>>[];
    _realtimeDataCache.forEach((key, putnici) {
      if (key.contains('|$normalizedDan|')) {
        result.addAll(putnici);
      }
    });
    return result;
  }

  /// 📅 DANAS PUTNICI - POBOLJŠANO FILTRIRANJE (UKLJUČUJE I MESEČNE)
  static List<Map<String, dynamic>> getPutniciZaDanas() {
    final today = DateTime.now();
    final dayNames = [
      'ponedeljak',
      'utorak',
      'sreda',
      'četvrtak',
      'petak',
      'subota',
      'nedelja'
    ];
    final todayName = dayNames[today.weekday - 1];

    final result = <Map<String, dynamic>>[];

    // Dodaj dnevne putnike za danas
    result.addAll(getPutniciByDan(todayName));

    // Dodaj sve mesečne putnike (oni putuju svaki dan)
    _realtimeDataCache.forEach((key, putnici) {
      if (key.contains('|mesecni|')) {
        // Za mesečne putnike - sada imaju grad kolonu direktno u bazi!
        for (var putnik in putnici) {
          final modifiedPutnik = Map<String, dynamic>.from(putnik);
          // Ne treba više postavljati grad iz ključa - već je u bazi
          // modifiedPutnik['grad'] već sadrži pravu vrednost iz grad kolone
          modifiedPutnik['mesecna_karta'] = true;
          result.add(modifiedPutnik);
        }
      }
    });

    return result;
  }

  /// Vraća putnike za danas kao List<Putnik> objekte (za UI)
  static List<Putnik> getPutniciZaDanasPutnik() {
    final rawData = getPutniciZaDanas();
    return rawData.map((data) => _mapToPutnik(data)).toList();
  }

  /// Konvertuje Map<String, dynamic> u Putnik objekat (ISPRAVLJEN ZA MESEČNE PUTNIKE)
  static Putnik _mapToPutnik(Map<String, dynamic> data) {
    // DETEKTUJ DA LI JE MESEČNI PUTNIK
    bool isMesecni = data.containsKey('stalno_vreme_bela_crkva') ||
        data.containsKey('stalno_vreme_vrsac') ||
        data.containsKey('adresa_bela_crkva') ||
        data.containsKey('adresa_vrsac');

    String grad = '';
    String polazak = '';
    String? adresa;

    if (isMesecni) {
      // MESEČNI PUTNICI - ispravno mapiranje
      if (data['adresa_bela_crkva'] != null &&
          data['adresa_bela_crkva'].toString().trim().isNotEmpty) {
        grad = 'Bela Crkva';
        adresa = data['adresa_bela_crkva'].toString();
        polazak = data['stalno_vreme_bela_crkva']?.toString() ?? '';
      } else if (data['adresa_vrsac'] != null &&
          data['adresa_vrsac'].toString().trim().isNotEmpty) {
        grad = 'Vršac';
        adresa = data['adresa_vrsac'].toString();
        polazak = data['stalno_vreme_vrsac']?.toString() ?? '';
      }
    } else {
      // DNEVNI PUTNICI - standardno mapiranje
      grad = data['grad']?.toString() ?? '';
      polazak = data['polazak']?.toString() ?? '';
      adresa = data['adresa']?.toString();
    }

    return Putnik(
      id: int.tryParse(data['id']?.toString() ?? '0'),
      ime: data['ime']?.toString() ?? '',
      grad: grad,
      dan: data['dan']?.toString() ?? '',
      polazak: polazak,
      adresa: adresa,
      mesecnaKarta: isMesecni,
      vozac: data['vozac']?.toString(),
      status: data['status']?.toString(),
      pokupljen: data['pokupljen'] == true || data['pokupljen'] == 1,
      iznosPlacanja: data['iznos_placanja']
          ?.toDouble(), // UKLONJEN fallback na data['iznos'] - kolona ne postoji
      vremeDodavanja: data['vreme_dodavanja'] != null
          ? DateTime.tryParse(data['vreme_dodavanja'].toString())
          : (data['created_at'] != null
              ? DateTime.tryParse(data['created_at'].toString())
              : null),
      obrisan: data['obrisan'] == true || data['obrisan'] == 1,
      placeno: data['placeno'] == true || data['placeno'] == 1,
      naplatioVozac: data['vozac']
          ?.toString(), // ✅ Koristi vozac kolonu umesto nepostojeće naplatio_vozac
      dodaoVozac: data['vozac']?.toString(), // ✅ Koristi vozac kolonu
      otkazaoVozac: data['vozac']
          ?.toString(), // ✅ Koristi vozac kolonu umesto nepostojeće otkazao_vozac
      priority: data['priority']?.toInt(),
    );
  }

  static Map<String, int> getStatistikePoGradovima() {
    final stats = <String, int>{};
    _realtimeDataCache.forEach((key, putnici) {
      final grad = key.split('|')[0];
      stats[grad] = (stats[grad] ?? 0) + putnici.length;
    });
    return stats;
  }

  /// 📅 DNEVNI PUTNICI HANDLER
  static void _handleDnevniPutniciChange(PostgresChangePayload payload) {
    _logger.d('📅 Dnevni putnici change: ${payload.eventType}');

    // Invalidate cache
    _invalidatePutniciCache();

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        _handleNewPutnikOptimized(payload.newRecord);
        break;
      case PostgresChangeEvent.update:
        _handleUpdatedPutnikOptimized(payload.newRecord, payload.oldRecord);
        break;
      case PostgresChangeEvent.delete:
        _handleDeletedPutnikOptimized(payload.oldRecord);
        break;
      default:
        break;
    }

    _scheduleDataChangeNotification();
  }

  /// 📊 MESEČNI PUTNICI HANDLER
  static void _handleMesecniPutniciChange(PostgresChangePayload payload) {
    _logger.d('📊 Mesečni putnici change: ${payload.eventType}');

    // Invalidate cache
    _invalidatePutniciCache();

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        _handleNewPutnikOptimized(payload.newRecord);
        break;
      case PostgresChangeEvent.update:
        _handleUpdatedPutnikOptimized(payload.newRecord, payload.oldRecord);
        break;
      case PostgresChangeEvent.delete:
        _handleDeletedPutnikOptimized(payload.oldRecord);
        break;
      default:
        break;
    }

    _scheduleDataChangeNotification();
  }

  static void _notifyDataChange() {
    for (final callback in _onDataChangeCallbacks) {
      try {
        callback();
      } catch (e) {
        _logger.e('❌ Data change callback error: $e');
      }
    }
  }

  static void addDataChangeListener(VoidCallback callback) {
    _onDataChangeCallbacks.add(callback);
  }

  static void removeDataChangeListener(VoidCallback callback) {
    _onDataChangeCallbacks.remove(callback);
  }

  /// LEGACY KOMPATIBILNOST - za postojeći kod
  static void registerDataChangeCallback(VoidCallback callback) {
    addDataChangeListener(callback);
  }

  static void unregisterDataChangeCallback(VoidCallback callback) {
    removeDataChangeListener(callback);
  }

  /// 📊 PERFORMANCE STATISTIKE
  static Map<String, dynamic> getPerformanceStats() {
    final totalPutnici = _realtimeDataCache.values
        .fold<int>(0, (sum, lista) => sum + lista.length);

    return {
      'is_listening': _isListening,
      'data_change_listeners': _onDataChangeCallbacks.length,
      'data_stream_listeners': _dataStreamListeners.length,
      'pending_notifications': _pendingNotifications.length,
      'cached_groups': _realtimeDataCache.length,
      'total_cached_putnici': totalPutnici,
      'groups_breakdown':
          _realtimeDataCache.map((key, value) => MapEntry(key, value.length)),
      'timer_stats': TimerManager.getStats(),
    };
  }

  /// 📬 BATCH NOTIFICATION QUEUE
  static void _queueNotification(String type, Map<String, dynamic> data) {
    _pendingNotifications.add({
      'type': type,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    // Schedule batch processing
    TimerManager.debounce(
        'notification_batch_processor', _notificationBatchDelay, () {
      _processBatchNotifications();
    });
  }

  /// 🔄 BATCH NOTIFICATION PROCESSOR
  static void _processBatchNotifications() {
    if (_pendingNotifications.isEmpty) return;

    final notifications =
        List<Map<String, dynamic>>.from(_pendingNotifications);
    _pendingNotifications.clear();

    _logger.i('📬 Processing ${notifications.length} batch notifications');

    // Grupiši po tipu
    final byType = <String, List<Map<String, dynamic>>>{};
    for (final notification in notifications) {
      final type = notification['type'] as String;
      byType.putIfAbsent(type, () => []).add(notification);
    }

    // Pošalji grupne notifikacije
    for (final entry in byType.entries) {
      switch (entry.key) {
        case 'novi_putnik':
          _sendBatchNoviPutnikNotification(entry.value);
          break;
        case 'otkazan_putnik':
          _sendBatchOtkazanPutnikNotification(entry.value);
          break;
      }
    }
  }

  /// 📬 BATCH NOVI PUTNIK NOTIFIKACIJE
  static void _sendBatchNoviPutnikNotification(
      List<Map<String, dynamic>> notifications) {
    if (notifications.isEmpty) return;

    try {
      const serverKey = 'XgBzST_isaDQVC-VKABx9BVMRvbP2dmP_vw5t12Pj8o';
      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');

      final count = notifications.length;
      final names = notifications
          .map((n) => n['data']['ime'] as String)
          .take(3)
          .join(', ');
      final moreText = count > 3 ? ' i još ${count - 3}' : '';

      final body = {
        'to': '/topics/all_drivers',
        'notification': {
          'title': '👥 $count novih putnika danas',
          'body': '$names$moreText',
          'icon': 'ic_notification',
          'sound': 'default',
        },
        'data': {
          'type': 'batch_novi_putnici',
          'count': count.toString(),
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        }
      };

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      };

      http.post(url, body: jsonEncode(body), headers: headers).then((response) {
        _logger.d('📬 Batch novi putnik notification sent: $count putnika');
      });
    } catch (e) {
      _logger.e('❌ Batch notification error: $e');
    }
  }

  /// 📬 BATCH OTKAZAN PUTNIK NOTIFIKACIJE
  static void _sendBatchOtkazanPutnikNotification(
      List<Map<String, dynamic>> notifications) {
    // Slično kao gore, ali za otkazane
    _logger.d(
        '📬 Processing ${notifications.length} otkazan putnik notifications');
  }

  /// 🧹 CLEANUP
  static Future<void> dispose() async {
    // _channel?.unsubscribe(); // UKLONJENO - putnici tabela ne postoji
    _dnevniPutniciChannel?.unsubscribe();
    _mesecniPutniciChannel?.unsubscribe();
    _onDataChangeCallbacks.clear();
    _dataStreamListeners.clear();
    _realtimeDataCache.clear();
    _pendingNotifications.clear();
    TimerManager.cancelTimer('notification_batch_processor');
    TimerManager.cancelTimer('data_change_notification');
    _isListening = false;
    _logger.i('🧹 Optimized realtime service disposed');
  }

  // Zadržavam postojeće API metode za kompatibilnost - VRAĆENO NA ORIGINALNU LOGIKU
  static Future<bool> dodajPutnika(Putnik putnik) async {
    try {
      if (putnik.mesecnaKarta == true) {
        // MESEČNI PUTNIK - ide u mesecni_putnici tabelu
        final data = <String, dynamic>{
          'putnik_ime': putnik.ime,
          'tip': 'radnik',
          'dan': putnik.dan,
          'status': 'radi',
          'aktivan': true,
        };

        // Mapiranje adrese i vremena na osnovu grada
        if (putnik.grad.toLowerCase().contains('bela')) {
          data['adresa_bela_crkva'] = putnik.adresa;
          data['polazak_bela_crkva'] = putnik.polazak;
        } else if (putnik.grad.toLowerCase().contains('vršac') ||
            putnik.grad.toLowerCase().contains('vrsac')) {
          data['adresa_vrsac'] = putnik.adresa;
          data['polazak_vrsac'] = putnik.polazak;
        }

        if (putnik.status != null) data['status'] = putnik.status;
        // if (putnik.iznosPlacanja != null) data['iznos'] = putnik.iznosPlacanja; // UKLONJEN - kolona ne postoji
        if (putnik.dodaoVozac != null) {
          data['vozac'] = putnik
              .dodaoVozac; // ✅ ISPRAVKA: koristi 'vozac' umesto 'dodao_vozac'
        }

        // print(
        //     '🔄 [OPTIMIZED SERVICE] Dodajem mesečnog putnika u mesecni_putnici: ${putnik.ime}');
        await _client.from('mesecni_putnici').insert(data);
        // print('✅ [OPTIMIZED SERVICE] Uspešno dodat mesečni putnik!');
      } else {
        // DNEVNI PUTNIK - ide u putovanja_istorija tabelu (RLS je sada rešen!)
        final data = putnik.toPutovanjaIstorijaMap();

        // print(
        //     '🔄 [OPTIMIZED SERVICE] Dodajem dnevnog putnika u putovanja_istorija: ${putnik.ime}');
        await _client.from('putovanja_istorija').insert(data);
        // print(
        //     '✅ [OPTIMIZED SERVICE] Uspešno dodat dnevni putnik u putovanja_istorija!');
      }

      // Invalidate cache
      _invalidatePutniciCache();

      return true;
    } catch (e) {
      _logger.e('❌ Dodaj putnik error: $e');
      return false;
    }
  }

  /// 🧪 DEBUG FUNKCIJE ZA TROUBLESHOOTING
  static void printDebugInfo() {}

  static List<String> getAllAvailableKeys() {
    return _realtimeDataCache.keys.toList()..sort();
  }

  static List<String> getAllGradovi() {
    final gradovi = <String>{};
    for (final key in _realtimeDataCache.keys) {
      gradovi.add(key.split('|')[0]);
    }
    return gradovi.toList()..sort();
  }

  static List<String> getAllDanovi() {
    final dani = <String>{};
    for (final key in _realtimeDataCache.keys) {
      dani.add(key.split('|')[1]);
    }
    return dani.toList()..sort();
  }

  static Map<String, dynamic> getCacheSnapshot() {
    return {
      'total_groups': _realtimeDataCache.length,
      'total_putnici': _realtimeDataCache.values
          .fold<int>(0, (sum, lista) => sum + lista.length),
      'gradovi': getAllGradovi(),
      'dani': getAllDanovi(),
      'sample_keys': _realtimeDataCache.keys.take(5).toList(),
    };
  }
}
