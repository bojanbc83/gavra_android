import 'dart:async';
import 'dart:io';


/// 🌐 CONNECTION RESILIENCE SERVICE
/// Automatski reconnect, network monitoring, fallback strategije (FIXED VERSION)
class ConnectionResilienceService {

  // Stream kontroleri
  static final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  static final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();

  // Stanje konekcije
  static bool _isOnline = true;
  static bool _isSupabaseConnected = true;
  static Timer? _reconnectTimer;
  static Timer? _healthCheckTimer;
  static Timer? _networkMonitorTimer;

  // Retry konfiguracija
  static const int _maxRetries = 5;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  static const Duration _healthCheckInterval = Duration(seconds: 30);
  static const Duration _networkCheckInterval = Duration(seconds: 10);

  // Getteri za stream-ove
  static Stream<bool> get connectionStateStream =>
      _connectionStateController.stream;
  static Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream;

  // Getteri za trenutno stanje
  static bool get isOnline => _isOnline;
  static bool get isSupabaseConnected => _isSupabaseConnected;
  static bool get isFullyConnected => _isOnline && _isSupabaseConnected;

  /// 🚀 INICIJALIZACIJA SERVISA
  static Future<void> initialize() async {
    // Proveri početno stanje konekcije
    await _checkInitialConnectivity();

    // Pokreni monitoring konekcije
    _startNetworkMonitoring();

    // Pokreni health check
    _startHealthCheck();
  }

  /// 📡 PROVERA POČETNE KONEKCIJE
  static Future<void> _checkInitialConnectivity() async {
    try {
      final isConnected = await _checkNetworkConnection();
      _updateConnectionState(isConnected);

      if (isConnected) {
        await _checkSupabaseConnection();
      }
    } catch (e) {
      _updateConnectionState(false);
    }
  }

  /// 🌐 PROVERA NETWORK KONEKCIJE
  static Future<bool> _checkNetworkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 👂 MONITORING NETWORK KONEKCIJE
  static void _startNetworkMonitoring() {
    _networkMonitorTimer = Timer.periodic(_networkCheckInterval, (timer) async {
      final wasOnline = _isOnline;
      final isConnected = await _checkNetworkConnection();

      if (wasOnline != isConnected) {
        _updateConnectionState(isConnected);

        if (isConnected && !_isSupabaseConnected) {
          // Network je vraćen, pokušaj reconnect na Supabase
          await _attemptSupabaseReconnect();
        }
      }
    });
  }

  /// 🏥 HEALTH CHECK ZA SUPABASE
  static void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) async {
      if (_isOnline) {
        await _checkSupabaseConnection();
      }
    });
  }

  /// 🔍 PROVERA SUPABASE KONEKCIJE
  static Future<void> _checkSupabaseConnection() async {
    try {
      // MIGRATED TO FIREBASE - Connection check disabled

      if (!_isSupabaseConnected) {
        _updateSupabaseState(true);
      }
    } catch (e) {
      _updateSupabaseState(false);

      if (_isOnline) {
        // Network je OK ali Supabase ne, pokušaj reconnect
        _scheduleSupabaseReconnect();
      }
    }
  }

  /// 🔄 POKUŠAJ SUPABASE RECONNECT
  static Future<void> _attemptSupabaseReconnect() async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        await _checkSupabaseConnection();

        if (_isSupabaseConnected) {
          return;
        }
      } catch (e) {
      }

      if (attempt < _maxRetries) {
        final delay = _baseRetryDelay * attempt;
        await Future<void>.delayed(delay);
      }
    }
  }

  /// ⏰ ZAKAŽI SUPABASE RECONNECT
  static void _scheduleSupabaseReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _attemptSupabaseReconnect();
    });
  }

  /// 📊 UPDATE NETWORK STATE
  static void _updateConnectionState(bool isConnected) {
    if (_isOnline != isConnected) {
      _isOnline = isConnected;
      _connectionStateController.add(isConnected);

      final status = isConnected ? 'Online' : 'Offline';
      _connectionStatusController.add(status);
    }
  }

  /// 📊 UPDATE SUPABASE STATE
  static void _updateSupabaseState(bool isConnected) {
    if (_isSupabaseConnected != isConnected) {
      _isSupabaseConnected = isConnected;

      final status =
          isConnected ? 'Supabase Connected' : 'Supabase Disconnected';
      _connectionStatusController.add(status);
    }
  }
  static Future<void> forceReconnectTest() async {
    await _attemptSupabaseReconnect();
  }

  /// 🔄 MANUAL REFRESH KONEKCIJE
  static Future<bool> refreshConnection() async {
    await _checkInitialConnectivity();
    return isFullyConnected;
  }

  /// 🧹 CLEANUP
  static void dispose() {
    _reconnectTimer?.cancel();
    _healthCheckTimer?.cancel();
    _networkMonitorTimer?.cancel();

    _connectionStateController.close();
    _connectionStatusController.close();
  }
}
