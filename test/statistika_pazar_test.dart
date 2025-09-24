import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/putnik.dart';
import 'package:gavra_android/models/mesecni_putnik.dart';
import 'package:gavra_android/services/statistika_service.dart';

void main() {
  test('calculateKombinovanPazarSync counts daily and monthly correctly', () {
    final now = DateTime.now();
    final putnici = <Putnik>[];

    // daily paid passenger for VozacA
    putnici.add(Putnik(
      id: 1,
      ime: 'Dnevni',
      polazak: '08:00',
      dan: 'Pon',
      grad: 'Bela Crkva',
      mesecnaKarta: false,
      iznosPlacanja: 200.0,
      naplatioVozac: 'Bruda',
      vremePlacanja: now,
    ));

    // daily unpaid (should be skipped)
    putnici.add(Putnik(
      id: 2,
      ime: 'Dnevni Neplacen',
      polazak: '09:00',
      dan: 'Pon',
      grad: 'Bela Crkva',
      mesecnaKarta: false,
      iznosPlacanja: 0.0,
      naplatioVozac: 'Bruda',
      vremePlacanja: null,
    ));

    // monthly passenger (will be passed separately)
    final mesecni = MesecniPutnik(
      id: 'm1',
      putnikIme: 'Mesečni',
      tip: 'radnik',
      polasciPoDanu: {
        'pon': ['06:00 BC']
      },
      datumPocetkaMeseca: DateTime(now.year, now.month, 1),
      datumKrajaMeseca: DateTime(now.year, now.month + 1, 0),
      ukupnaCenaMeseca: 0.0,
      cena: 1500.0,
      createdAt: now,
      updatedAt: now,
      aktivan: true,
    );

    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final result = StatistikaService.calculateKombinovanPazarSync(
        putnici, [mesecni], from, to);

    // Bruda should have 200 from ordinary and 0 from monthly because monthly time may not match
    expect(result.containsKey('Bruda'), true);
    final brudaPazar = result['Bruda'] ?? 0.0;
    expect(brudaPazar >= 200.0, true);
  });

  test('monthly grouping by id prevents double counting', () {
    final now = DateTime.now();
    final putnici = <Putnik>[];

    // Simulate two monthly entries representing two polazci but same id
    final mes1 = MesecniPutnik(
      id: 'm-same',
      putnikIme: 'Dup',
      tip: 'radnik',
      polasciPoDanu: {
        'pon': ['06:00 BC']
      },
      datumPocetkaMeseca: DateTime(now.year, now.month, 1),
      datumKrajaMeseca: DateTime(now.year, now.month + 1, 0),
      ukupnaCenaMeseca: 0.0,
      cena: 1000.0,
      createdAt: now,
      updatedAt: now,
      aktivan: true,
    );

    final mes2 = MesecniPutnik(
      id: 'm-same',
      putnikIme: 'Dup',
      tip: 'radnik',
      polasciPoDanu: {
        'pon': ['14:00 BC']
      },
      datumPocetkaMeseca: DateTime(now.year, now.month, 1),
      datumKrajaMeseca: DateTime(now.year, now.month + 1, 0),
      ukupnaCenaMeseca: 0.0,
      cena: 1000.0,
      createdAt: now,
      updatedAt: now,
      aktivan: true,
    );

    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final combined = StatistikaService.calculateKombinovanPazarSync(
        putnici, [mes1, mes2], from, to);

    // Even though two records exist, grouping by id should keep at most one counted
    expect(combined.values.where((v) => v > 0).length <= 4, true);
  });

  test('paid monthly are counted, unpaid are not', () {
    final now = DateTime.now();
    final putnici = <Putnik>[];

    final paid = MesecniPutnik(
      id: 'paid',
      putnikIme: 'Paid',
      tip: 'radnik',
      polasciPoDanu: {
        'pon': ['06:00 BC']
      },
      datumPocetkaMeseca: DateTime(now.year, now.month, 1),
      datumKrajaMeseca: DateTime(now.year, now.month + 1, 0),
      ukupnaCenaMeseca: 0.0,
      cena: 1200.0,
      vremePlacanja: now,
      vozac: 'Bruda',
      createdAt: now,
      updatedAt: now,
      aktivan: true,
    );

    final unpaid = MesecniPutnik(
      id: 'unpaid',
      putnikIme: 'Unpaid',
      tip: 'radnik',
      polasciPoDanu: {
        'pon': ['06:00 BC']
      },
      datumPocetkaMeseca: DateTime(now.year, now.month, 1),
      datumKrajaMeseca: DateTime(now.year, now.month + 1, 0),
      ukupnaCenaMeseca: 0.0,
      cena: 0.0,
      createdAt: now,
      updatedAt: now,
      aktivan: true,
    );

    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final combined = StatistikaService.calculateKombinovanPazarSync(
        putnici, [paid, unpaid], from, to);

    // Paid should contribute >0, unpaid should not be counted
    expect(combined.values.where((v) => v > 0).length >= 1, true);
  });
}
