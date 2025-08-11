import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:async/async.dart'; // Za StreamZip
import '../models/putnik.dart';
import 'realtime_notification_service.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/vozac_boja.dart'; // DODATO za validaciju vozača

// 🔄 UNDO STACK - Stack za čuvanje poslednih akcija
class UndoAction {
  final String
      type; // 'delete', 'pickup', 'payment', 'cancel', 'odsustvo', 'reset'
  final dynamic putnikId; // ✅ dynamic umesto int
  final Map<String, dynamic> oldData;
  final DateTime timestamp;

  UndoAction({
    required this.type,
    required this.putnikId, // ✅ dynamic umesto int
    required this.oldData,
    required this.timestamp,
  });
}

class PutnikService {
  final supabase = Supabase.instance.client;

  // 📚 UNDO STACK - Čuva poslednje akcije (max 10)
  static final List<UndoAction> _undoStack = [];
  static const int maxUndoActions = 10;

  // 📝 DODAJ U UNDO STACK
  void _addToUndoStack(
      String type, dynamic putnikId, Map<String, dynamic> oldData) {
    _undoStack.add(UndoAction(
      type: type,
      putnikId: putnikId,
      oldData: oldData,
      timestamp: DateTime.now(),
    ));

    // Ograniči stack na max broj akcija
    if (_undoStack.length > maxUndoActions) {
      _undoStack.removeAt(0);
    }
  }

  // 🔍 HELPER - Određi tabelu na osnovu putnika
  Future<String> _getTableForPutnik(dynamic id) async {
    debugPrint('🔍 DEBUG _getTableForPutnik - ID=$id (tip: ${id.runtimeType})');

    try {
      // Pokušaj prvo putovanja_istorija (int ili string ID)
      await supabase
          .from('putovanja_istorija')
          .select('id')
          .eq('id', id)
          .single();
      debugPrint('🔍 DEBUG _getTableForPutnik - pronašao u putovanja_istorija');
      return 'putovanja_istorija';
    } catch (e) {
      debugPrint(
          '🔍 DEBUG _getTableForPutnik - nije u putovanja_istorija, vraćam mesecni_putnici');
      return 'mesecni_putnici';
    }
  }

  // 🆕 UČITAJ PUTNIKA IZ BILO KOJE TABELE (po imenu)
  Future<Putnik?> getPutnikByName(String imePutnika) async {
    try {
      // Prvo pokušaj iz mesecni_putnici
      final mesecniResponse = await supabase
          .from('mesecni_putnici')
          .select('*')
          .eq('putnik_ime', imePutnika)
          .maybeSingle();

      if (mesecniResponse != null) {
        return Putnik.fromMesecniPutnici(mesecniResponse);
      }

      // Ako nije u mesecni_putnici, pokušaj iz putovanja_istorija za danas
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final putovanjaResponse = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('putnik_ime', imePutnika)
          .eq('datum', danas)
          .maybeSingle();

      if (putovanjaResponse != null) {
        return Putnik.fromPutovanjaIstorija(putovanjaResponse);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // 🆕 UČITAJ PUTNIKA IZ BILO KOJE TABELE (po ID)
  Future<Putnik?> getPutnikFromAnyTable(dynamic id) async {
    debugPrint(
        '🔍 DEBUG getPutnikFromAnyTable - ID=$id (tip: ${id.runtimeType})');

    try {
      // Prvo pokušaj iz putovanja_istorija
      final response = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('id', id)
          .limit(1);

      if (response.isNotEmpty) {
        debugPrint(
            '🔍 DEBUG getPutnikFromAnyTable - pronašao u putovanja_istorija');
        return Putnik.fromPutovanjaIstorija(response.first);
      }

      // Ako nije u putovanja_istorija, pokušaj iz mesecni_putnici
      final mesecniResponse = await supabase
          .from('mesecni_putnici')
          .select('*')
          .eq('id', id)
          .limit(1);

      if (mesecniResponse.isNotEmpty) {
        debugPrint(
            '🔍 DEBUG getPutnikFromAnyTable - pronašao u mesecni_putnici');
        return Putnik.fromMesecniPutnici(mesecniResponse.first);
      }

      debugPrint('❌ DEBUG getPutnikFromAnyTable - nije pronašao nigde');
      return null;
    } catch (e) {
      return null;
    }
  }

  // 🆕 NOVI: Učitaj sve putnike iz obe tabele
  Future<List<Putnik>> getAllPutniciFromBothTables() async {
    List<Putnik> allPutnici = [];

    try {
      // Učitaj dnevne putnike iz putovanja_istorija
      final dnevniResponse = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('tip_putnika', 'dnevni')
          .order('created_at', ascending: false);

      for (final data in dnevniResponse) {
        allPutnici.add(Putnik.fromPutovanjaIstorija(data));
      }

      // 🔧 ISPRAVKA: Učitaj i mesečne putnike kreirane kao dnevna putovanja
      final mesecniDnevniResponse = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('tip_putnika', 'mesecni')
          .order('created_at', ascending: false);

      for (final data in mesecniDnevniResponse) {
        allPutnici.add(Putnik.fromPutovanjaIstorija(data));
      }

      // 🗓️ SAMO DANAŠNJI DAN: Učitaj mesečne putnike iz mesecni_putnici SAMO za današnji dan
      // Ovo sprečava duplikate kada se kreiraju dnevna putovanja za buduće dane
      final danas = DateTime.now();
      final danasKratica = _getDayAbbreviation(danas.weekday);

      final mesecniResponse = await supabase
          .from('mesecni_putnici')
          .select('*')
          .eq('aktivan',
              true) // Koristi postojeću aktivan kolonu umesto obrisan
          .like('radni_dani', '%$danasKratica%')
          .order('created_at', ascending: false);

      for (final data in mesecniResponse) {
        // NOVA LOGIKA: Koristi fromMesecniPutniciMultiple da kreira više objekata
        final mesecniPutnici = Putnik.fromMesecniPutniciMultiple(data);
        // Filtriraj samo za današnji dan
        for (final putnik in mesecniPutnici) {
          if (putnik.dan.toLowerCase().contains(danasKratica.toLowerCase())) {
            allPutnici.add(putnik);
          }
        }
      }

      return allPutnici;
    } catch (e) {
      return [];
    }
  }

  // Helper funkcija za konverziju weekday u kraticu
  String _getDayAbbreviation(int weekday) {
    const dani = ['pon', 'uto', 'sre', 'čet', 'pet', 'sub', 'ned'];
    return dani[weekday - 1];
  }

  // 🆕 NOVI: Sačuvaj putnika u odgovarajuću tabelu (workaround - sve u mesecni_putnici)
  Future<bool> savePutnikToCorrectTable(Putnik putnik) async {
    try {
      // SVI PUTNICI - koristi mesecni_putnici tabelu kao workaround za RLS
      final data = putnik.toMesecniPutniciMap();

      if (putnik.id != null) {
        await supabase
            .from('mesecni_putnici')
            .update(data)
            .eq('id', putnik.id!);
      } else {
        await supabase.from('mesecni_putnici').insert(data);
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // ↩️ UNDO POSLEDNJU AKCIJU
  Future<String?> undoLastAction() async {
    if (_undoStack.isEmpty) {
      return 'Nema akcija za poništavanje';
    }

    final lastAction = _undoStack.removeLast();

    try {
      // Određi tabelu na osnovu ID-ja
      final tabela = await _getTableForPutnik(lastAction.putnikId);

      switch (lastAction.type) {
        case 'delete':
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
              'aktivan': true, // Vraća na aktivan umesto obrisan: false
            }).eq('id', lastAction.putnikId);
          } else {
            // putovanja_istorija - koristi novu 'status' kolonu
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'] ??
                  lastAction.oldData['status_bela_crkva_vrsac'] ??
                  'nije_se_pojavio',
            }).eq('id', lastAction.putnikId);
          }
          return 'Poništeno brisanje putnika';

        case 'pickup':
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              'broj_putovanja': lastAction.oldData['broj_putovanja'],
              'poslednje_putovanje':
                  lastAction.oldData['poslednje_putovanje'], // ✅ ISPRAVKA
            }).eq('id', lastAction.putnikId);
          } else {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
              'vreme_akcije': null, // ✅ ISPRAVKA - nova kolona
            }).eq('id', lastAction.putnikId);
          }
          return 'Poništeno pokupljanje';

        case 'payment':
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              // 'iznos': null // lastAction.oldData['iznos'] // UKLONJEN, // UKLONJEN - kolona ne postoji
              // 'datum_placanja': lastAction.oldData['datum_placanja'], // UKLONJEN - kolona ne postoji
            }).eq('id', lastAction.putnikId);
          } else {
            await supabase.from(tabela).update({
              'placeno': false,
              'iznos_placanja': null,
              'vreme_placanja': null,
            }).eq('id', lastAction.putnikId);
          }
          return 'Poništeno plaćanje';

        case 'cancel':
          if (tabela == 'mesecni_putnici') {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
            }).eq('id', lastAction.putnikId);
          } else {
            await supabase.from(tabela).update({
              'status': lastAction.oldData['status'],
              'vreme_akcije': lastAction.oldData[
                  'vreme_akcije'], // Koristi postojeću vreme_akcije kolonu
              'vozac': lastAction
                  .oldData['vozac'], // ✅ Koristi vozac umesto otkazao_vozac
            }).eq('id', lastAction.putnikId);
          }
          return 'Poništeno otkazivanje';

        default:
          return 'Nepoznata akcija za poništavanje';
      }
    } catch (e) {
      return 'Greška pri poništavanju: $e';
    }
  }

  // 📋 BROJ DOSTUPNIH UNDO AKCIJA
  int get undoActionsCount => _undoStack.length;

  // 🕒 POSLEDNJA AKCIJA INFO
  String? get lastActionInfo {
    if (_undoStack.isEmpty) return null;
    final action = _undoStack.last;
    final timeAgo = DateTime.now().difference(action.timestamp).inMinutes;
    return '${action.type} (pre ${timeAgo}min)';
  }

  /// ✅ DODAJ PUTNIKA (dnevni ili mesečni) - 🏘️ SA VALIDACIJOM GRADOVA
  Future<void> dodajPutnika(Putnik putnik) async {
    try {
      debugPrint('🚀 [DODAJ PUTNIKA] Početak dodavanja putnika: ${putnik.ime}');

      // 🚫 STRIKTNA VALIDACIJA VOZAČA
      if (!VozacBoja.isValidDriver(putnik.dodaoVozac)) {
        debugPrint('❌ [DODAJ PUTNIKA] Nevaljan vozač: ${putnik.dodaoVozac}');
        throw Exception(
            'NEVALJAN VOZAČ: "${putnik.dodaoVozac}". Dozvoljeni su samo: ${VozacBoja.validDrivers.join(", ")}');
      }
      debugPrint('✅ [DODAJ PUTNIKA] Vozač valjan: ${putnik.dodaoVozac}');

      // 🚫 VALIDACIJA GRADA
      if (GradAdresaValidator.isCityBlocked(putnik.grad)) {
        debugPrint('❌ [DODAJ PUTNIKA] Grad blokiran: ${putnik.grad}');
        throw Exception(
            'Grad "${putnik.grad}" nije dozvoljen. Dozvoljeni su samo Bela Crkva i Vršac.');
      }
      debugPrint('✅ [DODAJ PUTNIKA] Grad valjan: ${putnik.grad}');

      // 🏘️ VALIDACIJA ADRESE
      if (putnik.adresa != null && putnik.adresa!.isNotEmpty) {
        if (!GradAdresaValidator.validateAdresaForCity(
            putnik.adresa, putnik.grad)) {
          debugPrint(
              '❌ [DODAJ PUTNIKA] Adresa nije validna: ${putnik.adresa} za grad ${putnik.grad}');
          throw Exception(
              'Adresa "${putnik.adresa}" nije validna za grad "${putnik.grad}". Dozvoljene su samo adrese iz Bele Crkve i Vršca.');
        }
      }
      debugPrint('✅ [DODAJ PUTNIKA] Adresa validna: ${putnik.adresa}');

      if (putnik.mesecnaKarta == true) {
        debugPrint('📊 [DODAJ PUTNIKA] Dodajem MESEČNOG putnika...');
        // MESEČNI PUTNIK - dodaj u mesecni_putnici tabelu
        final insertData = {
          'putnik_ime': putnik.ime,
          'tip': 'radnik', // Default tip
          'polazak_bela_crkva':
              putnik.grad == 'Bela Crkva' ? putnik.polazak : null,
          'polazak_vrsac': putnik.grad == 'Vršac' ? putnik.polazak : null,
          'adresa_bela_crkva':
              putnik.grad == 'Bela Crkva' ? putnik.adresa : null,
          'adresa_vrsac': putnik.grad == 'Vršac' ? putnik.adresa : null,
          'radni_dani': putnik.dan,
          'status': 'radi', // ✅ JEDNOSTAVNO - default radi
          'aktivan': true, // Koristi postojeću aktivan kolonu umesto obrisan
        };

        debugPrint('📊 [DODAJ PUTNIKA] Insert data: $insertData');
        await supabase.from('mesecni_putnici').insert(insertData);
        debugPrint('✅ [DODAJ PUTNIKA] Mesečni putnik uspešno dodat');
      } else {
        debugPrint('📊 [DODAJ PUTNIKA] Dodajem DNEVNOG putnika...');
        // DNEVNI PUTNIK - dodaj u putovanja_istorija tabelu (RLS je sada rešen!)
        final insertData = putnik.toPutovanjaIstorijaMap();
        debugPrint('📊 [DODAJ PUTNIKA] Insert data: $insertData');
        await supabase.from('putovanja_istorija').insert(insertData);
        debugPrint('✅ [DODAJ PUTNIKA] Dnevni putnik uspešno dodat');
      }

      // 🔔 REAL-TIME NOTIFIKACIJA - Novi putnik dodat (samo za današnji dan)
      final now = DateTime.now();
      final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
      final todayName = dayNames[now.weekday - 1];

      // Proverava da li je putnik za današnji dan u nedelji
      if (putnik.dan == todayName) {
        debugPrint('📡 [DODAJ PUTNIKA] Šaljem real-time notifikaciju...');
        RealtimeNotificationService.sendRealtimeNotification(
          'Novi putnik',
          'Dodjen je novi putnik ${putnik.ime}',
          {'type': 'novi_putnik', 'putnik': putnik.ime},
        );
        debugPrint('✅ [DODAJ PUTNIKA] Real-time notifikacija poslata');
      } else {
        debugPrint(
            'ℹ️ [DODAJ PUTNIKA] Ne šaljem notifikaciju - putnik nije za danas (${putnik.dan} vs $todayName)');
      }

      debugPrint('🎉 [DODAJ PUTNIKA] SVE ZAVRŠENO USPEŠNO!');
    } catch (e) {
      debugPrint('💥 [DODAJ PUTNIKA] GREŠKA: $e');
      rethrow; // Ponovno baci grešku da je home_screen može uhvatiti
    }
  }

  /// ✅ KOMBINOVANI STREAM SVIH PUTNIKA (iz obe tabele) - REAL-TIME sa ERROR HANDLING
  Stream<List<Putnik>> streamKombinovaniPutnici() {
    debugPrint('🔄 [PUTNIK SERVICE] Pokretam kombinovani real-time stream...');

    // Pokušaj real-time stream sa error handling
    return StreamZip([
      // Stream mesečnih putnika sa error handling
      supabase
          .from('mesecni_putnici')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .handleError((error) {
            debugPrint('❌ [PUTNIK SERVICE] Greška u mesečni stream: $error');
            return <dynamic>[]; // Vrati prazan niz u slučaju greške
          }),
      // Stream dnevnih putnika sa error handling
      supabase
          .from('putovanja_istorija')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(100)
          .handleError((error) {
            debugPrint('❌ [PUTNIK SERVICE] Greška u dnevni stream: $error');
            return <dynamic>[]; // Vrati prazan niz u slučaju greške
          }),
    ]).handleError((error) {
      debugPrint('❌ [PUTNIK SERVICE] StreamZip greška: $error');
      // Ako se StreamZip potpuno pokvari, povuci se na fallback
      return [<dynamic>[], <dynamic>[]];
    }).map((List<dynamic> kombinovaniData) {
      try {
        final mesecniData = kombinovaniData[0] as List<dynamic>;
        final dnevniData = kombinovaniData[1] as List<dynamic>;

        List<Putnik> sviPutnici = [];

        debugPrint(
            '📊 [PUTNIK SERVICE] Real-time: ${mesecniData.length} mesečnih + ${dnevniData.length} dnevnih putnika');

        // 1. Dodaj mesečne putnike (filtriraj obrisane)
        for (final item in mesecniData) {
          try {
            // ✅ FILTRIRANJE: Prikaži samo aktivne koji NISU obrisani
            if (item['aktivan'] == true && item['obrisan'] != true) {
              final mesecniPutnici = Putnik.fromMesecniPutniciMultiple(item);
              sviPutnici.addAll(mesecniPutnici);
            }
          } catch (e) {
            debugPrint(
                '❌ [PUTNIK SERVICE] Greška pri mapiranju mesečnog putnika: $e');
          }
        }

        // 2. Dodaj dnevne putnike (real-time!) - filtriraj u kodu
        for (final item in dnevniData) {
          try {
            // Filtriraj po tip_putnika i obrisan statusu
            if (item['tip_putnika'] == 'dnevni' && item['obrisan'] != true) {
              final putnik = Putnik.fromPutovanjaIstorija(item);
              debugPrint(
                  '📍 [PUTNIK SERVICE] Real-time mapiran putnik: ${putnik.ime}, dan: ${putnik.dan}, polazak: ${putnik.polazak}, grad: ${putnik.grad}');
              sviPutnici.add(putnik);
            }
          } catch (e) {
            debugPrint(
                '❌ [PUTNIK SERVICE] Greška pri mapiranju dnevnog putnika: $e');
          }
        }

        // ✅ SORTIRANJE: Otkazani na dno
        sviPutnici.sort((a, b) {
          // Prvo sortiranje: aktivan vs otkazan
          if (a.jeOtkazan && !b.jeOtkazan) return 1; // a ide na dno
          if (!a.jeOtkazan && b.jeOtkazan) return -1; // b ide na dno

          // Ako su oba ista (oba aktivan ili oba otkazan), sortiraj po vremenu
          return (b.vremeDodavanja ?? DateTime.now())
              .compareTo(a.vremeDodavanja ?? DateTime.now());
        });

        debugPrint(
            '📈 [PUTNIK SERVICE] Real-time ukupno putnika: ${sviPutnici.length}');
        return sviPutnici;
      } catch (e) {
        debugPrint('❌ [PUTNIK SERVICE] Fatalna greška u map funkciji: $e');
        return <Putnik>[]; // Vrati prazan niz umesto crash-a
      }
    }).handleError((error) {
      debugPrint('❌ [PUTNIK SERVICE] Finalna greška: $error');
      return <Putnik>[]; // Vrati prazan niz umesto crash-a
    });
  }

  /// 🚨 FALLBACK - Statičko učitavanje kada real-time ne radi
  Stream<List<Putnik>> _fallbackStaticStream() {
    return Stream.periodic(const Duration(seconds: 30), (_) {
      return _loadStaticData();
    }).asyncMap((future) => future);
  }

  /// � Statičko učitavanje podataka
  Future<List<Putnik>> _loadStaticData() async {
    debugPrint('🔄 [PUTNIK SERVICE] Fallback - statičko učitavanje...');
    try {
      List<Putnik> sviPutnici = [];

      // 1. Učitaj mesečne putnike
      final mesecniData = await supabase
          .from('mesecni_putnici')
          .select('*')
          .eq('aktivan', true)
          .neq('obrisan', true)
          .order('created_at', ascending: false);

      for (final item in mesecniData) {
        final mesecniPutnici = Putnik.fromMesecniPutniciMultiple(item);
        sviPutnici.addAll(mesecniPutnici);
      }

      // 2. Učitaj dnevne putnike
      final dnevniData = await supabase
          .from('putovanja_istorija')
          .select('*')
          .eq('tip_putnika', 'dnevni')
          .neq('obrisan', true)
          .order('created_at', ascending: false)
          .limit(100);

      for (final item in dnevniData) {
        final putnik = Putnik.fromPutovanjaIstorija(item);
        sviPutnici.add(putnik);
      }

      // Sortiranje
      sviPutnici.sort((a, b) {
        if (a.jeOtkazan && !b.jeOtkazan) return 1;
        if (!a.jeOtkazan && b.jeOtkazan) return -1;
        return (b.vremeDodavanja ?? DateTime.now())
            .compareTo(a.vremeDodavanja ?? DateTime.now());
      });

      debugPrint(
          '📈 [PUTNIK SERVICE] Fallback ukupno putnika: ${sviPutnici.length}');
      return sviPutnici;
    } catch (e) {
      debugPrint('❌ [PUTNIK SERVICE] Greška u fallback: $e');
      return <Putnik>[];
    }
  }

  /// ✅ STREAM SVIH PUTNIKA (iz mesecni_putnici tabele - workaround za RLS)
  Stream<List<Putnik>> streamPutnici() {
    return supabase
        .from('mesecni_putnici')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          final allPutnici = <Putnik>[];
          for (final item in data) {
            // NOVA LOGIKA: Koristi fromMesecniPutniciMultiple
            final mesecniPutnici = Putnik.fromMesecniPutniciMultiple(item);
            allPutnici.addAll(mesecniPutnici);
          }
          return allPutnici;
        });
  }

  /// 📊 NOVA METODA - Stream mesečnih putnika sa filterom po gradu
  Stream<List<Putnik>> streamMesecniPutnici(String grad) {
    return supabase
        .from('mesecni_putnici')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          final Map<String, Putnik> uniquePutnici =
              {}; // Mapa po imenima da izbegnemo duplikate

          for (final item in data) {
            // Preskačemo obrisane putnike
            if (item['aktivan'] != true) continue;

            bool dodaj = false;
            String? adresa;

            // Filter po gradu - proveri odgovarajuće adresno polje
            if (grad == 'Bela Crkva') {
              if (item['adresa_bela_crkva'] != null &&
                  item['adresa_bela_crkva'].toString().trim().isNotEmpty) {
                dodaj = true;
                adresa = item['adresa_bela_crkva'];
              }
            } else if (grad == 'Vršac') {
              if (item['adresa_vrsac'] != null &&
                  item['adresa_vrsac'].toString().trim().isNotEmpty) {
                dodaj = true;
                adresa = item['adresa_vrsac'];
              }
            }

            if (dodaj) {
              final ime = item['ime']?.toString() ?? '';

              // Dodaj ili ažuriraj putnika u mapi (samo jedan po imenu)
              uniquePutnici[ime] = Putnik.fromMap({
                'id': item['id'],
                'ime': ime,
                'mesecna_karta': true,
                'status': item['status'],
                'tip_putnika': item['tip'],
                'aktivan': item['aktivan'],
                'iznos_placanja': null,
                'vreme_placanja': null,

                'adresa': adresa,
                'vreme_dodavanja': item['created_at'],
                'broj_putovanja': item['broj_putovanja'],
                'poslednja_voznja': item['poslednja_voznja'],
                // Meta podaci za mesečne putnike
                'grad': grad, // Eksplicitno postavljamo grad
                'polazak': '', // Prazan jer mesečni nemaju polazak
                'dan': item['dan'] ?? '', // Dan iz baze podataka
              });
            }
          }

          final List<Putnik> mesecniPutnici = uniquePutnici.values.toList();

          return mesecniPutnici;
        });
  }

  /// 📊 NOVA METODA - Stream mesečnih putnika sa filterom po gradu i danu
  Stream<List<Putnik>> streamMesecniPutniciPoGraduDanu(
      String grad, String dan) {
    return supabase
        .from('mesecni_putnici')
        .stream(primaryKey: ['id'])
        .eq('dan', dan) // Filtriranje po danu
        .order('created_at', ascending: false)
        .map((data) {
          final Map<String, Putnik> uniquePutnici =
              {}; // Mapa po imenima da izbegnemo duplikate

          for (final item in data) {
            // Preskačemo obrisane putnike
            if (item['aktivan'] != true) continue;

            bool dodaj = false;
            String? adresa;

            // Filter po gradu - proveri odgovarajuće adresno polje
            if (grad == 'Bela Crkva') {
              if (item['adresa_bela_crkva'] != null &&
                  item['adresa_bela_crkva'].toString().trim().isNotEmpty) {
                dodaj = true;
                adresa = item['adresa_bela_crkva'];
              }
            } else if (grad == 'Vršac') {
              if (item['adresa_vrsac'] != null &&
                  item['adresa_vrsac'].toString().trim().isNotEmpty) {
                dodaj = true;
                adresa = item['adresa_vrsac'];
              }
            }

            if (dodaj) {
              final ime = item['ime']?.toString() ?? '';

              // Dodaj ili ažuriraj putnika u mapi (samo jedan po imenu)
              uniquePutnici[ime] = Putnik.fromMap({
                'id': item['id'],
                'ime': ime,
                'mesecna_karta': true,
                'status': item['status'],
                'tip_putnika': item['tip'],
                'aktivan': item['aktivan'],
                'iznos_placanja': null,
                'vreme_placanja': null,

                'adresa': adresa,
                'vreme_dodavanja': item['created_at'],
                'broj_putovanja': item['broj_putovanja'],
                'poslednja_voznja': item['poslednja_voznja'],
                // Meta podaci za mesečne putnike
                'grad': grad, // Eksplicitno postavljamo grad
                'polazak': '', // Prazan jer mesečni nemaju polazak
                'dan': item['dan'] ?? '', // Dan iz baze podataka
              });
            }
          }

          final List<Putnik> mesecniPutnici = uniquePutnici.values.toList();

          return mesecniPutnici;
        });
  }

  /// ✅ OBRISI PUTNIKA (Soft Delete - čuva statistike)
  Future<void> obrisiPutnika(dynamic id) async {
    debugPrint('🗑️ [BRISANJE] Brišem putnika ID: $id');

    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);
    debugPrint('🗑️ [BRISANJE] Tabela: $tabela');

    // Prvo dohvati podatke putnika za undo stack
    final response = await supabase.from(tabela).select().eq('id', id).single();

    // 📝 DODAJ U UNDO STACK
    _addToUndoStack('delete', id, response);

    // ✅ KONZISTENTNO BRISANJE - obe tabele imaju obrisan kolonu
    await supabase.from(tabela).update({
      'obrisan': true, // ✅ Sada POSTOJI u obe tabele
      'status': 'obrisan', // Dodatno označavanje u status
      'vreme_akcije': DateTime.now().toIso8601String(),
    }).eq('id', id);

    debugPrint('🗑️ [BRISANJE] Putnik označen kao obrisan u tabeli: $tabela');
  }

  /// ✅ OZNAČI KAO POKUPLJEN
  Future<void> oznaciPokupljen(dynamic id, String currentDriver) async {
    debugPrint(
        '🔍 DEBUG oznaciPokupljen - ID=$id (tip: ${id.runtimeType}), vozač=$currentDriver');

    // STRIKTNA VALIDACIJA VOZAČA
    if (!VozacBoja.isValidDriver(currentDriver)) {
      throw ArgumentError(
          'NEVALJAN VOZAČ: "$currentDriver". Dozvolje\\\\ni su samo: ${VozacBoja.validDrivers.join(", ")}');
    }

    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);
    debugPrint('🔍 DEBUG oznaciPokupljen - tabela=$tabela');

    // Prvo dohvati podatke putnika za notifikaciju
    final response = await supabase.from(tabela).select().eq('id', id).single();
    final putnik = Putnik.fromMap(response);
    debugPrint(
        '🔍 DEBUG oznaciPokupljen - putnik.ime=${putnik.ime}, mesecnaKarta=${putnik.mesecnaKarta}');

    // 📝 DODAJ U UNDO STACK
    _addToUndoStack('pickup', id, response);

    if (tabela == 'mesecni_putnici') {
      // Za mesečne putnike ažuriraj samo poslednje_putovanje (pickup timestamp)
      // 🕐 KORISTI JEDNOSTAVAN ISO STRING - automatski timezone handling
      final now = DateTime.now();
      debugPrint(
          '🔍 DEBUG oznaciPokupljen - ažuriram mesečnog putnika sa now=$now (ISO: ${now.toIso8601String()})');

      await supabase.from(tabela).update({
        'poslednje_putovanje':
            now.toIso8601String(), // ✅ JEDNOSTAVAN ISO STRING
      }).eq('id', id);

      debugPrint('🔍 DEBUG oznaciPokupljen - mesečni putnik ažuriran!');
    } else {
      // Za putovanja_istorija koristi novu 'status' kolonu
      debugPrint('🔍 DEBUG oznaciPokupljen - ažuriram dnevnog putnika');

      await supabase.from(tabela).update({
        'status': 'pokupljen',
        'vreme_akcije': DateTime.now().toIso8601String(),
      }).eq('id', id);

      debugPrint('🔍 DEBUG oznaciPokupljen - dnevni putnik ažuriran!');
    }

    // 📊 AŽURIRAJ STATISTIKE ako je mesečni putnik i pokupljen je
    if (putnik.mesecnaKarta == true) {
      // Statistike se računaju dinamički kroz StatistikaService
      // bez potrebe za dodatnim ažuriranjem
    }

    // (Uklonjeno slanje notifikacije za pokupljenog putnika)
  }

  /// ✅ OZNAČI KAO PLAĆENO
  Future<void> oznaciPlaceno(
      dynamic id, double iznos, String naplatioVozac) async {
    // ✅ dynamic umesto int
    // STRIKTNA VALIDACIJA VOZAČA
    if (!VozacBoja.isValidDriver(naplatioVozac)) {
      throw ArgumentError(
          'NEVALJAN VOZAČ: "$naplatioVozac". Dozvoljeni su samo: ${VozacBoja.validDrivers.join(", ")}');
    }

    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);

    // Prvo dohvati podatke putnika za notifikaciju
    final response = await supabase.from(tabela).select().eq('id', id).single();

    // 📝 DODAJ U UNDO STACK
    _addToUndoStack('payment', id, response);

    if (tabela == 'mesecni_putnici') {
      // Za mesečne putnike koristi njihove kolone
      await supabase.from(tabela).update({
        // 'iznos': iznos, // UKLONJEN - kolona ne postoji

        // 'datum_placanja': DateTime.now().toIso8601String(), // UKLONJEN - kolona ne postoji
      }).eq('id', id);
    } else {
      // Za putovanja_istorija koristi cena kolonu
      await supabase.from(tabela).update({
        'cena': iznos,
        'vreme_akcije': DateTime.now().toIso8601String(),
      }).eq('id', id);
    }

    // (Uklonjeno slanje notifikacije za plaćanje)
  }

  /// ✅ OTKAZI PUTNIKA
  Future<void> otkaziPutnika(dynamic id, String otkazaoVozac) async {
    // ✅ dynamic umesto int
    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);

    // Prvo dohvati podatke putnika za notifikaciju
    final response = await supabase.from(tabela).select().eq('id', id).single();

    // 📝 DODAJ U UNDO STACK
    _addToUndoStack('cancel', id, response);

    if (tabela == 'mesecni_putnici') {
      // Za mesečne putnike koristi 'status' kolonu za otkazivanje
      await supabase.from(tabela).update({
        'status': 'otkazano',
      }).eq('id', id);
    } else {
      // Za putovanja_istorija koristi novu 'status' kolonu
      await supabase.from(tabela).update({
        'status': 'otkazano',
        'vreme_akcije': DateTime.now().toIso8601String(),
      }).eq('id', id);
    }

    // 📬 POŠALJI NOTIFIKACIJU ZA OTKAZIVANJE (za tekući dan)
    try {
      final now = DateTime.now();
      final dayNames = ['Pon', 'Uto', 'Sre', 'Čet', 'Pet', 'Sub', 'Ned'];
      final todayName = dayNames[now.weekday - 1];

      // Proverava da li je otkazani putnik za današnji dan u nedelji
      final putnikDan = response['dan'] ?? '';

      // ✅ POBOLJŠANA LOGIKA - proverava da li današnji dan sadrži u listi dana putnika
      // Za mesečne putnike dan može biti "pon,uto,sre,cet,pet", pa treba da proverava sadrži li današnji dan
      final danLowerCase = putnikDan.toLowerCase();
      final todayLowerCase = todayName.toLowerCase();

      if (danLowerCase.contains(todayLowerCase) || putnikDan == todayName) {
        debugPrint(
            '📬 Šaljem notifikaciju za otkazivanje putnika: ${response['putnik_ime']} za dan: $todayName (putnikDan: $putnikDan)');
        RealtimeNotificationService.sendRealtimeNotification(
          'Otkazan putnik',
          'Otkazan je putnik ${response['putnik_ime']}',
          {'type': 'otkazan_putnik', 'putnik': response['putnik_ime']},
        );
      } else {
        debugPrint(
            '📬 Ne šaljem notifikaciju - putnik nije za današnji dan. Putnik dan: $putnikDan, Današnji dan: $todayName');
      }
    } catch (e) {
      debugPrint('📬 Greška pri slanju notifikacije za otkazivanje: $e');
      // Greška pri slanju notifikacije - ne prekidaj otkazivanje
    }
  }

  /// ✅ DOHVATI PO GRADU, DANU, VREMENU (iz putovanja_istorija)
  Future<List<Putnik>> getPutniciZaGradDanVreme(
    String grad,
    String dan,
    String vreme,
  ) async {
    final data = await supabase
        .from('putovanja_istorija')
        .select()
        .eq('tip_putnika', 'dnevni')
        .eq('adresa_polaska', grad) // koristimo adresa_polaska umesto grad
        .eq('vreme_polaska', vreme)
        .neq('status', 'otkazano') as List<dynamic>?;

    if (data == null) return [];
    return data.map((e) => Putnik.fromMap(e)).toList();
  }

  /// 📊 PREDVIĐANJE BROJ PUTNIKA (iz putovanja_istorija)
  Future<Map<String, dynamic>> getPredvidjanje() async {
    try {
      // Dohvati sve putnike iz putovanja_istorija iz poslednja 4 nedelje
      final fourWeeksAgo = DateTime.now().subtract(const Duration(days: 28));

      final data = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('tip_putnika', 'dnevni')
          .gte('created_at', fourWeeksAgo.toIso8601String())
          .neq('status', 'otkazano') as List<dynamic>?;

      if (data == null || data.isEmpty) {
        return {
          'ukupno_prosek': 0.0,
          'po_danima': <String, double>{},
          'po_vremenima': <String, double>{},
          'po_gradovima': <String, double>{},
          'preporuke': <String>[],
        };
      }

      final putnici = data.map((e) => Putnik.fromMap(e)).toList();

      // Grupisanje po danima
      final poDanima = <String, List<Putnik>>{};
      final poVremenima = <String, List<Putnik>>{};
      final poGradovima = <String, List<Putnik>>{};

      for (final putnik in putnici) {
        // Po danima
        poDanima.putIfAbsent(putnik.dan, () => []).add(putnik);

        // Po vremenima
        final vreme = putnik.polazak;
        poVremenima.putIfAbsent(vreme, () => []).add(putnik);

        // Po gradovima
        final grad = putnik.grad;
        poGradovima.putIfAbsent(grad, () => []).add(putnik);
      }

      // Proseci
      final prosekPoDanima = <String, double>{};
      poDanima.forEach((dan, lista) {
        prosekPoDanima[dan] = lista.length / 4.0; // 4 nedelje
      });

      final prosekPoVremenima = <String, double>{};
      poVremenima.forEach((vreme, lista) {
        prosekPoVremenima[vreme] = lista.length / 4.0;
      });

      final prosekPoGradovima = <String, double>{};
      poGradovima.forEach((grad, lista) {
        prosekPoGradovima[grad] = lista.length / 4.0;
      });

      // Preporuke na osnovu podataka
      final preporuke = <String>[];

      // Najpopularniji dan
      if (prosekPoDanima.isNotEmpty) {
        final najpopularnijiDan =
            prosekPoDanima.entries.reduce((a, b) => a.value > b.value ? a : b);
        preporuke.add(
            'Najpopularniji dan: ${najpopularnijiDan.key} (${najpopularnijiDan.value.toStringAsFixed(1)} putnika/dan)');
      }

      // Najpopularnije vreme
      if (prosekPoVremenima.isNotEmpty) {
        final najpopularnijeVreme = prosekPoVremenima.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        preporuke.add(
            'Najpopularnije vreme: ${najpopularnijeVreme.key} (${najpopularnijeVreme.value.toStringAsFixed(1)} putnika/dan)');
      }

      // Najpopularniji grad
      if (prosekPoGradovima.isNotEmpty) {
        final najpopularnijiGrad = prosekPoGradovima.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        preporuke.add(
            'Najpopularniji grad: ${najpopularnijiGrad.key} (${najpopularnijiGrad.value.toStringAsFixed(1)} putnika/dan)');
      }

      // Dodatne preporuke
      if (prosekPoDanima['Pet'] != null && prosekPoDanima['Pet']! > 15) {
        preporuke.add(
            '⚠️ Petak je često preopterećen - razmisliti o dodatnim polascima');
      }

      if (prosekPoVremenima['7:00'] != null &&
          prosekPoVremenima['7:00']! > 12) {
        preporuke.add('🌅 Jutarnji polasci (7:00) su vrlo popularni');
      }

      return {
        'ukupno_prosek': putnici.length / 4.0,
        'po_danima': prosekPoDanima,
        'po_vremenima': prosekPoVremenima,
        'po_gradovima': prosekPoGradovima,
        'preporuke': preporuke,
        'period_analiza':
            '${fourWeeksAgo.day}/${fourWeeksAgo.month} - ${DateTime.now().day}/${DateTime.now().month}',
      };
    } catch (e) {
      return {
        'error': 'Greška pri analizi: $e',
        'ukupno_prosek': 0.0,
        'po_danima': <String, double>{},
        'po_vremenima': <String, double>{},
        'po_gradovima': <String, double>{},
        'preporuke': <String>[],
      };
    }
  }

  // 📊 Statistike po mesecima (kombinovano dnevni i mesečni putnici)
  Future<Map<String, int>> getBrojVoznjiPoMesecima(String imePutnika) async {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);

    // Dohvati iz putovanja_istorija
    final dnevniData = await supabase
        .from('putovanja_istorija')
        .select()
        .eq('putnik_ime', imePutnika)
        .eq('tip_putnika', 'dnevni')
        .gte('created_at', startOfYear.toIso8601String());

    final mesecniData = await supabase
        .from('mesecni_putnici')
        .select()
        .eq('putnik_ime', imePutnika)
        .eq('aktivan', true)
        .gte('created_at', startOfYear.toIso8601String());

    final List<Putnik> voznje = [
      ...(dnevniData as List).map((e) => Putnik.fromMap(e)),
      ...(mesecniData as List).map((e) => Putnik.fromMap({
            ...e,
            'created_at': e['created_at'],
            'status': e['status'] ?? 'radi', // ✅ JEDNOSTAVNO
          })),
    ];

    // Grupisanje po mesecu i danu
    final Map<String, Map<String, List<Putnik>>> poMesecuDanu = {};
    for (var v in voznje) {
      if (v.vremeDodavanja != null) {
        final mesec =
            '${v.vremeDodavanja!.month.toString().padLeft(2, '0')}.${v.vremeDodavanja!.year}';
        final dan =
            v.vremeDodavanja!.toIso8601String().substring(0, 10); // yyyy-MM-dd
        poMesecuDanu.putIfAbsent(mesec, () => {});
        poMesecuDanu[mesec]!.putIfAbsent(dan, () => []);
        poMesecuDanu[mesec]![dan]!.add(v);
      }
    }

    // Za svaki dan proveri: ako postoji bar jedan putnik koji NIJE otkazan, bolovanje ili godišnji, broji se kao vožnja
    final Map<String, int> brojPoMesecima = {};
    poMesecuDanu.forEach((mesec, daniMap) {
      int brojac = 0;
      daniMap.forEach((dan, listaPutnika) {
        final allExcluded = listaPutnika.every((p) => (p.status != null &&
            (p.status!.toLowerCase() == 'otkazano' ||
                p.status!.toLowerCase() == 'otkazan' ||
                p.status!.toLowerCase() == 'bolovanje' ||
                p.status!.toLowerCase() == 'godisnji')));
        if (!allExcluded) {
          brojac++;
        }
      });
      brojPoMesecima[mesec] = brojac;
    });
    return brojPoMesecima;
  }

  /// 🚫 OZNAČI KAO BOLOVANJE/GODIŠNJI (samo za admin)
  Future<void> oznaciBolovanjeGodisnji(
      dynamic id, String tipOdsustva, String currentDriver) async {
    // ✅ dynamic umesto int
    // Određi tabelu na osnovu ID-ja
    final tabela = await _getTableForPutnik(id);

    // Prvo dohvati podatke putnika za undo stack
    final response = await supabase.from(tabela).select().eq('id', id).single();

    // 📝 DODAJ U UNDO STACK
    _addToUndoStack('odsustvo', id, response);

    if (tabela == 'mesecni_putnici') {
      // ✅ JEDNOSTAVNO - samo setuj status na bolovanje/godisnji
      await supabase.from(tabela).update({
        'status': tipOdsustva.toLowerCase(), // 'bolovanje' ili 'godisnji'
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } else {
      // Za putovanja_istorija koristi 'status' kolonu
      await supabase.from(tabela).update({
        'status': tipOdsustva.toLowerCase(), // 'bolovanje' ili 'godisnji'
        'vreme_akcije': DateTime.now().toIso8601String(),
      }).eq('id', id);
    }
  }

  /// 🔄 RESETUJ KARTICU U POČETNO STANJE (samo za validne vozače)
  Future<void> resetPutnikCard(String imePutnika, String currentDriver) async {
    try {
      debugPrint('🔄 RESET START - $imePutnika: vozač=$currentDriver');

      if (!VozacBoja.isValidDriver(currentDriver)) {
        debugPrint(
            '❌ RESET FAILED - $imePutnika: nevaljan vozač $currentDriver');
        throw Exception('Samo validni vozači mogu da resetuju kartice');
      }

      debugPrint('✅ RESET VOZAČ VALJAN - $imePutnika: nastavljam sa resetom');

      // Pokušaj reset u mesecni_putnici tabeli
      try {
        debugPrint('🔍 RESET - $imePutnika: tražim u mesecni_putnici');
        final mesecniResponse = await supabase
            .from('mesecni_putnici')
            .select()
            .eq('putnik_ime', imePutnika)
            .maybeSingle();

        if (mesecniResponse != null) {
          debugPrint(
              '🔄 RESET MESECNI PUTNIK - $imePutnika: resetujem status, poslednje_putovanje');
          await supabase.from('mesecni_putnici').update({
            'status': 'radi', // ✅ JEDNOSTAVNO - samo jedna kolona!
            'poslednje_putovanje': null, // ✅ KLJUČNO - ovo je vremePokupljenja!
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('putnik_ime', imePutnika);

          debugPrint('✅ RESET MESECNI PUTNIK ZAVRŠEN - $imePutnika');
          return;
        }

        debugPrint('❌ RESET - $imePutnika: nije pronađen u mesecni_putnici');
      } catch (e) {
        debugPrint('❌ RESET MESECNI ERROR - $imePutnika: $e');
        // Ako nema u mesecni_putnici, nastavi sa putovanja_istorija
      }

      // Pokušaj reset u putovanja_istorija tabeli
      debugPrint('🔍 RESET - $imePutnika: tražim u putovanja_istorija');
      final danas = DateTime.now().toIso8601String().split('T')[0];
      final putovanjaResponse = await supabase
          .from('putovanja_istorija')
          .select()
          .eq('putnik_ime', imePutnika)
          .eq('datum', danas)
          .maybeSingle();

      if (putovanjaResponse != null) {
        debugPrint(
            '🔄 RESET DNEVNI PUTNIK - $imePutnika: resetujem status i cenu');
        await supabase
            .from('putovanja_istorija')
            .update({
              'status': 'nije_se_pojavio',
              'cena': 0,
              'vreme_akcije': DateTime.now().toIso8601String(),
            })
            .eq('putnik_ime', imePutnika)
            .eq('datum', danas);

        debugPrint('✅ RESET DNEVNI PUTNIK ZAVRŠEN - $imePutnika');
      } else {
        debugPrint(
            '❌ RESET - $imePutnika: nije pronađen ni u putovanja_istorija za danas');
      }
    } catch (e) {
      debugPrint('❌ RESET CARD ERROR - $imePutnika: $e');
      // Greška pri resetovanju kartice
      rethrow;
    }
  }

  /// 🔄 RESETUJ POKUPLJENE PUTNIKE KADA SE PROMENI VREME POLASKA
  Future<void> resetPokupljenjaNaPolazak(
      String novoVreme, String grad, String currentDriver) async {
    try {
      debugPrint(
          '🔄 RESET POKUPLJENJA - novo vreme: $novoVreme, grad: $grad, vozač: $currentDriver');

      if (!VozacBoja.isValidDriver(currentDriver)) {
        debugPrint(
            '❌ RESET POKUPLJENJA FAILED - nevaljan vozač $currentDriver');
        return;
      }

      // Resetuj mesečne putnike koji su pokupljeni van trenutnog vremena polaska
      try {
        final mesecniPutnici = await supabase
            .from('mesecni_putnici')
            .select(
                'id, putnik_ime, polazak_bela_crkva, polazak_vrsac, poslednje_putovanje')
            .eq('aktivan', true)
            .not('poslednje_putovanje', 'is', null);

        for (final putnik in mesecniPutnici) {
          final ime = putnik['putnik_ime'] as String;
          final vremePokupljenja =
              DateTime.tryParse(putnik['poslednje_putovanje'] as String);

          if (vremePokupljenja == null) continue;

          // Provjeri polazak za odgovarajući grad
          String? polazakVreme;
          if (grad == 'Bela Crkva') {
            polazakVreme = putnik['polazak_bela_crkva'] as String?;
          } else if (grad == 'Vršac') {
            polazakVreme = putnik['polazak_vrsac'] as String?;
          }

          if (polazakVreme == null ||
              polazakVreme.isEmpty ||
              polazakVreme == '00:00:00') {
            continue;
          }

          // Provjeri da li je pokupljen van vremenskog okvira novog polaska
          final novoPolazakSati = int.tryParse(novoVreme.split(':')[0]) ?? 0;
          final pokupljenSati = vremePokupljenja.hour;
          final razlika = (pokupljenSati - novoPolazakSati).abs();

          // Ako je pokupljen van tolerancije (±3 sata) od novog vremena polaska, resetuj ga
          if (razlika > 3) {
            debugPrint(
                '🔄 RESETUJEM $ime - pokupljen u $pokupljenSati:XX, novo vreme polaska $novoVreme (razlika: ${razlika}h)');

            await supabase.from('mesecni_putnici').update({
              'poslednje_putovanje': null,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', putnik['id']);

            debugPrint('✅ RESETOVAN $ime - status pokupljanja očišćen');
          }
        }

        debugPrint('✅ RESET MESEČNIH PUTNIKA ZAVRŠEN');
      } catch (e) {
        debugPrint('❌ RESET MESEČNIH PUTNIKA ERROR: $e');
      }

      // Resetuj dnevne putnike koji su pokupljeni van trenutnog vremena polaska
      try {
        final danas = DateTime.now().toIso8601String().split('T')[0];
        final dnevniPutnici = await supabase
            .from('putovanja_istorija')
            .select('id, putnik_ime, vreme_polaska, vreme_akcije')
            .eq('datum', danas)
            .eq('grad', grad)
            .eq('status', 'pokupljen');

        for (final putnik in dnevniPutnici) {
          final ime = putnik['putnik_ime'] as String;
          final vremeAkcije =
              DateTime.tryParse(putnik['vreme_akcije'] as String);

          if (vremeAkcije == null) continue;

          final novoPolazakSati = int.tryParse(novoVreme.split(':')[0]) ?? 0;
          final pokupljenSati = vremeAkcije.hour;
          final razlika = (pokupljenSati - novoPolazakSati).abs();

          // Ako je pokupljen van tolerancije (±3 sata) od novog vremena polaska, resetuj ga
          if (razlika > 3) {
            debugPrint(
                '🔄 RESETUJEM DNEVNI $ime - pokupljen u $pokupljenSati:XX, novo vreme polaska $novoVreme (razlika: ${razlika}h)');

            await supabase.from('putovanja_istorija').update({
              'status': 'nije_se_pojavio',
              'cena': 0,
              'vreme_akcije': DateTime.now().toIso8601String(),
            }).eq('id', putnik['id']);

            debugPrint('✅ RESETOVAN DNEVNI $ime - status pokupljanja očišćen');
          }
        }

        debugPrint('✅ RESET DNEVNIH PUTNIKA ZAVRŠEN');
      } catch (e) {
        debugPrint('❌ RESET DNEVNIH PUTNIKA ERROR: $e');
      }

      debugPrint('✅ RESET POKUPLJENJA KOMPLETIRAN');
    } catch (e) {
      debugPrint('❌ RESET POKUPLJENJA ERROR: $e');
    }
  }
}
