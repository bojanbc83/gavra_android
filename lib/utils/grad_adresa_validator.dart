/// 🏘️ UTIL ZA VALIDACIJU GRADOVA I ADRESA
/// Ograničava aplikaciju na opštine Bela Crkva i Vršac (uključujući sva naselja)
class GradAdresaValidator {
  /// 🏘️ NASELJA I ADRESE OPŠTINE BELA CRKVA
  static const List<String> naseljaOpstineBelaCrkva = [
    'bela crkva',
    'kaluđerovo',
    'jasenovo',
    'čenta',
    'grebenac',
    'krstur',
    'pločica',
    'dupljaja',
    'kruščica',
    'velika greda',
    'dobričevo',
    'posta', // Pošta Bela Crkva
  ];

  /// 🏘️ NASELJA I ADRESE OPŠTINE VRŠAC
  static const List<String> naseljaOpstineVrsac = [
    'vršac',
    'vrsac',
    'malo središte',
    'veliko središte',
    'mesić',
    'pavliš',
    'ritiševo',
    'straža',
    'straza',
    'uljma',
    'vojvodinci',
    'zagajica',
    'gudurica',
    'kuštilj',
    'marcovac',
    'potporanj',
    'sočica',
    'bolnica', // Bolnica Vršac
  ];

  /// 🔤 NORMALIZUJ SRPSKE KARAKTERE
  static String normalizeString(String? input) {
    if (input == null) {
      return '';
    }

    String normalized = input.toString().trim().toLowerCase();

    // Normalizuj srpske karaktere
    normalized = normalized
        .replaceAll('š', 's')
        .replaceAll('đ', 'd')
        .replaceAll('č', 'c')
        .replaceAll('ć', 'c')
        .replaceAll('ž', 'z')
        .replaceAll('vršac', 'vrsac')
        .replaceAll('vr?ac', 'vrsac')
        .replaceAll('četvrtak', 'cetvrtak')
        .replaceAll('čet', 'cet')
        .replaceAll('pošta', 'posta');

    return normalized;
  }

  /// 🏘️ PROVERI DA LI JE ADRESA U DOZVOLJENIM OPŠTINAMA (Bela Crkva ili Vršac)
  static bool isAdresaInAllowedCity(String? adresa, String? putnikGrad) {
    if (adresa == null || adresa.trim().isEmpty) {
      return true; // Bez adrese je OK
    }

    final normalizedAdresa = normalizeString(adresa);
    final normalizedPutnikGrad = normalizeString(putnikGrad);

    // 🚫 PRVO BLOKIRAJ EKSPLICITNO ZABRANJENE GRADOVE
    final containsVranje = normalizedAdresa.contains('vranje');
    final containsPancevo = normalizedAdresa.contains('pancevo');
    final containsBeograd = normalizedAdresa.contains('beograd');
    final containsNS = normalizedAdresa.contains('novi sad');

    if (containsVranje || containsPancevo || containsBeograd || containsNS) {
      return false; // Eksplicitno blokiraj druge gradove
    }

    // ✅ AKO GRAD PRIPADA DOZVOLJENIM OPŠTINAMA, DOZVOLI BILO KOJU ADRESU
    final gradBelongs = naseljaOpstineBelaCrkva
            .any((naselje) => normalizedPutnikGrad.contains(naselje)) ||
        naseljaOpstineVrsac
            .any((naselje) => normalizedPutnikGrad.contains(naselje));

    if (gradBelongs) {
      return true; // Dozvoli bilo koju adresu u validnim opštinama
    }

    // 🔍 PROVERI DA LI ADRESA SADRŽI POZNATA NASELJA (fallback)
    final belongsToBelaCrkva = naseljaOpstineBelaCrkva
        .any((naselje) => normalizedAdresa.contains(naselje));

    final belongsToVrsac = naseljaOpstineVrsac
        .any((naselje) => normalizedAdresa.contains(naselje));

    // Dozvoli ako pripada bilo kojoj opštini
    return belongsToBelaCrkva || belongsToVrsac;
  }

  /// 🔍 POBOLJŠANO GRAD POREĐENJE - sa cross-search logikom između opština
  /// 🎯 LOGIKA: Prvo traži u svojoj opštini, zatim proširi na drugu opštinu
  /// 🗺️ GOOGLE MAPS FRIENDLY: Dozvoljava bilo koju adresu u validnim opštinama
  static bool isGradMatch(
      String? putnikGrad, String? putnikAdresa, String selectedGrad) {
    final normalizedPutnikGrad = normalizeString(putnikGrad);
    final normalizedSelectedGrad = normalizeString(selectedGrad);
    final normalizedPutnikAdresa = normalizeString(putnikAdresa);

    // Prvo proveri da li je adresa u dozvoljenim opštinama
    if (!isAdresaInAllowedCity(putnikAdresa, putnikGrad)) {
      return false;
    }

    // 🎯 OPŠTINSKA LOGIKA - bilo koja adresa u opštini je validna
    final putnikFromBelaCrkva = naseljaOpstineBelaCrkva.any((naselje) =>
            normalizedPutnikGrad.contains(naselje) ||
            normalizedPutnikAdresa.contains(naselje)) ||
        // Ili ako je grad eksplicitno "bela crkva"
        normalizedPutnikGrad.contains('bela');

    final putnikFromVrsac = naseljaOpstineVrsac.any((naselje) =>
            normalizedPutnikGrad.contains(naselje) ||
            normalizedPutnikAdresa.contains(naselje)) ||
        // Ili ako je grad eksplicitno "vršac"
        normalizedPutnikGrad.contains('vrsac');

    // Proveri da li je selektovana opština Bela Crkva
    final selectedBelaCrkva = normalizedSelectedGrad.contains('bela');

    // Proveri da li je selektovana opština Vršac
    final selectedVrsac = normalizedSelectedGrad.contains('vrsac');

    // 🎯 CROSS-SEARCH LOGIKA
    if (selectedBelaCrkva) {
      // Prvo traži u opštini Bela Crkva
      if (putnikFromBelaCrkva) {
        return true;
      }
      // Zatim proširi pretragu na opštinu Vršac
      if (putnikFromVrsac) {
        return true;
      }
    }

    if (selectedVrsac) {
      // Prvo traži u opštini Vršac
      if (putnikFromVrsac) {
        return true;
      }
      // Zatim proširi pretragu na opštinu Bela Crkva
      if (putnikFromBelaCrkva) {
        return true;
      }
    }

    return false;
  }

  /// 📍 VALIDUJ ADRESU PRILIKOM DODAVANJA PUTNIKA
  static bool validateAdresaForCity(String? adresa, String? grad) {
    if (adresa == null || adresa.trim().isEmpty) {
      return true;
    }
    if (grad == null || grad.trim().isEmpty) {
      return false;
    }

    final normalizedGrad = normalizeString(grad);

    // Proveri da li grad pripada opštini Bela Crkva
    final belongsToBelaCrkva = naseljaOpstineBelaCrkva
        .any((naselje) => normalizedGrad.contains(naselje));

    // Proveri da li grad pripada opštini Vršac
    final belongsToVrsac =
        naseljaOpstineVrsac.any((naselje) => normalizedGrad.contains(naselje));

    if (belongsToBelaCrkva) {
      return isAdresaInAllowedCity(adresa, 'Bela Crkva');
    }

    if (belongsToVrsac) {
      return isAdresaInAllowedCity(adresa, 'Vršac');
    }

    return false; // Ako grad nije iz dozvoljenih opština, odbaci
  }

  /// 🚫 LISTA BLOKIRANIH GRADOVA
  static const List<String> blockedCities = [
    'vranje',
    'pancevo',
    'beograd',
    'novi sad',
    'nis',
    'kragujevac',
    'subotica',
    'zrenjanin',
    'novi pazar',
    'leskovac',
  ];

  /// 🚫 PROVERI DA LI JE GRAD BLOKIRAN
  static bool isCityBlocked(String? grad) {
    if (grad == null || grad.trim().isEmpty) {
      return false;
    }

    final normalizedGrad = normalizeString(grad);

    // Prvo proveri da li pripada dozvoljenim opštinama
    final belongsToBelaCrkva = naseljaOpstineBelaCrkva
        .any((naselje) => normalizedGrad.contains(naselje));

    final belongsToVrsac =
        naseljaOpstineVrsac.any((naselje) => normalizedGrad.contains(naselje));

    // Ako pripada dozvoljenim opštinama, ne blokiraj
    if (belongsToBelaCrkva || belongsToVrsac) {
      return false;
    }

    // Inače proveri da li je u listi blokiranih gradova
    return blockedCities.any((blocked) =>
        normalizedGrad.contains(blocked) || blocked.contains(normalizedGrad));
  }

  /// ⏰ NORMALIZUJ VREME - konvertuj "05:00:00" u "5:00"
  static String normalizeTime(String? time) {
    if (time == null || time.isEmpty) {
      return '';
    }

    String normalized = time.trim();

    // Ukloni sekunde ako postoje (05:00:00 -> 05:00)
    if (normalized.contains(':') && normalized.split(':').length == 3) {
      List<String> parts = normalized.split(':');
      normalized = '${parts[0]}:${parts[1]}';
    }

    // Ukloni leading zero (05:00 -> 5:00)
    if (normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }

    return normalized;
  }
}
