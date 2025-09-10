import 'package:flutter/material.dart';
import '../models/putnik.dart';
import '../widgets/putnik_list.dart';
import '../services/putnik_service.dart';

class DugoviScreen extends StatefulWidget {
  final String? currentDriver;
  const DugoviScreen({Key? key, this.currentDriver}) : super(key: key);

  @override
  State<DugoviScreen> createState() => _DugoviScreenState();
}

class _DugoviScreenState extends State<DugoviScreen> {
  // final PutnikService _putnikService = PutnikService();
  String? _currentDriver;

  @override
  void initState() {
    super.initState();
    _currentDriver = widget.currentDriver;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
        ),
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.white),
        title: const Text(
          'Dužnici',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.2,
            shadows: [
              Shadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<Putnik>>(
        stream: PutnikService().streamKombinovaniPutnici(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final danas = DateTime.now();
          final danasString =
              "${danas.day.toString().padLeft(2, '0')}.${danas.month.toString().padLeft(2, '0')}.${danas.year}";

          debugPrint('🔍 DUGOVI DEBUG: Tražim dužnike za datum: $danasString');
          debugPrint(
              '🔍 DUGOVI DEBUG: Ukupno putnika u stream-u: ${snapshot.data!.length}');

          // Ispišimo sve putnike za debug
          for (final p in snapshot.data!) {
            if (p.ime.contains('TESTDODAO') || p.ime.contains('KURAPAL')) {
              debugPrint(
                  '🔍 DUGOVI DEBUG: ${p.ime} - dan: "${p.dan}", jePokupljen: ${p.jePokupljen}, iznosPlacanja: ${p.iznosPlacanja}, mesecnaKarta: ${p.mesecnaKarta}, status: "${p.status}"');
            }
          }

          // Dužnik je onaj koji je pokupljen i nije platio (iznosPlacanja == null ili 0) - SAMO PUTNICI KOJE JE OVAJ VOZAČ POKUPLJAO
          final duznici = snapshot.data!
              .where((p) =>
                  (p.iznosPlacanja == null || p.iznosPlacanja == 0) &&
                  (p.jePokupljen) &&
                  (p.status == null ||
                      (p.status != 'Otkazano' && p.status != 'otkazan')) &&
                  (p.mesecnaKarta != true) &&
                  (p.pokupioVozac ==
                      _currentDriver)) // 🔥 NOVO: samo oni koje je OVAJ vozač pokupljao
              // (p.dan == danasString)) // PRIVREMENO ISKLJUČEN FILTER ZA DATUM
              .toList();

          // Sortiraj po datumu (najnoviji prvi)
          duznici.sort((a, b) {
            // Koristiti vremeDodavanja ako postoji, inače vremePokupljenja, inače dan
            DateTime? aDate = a.vremeDodavanja ?? a.vremePokupljenja;
            DateTime? bDate = b.vremeDodavanja ?? b.vremePokupljenja;

            // Ako nema datuma, koristi dan string kao fallback
            if (aDate == null && bDate == null) {
              return b.dan.compareTo(a.dan); // najnoviji dan prvo
            }
            if (aDate == null) return 1; // b je noviji
            if (bDate == null) return -1; // a je noviji

            return bDate.compareTo(aDate); // najnoviji prvo
          });

          debugPrint('🔍 DUGOVI DEBUG: Pronađeno dužnika: ${duznici.length}');
          for (final d in duznici) {
            debugPrint('🔍 DUGOVI DEBUG: Dužnik: ${d.ime}');
          }
          if (duznici.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  SizedBox(height: 8),
                  Text('Nema neplaćenih putnika!',
                      style: TextStyle(color: Colors.green, fontSize: 16)),
                ],
              ),
            );
          }
          return PutnikList(
            putnici: duznici,
            currentDriver: widget.currentDriver,
          );
        },
      ),
    );
  }
}
