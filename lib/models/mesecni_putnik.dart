import 'dart:convert';

class MesecniPutnik {
  final String id;
  final String putnikIme;
  final String tip;
  final String? tipSkole;
  final String? brojTelefona;

  /// Nova struktura: mapa dan -> lista polazaka (npr. {"pon": ["6 VS", "13 BC"]})
  final Map<String, List<String>> polasciPoDanu;
  final String? adresaBelaCrkva;
  final String? adresaVrsac;
  // Stare kolone - zadržavamo za kompatibilnost
  final Map<String, String>? polazakBelaCrkva;
  final Map<String, String>? polazakVrsac;
  final String tipPrikazivanja;
  final String radniDani;
  final bool aktivan;
  final String status;
  final DateTime datumPocetkaMeseca;
  final DateTime datumKrajaMeseca;
  final double ukupnaCenaMeseca;
  final double? cena; // ✅ NOVA KOLONA - cena mesečne karte
  final int brojPutovanja;
  final int brojOtkazivanja;
  final DateTime? poslednjiPutovanje;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool obrisan; // Soft delete flag

  // 💰 NOVA POLJA ZA STATISTIKU PLAĆANJA
  final DateTime? vremePlacanja; // vreme kada je plaćen - NOVA KOLONA
  final int? placeniMesec; // mesec za koji je plaćeno (1-12)
  final int? placenaGodina; // godina za koju je plaćeno

  // 🚗 DRIVER TRACKING POLJA - JEDNOSTAVAN PRISTUP
  final String?
      vozac; // jedan vozač za sve akcije (dodao, pokupil, naplatio, otkazao)
  final bool pokupljen; // da li je pokupljen
  final DateTime? vremePokupljenja; // kada je pokupljen

  // Helper funkcije za JSON konverziju
  static Map<String, String>? _parsePolazakVreme(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      // Ako je string, verovatno je stari format - konvertuj u novi
      if (value.isEmpty || value == '00:00:00') return null;
      // Za sada, postavi isto vreme za sve dane
      return {
        'pon': value,
        'uto': value,
        'sre': value,
        'cet': value,
        'pet': value,
      };
    }
    if (value is Map) {
      // Ako je već mapa, konvertuj u Map<String, String>
      return Map<String, String>.from(value);
    }
    return null;
  }

  static String? _polazakVremeToTime(Map<String, String>? polazakVreme) {
    if (polazakVreme == null || polazakVreme.isEmpty) return null;

    // Pronađi prvo definirano vreme iz mape
    for (final entry in polazakVreme.entries) {
      if (entry.value.isNotEmpty && entry.value != '00:00') {
        // Konvertuj u TIME format HH:MM:SS
        String timeValue = entry.value;
        if (timeValue.length == 5) {
          // Ako je HH:MM, dodaj :00
          timeValue = '$timeValue:00';
        }
        return timeValue;
      }
    }
    return null;
  }

  MesecniPutnik({
    required this.id,
    required this.putnikIme,
    required this.tip,
    this.tipSkole,
    this.brojTelefona,
    required this.polasciPoDanu,
    this.adresaBelaCrkva,
    this.adresaVrsac,
    // Stare kolone za kompatibilnost
    this.polazakBelaCrkva,
    this.polazakVrsac,
    this.tipPrikazivanja = 'fiksan',
    this.radniDani = 'pon,uto,sre,cet,pet',
    this.aktivan = true,
    this.status = 'radi',
    required this.datumPocetkaMeseca,
    required this.datumKrajaMeseca,
    this.ukupnaCenaMeseca = 0.0,
    this.cena,
    this.brojPutovanja = 0,
    this.brojOtkazivanja = 0,
    this.poslednjiPutovanje,
    required this.createdAt,
    required this.updatedAt,
    this.obrisan = false,
    this.vremePlacanja,
    this.placeniMesec,
    this.placenaGodina,
    this.vozac,
    this.pokupljen = false,
    this.vremePokupljenja,
  });

  // Factory constructor za kreiranje iz Map-a (Supabase response)
  factory MesecniPutnik.fromMap(Map<String, dynamic> map) {
    // Backward kompatibilnost: ako nema polasci_po_danu koristi stare kolone
    Map<String, List<String>> polasciPoDanu = {};
    if (map['polasci_po_danu'] != null) {
      final raw = map['polasci_po_danu'];
      if (raw is String) {
        // JSON string
        polasciPoDanu =
            Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, List<String>.from(v)));
      } else if (raw is Map) {
        polasciPoDanu =
            raw.map((k, v) => MapEntry(k as String, List<String>.from(v)));
      }
    } else {
      // Ako nema JSON, koristi stare kolone (samo jedan polazak po danu)
      for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
        final bc = map['polazak_bc_$dan'];
        final vs = map['polazak_vs_$dan'];
        final List<String> polasci = [];
        if (bc != null && bc is String && bc.isNotEmpty)
          polasci.add('${bc} BC');
        if (vs != null && vs is String && vs.isNotEmpty)
          polasci.add('${vs} VS');
        if (polasci.isNotEmpty) polasciPoDanu[dan] = polasci;
      }
    }
    return MesecniPutnik(
      id: map['id'] as String,
      putnikIme: map['putnik_ime'] as String,
      tip: map['tip'] as String,
      tipSkole: map['tip_skole'] as String?,
      brojTelefona: map['broj_telefona'] as String?,
      polasciPoDanu: polasciPoDanu,
      adresaBelaCrkva: map['adresa_bela_crkva'] as String?,
      adresaVrsac: map['adresa_vrsac'] as String?,
      polazakBelaCrkva: _parsePolazakVreme(map['polazak_bela_crkva']),
      polazakVrsac: _parsePolazakVreme(map['polazak_vrsac']),
      tipPrikazivanja: map['tip_prikazivanja'] as String? ?? 'fiksan',
      radniDani: map['radni_dani'] as String? ?? 'pon,uto,sre,cet,pet',
      aktivan: map['aktivan'] as bool? ?? true,
      status: map['status'] as String? ?? 'radi',
      datumPocetkaMeseca: DateTime.parse(map['datum_pocetka_meseca'] as String),
      datumKrajaMeseca: DateTime.parse(map['datum_kraja_meseca'] as String),
      ukupnaCenaMeseca: (map['cena'] as num?)?.toDouble() ?? 0.0,
      cena: (map['cena'] as num?)?.toDouble(),
      brojPutovanja: map['broj_putovanja'] as int? ?? 0,
      brojOtkazivanja: map['broj_otkazivanja'] as int? ?? 0,
      poslednjiPutovanje: map['poslednje_putovanje'] != null
          ? DateTime.parse(map['poslednje_putovanje'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      obrisan: map['obrisan'] as bool? ?? false,
      vremePlacanja: map['vreme_placanja'] != null
          ? DateTime.parse(map['vreme_placanja'] as String)
          : null,
      placeniMesec: map['placeni_mesec'] as int?,
      placenaGodina: map['placena_godina'] as int?,
      vozac: map['naplata_vozac'] as String?,
      pokupljen: false,
      vremePokupljenja: null,
    );
  }

  // Konvertuje u Map za slanje u Supabase
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'putnik_ime': putnikIme,
      'tip': tip,
      'tip_skole': tipSkole,
      'broj_telefona': brojTelefona,
      'polasci_po_danu': polasciPoDanu,
      'adresa_bela_crkva': adresaBelaCrkva,
      'adresa_vrsac': adresaVrsac,
      'polazak_bela_crkva': _polazakVremeToTime(polazakBelaCrkva),
      'polazak_vrsac': _polazakVremeToTime(polazakVrsac),
      'tip_prikazivanja': tipPrikazivanja,
      'radni_dani': radniDani,
      'aktivan': aktivan,
      'status': status,
      'datum_pocetka_meseca':
          datumPocetkaMeseca.toIso8601String().split('T')[0],
      'datum_kraja_meseca': datumKrajaMeseca.toIso8601String().split('T')[0],
      'cena': cena ?? ukupnaCenaMeseca,
      'broj_putovanja': brojPutovanja,
      'broj_otkazivanja': brojOtkazivanja,
      'poslednje_putovanje':
          poslednjiPutovanje?.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'obrisan': obrisan,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'vozac': vozac,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  // CopyWith method za kreiranje kopije sa promenjenim vrednostima
  MesecniPutnik copyWith({
    String? id,
    String? putnikIme,
    String? tip,
    String? tipSkole,
    String? brojTelefona,
    Map<String, List<String>>? polasciPoDanu,
    String? adresaBelaCrkva,
    String? adresaVrsac,
    Map<String, String>? polazakBelaCrkva,
    Map<String, String>? polazakVrsac,
    String? tipPrikazivanja,
    String? radniDani,
    bool? aktivan,
    String? status,
    DateTime? datumPocetkaMeseca,
    DateTime? datumKrajaMeseca,
    double? ukupnaCenaMeseca,
    double? cena,
    int? brojPutovanja,
    int? brojOtkazivanja,
    DateTime? poslednjiPutovanje,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? obrisan,
    DateTime? vremePlacanja,
    String? vozac,
    bool? pokupljen,
    DateTime? vremePokupljenja,
  }) {
    return MesecniPutnik(
      id: id ?? this.id,
      putnikIme: putnikIme ?? this.putnikIme,
      tip: tip ?? this.tip,
      tipSkole: tipSkole ?? this.tipSkole,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      polasciPoDanu: polasciPoDanu ?? this.polasciPoDanu,
      adresaBelaCrkva: adresaBelaCrkva ?? this.adresaBelaCrkva,
      adresaVrsac: adresaVrsac ?? this.adresaVrsac,
      polazakBelaCrkva: polazakBelaCrkva ?? this.polazakBelaCrkva,
      polazakVrsac: polazakVrsac ?? this.polazakVrsac,
      tipPrikazivanja: tipPrikazivanja ?? this.tipPrikazivanja,
      radniDani: radniDani ?? this.radniDani,
      aktivan: aktivan ?? this.aktivan,
      status: status ?? this.status,
      datumPocetkaMeseca: datumPocetkaMeseca ?? this.datumPocetkaMeseca,
      datumKrajaMeseca: datumKrajaMeseca ?? this.datumKrajaMeseca,
      ukupnaCenaMeseca: ukupnaCenaMeseca ?? this.ukupnaCenaMeseca,
      cena: cena ?? this.cena,
      brojPutovanja: brojPutovanja ?? this.brojPutovanja,
      brojOtkazivanja: brojOtkazivanja ?? this.brojOtkazivanja,
      poslednjiPutovanje: poslednjiPutovanje ?? this.poslednjiPutovanje,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      obrisan: obrisan ?? this.obrisan,
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      vozac: vozac ?? this.vozac,
      pokupljen: pokupljen ?? this.pokupljen,
      vremePokupljenja: vremePokupljenja ?? this.vremePokupljenja,
    );
  }

  @override
  String toString() {
    return 'MesecniPutnik(id: $id, ime: $putnikIme, tip: $tip, aktivan: $aktivan)';
  }

  // 💰 HELPER METODE ZA PLAĆANJE
  bool get jePlacen =>
      vremePlacanja != null &&
      (cena ?? 0) > 0; // ✅ NOVA KOLONA - koristi cena umesto ukupnaCenaMeseca

  String get statusPlacanja {
    if (jePlacen) {
      return 'Plaćeno: ${(cena ?? 0).toStringAsFixed(0)} RSD (${vremePlacanja!.toString().split('T')[0]})';
    }
    return 'Nije plaćeno';
  }

  // 🔄 KOMPATIBILNOST SA PUTNIK MODELOM
  double? get iznosPlacanja => (cena ?? 0) > 0
      ? cena
      : ukupnaCenaMeseca > 0
          ? ukupnaCenaMeseca
          : null; // Mapiranje za kompatibilnost - prioritet ima cena kolona

  // 🚗 HELPER METODE ZA DRIVER TRACKING
  String? get naplatioVozac =>
      jePlacen ? vozac : null; // Ko je naplatio (ako je plaćeno)
  String? get pokupioVozac =>
      pokupljen ? vozac : null; // Ko je pokupil (ako je pokupljen)
  String? get dodaoVozac => vozac; // Ko je dodao mesečnog putnika
  String? get otkazaoVozac => (!aktivan && vozac != null)
      ? vozac
      : null; // Ko je otkazao (ako je neaktivan)

  // 📅 HELPER METODE ZA VREMENA POLASKA PO DANIMA
  /// Vraća vreme polaska iz Bele Crkve za specifičan dan
  /// [dan] može biti: 'pon', 'uto', 'sre', 'cet', 'pet'
  String? getPolazakBelaCrkvaZaDan(String dan) {
    switch (dan) {
      case 'pon':
        // Više nema polazakBcPon, koristi polazakBelaCrkva?[dan] ili null
        return polazakBelaCrkva?[dan];
      case 'uto':
        return polazakBelaCrkva?[dan];
      case 'sre':
        return polazakBelaCrkva?[dan];
      case 'cet':
        return polazakBelaCrkva?[dan];
      case 'pet':
        return polazakBelaCrkva?[dan];
      default:
        return polazakBelaCrkva?[dan];
    }
  }

  /// Vraća vreme polaska iz Vršca za specifičan dan
  /// [dan] može biti: 'pon', 'uto', 'sre', 'cet', 'pet'
  String? getPolazakVrsacZaDan(String dan) {
    switch (dan) {
      case 'pon':
        return polazakVrsac?[dan];
      case 'uto':
        return polazakVrsac?[dan];
      case 'sre':
        return polazakVrsac?[dan];
      case 'cet':
        return polazakVrsac?[dan];
      case 'pet':
        return polazakVrsac?[dan];
      default:
        return polazakVrsac?[dan];
    }
  }

  /// Vraća vreme polaska za trenutni dan nedelje
  String? getPolazakZaDanasnjiDan(String grad) {
    final danasnjiDan = _getDanNedelje();
    if (grad.toLowerCase().contains('bela') ||
        grad.toLowerCase().contains('crkva')) {
      return getPolazakBelaCrkvaZaDan(danasnjiDan);
    } else if (grad.toLowerCase().contains('vršac') ||
        grad.toLowerCase().contains('vrsac')) {
      return getPolazakVrsacZaDan(danasnjiDan);
    }
    return null;
  }

  /// Helper metod za dobijanje naziva dana nedelje
  String _getDanNedelje() {
    final sada = DateTime.now();
    final danNedelje = sada.weekday; // 1=Monday, 7=Sunday

    switch (danNedelje) {
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
        return 'sub'; // Subota (ako dodamo)
      case 7:
        return 'ned'; // Nedelja (ako dodamo)
      default:
        return 'pon';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MesecniPutnik && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
