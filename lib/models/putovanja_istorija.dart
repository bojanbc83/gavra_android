class PutovanjaIstorija {
  final String id;
  final String? mesecniPutnikId;
  final String tipPutnika;
  final DateTime datum;
  final String vremePolaska;
  final DateTime? vremeAkcije; // OPCIONO - možda se mapira na vreme_pokupljenja
  final String adresaPolaska;
  final String status; // UMESTO statusBelaCrkvaVrsac i statusVrsacBelaCrkva
  final String? statusBelaCrkvaVrsac; // DEPRECATED - čuva se za kompatibilnost
  final String? statusVrsacBelaCrkva; // DEPRECATED - čuva se za kompatibilnost
  final String putnikIme;
  final String? brojTelefona;
  final double cena;
  final DateTime createdAt;
  final DateTime updatedAt;

  // NOVA POLJA koja postoje u bazi
  final String? dan;
  final String? grad;
  final bool obrisan;
  final bool pokupljen;
  final String? vozac;
  final DateTime? vremePlacanja;
  final DateTime? vremePokupljenja;
  final String? dozvoljeniPutnikId;
  final String? pokupljanjeVozac;
  final String? naplataVozac;
  final String? otkazaoVozac;
  final String? dodaoVozac;
  final String? sitanNovac;
  final Map<String, dynamic>? rawData;
  final DateTime? vremePokupljenjaTs;
  final DateTime? vremePlacanjaTs;

  PutovanjaIstorija({
    required this.id,
    this.mesecniPutnikId,
    required this.tipPutnika,
    required this.datum,
    required this.vremePolaska,
    this.vremeAkcije, // OPCIONO
    required this.adresaPolaska,
    this.status = 'nije_se_pojavio', // DEFAULT vrednost
    this.statusBelaCrkvaVrsac = 'nije_se_pojavio', // DEPRECATED
    this.statusVrsacBelaCrkva = 'nije_se_pojavio', // DEPRECATED
    required this.putnikIme,
    this.brojTelefona,
    this.cena = 0.0,
    required this.createdAt,
    required this.updatedAt,
    // NOVA POLJA
    this.dan,
    this.grad,
    this.obrisan = false,
    this.pokupljen = false,
    this.vozac,
    this.vremePlacanja,
    this.vremePokupljenja,
    this.dozvoljeniPutnikId,
    this.pokupljanjeVozac,
    this.naplataVozac,
    this.otkazaoVozac,
    this.dodaoVozac,
    this.sitanNovac,
    this.rawData,
    this.vremePokupljenjaTs,
    this.vremePlacanjaTs,
  });

  // Factory constructor za kreiranje iz Map-a (Supabase response)
  factory PutovanjaIstorija.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());
    }

    bool parseBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      final s = v.toString().toLowerCase().trim();
      return (s == 'true' || s == 't' || s == '1' || s == 'yes' || s == 'y');
    }

    String? resolveString(Map<String, dynamic> m, List<String> keys) {
      for (final k in keys) {
        if (m.containsKey(k) && m[k] != null) return m[k].toString();
      }
      return null;
    }

    return PutovanjaIstorija(
      id: map['id']?.toString() ?? '',
      mesecniPutnikId: map['mesecni_putnik_id']?.toString(),
      tipPutnika: map['tip_putnika']?.toString() ?? '',
      datum: parseDate(map['datum']),
      vremePolaska: map['vreme_polaska']?.toString() ?? '',
      vremeAkcije: map['vreme_pokupljenja'] != null
          ? parseDate(map['vreme_pokupljenja'])
          : null,
      adresaPolaska: map['adresa_polaska']?.toString() ?? '',
      status: map['status']?.toString() ?? 'nije_se_pojavio',
      statusBelaCrkvaVrsac: map['status']?.toString() ?? 'nije_se_pojavio',
      statusVrsacBelaCrkva: map['status']?.toString() ?? 'nije_se_pojavio',
      putnikIme: resolveString(map, ['putnik_ime', 'ime']) ?? '',
      brojTelefona: resolveString(map, ['broj_telefona', 'telefon']),
      cena: (map['cena'] as num?)?.toDouble() ??
          (map['cena_numeric'] as num?)?.toDouble() ??
          0.0,
      createdAt: parseDate(map['created_at'] ?? map['createdAt']),
      updatedAt: parseDate(map['updated_at'] ?? map['updatedAt']),
      // NOVA POLJA
      dan: map['dan'] as String?,
      grad: map['grad'] as String?,
      obrisan: parseBool(map['obrisan']),
      pokupljen: parseBool(map['pokupljen']),
      vozac: map['vozac']?.toString(),
      vremePlacanja: map['vreme_placanja'] != null
          ? parseDate(map['vreme_placanja'])
          : null,
      vremePokupljenja: map['vreme_pokupljenja'] != null
          ? parseDate(map['vreme_pokupljenja'])
          : null,
      dozvoljeniPutnikId: map['dozvoljeni_putnik_id']?.toString(),
      pokupljanjeVozac: map['pokupljanje_vozac']?.toString(),
      naplataVozac: map['naplata_vozac']?.toString(),
      otkazaoVozac: map['otkazao_vozac']?.toString(),
      dodaoVozac: map['dodao_vozac']?.toString(),
      sitanNovac: map['sitan_novac']?.toString(),
      rawData: (map['raw_data'] is Map)
          ? Map<String, dynamic>.from(map['raw_data'])
          : null,
      vremePokupljenjaTs: map['vreme_pokupljenja_ts'] != null
          ? parseDate(map['vreme_pokupljenja_ts'])
          : null,
      vremePlacanjaTs: map['vreme_placanja_ts'] != null
          ? parseDate(map['vreme_placanja_ts'])
          : null,
    );
  }

  // Konvertuje u Map za slanje u Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mesecni_putnik_id': mesecniPutnikId,
      'tip_putnika': tipPutnika,
      'datum': datum.toIso8601String().split('T')[0],
      'vreme_polaska': vremePolaska,
      'adresa_polaska': adresaPolaska,
      'status':
          status, // KORISTI status umesto status_bela_crkva_vrsac/status_vrsac_bela_crkva
      'putnik_ime': putnikIme,
      'broj_telefona': brojTelefona,
      'cena': cena,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // NOVA POLJA
      'dan': dan,
      'grad': grad,
      'obrisan': obrisan,
      'pokupljen': pokupljen,
      'vozac': vozac,
      'vreme_placanja': vremePlacanja?.toIso8601String(),
      'vreme_pokupljenja': vremePokupljenja?.toIso8601String(),
      'dozvoljeni_putnik_id': dozvoljeniPutnikId,
      'pokupljanje_vozac': pokupljanjeVozac,
      'naplata_vozac': naplataVozac,
      'otkazao_vozac': otkazaoVozac,
      'dodao_vozac': dodaoVozac,
      'sitan_novac': sitanNovac,
      'raw_data': rawData,
      'vreme_pokupljenja_ts': vremePokupljenjaTs?.toIso8601String(),
      'vreme_placanja_ts': vremePlacanjaTs?.toIso8601String(),
    };
  }

  // CopyWith method za kreiranje kopije sa promenjenim vrednostima
  PutovanjaIstorija copyWith({
    String? id,
    String? mesecniPutnikId,
    String? tipPutnika,
    DateTime? datum,
    String? vremePolaska,
    DateTime? vremeAkcije,
    String? adresaPolaska,
    String? status,
    String? statusBelaCrkvaVrsac,
    String? statusVrsacBelaCrkva,
    String? putnikIme,
    String? brojTelefona,
    double? cena,
    DateTime? createdAt,
    DateTime? updatedAt,
    // NOVA POLJA
    String? dan,
    String? grad,
    bool? obrisan,
    bool? pokupljen,
    String? vozac,
    DateTime? vremePlacanja,
    DateTime? vremePokupljenja,
    String? dozvoljeniPutnikId,
    String? pokupljanjeVozac,
    String? naplataVozac,
    String? otkazaoVozac,
    String? dodaoVozac,
    String? sitanNovac,
    Map<String, dynamic>? rawData,
    DateTime? vremePokupljenjaTs,
    DateTime? vremePlacanjaTs,
  }) {
    return PutovanjaIstorija(
      id: id ?? this.id,
      mesecniPutnikId: mesecniPutnikId ?? this.mesecniPutnikId,
      tipPutnika: tipPutnika ?? this.tipPutnika,
      datum: datum ?? this.datum,
      vremePolaska: vremePolaska ?? this.vremePolaska,
      vremeAkcije: vremeAkcije ?? this.vremeAkcije,
      adresaPolaska: adresaPolaska ?? this.adresaPolaska,
      status: status ?? this.status,
      statusBelaCrkvaVrsac: statusBelaCrkvaVrsac ?? this.statusBelaCrkvaVrsac,
      statusVrsacBelaCrkva: statusVrsacBelaCrkva ?? this.statusVrsacBelaCrkva,
      putnikIme: putnikIme ?? this.putnikIme,
      brojTelefona: brojTelefona ?? this.brojTelefona,
      cena: cena ?? this.cena,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // NOVA POLJA
      dan: dan ?? this.dan,
      grad: grad ?? this.grad,
      obrisan: obrisan ?? this.obrisan,
      pokupljen: pokupljen ?? this.pokupljen,
      vozac: vozac ?? this.vozac,
      vremePlacanja: vremePlacanja ?? this.vremePlacanja,
      vremePokupljenja: vremePokupljenja ?? this.vremePokupljenja,
      dozvoljeniPutnikId: dozvoljeniPutnikId ?? this.dozvoljeniPutnikId,
      pokupljanjeVozac: pokupljanjeVozac ?? this.pokupljanjeVozac,
      naplataVozac: naplataVozac ?? this.naplataVozac,
      otkazaoVozac: otkazaoVozac ?? this.otkazaoVozac,
      dodaoVozac: dodaoVozac ?? this.dodaoVozac,
      sitanNovac: sitanNovac ?? this.sitanNovac,
      rawData: rawData ?? this.rawData,
      vremePokupljenjaTs: vremePokupljenjaTs ?? this.vremePokupljenjaTs,
      vremePlacanjaTs: vremePlacanjaTs ?? this.vremePlacanjaTs,
    );
  }

  // Helper metodi za status - AŽURIRANI za novu status kolonu
  bool get jePokupljenBelaCrkvaVrsac => status == 'pokupljen' || pokupljen;
  bool get jePokupljenVrsacBelaCrkva => status == 'pokupljen' || pokupljen;
  bool get jeOtkazaoBelaCrkvaVrsac =>
      status == 'otkazao_poziv' || status == 'otkazano';
  bool get jeOtkazaoVrsacBelaCrkva =>
      status == 'otkazao_poziv' || status == 'otkazano';
  bool get nijeSePojavioBelaCrkvaVrsac => status == 'nije_se_pojavio';
  bool get nijeSePojavioVrsacBelaCrkva => status == 'nije_se_pojavio';

  bool get jeMesecni => tipPutnika == 'mesecni';
  bool get jeDnevni => tipPutnika == 'dnevni';

  @override
  String toString() {
    return 'PutovanjaIstorija(id: $id, ime: $putnikIme, datum: $datum, tip: $tipPutnika)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PutovanjaIstorija && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
