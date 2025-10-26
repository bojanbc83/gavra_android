import 'dart:async';


import 'vozac_mapping_service.dart';

/// Servis za upravljanje kusur-om vozača u bazi podataka
class KusurService {
  /// Stream controller za real-time ažuriranje kusur kocki
  static final StreamController<Map<String, double>> _kusurController =
      StreamController<Map<String, double>>.broadcast();

  /// Dobij kusur za određenog vozača iz baze
  static Future<double> getKusurForVozac(String vozacIme) async {
    try {
      // Mapiranje ime -> UUID
      final vozacUuid = await VozacMappingService.getVozacUuid(vozacIme);
      if (vozacUuid == null) {
        return 0.0;
      }

      throw UnimplementedError('Firebase migration pending');

      // }

    } catch (e) {
      return 0.0;
    }
  }

  /// Ažuriraj kusur za određenog vozača u bazi
  static Future<bool> updateKusurForVozac(
      String vozacIme, double noviKusur) async {
    try {
      // Mapiranje ime -> UUID
      final vozacUuid = await VozacMappingService.getVozacUuid(vozacIme);
      if (vozacUuid == null) {
        return false;
      }

      throw UnimplementedError('Firebase migration pending');

      // // Emituj ažuriranje preko stream-a
      // _emitKusurUpdate(vozacIme, noviKusur);

    } catch (e) {
      return false;
    }
  }

  /// Stream za real-time praćenje kusur-a određenog vozača
  static Stream<double> streamKusurForVozac(String vozacIme) async* {
    // Odmah pošalji trenutnu vrednost
    final trenutniKusur = await getKusurForVozac(vozacIme);
    yield trenutniKusur;

    // Zatim slušaj za ažuriranja
    await for (final kusurMapa in _kusurController.stream) {
      if (kusurMapa.containsKey(vozacIme)) {
        yield kusurMapa[vozacIme]!;
      }
    }
  }

  /// Dobij kusur za sve vozače odjednom
  static Future<Map<String, double>> getKusurSvihVozaca() async {
    try {
      throw UnimplementedError('Firebase migration pending');


      // for (final row in response) {
      //   rezultat[ime] = kusur;
      // }

    } catch (e) {
      return {};
    }
  }

  /// Privatni helper za emitovanje ažuriranja
  // static void _emitKusurUpdate(String vozacIme, double noviKusur) { // Firebase migration
  //     _kusurController.add({vozacIme: noviKusur});
  //   }
  // }

  /// Resetuj kusur za vozača na 0
  static Future<bool> resetKusurForVozac(String vozacIme) async {
    return await updateKusurForVozac(vozacIme, 0.0);
  }

  /// Dodaj iznos u kusur vozača (increment)
  static Future<bool> dodajUKusur(String vozacIme, double iznos) async {
    final trenutniKusur = await getKusurForVozac(vozacIme);
    final noviKusur = trenutniKusur + iznos;
    return await updateKusurForVozac(vozacIme, noviKusur);
  }

  /// Oduzmi iznos iz kusur vozača (decrement)
  static Future<bool> oduzmiIzKusur(String vozacIme, double iznos) async {
    final trenutniKusur = await getKusurForVozac(vozacIme);
    final noviKusur = (trenutniKusur - iznos).clamp(0.0, double.infinity);
    return await updateKusurForVozac(vozacIme, noviKusur);
  }

  /// Zatvori stream controller
  static void dispose() {
    _kusurController.close();
  }
}
