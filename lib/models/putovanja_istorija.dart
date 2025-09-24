class PutovanjaIstorija {
  final String id;
  final String? mesecniPutnikId;
  final String tipPutnika;
  final DateTime datum;
  final String vremePolaska;
  final DateTime? vremeAkcije;
  final String adresaPolaska;
  final String status;
  final String? statusBelaCrkvaVrsac;
  final String? statusVrsacBelaCrkva;
  final String putnikIme;
  final String? brojTelefona;
  final double cena;
  final DateTime createdAt;
  final DateTime updatedAt;

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
    this.vremeAkcije,
    required this.adresaPolaska,
    this.status = 'nije_se_pojavio',
    this.statusBelaCrkvaVrsac,
    this.statusVrsacBelaCrkva,
    required this.putnikIme,
    this.brojTelefona,
    this.cena = 0.0,
    required this.createdAt,
    required this.updatedAt,
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

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  factory PutovanjaIstorija.fromMap(Map<String, dynamic> map) {
    return PutovanjaIstorija(
      id: map['id']?.toString() ?? '',
      mesecniPutnikId: map['mesecni_putnik_id']?.toString(),
      tipPutnika: map['tip_putnika']?.toString() ?? '',
      datum: _parseDate(map['datum']),
      vremePolaska: map['vreme_polaska']?.toString() ?? '',
      adresaPolaska: map['adresa_polaska']?.toString() ?? '',
      status: (map['status'] ?? 'nije_se_pojavio').toString(),
      statusBelaCrkvaVrsac:
          (map['status_bela_crkva_vrsac'] ?? map['status_bela_crkva_vrsac'])
              .toString(),
      statusVrsacBelaCrkva:
          (map['status_vrsac_bela_crkva'] ?? map['status_vrsac_bela_crkva'])
              .toString(),
      putnikIme: (map['putnik_ime'] ?? map['ime'])?.toString() ?? '',
      brojTelefona: (map['broj_telefona'] ?? map['telefon'])?.toString(),
      cena: (map['cena'] as num?)?.toDouble() ?? 0.0,
      createdAt: _parseDate(map['created_at'] ??
          map['createdAt'] ??
          DateTime.now().toIso8601String()),
      updatedAt: _parseDate(map['updated_at'] ??
          map['updatedAt'] ??
          DateTime.now().toIso8601String()),
      dan: map['dan']?.toString(),
      grad: map['grad']?.toString(),
      obrisan: (map['obrisan'] as bool?) ?? (map['deleted'] as bool?) ?? false,
      pokupljen: (map['pokupljen'] as bool?) ?? false,
      vozac: map['vozac']?.toString(),
      vremePlacanja:
          _parseDate(map['vreme_placanja'] ?? map['vreme_placanja_ts']),
      vremePokupljenja:
          _parseDate(map['vreme_pokupljenja'] ?? map['vreme_pokupljenja_ts']),
      dozvoljeniPutnikId: map['dozvoljeni_putnik_id']?.toString(),
      pokupljanjeVozac: map['pokupljanje_vozac']?.toString(),
      naplataVozac: map['naplata_vozac']?.toString(),
      otkazaoVozac: map['otkazao_vozac']?.toString(),
      dodaoVozac: map['dodao_vozac']?.toString(),
      sitanNovac: map['sitan_novac']?.toString(),
      rawData: (map['raw_data'] is Map)
          ? Map<String, dynamic>.from(map['raw_data'])
          : null,
      vremePokupljenjaTs:
          _parseDate(map['vreme_pokupljenja_ts'] ?? map['vreme_pokupljenja']),
      vremePlacanjaTs:
          _parseDate(map['vreme_placanja_ts'] ?? map['vreme_placanja']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mesecni_putnik_id': mesecniPutnikId,
      'tip_putnika': tipPutnika,
      'datum': datum.toIso8601String().split('T')[0],
      'vreme_polaska': vremePolaska,
      'adresa_polaska': adresaPolaska,
      'putnik_ime': putnikIme,
      'broj_telefona': brojTelefona,
      'cena': cena,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'raw_data': rawData,
    };
  }

  bool get jeMesecni => tipPutnika == 'mesecni';
  bool get jeDnevni => tipPutnika == 'dnevni';

  @override
  String toString() => 'PutovanjaIstorija(id: $id, ime: $putnikIme)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PutovanjaIstorija && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
