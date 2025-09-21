import '../utils/mesecni_helpers.dart';

class MesecniPutnik {
  final String id;
  final String putnikIme;
  final String tip;
  final String? tipSkole;
  final String? brojTelefona;
  // Computed per-day polasci (day short -> list like ['6:00 BC', '14:00 VS']).
  // This is constructed from per-day columns (e.g. `polazak_bc_pon`) at `fromMap` time.
  final Map<String, List<String>> polasciPoDanu;
  final String? adresaBelaCrkva;
  final String? adresaVrsac;
  final String tipPrikazivanja;
  final String radniDani;
  final bool aktivan;
  final String status;
  final DateTime datumPocetkaMeseca;
  final DateTime datumKrajaMeseca;
  final double ukupnaCenaMeseca;
  final double? cena;
  final int brojPutovanja;
  final int brojOtkazivanja;
  final DateTime? poslednjiPutovanje;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool obrisan;

  final DateTime? vremePlacanja;
  final int? placeniMesec;
  final int? placenaGodina;

  final String? vozac;
  final bool pokupljen;
  final DateTime? vremePokupljenja;

  MesecniPutnik({
    required this.id,
    required this.putnikIme,
    required this.tip,
    this.tipSkole,
    this.brojTelefona,
    required this.polasciPoDanu,
    this.adresaBelaCrkva,
    this.adresaVrsac,
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

  factory MesecniPutnik.fromMap(Map<String, dynamic> map) {
    // Build parsedPolasci from per-day DB columns using helpers.
    final Map<String, List<String>> parsedPolasci = {};
    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      final List<String> list = [];
      final bc = MesecniHelpers.getPolazakForDay(map, dan, 'bc');
      final vs = MesecniHelpers.getPolazakForDay(map, dan, 'vs');
      if (bc != null && bc.isNotEmpty) list.add('$bc BC');
      if (vs != null && vs.isNotEmpty) list.add('$vs VS');
      if (list.isNotEmpty) parsedPolasci[dan] = list;
    }

    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());
    }

    return MesecniPutnik(
      id: map['id']?.toString() ?? '',
      putnikIme: map['putnik_ime']?.toString() ?? '',
      tip: map['tip']?.toString() ?? '',
      tipSkole: map['tip_skole']?.toString(),
      brojTelefona: map['broj_telefona']?.toString(),
      polasciPoDanu: parsedPolasci,
      adresaBelaCrkva: map['adresa_bela_crkva']?.toString(),
      adresaVrsac: map['adresa_vrsac']?.toString(),
      tipPrikazivanja: map['tip_prikazivanja']?.toString() ?? 'fiksan',
      radniDani: map['radni_dani']?.toString() ?? 'pon,uto,sre,cet,pet',
      aktivan: MesecniHelpers.isActiveFromMap(map),
      status: map['status']?.toString() ?? 'radi',
      datumPocetkaMeseca: parseDate(map['datum_pocetka_meseca']),
      datumKrajaMeseca: parseDate(map['datum_kraja_meseca']),
      ukupnaCenaMeseca: (map['ukupna_cena_meseca'] as num?)?.toDouble() ??
          (map['cena'] as num?)?.toDouble() ??
          0.0,
      cena: (map['cena'] as num?)?.toDouble(),
      brojPutovanja: map['broj_putovanja'] as int? ?? 0,
      brojOtkazivanja: map['broj_otkazivanja'] as int? ?? 0,
      poslednjiPutovanje: map['poslednje_putovanje'] != null
          ? parseDate(map['poslednje_putovanje'])
          : null,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
      obrisan: !(MesecniHelpers.isActiveFromMap(map)),
      vremePlacanja: map['vreme_placanja'] != null
          ? parseDate(map['vreme_placanja'])
          : null,
      placeniMesec: map['placeni_mesec'] as int?,
      placenaGodina: map['placena_godina'] as int?,
      vozac: map['naplata_vozac']?.toString(),
      pokupljen: false,
      vremePokupljenja: null,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'putnik_ime': putnikIme,
      'tip': tip,
      'tip_skole': tipSkole,
      'broj_telefona': brojTelefona,
      // Note: we intentionally do not include a 'polasci_po_danu' JSON field here.
      // Per-day columns (polazak_bc_pon, polazak_vs_pon, ...) are written by services.
      'adresa_bela_crkva': adresaBelaCrkva,
      'adresa_vrsac': adresaVrsac,
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
      'poslednje_putovanje': poslednjiPutovanje?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'obrisan': obrisan,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'naplata_vozac': vozac,
    };

    return map;
  }

  MesecniPutnik copyWith({
    String? id,
    String? putnikIme,
    String? tip,
    String? tipSkole,
    String? brojTelefona,
    Map<String, List<String>>? polasciPoDanu,
    String? adresaBelaCrkva,
    String? adresaVrsac,
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
    int? placeniMesec,
    int? placenaGodina,
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
      placeniMesec: placeniMesec ?? this.placeniMesec,
      placenaGodina: placenaGodina ?? this.placenaGodina,
      vozac: vozac ?? this.vozac,
      pokupljen: pokupljen ?? this.pokupljen,
      vremePokupljenja: vremePokupljenja ?? this.vremePokupljenja,
    );
  }

  @override
  String toString() {
    return 'MesecniPutnik(id: $id, putnikIme: $putnikIme, tip: $tip, aktivan: $aktivan)';
  }

  double? get iznosPlacanja => (cena != null && cena! > 0)
      ? cena
      : (ukupnaCenaMeseca > 0 ? ukupnaCenaMeseca : null);

  bool get jePlacen => vremePlacanja != null && (cena ?? 0) > 0;

  String get statusPlacanja {
    if (jePlacen) {
      return 'Plaćeno: ${(cena ?? 0).toStringAsFixed(0)} RSD (${vremePlacanja!.toIso8601String().split('T')[0]})';
    }
    return 'Nije plaćeno';
  }

  String? getPolazakBelaCrkvaZaDan(String dan) {
    final list = polasciPoDanu[dan];
    if (list == null || list.isEmpty) return null;
    for (final e in list)
      if (e.endsWith(' BC')) return e.replaceFirst(' BC', '');
    return list.first.replaceAll(RegExp(r'\s+(BC|VS)\$'), '');
  }

  String? getPolazakVrsacZaDan(String dan) {
    final list = polasciPoDanu[dan];
    if (list == null || list.isEmpty) return null;
    for (final e in list)
      if (e.endsWith(' VS')) return e.replaceFirst(' VS', '');
    return list.first.replaceAll(RegExp(r'\s+(BC|VS)\$'), '');
  }

  // _getDanNedelje removed: callers should use DateTime.now().weekday logic as needed.

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MesecniPutnik && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
// 🔄 KOMPATIBILNOST SA PUTNIK MODELOM
