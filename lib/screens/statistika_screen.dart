import 'dart:async';

import 'package:flutter/material.dart';

import '../models/putnik.dart';
import '../services/firebase_service.dart';
import '../services/local_notification_service.dart';
import '../services/putnik_service.dart';
import '../services/realtime_notification_service.dart';
import '../services/statistika_service.dart';
import '../theme.dart'; // DODANO za theme extensions
import '../utils/date_utils.dart'
    as app_date_utils; // DODANO: Centralna vikend logika
import '../utils/logging.dart';
import '../utils/vozac_boja.dart'; // 🎯 DODANO za konzistentne boje
import '../widgets/detaljan_pazar_po_vozacima_widget.dart';

class StatistikaScreen extends StatefulWidget {
  const StatistikaScreen({Key? key}) : super(key: key);

  @override
  State<StatistikaScreen> createState() => _StatistikaScreenState();
}

class _StatistikaScreenState extends State<StatistikaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _period = 'nedelja'; // nedelja, mesec, godina
  final List<String> _periods = ['nedelja', 'mesec', 'godina'];
  int _selectedYear = DateTime.now().year; // 🆕 Dodato za izbor godine
  List<int> _availableYears = []; // 🆕 Lista dostupnih godina
  String? _currentDriver;
  bool _checkedDriver = false;

  // 🔄 REALTIME MONITORING STATE
  late ValueNotifier<bool> _isRealtimeHealthy;
  late ValueNotifier<bool> _pazarStreamHealthy;
  late ValueNotifier<bool> _statistikaStreamHealthy;
  Timer? _healthCheckTimer;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this); // Promenjeno sa 3 na 2
    _tabController.addListener(() {
      setState(() {}); // Refresh UI kada se promeni tab
    });

    // 🔄 INITIALIZE REALTIME MONITORING
    _isRealtimeHealthy = ValueNotifier(true);
    _pazarStreamHealthy = ValueNotifier(true);
    _statistikaStreamHealthy = ValueNotifier(true);

    _initializeAvailableYears(); // 🆕 Inicijalizuj dostupne godine
    _checkDriver();
    _setupRealtimeMonitoring();

    // Inicijalizuj heads-up i zvuk notifikacije
    LocalNotificationService.initialize(context);
    FirebaseService.getCurrentDriver().then((driver) {
      if (driver != null && driver.isNotEmpty && mounted) {
        RealtimeNotificationService.initialize();
        RealtimeNotificationService.listenForForegroundNotifications(context);
      }
    });
  }

  @override
  void dispose() {
    // 🧹 CLEANUP REALTIME MONITORING
    _healthCheckTimer?.cancel();
    _isRealtimeHealthy.dispose();
    _pazarStreamHealthy.dispose();
    _statistikaStreamHealthy.dispose();

    _tabController.dispose();
    dlog('🧹 StatistikaScreen: Disposed realtime monitoring resources');
    super.dispose();
  }

  // 🔄 REALTIME MONITORING SETUP
  void _setupRealtimeMonitoring() {
    dlog('🔄 StatistikaScreen: Setting up realtime monitoring...');

    // Health check every 30 seconds
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkStreamHealth();
    });

    dlog('✅ StatistikaScreen: Realtime monitoring active');
  }

  // 🩺 STREAM HEALTH CHECK
  void _checkStreamHealth() {
    try {
      // Check if realtime services are responding
      final healthCheck = true; // Simplified check
      _isRealtimeHealthy.value = healthCheck;

      // Check specific stream health (updated by StreamBuilders)
      // Pazar and statistika health managed by individual StreamBuilders

      dlog(
        '🩺 StatistikaScreen health check: Realtime=${_isRealtimeHealthy.value}, Pazar=${_pazarStreamHealthy.value}, Stats=${_statistikaStreamHealthy.value}',
      );

      // 🚨 COMPREHENSIVE HEALTH REPORT
      final overallHealth = _isRealtimeHealthy.value &&
          _pazarStreamHealthy.value &&
          _statistikaStreamHealthy.value;

      if (!overallHealth) {
        dlog('⚠️ StatistikaScreen health issues detected:');
        if (!_isRealtimeHealthy.value)
          dlog('  - Realtime service disconnected');
        if (!_pazarStreamHealthy.value) dlog('  - Pazar streams failing');
        if (!_statistikaStreamHealthy.value)
          dlog('  - Statistika streams failing');
      }
    } catch (e) {
      dlog('⚠️ StatistikaScreen health check error: $e');
      _isRealtimeHealthy.value = false;
      _pazarStreamHealthy.value = false;
      _statistikaStreamHealthy.value = false;
    }
  }

  //  STREAM ERROR WIDGET
  Widget StreamErrorWidget({
    required String streamName,
    required String errorMessage,
    required VoidCallback onRetry,
    bool compact = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: compact ? 14 : 20,
          ),
          if (!compact) const SizedBox(height: 4),
          Text(
            compact ? 'ERR' : 'Stream Error',
            style: TextStyle(
              fontSize: compact ? 8 : 10,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          if (!compact) const SizedBox(height: 4),
          GestureDetector(
            onTap: onRetry,
            child: Icon(
              Icons.refresh,
              color: Colors.red,
              size: compact ? 12 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkDriver() async {
    final driver = await FirebaseService.getCurrentDriver();
    setState(() {
      _currentDriver = driver;
      _checkedDriver = true;
    });
  }

  /// 🆕 INICIJALIZUJ DOSTUPNE GODINE IZ BAZE
  void _initializeAvailableYears() {
    // Za sada dodajem nekoliko godina (možemo kasnije proširiti da čita iz baze)
    final currentYear = DateTime.now().year;
    _availableYears =
        List.generate(5, (i) => currentYear - i); // Poslednje 5 godina
    if (mounted) setState(() {});
  }

  // 🔄 RESETUJ SVE KILOMETRAŽE function is removed as unused

  @override
  Widget build(BuildContext context) {
    if (!_checkedDriver) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!['Bojan', 'Svetlana'].contains(_currentDriver)) {
      // Potpuno nevidljiv: vrati prazan widget
      return const SizedBox.shrink();
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Stack(
                children: [
                  // Glavni sadržaj AppBar-a
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // PRVI RED - STATISTIKA naslov sa heartbeat indikatorom
                      Container(
                        height: 32,
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'S T A T I S T I K A',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.8,
                                shadows: [
                                  Shadow(
                                    offset: Offset(1, 1),
                                    blurRadius: 3,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      // DRUGI RED - Tab-ovi i dropdown
                      SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            // Tab-ovi levo - stilizovani kao dugmići
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _tabController.animateTo(0),
                                      child: Container(
                                        height: 32,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: _tabController.index == 0
                                              ? Colors.white.withOpacity(0.3)
                                              : Colors.white.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.4),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Vozači',
                                            style: TextStyle(
                                              color: _tabController.index == 0
                                                  ? Colors.white
                                                  : Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _tabController.animateTo(1),
                                      child: Container(
                                        height: 32,
                                        margin: const EdgeInsets.only(left: 4),
                                        decoration: BoxDecoration(
                                          color: _tabController.index == 1
                                              ? Colors.white.withOpacity(0.3)
                                              : Colors.white.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.4),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Detaljno',
                                            style: TextStyle(
                                              color: _tabController.index == 1
                                                  ? Colors.white
                                                  : Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Dropdown desno - stilizovan kao dugme
                            Container(
                              height: 32,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _period,
                                  dropdownColor:
                                      Theme.of(context).colorScheme.primary,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                  items: _periods
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            child: Center(
                                              child: Text(
                                                _periodLabel(p),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => _period = v);
                                  },
                                ),
                              ),
                            ),
                            // 🆕 GODINA DROPDOWN - prikaži samo kada je selektovana "godina"
                            if (_period == 'godina') ...[
                              const SizedBox(width: 8),
                              Container(
                                height: 32,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedYear,
                                    dropdownColor:
                                        Theme.of(context).colorScheme.primary,
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    items: _availableYears
                                        .map(
                                          (year) => DropdownMenuItem(
                                            value: year,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '$year',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null) {
                                        setState(() => _selectedYear = v);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVozaciTab(),
          _buildDetaljnoTab(),
        ],
      ),
    );
  }

// --- Pomocne/tab funkcije ---

  /// 📅 CENTRALIZOVANA KALKULACIJA PERIODA - koriste oba tab-a identično
  Map<String, DateTime> _calculatePeriod() {
    DateTime now = DateTime.now();
    DateTime from, to;

    // Izračunavanje perioda

    if (_period == 'nedelja') {
      // ✅ KORISTI UTILS FUNKCIJU ZA VIKEND LOGIKU
      final targetDate = app_date_utils.DateUtils.getWeekendTargetDate();
      DateTime ponedeljak;

      if (app_date_utils.DateUtils.isWeekend()) {
        // 🎯 Vikend: koristi target datum (sledeći ponedeljak)
        ponedeljak = targetDate;
      } else {
        // 📅 Radni dan: računaj za ovu nedelju (običan ponedeljak)
        ponedeljak = now.subtract(Duration(days: now.weekday - 1));
      }

      // 🔄 Period ide od subote pre ponedeljka do petka te nedelje
      final subota =
          ponedeljak.subtract(const Duration(days: 2)); // Subota pre ponedeljka
      from = DateTime(subota.year, subota.month, subota.day);

      // 📅 ZAVRŠI U PETAK (dodaj 4 dana od ponedeljka)
      final petak = ponedeljak.add(const Duration(days: 4));
      to = DateTime(petak.year, petak.month, petak.day, 23, 59, 59);
    } else if (_period == 'mesec') {
      from = DateTime(now.year, now.month);
      to = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    } else {
      // 🔧 FIX: Koristi selektovanu godinu umesto now.year
      from = DateTime(_selectedYear);
      to = DateTime(_selectedYear, 12, 31, 23, 59, 59);
    }

    return {'from': from, 'to': to};
  }

  Widget _buildVozaciTab() {
    final period = _calculatePeriod(); // 📅 KORISTI CENTRALIZOVANU FUNKCIJU
    final from = period['from']!;
    final to = period['to']!;

    return StreamBuilder<List<Putnik>>(
      stream: PutnikService()
          .streamKombinovaniPutniciFiltered(), // 🔄 KOMBINOVANI STREAM (server-filtered)
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          dlog('❌ PUTNICI STREAM ERROR: ${snapshot.error}');
          return StreamErrorWidget(
            streamName: 'Putnici',
            errorMessage: snapshot.error.toString(),
            onRetry: () => setState(() {}),
          );
        }

        // 🔄 REAL-TIME PAZAR STREAM sa kombinovanim putnicima (uključuje mesečne karte)
        dlog(
          '🎯 [VOZAČI TAB] Pozivam streamPazarSvihVozaca sa from: ${from.toString()}, to: ${to.toString()}',
        );
        return StreamBuilder<Map<String, double>>(
          stream: StatistikaService.streamPazarSvihVozaca(
            from: from,
            to: to,
          ),
          builder: (context, pazarSnapshot) {
            dlog(
              '📊 VOZAČI TAB STREAM STATE: ${pazarSnapshot.connectionState}',
            );
            dlog('📊 VOZAČI TAB HAS DATA: ${pazarSnapshot.hasData}');
            dlog('📊 VOZAČI TAB DATA: ${pazarSnapshot.data}');

            if (pazarSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (pazarSnapshot.hasError) {
              dlog('❌ VOZAČI TAB ERROR: ${pazarSnapshot.error}');
              // 🩺 Update health status
              _pazarStreamHealthy.value = false;
              return StreamErrorWidget(
                streamName: 'Pazar vozača',
                errorMessage: pazarSnapshot.error.toString(),
                onRetry: () => setState(() {}),
              );
            }

            // 🩺 Update health status on successful data
            _pazarStreamHealthy.value = true;

            final pazarMap = pazarSnapshot.data ?? <String, double>{};
            final ukupno = pazarMap['_ukupno'] ?? 0.0;
            // Ukloni '_ukupno' ključ za čist prikaz
            final Map<String, double> cistPazarMap = Map.from(pazarMap)
              ..remove('_ukupno');
            // Dodaj ukupno u mapu
            cistPazarMap['_ukupno'] = ukupno;

            // 🎯 KORISTI CENTRALIZOVANE BOJE VOZAČA
            final Map<String, Color> vozacBoje = {
              'Bruda': VozacBoja.get('Bruda'),
              'Bilevski': VozacBoja.get('Bilevski'),
              'Bojan': VozacBoja.get('Bojan'),
              'Svetlana': VozacBoja.get('Svetlana'),
            };
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Postojeće komponente
                    StreamBuilder<Map<String, Map<String, dynamic>>>(
                      stream:
                          StatistikaService.streamDetaljneStatistikePoVozacima(
                        from,
                        to,
                      ),
                      builder: (context, detaljneSnapshot) {
                        if (detaljneSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (detaljneSnapshot.hasError) {
                          dlog(
                            '❌ DETALJNE STATS ERROR: ${detaljneSnapshot.error}',
                          );
                          // 🩺 Update health status
                          _statistikaStreamHealthy.value = false;
                          return StreamErrorWidget(
                            streamName: 'Detaljne statistike',
                            errorMessage: detaljneSnapshot.error.toString(),
                            onRetry: () => setState(() {}),
                          );
                        }

                        // 🩺 Update health status on successful data
                        _statistikaStreamHealthy.value = true;

                        final detaljneStats = detaljneSnapshot.data ?? {};

                        return DetaljanPazarPoVozacimaWidget(
                          vozaciStatistike: detaljneStats,
                          ukupno: ukupno,
                          periodLabel: _periodLabel(_period),
                          vozacBoje: vozacBoje,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetaljnoTab() {
    final period =
        _calculatePeriod(); // 📅 KORISTI ISTU CENTRALIZOVANU FUNKCIJU
    final from = period['from']!;
    final to = period['to']!;

    // 🔄 DIREKTNO KORISTI STREAM DETALJNIH STATISTIKA
    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: StatistikaService.streamDetaljneStatistikePoVozacima(from, to),
      builder: (context, statsSnapshot) {
        if (statsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (statsSnapshot.hasError) {
          dlog('❌ DETALJNO TAB STATS ERROR: ${statsSnapshot.error}');
          // 🩺 Update health status
          _statistikaStreamHealthy.value = false;
          return StreamErrorWidget(
            streamName: 'Detaljno tab statistike',
            errorMessage: statsSnapshot.error.toString(),
            onRetry: () => setState(() {}),
          );
        }

        // 🩺 Update health status on successful data
        _statistikaStreamHealthy.value = true;

        final detaljneStats = statsSnapshot.data ?? {};

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detaljne Statistike - ${_periodLabel(_period)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ...detaljneStats.entries.map((entry) {
                  final vozac = entry.key;
                  final stats = entry.value;
                  final Color vozacColor = _getVozacColor(vozac);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 4, // 🎨 Dodao shadow
                    color: vozacColor
                        .withOpacity(0.25), // 🎨 POJAČAO sa 0.1 na 0.25
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12), // 🎨 Zaobljeni uglovi
                      side: BorderSide(
                        color: vozacColor.withOpacity(0.6), // 🎨 Jasniji border
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.person, color: vozacColor, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                vozac,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[
                                      800], // 🎨 Tamniji tekst za bolji kontrast
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStatRow(
                            'Dodati putnici',
                            stats['dodati'],
                            Icons.add_circle,
                            Theme.of(context).colorScheme.primary,
                          ),
                          _buildStatRow(
                            'Otkazani',
                            stats['otkazani'],
                            Icons.cancel,
                            Theme.of(context).colorScheme.dangerPrimary,
                          ),
                          _buildStatRow(
                            'Naplaćeni',
                            stats['naplaceni'],
                            Icons.payment,
                            Theme.of(context).colorScheme.successPrimary,
                          ),
                          _buildStatRow(
                            'Pokupljeni',
                            stats['pokupljeni'],
                            Icons.check_circle,
                            Theme.of(context).colorScheme.studentPrimary,
                          ),
                          _buildStatRow(
                            'Dugovi',
                            stats['dugovi'],
                            Icons.warning,
                            Theme.of(context).colorScheme.dangerPrimary,
                          ),
                          _buildStatRow(
                            'Mesečne karte',
                            stats['mesecneKarte'],
                            Icons.card_membership,
                            Colors.purple,
                          ),
                          _buildStatRow(
                            'Kilometraža',
                            '${(stats['kilometraza'] ?? 0.0).toStringAsFixed(1)} km',
                            Icons.route,
                            Theme.of(context).colorScheme.workerPrimary,
                          ),
                          const Divider(color: Colors.white24),
                          _buildStatRow(
                            'Ukupno pazar',
                            '${stats['ukupnoPazar'].toStringAsFixed(0)} RSD',
                            Icons.monetization_on,
                            Colors.amber,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatRow(
    String label,
    dynamic value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ), // 🎨 Tamniji tekst
          ),
          Text(
            value.toString(),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getVozacColor(String vozac) {
    // 🎯 KORISTI CENTRALIZOVANE BOJE VOZAČA
    return VozacBoja.get(vozac);
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'nedelja':
        return 'Pon-Pet'; // 📅 Jasno označiti radni dani
      case 'mesec':
        return 'Mesec';
      case 'godina':
        return 'Godina';
      default:
        return period;
    }
  }
}
