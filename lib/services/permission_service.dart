import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// foundation import not needed here
import '../globals.dart'; // Import za navigatorKey

/// 🔐 CENTRALIZOVANI SERVIS ZA SVE DOZVOLE
/// Zahteva sve dozvole pri prvom pokretanju aplikacije
/// i zatim ih koristi automatski bez dodatnih pitanja
class PermissionService {
  static const String _firstLaunchKey = 'app_first_launch_permissions';

  /// 🚀 INICIJALNO ZAHTEVANJE SVIH DOZVOLA (poziva se u main.dart)
  static Future<bool> requestAllPermissionsOnFirstLaunch(
    BuildContext context,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool(_firstLaunchKey) ?? true;

    if (isFirstLaunch) {
      // Proveri da li je context još uvek aktivan pre korišćenja
      if (!context.mounted) return false;
      return await _showPermissionSetupDialog(context);
    }

    // Nije prvi pokret - proverava da li su dozvole i dalje aktivne
    return await _checkExistingPermissions();
  }

  /// 🔧 HELPER WIDGET ZA PERMISSION ROW
  static Widget _buildPermissionRow(
      BuildContext context, IconData icon, Color accentColor, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: accentColor, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 17,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// �📱 DIALOG ZA POČETNO PODEŠAVANJE DOZVOLA
  static Future<bool> _showPermissionSetupDialog(BuildContext context) async {
    if (!context.mounted) return false;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.security,
                      color: Theme.of(context).colorScheme.primary, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Podešavanje',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Potrebne dozvole:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPermissionRow(context, Icons.location_on,
                        Colors.green, 'GPS lokacija - za navigaciju'),
                    const SizedBox(height: 6),
                    _buildPermissionRow(context, Icons.phone, Colors.blue,
                        'Pozivi - za kontakt'),
                    const SizedBox(height: 6),
                    _buildPermissionRow(context, Icons.message, Colors.orange,
                        'SMS poruke - za obaveštenja'),
                    const SizedBox(height: 6),
                    _buildPermissionRow(context, Icons.notifications,
                        Colors.purple, 'Notifikacije - za putovanja'),
                    const SizedBox(height: 12),
                    Text(
                      'Dozvole se zahtevaju samo jednom.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'PRESKOČI',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Pozovi zahtevanje dozvola kada korisnik klikne dugme
                    final success = await requestAllPermissions();
                    if (context.mounted) {
                      Navigator.of(context).pop(success);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('ODOBRI',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// ✅ ZAHTEVANJE SVIH DOZVOLA ODJEDNOM
  static Future<bool> requestAllPermissions() async {
    try {
      // 1. 📍 LOKACIJA (obavezno za navigaciju)
      final locationStatus = await _requestLocationPermission();

      // 2. 📞 POZIVI (za kontakt sa putnicima)
      final phoneStatus = await Permission.phone.request();

      // 3. 📱 SMS (za slanje poruka)
      final smsStatus = await Permission.sms.request();

      // 4. 🔔 NOTIFIKACIJE (za obaveštenja)
      await Permission.notification.request();

      // Sačuvaj da su dozvole zatražene
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstLaunchKey, false);

      // Vraća true ako su sve kritične dozvole odobrene
      final allCriticalGranted = locationStatus &&
          (phoneStatus.isGranted || phoneStatus.isLimited) &&
          (smsStatus.isGranted || smsStatus.isLimited);

      return allCriticalGranted;
    } catch (e) {
      return false;
    }
  }

  /// 🛰️ SPECIJALNO ZAHTEVANJE LOKACIJSKIH DOZVOLA
  static Future<bool> _requestLocationPermission() async {
    try {
      // Prvo proveri da li je Location Service uključen
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Pokušaj da uključi automatski
        await Geolocator.openLocationSettings();
        // Proveri ponovo
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }

      // Zatim zahtevaj dozvole
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return serviceEnabled &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (e) {
      return false;
    }
  }

  /// 🔍 PROVERA POSTOJEĆIH DOZVOLA
  static Future<bool> _checkExistingPermissions() async {
    try {
      final location = await _isLocationPermissionGranted();
      final phone = await Permission.phone.status;
      final sms = await Permission.sms.status;

      return location &&
          (phone.isGranted || phone.isLimited) &&
          (sms.isGranted || sms.isLimited);
    } catch (e) {
      return false;
    }
  }

  /// 📍 BRZA PROVERA LOKACIJSKE DOZVOLE
  static Future<bool> _isLocationPermissionGranted() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();

      return serviceEnabled &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (e) {
      return false;
    }
  }

  /// 🚗 INSTANT GPS ZA NAVIGACIJU (bez dodatnih dialoga)
  static Future<bool> ensureGpsForNavigation() async {
    try {
      // Brza provera - ako je sve OK, samo nastavi
      final isReady = await _isLocationPermissionGranted();
      if (isReady) {
        return true;
      }

      // Proveri da li je GPS usluga uključena
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Pokaži upozorenje pre otvaranja settings
        final context = navigatorKey.currentContext;
        if (context != null && context.mounted) {
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.gps_off, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('GPS je isključen'),
                ],
              ),
              content: const Text(
                'Za navigaciju treba da uključite GPS u podešavanjima.\n\n'
                'Tapnite "Uključi GPS" da otvorite podešavanja.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Otkaži'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Uključi GPS'),
                ),
              ],
            ),
          );

          if (shouldOpen == true) {
            await Geolocator.openLocationSettings();
            // Sačekaj malo da korisnik uključi GPS
            await Future<void>.delayed(const Duration(seconds: 2));
            serviceEnabled = await Geolocator.isLocationServiceEnabled();
          }
        } else {
          await Geolocator.openLocationSettings();
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return serviceEnabled &&
          permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever;
    } catch (e) {
      return false;
    }
  }

  /// 📞 INSTANT POZIV (bez dodatnih dialoga)
  static Future<bool> ensurePhonePermission() async {
    try {
      final status = await Permission.phone.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      final result = await Permission.phone.request();
      return result.isGranted || result.isLimited;
    } catch (e) {
      return false;
    }
  }

  /// 📱 INSTANT SMS (bez dodatnih dialoga)
  static Future<bool> ensureSmsPermission() async {
    try {
      final status = await Permission.sms.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      final result = await Permission.sms.request();
      return result.isGranted || result.isLimited;
    } catch (e) {
      return false;
    }
  }

  /// 🔔 STATUS SVIH DOZVOLA
  static Future<Map<String, bool>> getPermissionStatus() async {
    return {
      'location': await _isLocationPermissionGranted(),
      'phone': (await Permission.phone.status).isGranted,
      'sms': (await Permission.sms.status).isGranted,
      'notification': (await Permission.notification.status).isGranted,
    };
  }

  /// ⚙️ OTVORI SETTINGS ZA RUČNO PODEŠAVANJE
  static Future<void> openPermissionSettings() async {
    // Otvori system settings za dozvole aplikacije
    try {
      await Permission.phone
          .request(); // Ovo će otvoriti settings ako je potrebno
    } catch (e) {}
  }

  /// 🔧 HUAWEI SPECIFIČNA LOGIKA - Graceful handling na Huawei uređajima
  static Future<bool> ensureSmsPermissionHuawei() async {
    try {
      // Prvo pokušaj standardni pristup
      final status = await Permission.sms.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      // Huawei specifično - pokušaj zahtev
      final result = await Permission.sms.request();

      // Ako Huawei blokira dozvolu, nastavi sa URL launcher pristupom
      if (result.isDenied || result.isPermanentlyDenied) {
        return true; // Vraća true jer će koristiti URL launcher
      }

      return result.isGranted || result.isLimited;
    } catch (e) {
      return true; // Fallback na URL launcher
    }
  }

  /// 📞 HUAWEI SPECIFIČNA LOGIKA - Phone permission
  static Future<bool> ensurePhonePermissionHuawei() async {
    try {
      final status = await Permission.phone.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      final result = await Permission.phone.request();

      // Huawei fallback
      if (result.isDenied || result.isPermanentlyDenied) {
        return true; // Vraća true jer će koristiti tel: URI
      }

      return result.isGranted || result.isLimited;
    } catch (e) {
      return true; // Fallback na tel: URI
    }
  }
}
