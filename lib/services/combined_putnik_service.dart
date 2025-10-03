import '../models/putnik.dart';
import 'dnevni_putnik_service.dart';
import 'mesecni_putnik_service_novi.dart';
import 'adresa_service.dart';
import 'ruta_service.dart';
import 'realtime_service.dart';
import 'package:logger/logger.dart';
import '../utils/grad_adresa_validator.dart';
import '../utils/logging.dart';

/// Kombinovani servis za putnike - koristi normalizovanu šemu ali pruža
/// kompatibilan interfejs sa starim PutnikService-om
class CombinedPutnikService {
  final Logger _logger = Logger();
  final DnevniPutnikService _dnevniService = DnevniPutnikService();
  final MesecniPutnikServiceNovi _mesecniService = MesecniPutnikServiceNovi();
  final AdresaService _adresaService = AdresaService();
  final RutaService _rutaService = RutaService();

  /// Stream kombinovanih putnika filtriranih po parametrima
  Stream<List<Putnik>> streamKombinovaniPutniciFiltered({
    String? isoDate,
    String? grad,
    String? vreme,
  }) {
    // 🆕 Koristi RealtimeService za realtime stream
    return RealtimeService.instance.streamKombinovaniPutnici(
      isoDate: isoDate,
      grad: grad,
      vreme: vreme,
    );
  }

  /// Dohvata kombinovane putnike za dati datum
  Future<List<Putnik>> getKombinovaniPutnici({
    String? isoDate,
    String? grad,
    String? vreme,
  }) async {
    try {
      // final date = isoDate != null ? DateTime.parse(isoDate) : DateTime.now();

      // TODO: Dohvati dnevne putnike - PRIVREMENO ONEMOGUĆENO
      // final dnevniPutnici = await _dnevniService.getDnevniPutniciZaDatum(date);

      // TODO: Dohvati mesečne putnike - PRIVREMENO ONEMOGUĆENO
      // final mesecniPutnici = await _mesecniService.getAktivniMesecniPutnici();

      // Konvertuj u Putnik objekte
      final List<Putnik> result = [];

      // TODO: Konvertuj dnevne putnike - PRIVREMENO ONEMOGUĆENO
      // for (final dnevniPutnik in dnevniPutnici) {
      //   // PROBLEM: dnevniPutnik nema adresaId, rutaId ili toPutnik metodu
      //   // final adresa = await _adresaService.getAdresaById(dnevniPutnik.adresaId);
      //   // final ruta = await _rutaService.getRutaById(dnevniPutnik.rutaId);
      //   // if (adresa != null && ruta != null) {
      //   //   result.add(dnevniPutnik.toPutnik(adresa, ruta));
      //   // }
      // }

      // TODO: Konvertuj mesečne putnike za dati dan - PRIVREMENO ONEMOGUĆENO
      // final dan = _getDayAbbreviation(date.weekday);
      // for (final mesecniPutnik in mesecniPutnici) {
      //   // PROBLEM: mesecniPutnik nema adresaId, rutaId ili toPutnikList metodu
      //   // final adresa = await _adresaService.getAdresaById(mesecniPutnik.adresaId);
      //   // final ruta = await _rutaService.getRutaById(mesecniPutnik.rutaId);
      //   // if (adresa != null && ruta != null) {
      //   //   result.addAll(mesecniPutnik.toPutnikList(dan, adresa, ruta));
      //   // }
      // }

      // Filtriraj po gradu i vremenu koristeći normalizaciju (vrijeme/grad)
      final filtered = result.where((putnik) {
        if (grad != null) {
          if (!GradAdresaValidator.isGradMatch(
              putnik.grad, putnik.adresa, grad)) {
            return false;
          }
        }
        if (vreme != null) {
          // Normalize both times before comparison (handles 05:00 vs 5:00, seconds, etc.)
          if (GradAdresaValidator.normalizeTime(putnik.polazak) !=
              GradAdresaValidator.normalizeTime(vreme)) {
            return false;
          }
        }
        return true;
      }).toList();

      try {
        final sampleFiltered = filtered
            .take(10)
            .map((p) => '${p.ime}@${p.polazak}@${p.grad}')
            .toList();
        dlog(
            '🔎 [COMBINED] after filtering (grad=$grad, vreme=$vreme): ${filtered.length} -> sample: $sampleFiltered');
      } catch (_) {}

      return filtered;
    } catch (e) {
      _logger.e('Error in getKombinovaniPutnici: $e');
      return [];
    }
  }

  /// Konvertuje broj dana u nedelji u skraćenicu
  String _getDayAbbreviation(int weekday) {
    switch (weekday) {
      case 1:
        return 'pon';
      case 2:
        return 'uto';
      case 3:
        return 'sre';
      case 4:
        return 'cet';
      case 5:
        return 'pet';
      case 6:
        return 'sub';
      case 7:
        return 'ned';
      default:
        return 'pon';
    }
  }

  /// Dohvata sve putnike iz obe tabele (za kompatibilnost)
  Future<List<Putnik>> getAllPutniciFromBothTables({String? targetDay}) async {
    // TODO: Implementirati dohvatanje iz normalizovane šeme - PRIVREMENO ONEMOGUĆENO
    // PROBLEM: Ni dnevni ni mesečni modeli nemaju potrebna polja i metode
    try {
      dlog(
          '⚠️ getAllPutniciFromBothTables: Metoda privremeno onemogućena - model refactoring u toku');
      return [];

      // TODO: Implement kada se kompletira refactoring modela
      // final DateTime targetDate = ...
      // final dnevniPutnici = await _dnevniService.getDnevniPutniciZaDatum(targetDate);
      // final mesecniPutnici = await _mesecniService.getAktivniMesecniPutnici();
      // ... convert to Putnik list
    } catch (e) {
      dlog('❌ Error in getAllPutniciFromBothTables: $e');
      return [];
    }
  }

  /// Map full day name (e.g., "Ponedeljak") to short abbreviation used by model
  String _abbrevFromFullName(String fullDay) {
    switch (fullDay.toLowerCase()) {
      case 'ponedeljak':
      case 'pon':
        return 'pon';
      case 'utorak':
      case 'uto':
        return 'uto';
      case 'sreda':
      case 'sre':
        return 'sre';
      case 'četvrtak':
      case 'cet':
      case 'čet':
        return 'cet';
      case 'petak':
      case 'pet':
        return 'pet';
      case 'subota':
      case 'sub':
        return 'sub';
      case 'nedelja':
      case 'ned':
        return 'ned';
      default:
        // Fallback to 'pon' so toPutnikList can handle it; callers should pass valid day
        return 'pon';
    }
  }

  /// Dodaje putnika (za kompatibilnost)
  Future<void> dodajPutnika(Putnik putnik) async {
    // TODO: Implementirati dodavanje u normalizovanu šemu
    // Za sada samo logujemo
    _logger.i('🚀 DODAJ PUTNIKA: ${putnik.ime}');
  }

  /// Resetuje pokupljenja za nova vremena polaska (za kompatibilnost sa starim interfejsom)
  Future<void> resetPokupljenjaNaPolazak(
      String novoVreme, String grad, String currentDriver) async {
    try {
      _logger.i(
          '🔄 RESET POKUPLJENJA - novo vreme: $novoVreme, grad: $grad, vozač: $currentDriver');
      // TODO: Implementirati logiku za reset pokupljenja u normalizovanoj šemi
    } catch (e) {
      _logger.e('❌ Error in resetPokupljenjaNaPolazak: $e');
    }
  }
}
