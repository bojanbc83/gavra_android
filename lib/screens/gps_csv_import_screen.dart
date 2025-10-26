import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/unified_gps_service.dart';
import '../services/gps_data_migration_service.dart';

/// 📊 GPS CSV IMPORT SCREEN
/// UI za import GPS podataka iz CSV datoteke
class GpsCsvImportScreen extends StatefulWidget {
  const GpsCsvImportScreen({Key? key}) : super(key: key);

  @override
  State<GpsCsvImportScreen> createState() => _GpsCsvImportScreenState();
}

class _GpsCsvImportScreenState extends State<GpsCsvImportScreen> {
  bool _isImporting = false;
  String? _selectedFilePath;
  Map<String, dynamic>? _importResult;
  int _maxRecords = 1000;
  bool _forceOverwrite = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 GPS CSV Import'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFileSelection(),
            const SizedBox(height: 20),
            _buildImportSettings(),
            const SizedBox(height: 20),
            _buildImportButton(),
            const SizedBox(height: 20),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📁 Izbor CSV Datoteke',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (_selectedFilePath != null) ...[
              Text('Izabrana datoteka:',
                  style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 5),
              Text(
                _selectedFilePath!,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 10),
            ],
            ElevatedButton.icon(
              onPressed: _selectCsvFile,
              icon: const Icon(Icons.folder_open),
              label: Text(_selectedFilePath == null
                  ? 'Izaberi CSV datoteku'
                  : 'Promeni datoteku'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚙️ Podešavanja Importa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),

            // Max Records Setting
            Text('Maksimalan broj zapisa: $_maxRecords'),
            Slider(
              value: _maxRecords.toDouble(),
              min: 100,
              max: 5000,
              divisions: 49,
              label: _maxRecords.toString(),
              onChanged: (value) {
                setState(() {
                  _maxRecords = value.toInt();
                });
              },
            ),

            const SizedBox(height: 10),

            // Force Overwrite Setting
            CheckboxListTile(
              title: const Text('Prepiši postojeće zapise'),
              subtitle: const Text(
                  'Ako je uključeno, postojeći zapisi će biti prepravani'),
              value: _forceOverwrite,
              onChanged: (value) {
                setState(() {
                  _forceOverwrite = value ?? false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton() {
    return ElevatedButton.icon(
      onPressed: _canStartImport() ? _startImport : null,
      icon: _isImporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.upload_file),
      label: Text(
          _isImporting ? 'Importujem GPS podatke...' : '🚀 Pokreni Import'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildResults() {
    if (_importResult == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '📊 Rezultati importa će biti prikazani ovde...',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final success = _importResult!['success'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  success ? '✅ Import Uspešan' : '❌ Import Neuspešan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: success ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Expanded(
              child: SingleChildScrollView(
                child: _buildResultDetails(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultDetails() {
    final result = _importResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result['success'] == true) ...[
          _buildResultRow(
              '📊 Ukupno zapisa:', result['total']?.toString() ?? 'N/A'),
          _buildResultRow(
              '✅ Importovano:', result['migrated']?.toString() ?? 'N/A'),
          _buildResultRow(
              '📈 Uspešnost:', '${result['success_rate'] ?? 'N/A'}%'),
          _buildResultRow('📁 Izvor:', result['source'] ?? 'N/A'),
          const SizedBox(height: 15),
          const Text('🔍 Verifikacija:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          if (result['verification'] != null) ...[
            _buildResultRow(
                'Firebase ukupno:',
                result['verification']['firebase_total_count']?.toString() ??
                    'N/A'),
            _buildResultRow('Status migracije:',
                result['verification']['migration_status'] ?? 'N/A'),
          ],
          if (result['updated_system_status'] != null) ...[
            const SizedBox(height: 15),
            const Text('📊 Status Sistema:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            _buildResultRow(
                'GPS zapisi u Firebase:',
                result['updated_system_status']['firebase_gps_count']
                        ?.toString() ??
                    'N/A'),
            _buildResultRow(
                'Sistem inicijalizovan:',
                result['updated_system_status']['initialized']?.toString() ??
                    'N/A'),
          ],
        ] else ...[
          Text(
            'Greška: ${result['error'] ?? 'Nepoznata greška'}',
            style: const TextStyle(color: Colors.red),
          ),
          if (result['migrated'] != null) ...[
            const SizedBox(height: 10),
            _buildResultRow('Delimično importovano:',
                result['migrated']?.toString() ?? '0'),
          ],
        ],
      ],
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  bool _canStartImport() {
    return _selectedFilePath != null && !_isImporting;
  }

  Future<void> _selectCsvFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFilePath = result.files.first.path;
          _importResult = null; // Clear previous results
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Greška pri izboru datoteke: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startImport() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isImporting = true;
      _importResult = null;
    });

    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 15),
              Text('Importujem GPS podatke...'),
              Text('Ovo može potrajati nekoliko minuta.',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );

      final result = await UnifiedGpsService.importGpsDataFromCsv(
        csvFilePath: _selectedFilePath!,
        forceOverwrite: _forceOverwrite,
        maxRecords: _maxRecords,
      );

      // Close progress dialog
      Navigator.of(context).pop();

      setState(() {
        _importResult = result;
      });

      // Show success/error snackbar
      final success = result['success'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '✅ GPS import završen: ${result['migrated']}/${result['total']} zapisa'
              : '❌ GPS import neuspešan: ${result['error']}'),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // Close progress dialog
      Navigator.of(context).pop();

      setState(() {
        _importResult = {
          'success': false,
          'error': e.toString(),
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Greška tokom importa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }
}
