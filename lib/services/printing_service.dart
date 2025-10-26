import 'package:flutter/material.dart';

class PrintingService {
  /// Štampa spisak putnika za selektovani dan i vreme
  static Future<void> printPutniksList(
    String selectedDay,
    String selectedVreme,
    String selectedGrad,
    BuildContext context,
  ) async {
    try {
      // Temporarily disabled during Firebase migration testing
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '🚧 Štampanje je privremeno nedostupno tokom testiranja Firebase migracije'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška pri štampanju: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
