import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String repoOwner = 'bojanbc83';
  static const String repoName = 'gavra_android';
  static const String githubApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Proverava da li je dostupna nova verzija
  static Future<bool> checkForUpdate() async {
    try {
      // Trenutna verzija aplikacije
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      print('🔍 Trenutna verzija: $currentVersion');
      print(
          '📱 Build mode: ${packageInfo.buildSignature.isEmpty ? "RELEASE" : "DEBUG"}');

      // GitHub API poziv
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String latestVersion = data['tag_name'].replaceAll('v', '');

        print('🚀 Najnovija verzija na GitHub: $latestVersion');

        // Poredi verzije
        bool hasUpdate = _isNewerVersion(currentVersion, latestVersion);
        print('📊 Ima update: $hasUpdate');
        print(
            '🔍 DETALJNO: $currentVersion vs $latestVersion = ${hasUpdate ? "TREBA UPDATE" : "NEMA UPDATE"}');

        return hasUpdate;
      } else {
        print('❌ GitHub API greška: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Greška pri proveri update-a: $e');
    }
    return false;
  }

  /// Vraća informacije o najnovijoj verziji
  static Future<Map<String, dynamic>?> getLatestVersionInfo() async {
    try {
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'version': data['tag_name'].replaceAll('v', ''),
          'name': data['name'] ?? 'Nova verzija',
          'body': data['body'] ?? 'Poboljšanja i ispravke',
          'downloadUrl': data['assets'] != null && data['assets'].isNotEmpty
              ? data['assets'][0]['browser_download_url']
              : data['html_url'],
          'publishedAt': data['published_at'],
        };
      }
    } catch (e) {
      print('❌ Greška pri dobijanju info o verziji: $e');
    }
    return null;
  }

  /// Otvara download stranicu za novu verziju
  static Future<void> openUpdatePage() async {
    const url = 'https://github.com/$repoOwner/$repoName/releases/latest';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  /// Otvara direktan APK download
  static Future<void> downloadApk() async {
    final versionInfo = await getLatestVersionInfo();
    if (versionInfo != null && versionInfo['downloadUrl'] != null) {
      final url = versionInfo['downloadUrl'];
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Poredi da li je nova verzija novija od trenutne
  static bool _isNewerVersion(String current, String latest) {
    try {
      List<int> currentParts =
          current.split('.').map((e) => int.parse(e)).toList();
      List<int> latestParts =
          latest.split('.').map((e) => int.parse(e)).toList();

      // Dopuni sa nulama ako je potrebno
      while (currentParts.length < 3) currentParts.add(0);
      while (latestParts.length < 3) latestParts.add(0);

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (e) {
      print('❌ Greška pri poređenju verzija: $e');
    }
    return false;
  }
}

/// Update checker sa UI dijalogom
class UpdateChecker {
  static Future<void> checkAndShowUpdate(BuildContext context) async {
    try {
      bool hasUpdate = await UpdateService.checkForUpdate();

      if (hasUpdate && context.mounted) {
        final versionInfo = await UpdateService.getLatestVersionInfo();
        _showUpdateDialog(context, versionInfo);
      }
    } catch (e) {
      print('❌ Greška u automatskoj proveri: $e');
    }
  }

  static void _showUpdateDialog(
      BuildContext context, Map<String, dynamic>? versionInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Nova verzija! 🚀'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (versionInfo != null) ...[
              Text('Verzija: ${versionInfo['version']}',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(versionInfo['name'] ?? 'Nova verzija'),
              SizedBox(height: 8),
              Text('Šta je novo:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(versionInfo['body'] ?? 'Poboljšanja i ispravke'),
            ] else ...[
              Text('Dostupna je nova verzija Gavra Android aplikacije.'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kasnije'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              UpdateService.downloadApk();
            },
            icon: Icon(Icons.download),
            label: Text('Download'),
          ),
        ],
      ),
    );
  }

  /// Manualna provera update-a (za dugme u settings)
  static Future<void> manualUpdateCheck(BuildContext context) async {
    // Pokazuj loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Proveravam update-e...'),
          ],
        ),
      ),
    );

    try {
      bool hasUpdate = await UpdateService.checkForUpdate();
      Navigator.pop(context); // Zatvori loading

      if (hasUpdate) {
        final versionInfo = await UpdateService.getLatestVersionInfo();
        _showUpdateDialog(context, versionInfo);
      } else {
        // Nema update-a
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Nema update-a ✅'),
            content: Text('Koristiš najnoviju verziju aplikacije.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Zatvori loading
      // Greška
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Greška ❌'),
          content: Text(
              'Nemoguće proveriti update-e. Proverite internet konekciju.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
