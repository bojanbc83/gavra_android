import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// 🔥 GAVRA 013 - SUPABASE DATA EXPORT SCRIPT
///
/// Exportuje sve podatke iz Supabase pre migracije na Firebase
/// Pokreće se sa: dart run lib/scripts/supabase_export.dart

class SupabaseExporter {
  // 🔑 SUPABASE CREDENTIALS
  static const String supabaseUrl = 'https://gjtabtwudbrmfeyjiicu.supabase.co';
  static const String supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdqdGFidHd1ZGJybWZleWppaWN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MzYyOTIsImV4cCI6MjA2MzAxMjI5Mn0.TwAfvlyLIpnVf-WOixvApaQr6NpK9u-VHpRkmbkAKYk';

  static const Map<String, String> headers = {
    'apikey': supabaseKey,
    'Authorization': 'Bearer $supabaseKey',
    'Content-Type': 'application/json',
  };

  /// 📊 Lista svih tabela za export
  static const List<String> tablesToExport = [
    'vozaci',
    'mesecni_putnici',
    'dnevni_putnici',
    'putovanja_istorija',
    'adrese',
    'vozila',
    'gps_lokacije',
    'rute',
  ];

  /// 📁 Kreira backup direktorij
  static Future<Directory> createBackupDirectory() async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupDir = Directory('backup/supabase_export_$timestamp');
    await backupDir.create(recursive: true);
    print('📁 Backup direktorij kreiran: ${backupDir.path}');
    return backupDir;
  }

  /// 📤 Exportuje jednu tabelu
  static Future<void> exportTable(String tableName, Directory backupDir) async {
    try {
      print('📤 Exportujem tabelu: $tableName...');

      // Paginacija - uzmi sve podatke
      List<Map<String, dynamic>> allData = [];
      int offset = 0;
      const int limit = 1000;

      while (true) {
        final url =
            '$supabaseUrl/rest/v1/$tableName?select=*&offset=$offset&limit=$limit';
        final response = await http.get(Uri.parse(url), headers: headers);

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }

        final dynamic responseData = json.decode(response.body);
        final List<dynamic> pageData = responseData as List<dynamic>;
        if (pageData.isEmpty) break;

        allData.addAll(pageData.cast<Map<String, dynamic>>());
        offset += limit;

        print(
            '  📋 Učitao ${pageData.length} zapisa (ukupno: ${allData.length})');
      }

      // 💾 Sačuvaj u JSON file
      final file = File(path.join(backupDir.path, '$tableName.json'));
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'table': tableName,
          'exported_at': DateTime.now().toIso8601String(),
          'total_records': allData.length,
          'data': allData,
        }),
      );

      print('✅ Exportovano $tableName: ${allData.length} zapisa');
    } catch (e) {
      print('❌ Greška pri exportu tabele $tableName: $e');
      rethrow;
    }
  }

  /// 👥 Exportuje Supabase Auth korisnike (ako moguće)
  static Future<void> exportAuthUsers(Directory backupDir) async {
    try {
      print('👥 Exportujem Auth korisnike...');

      // Auth podaci se mogu čitati samo sa admin API-jem
      // Za sada preskačemo ili koristimo custom endpoint
      final file = File(path.join(backupDir.path, 'auth_users.json'));
      await file.writeAsString(
        json.encode({
          'note': 'Auth podaci se exportuju ručno iz Supabase Dashboard',
          'exported_at': DateTime.now().toIso8601String(),
          'instructions': [
            '1. Idi na Supabase Dashboard',
            '2. Authentication > Users',
            '3. Export to CSV/JSON',
            '4. Sačuvaj kao auth_users_manual.json',
          ],
        }),
      );

      print('📝 Auth export instrukcije kreirane');
    } catch (e) {
      print('⚠️  Auth export preskočen: $e');
    }
  }

  /// 📊 Kreira export summary
  static Future<void> createExportSummary(Directory backupDir) async {
    final summaryFile = File(path.join(backupDir.path, 'export_summary.json'));

    // Broji zapise u svakom fajlu
    Map<String, int> recordCounts = {};
    for (final tableName in tablesToExport) {
      try {
        final file = File(path.join(backupDir.path, '$tableName.json'));
        if (await file.exists()) {
          final content = json.decode(await file.readAsString());
          recordCounts[tableName] = (content['total_records'] as int?) ?? 0;
        }
      } catch (e) {
        recordCounts[tableName] = 0;
      }
    }

    final summary = {
      'export_completed_at': DateTime.now().toIso8601String(),
      'backup_directory': backupDir.path,
      'tables_exported': recordCounts.length,
      'total_records': recordCounts.values.fold(0, (a, b) => a + b),
      'record_counts': recordCounts,
      'files_created': [
        ...tablesToExport.map((t) => '$t.json'),
        'auth_users.json',
        'export_summary.json',
      ],
    };

    await summaryFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary),
    );

    print('\n📊 EXPORT ZAVRŠEN!');
    print('📁 Backup lokacija: ${backupDir.path}');
    print('📋 Ukupno tabela: ${recordCounts.length}');
    print('📊 Ukupno zapisa: ${summary['total_records']}');
    recordCounts.forEach((table, count) {
      print('   $table: $count zapisa');
    });
  }

  /// 🚀 GLAVNA EXPORT FUNKCIJA
  static Future<void> main() async {
    try {
      print('🔥 GAVRA 013 - SUPABASE EXPORT STARTED');
      print('🕐 ${DateTime.now()}');
      print('');

      // Kreiraj backup direktorij
      final backupDir = await createBackupDirectory();

      // Exportuj sve tabele
      for (final tableName in tablesToExport) {
        await exportTable(tableName, backupDir);
      }

      // Exportuj auth korisnike
      await exportAuthUsers(backupDir);

      // Kreiraj summary
      await createExportSummary(backupDir);

      print('\n🎉 EXPORT USPEŠNO ZAVRŠEN!');
    } catch (e, stackTrace) {
      print('\n💥 KRITIČNA GREŠKA:');
      print('$e');
      print('\n📍 Stack trace:');
      print('$stackTrace');
      exit(1);
    }
  }
}

/// 🎬 ENTRY POINT
void main() async {
  await SupabaseExporter.main();
}
