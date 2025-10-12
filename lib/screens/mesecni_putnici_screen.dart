import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/mesecni_putnik.dart';
import '../services/mesecni_putnik_service.dart';
import '../services/permission_service.dart'; // DODANO za konzistentnu telefon logiku
import '../services/real_time_statistika_service.dart';
import '../services/realtime_service.dart';
import '../services/smart_address_autocomplete_service.dart';
import '../services/vozac_mapping_service.dart';
import '../theme.dart';
import '../utils/filter_and_sort_putnici.dart';
import '../utils/logging.dart';
import '../utils/mesecni_helpers.dart';
import '../utils/time_validator.dart';
import '../utils/vozac_boja.dart';
import '../widgets/custom_back_button.dart';
import '../widgets/realtime_error_widgets.dart'; // 🚨 REALTIME error handling

class MesecniPutniciScreen extends StatefulWidget {
  const MesecniPutniciScreen({Key? key}) : super(key: key);

  @override
  State<MesecniPutniciScreen> createState() => _MesecniPutniciScreenState();
}

class _MesecniPutniciScreenState extends State<MesecniPutniciScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'svi'; // 'svi', 'radnik', 'ucenik'

  // Supabase klijent
  final SupabaseClient supabase = Supabase.instance.client;

  // Novi servis instance
  final MesecniPutnikService _mesecniPutnikService = MesecniPutnikService();

  // 🔄 OPTIMIZACIJA: Debounced search stream i filter stream
  late final BehaviorSubject<String> _searchSubject;
  late final BehaviorSubject<String> _filterSubject;
  late final Stream<String> _debouncedSearchStream;

  // 🔄 OPTIMIZACIJA: Connection resilience
  StreamSubscription<dynamic>? _connectionSubscription;
  bool _isConnected = true;

  // 🔄 REALTIME MONITORING STATE (V3.0 Clean Architecture)
  late ValueNotifier<bool> _isRealtimeHealthy;
  late ValueNotifier<bool> _mesecniPutniciStreamHealthy;
  Timer? _monitoringTimer;
  late ValueNotifier<String> _realtimeHealthStatus;
  late ValueNotifier<bool> _isNetworkConnected;

  // Form controllers
  String _novoIme = '';
  String _noviTip = 'radnik';
  String _novaTipSkole = '';
  String _noviBrojTelefona = '';
  String _noviBrojTelefonaOca = '';
  String _noviBrojTelefonaMajke = '';
  String _novaAdresaBelaCrkva = '';
  String _novaAdresaVrsac = '';

  // Working days state
  Map<String, bool> _noviRadniDani = {
    'pon': true,
    'uto': true,
    'sre': true,
    'cet': true,
    'pet': true,
  };

  // Departure times controllers - Bela Crkva
  final TextEditingController _polazakBcPonController = TextEditingController();
  final TextEditingController _polazakBcUtoController = TextEditingController();
  final TextEditingController _polazakBcSreController = TextEditingController();
  final TextEditingController _polazakBcCetController = TextEditingController();
  final TextEditingController _polazakBcPetController = TextEditingController();

  // Departure times controllers - Vršac
  final TextEditingController _polazakVsPonController = TextEditingController();
  final TextEditingController _polazakVsUtoController = TextEditingController();
  final TextEditingController _polazakVsSreController = TextEditingController();
  final TextEditingController _polazakVsCetController = TextEditingController();
  final TextEditingController _polazakVsPetController = TextEditingController();

  // Legacy map structures
  final Map<String, String> _novaVremenaBC = {
    'pon': '',
    'uto': '',
    'sre': '',
    'cet': '',
    'pet': '',
  };

  final Map<String, String> _novaVremenaVS = {
    'pon': '',
    'uto': '',
    'sre': '',
    'cet': '',
    'pet': '',
  };

  // Convert working days to string
  String _getRadniDaniString() {
    final List<String> odabraniDani = [];
    _noviRadniDani.forEach((dan, selected) {
      if (selected) {
        odabraniDani.add(dan);
      }
    });
    return odabraniDani.join(',');
  }

  // Parse working days from string
  void _setRadniDaniFromString(String radniDaniStr) {
    final daniList = radniDaniStr.split(',');
    _noviRadniDani = {
      'pon': daniList.contains('pon'),
      'uto': daniList.contains('uto'),
      'sre': daniList.contains('sre'),
      'cet': daniList.contains('cet'),
      'pet': daniList.contains('pet'),
    };
  }

  // Edit dialog controllers
  late TextEditingController _imeController;
  late TextEditingController _tipSkoleController;
  late TextEditingController _brojTelefonaController;
  late TextEditingController _brojTelefonaOcaController;
  late TextEditingController _brojTelefonaMajkeController;
  late TextEditingController _adresaBelaCrkvaController;
  late TextEditingController _adresaVrsacController;

  // Departure time controllers
  final Map<String, TextEditingController> _vremenaBcControllers = {};
  final Map<String, TextEditingController> _vremenaVsControllers = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeOptimizations();
  }

  void _initializeControllers() {
    _imeController = TextEditingController();
    _tipSkoleController = TextEditingController();
    _brojTelefonaController = TextEditingController();
    _brojTelefonaOcaController = TextEditingController();
    _brojTelefonaMajkeController = TextEditingController();
    _adresaBelaCrkvaController = TextEditingController();
    _adresaVrsacController = TextEditingController();

    // Kreiraj controller-e za svaки dan
    const dani = ['pon', 'uto', 'sre', 'cet', 'pet'];
    for (final dan in dani) {
      _vremenaBcControllers[dan] = TextEditingController();
      _vremenaVsControllers[dan] = TextEditingController();
    }
  }

  // 🔄 OPTIMIZACIJA: Inicijalizacija debounced search i error handling
  void _initializeOptimizations() {
    // Debounced search stream sa seeded vrednostima
    _searchSubject = BehaviorSubject<String>.seeded('');
    _filterSubject = BehaviorSubject<String>.seeded('svi');
    _debouncedSearchStream = _searchSubject
        .debounceTime(const Duration(milliseconds: 300))
        .distinct();

    // Listen za search promene
    _searchController.addListener(() {
      _searchSubject.add(_searchController.text);
    });

    // Connection monitoring (placeholder - možete proširiti)
    _isConnected = true;
    _connectionSubscription = null; // Initialize to null for now

    // 🔄 V3.0 REALTIME MONITORING SETUP (Clean Architecture)
    _setupRealtimeMonitoring();
  }

  // 🔄 V3.0 REALTIME MONITORING SETUP (Backend only - no visual heartbeat)
  void _setupRealtimeMonitoring() {
    _isRealtimeHealthy = ValueNotifier(true);
    _mesecniPutniciStreamHealthy = ValueNotifier(true);
    _realtimeHealthStatus = ValueNotifier('healthy');
    _isNetworkConnected = ValueNotifier(_isConnected);

    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateHealthStatus();
    });
  }

  void _updateHealthStatus() {
    final streamHealthy = _mesecniPutniciStreamHealthy.value;
    _isRealtimeHealthy.value = streamHealthy;

    // Update network status
    _isNetworkConnected.value = _isConnected;

    // Update health status
    if (!_isConnected) {
      _realtimeHealthStatus.value = 'error';
    } else if (!streamHealthy) {
      _realtimeHealthStatus.value = 'error';
    } else {
      _realtimeHealthStatus.value = 'healthy';
    }
  }

  @override
  void dispose() {
    // 🔄 V3.0 REALTIME MONITORING CLEANUP
    _monitoringTimer?.cancel();
    _isRealtimeHealthy.dispose();
    _mesecniPutniciStreamHealthy.dispose();
    _realtimeHealthStatus.dispose();
    _isNetworkConnected.dispose();

    // 🔄 OPTIMIZACIJA: Cleanup resources
    _searchSubject.close();
    _filterSubject.close();
    _connectionSubscription?.cancel();

    _searchController.dispose();
    _imeController.dispose();
    _tipSkoleController.dispose();
    _brojTelefonaController.dispose();
    _brojTelefonaOcaController.dispose();
    _brojTelefonaMajkeController.dispose();
    _adresaBelaCrkvaController.dispose();
    _adresaVrsacController.dispose();

    // Dispose vremena controller-e
    for (final controller in _vremenaBcControllers.values) {
      controller.dispose();
    }
    for (final controller in _vremenaVsControllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const GradientBackButton(),
                  Expanded(
                    child: Text(
                      'Mesečni Putnici',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            offset: const Offset(1, 1),
                            blurRadius: 3,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Filter za radnike sa brojem
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.engineering,
                          color: _selectedFilter == 'radnik'
                              ? Colors.white
                              : Colors.white70,
                        ),
                        onPressed: () {
                          // 🔄 OPTIMIZOVANO: Stream update umesto setState
                          final newFilter =
                              _selectedFilter == 'radnik' ? 'svi' : 'radnik';
                          _selectedFilter = newFilter;
                          _filterSubject.add(newFilter);
                        },
                        tooltip: 'Filtriraj radnike',
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: StreamBuilder<List<MesecniPutnik>>(
                          stream: _mesecniPutnikService.mesecniPutniciStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final brojRadnika = snapshot.data!
                                .where(
                                  (p) =>
                                      p.tip == 'radnik' &&
                                      p.aktivan &&
                                      !p.obrisan &&
                                      p.status != 'bolovanje' &&
                                      p.status != 'godišnje',
                                )
                                .length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF6B6B),
                                    Color(0xFFFF8E53),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              child: Text(
                                '$brojRadnika',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  // Filter za učenike sa brojem
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.school,
                          color: _selectedFilter == 'ucenik'
                              ? Colors.white
                              : Colors.white70,
                        ),
                        onPressed: () {
                          // 🔄 OPTIMIZOVANO: Stream update umesto setState
                          final newFilter =
                              _selectedFilter == 'ucenik' ? 'svi' : 'ucenik';
                          _selectedFilter = newFilter;
                          _filterSubject.add(newFilter);
                        },
                        tooltip: 'Filtriraj učenike',
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: StreamBuilder<List<MesecniPutnik>>(
                          stream: _mesecniPutnikService.mesecniPutniciStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            final brojUcenika = snapshot.data!
                                .where(
                                  (p) =>
                                      p.tip == 'ucenik' &&
                                      p.aktivan &&
                                      !p.obrisan &&
                                      p.status != 'bolovanje' &&
                                      p.status != 'godišnje',
                                )
                                .length;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4ECDC4),
                                    Color(0xFF44A08D),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.teal.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 24,
                                minHeight: 24,
                              ),
                              child: Text(
                                '$brojUcenika',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      switch (value) {
                        case 'export':
                          _exportPutnici();
                          break;
                        case 'import':
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Import funkcionalnost će biti dodana uskoro',
                              ),
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.download, size: 20),
                            SizedBox(width: 8),
                            Text('Export u CSV'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'import',
                        child: Row(
                          children: [
                            Icon(Icons.upload, size: 20),
                            SizedBox(width: 8),
                            Text('Import iz CSV'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => _pokaziDijalogZaDodavanje(),
                    tooltip: 'Dodaj novog putnika',
                  ),
                  // 🔄 V3.0: Discrete network status monitoring
                  ValueListenableBuilder<String>(
                    valueListenable: _realtimeHealthStatus,
                    builder: (context, healthStatus, child) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: _isNetworkConnected,
                        builder: (context, isConnected, child) {
                          if (!isConnected || healthStatus == 'error') {
                            return Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                isConnected
                                    ? Icons.error_outline
                                    : Icons.wifi_off,
                                color: Colors.white,
                                size: 16,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // 🔍 SEARCH BAR
          Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _searchController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Pretraži putnike...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).primaryColor,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 📋 LISTA PUTNIKA - 🔄 OPTIMIZOVANO: CombineLatest streams za reaktivno filtriranje
          Expanded(
            child: StreamBuilder<List<MesecniPutnik>>(
              stream: Rx.combineLatest3(
                _mesecniPutnikService.mesecniPutniciStream,
                _debouncedSearchStream,
                _filterSubject.stream,
                (
                  List<MesecniPutnik> putnici,
                  String searchTerm,
                  String filterType,
                ) {
                  // Serialize putnici to List<Map<String, dynamic>> for compute
                  final putniciMap = putnici.map((p) => p.toMap()).toList();
                  return compute(filterAndSortPutnici, {
                    'putnici': putniciMap,
                    'searchTerm': searchTerm,
                    'filterType': filterType,
                  }).then(
                    (resultList) =>
                        // Deserialize result back to MesecniPutnik
                        (resultList as List)
                            .map(
                              (m) => MesecniPutnik.fromMap(
                                Map<String, dynamic>.from(m as Map),
                              ),
                            )
                            .toList(),
                  );
                },
              ).asyncExpand((future) => Stream.fromFuture(future)),
              builder: (context, snapshot) {
                // 🔄 OPTIMIZOVANO: Enhanced error handling sa retry opcijom
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return StreamErrorWidget(
                    streamName: 'MesecniPutniciMain',
                    errorMessage: snapshot.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }

                final filteredPutnici = snapshot.data ?? [];
                // Prikaži samo prvih 50 rezultata
                final prikazaniPutnici = filteredPutnici.length > 50
                    ? filteredPutnici.sublist(0, 50)
                    : filteredPutnici;

                if (prikazaniPutnici.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchController.text.isNotEmpty
                              ? Icons.search_off
                              : Icons.group_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isNotEmpty
                              ? 'Nema rezultata pretrage'
                              : 'Nema mesečnih putnika',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_searchController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Pokušajte sa drugim terminom',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: prikazaniPutnici.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final putnik = prikazaniPutnici[index];
                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 300 + (index * 50)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: _buildPutnikCard(putnik, index + 1),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPutnikCard(MesecniPutnik putnik, int redniBroj) {
    final bool bolovanje = putnik.status == 'bolovanje';
    // Pronađi prvi dan koji ima definisano vreme
    String? danSaVremenom;
    for (String dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      if (putnik.getPolazakBelaCrkvaZaDan(dan) != null ||
          putnik.getPolazakVrsacZaDan(dan) != null) {
        danSaVremenom = dan;
        break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: bolovanje
              ? LinearGradient(
                  colors: [Colors.amber[50]!, Colors.orange[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.white, Colors.grey[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: Border.all(
            color: bolovanje ? Colors.orange[200]! : Colors.grey[200]!,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📋 HEADER - Ime, broj i aktivnost switch
              Row(
                children: [
                  // Redni broj i ime
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          '$redniBroj.',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            putnik.putnikIme,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: bolovanje ? Colors.orange : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Switch za aktivnost ili bolovanje
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bolovanje
                            ? 'BOLUJE'
                            : (putnik.aktivan ? 'AKTIVAN' : 'PAUZIRAN'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: bolovanje
                              ? Colors.orange
                              : (putnik.aktivan ? Colors.green : Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Switch(
                        value: putnik.aktivan,
                        onChanged: bolovanje
                            ? null
                            : (value) => _toggleAktivnost(putnik),
                        activeColor: Colors.green,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 📝 OSNOVNE INFORMACIJE - tip, telefon, škola, statistike u jednom redu
              Row(
                children: [
                  // Tip putnika
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Icon(
                          putnik.tip == 'radnik'
                              ? Icons.engineering
                              : Icons.school,
                          size: 16,
                          color: putnik.tip == 'radnik'
                              ? Colors.blue.shade600
                              : Colors.green.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          putnik.tip.toUpperCase(),
                          style: TextStyle(
                            color: putnik.tip == 'radnik'
                                ? Colors.blue.shade700
                                : Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Telefon - prikaže broj dostupnih kontakata
                  if (putnik.brojTelefona != null ||
                      putnik.brojTelefonaOca != null ||
                      putnik.brojTelefonaMajke != null)
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          // Ikone za dostupne kontakte
                          if (putnik.brojTelefona != null)
                            Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.green.shade600,
                            ),
                          if (putnik.brojTelefonaOca != null)
                            Icon(
                              Icons.man,
                              size: 14,
                              color: Colors.blue.shade600,
                            ),
                          if (putnik.brojTelefonaMajke != null)
                            Icon(
                              Icons.woman,
                              size: 14,
                              color: Colors.pink.shade600,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            '${_prebrojKontakte(putnik)} kontakt${_prebrojKontakte(putnik) == 1 ? '' : 'a'}',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Tip škole/ustanova (ako postoji)
                  if (putnik.tipSkole != null)
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(
                            putnik.tip == 'ucenik'
                                ? Icons.school_outlined
                                : Icons.business_outlined,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              putnik.tipSkole!,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // � RADNO VREME - prikaži polazak vremena ako su definisana za bilo koji dan
              if (danSaVremenom != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Radno vreme',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Polazak iz Bele Crkve
                          if (putnik.getPolazakBelaCrkvaZaDan(danSaVremenom) !=
                              null)
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.departure_board,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  Icon(
                                    Icons.departure_board,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'B.Crkva: ${putnik.getPolazakBelaCrkvaZaDan(danSaVremenom)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Polazak iz Vršca
                          if (putnik.getPolazakVrsacZaDan(danSaVremenom) !=
                              null)
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.departure_board,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Vršac: ${putnik.getPolazakVrsacZaDan(danSaVremenom)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      // Radni dani
                      if (putnik.radniDani.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Radni dani: ${putnik.radniDani}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              // �💰 PLAĆANJE I STATISTIKE - jednaki elementi u redu
              Row(
                children: [
                  // 💰 DUGME ZA PLAĆANJE
                  Expanded(
                    child: _buildCompactActionButton(
                      onPressed: () => _prikaziPlacanje(putnik),
                      icon: putnik.cena != null && putnik.cena! > 0
                          ? Icons.check_circle_outline
                          : Icons.payments_outlined,
                      label: putnik.cena != null && putnik.cena! > 0
                          ? '${putnik.cena!.toStringAsFixed(0)} RSD'
                          : 'Plati',
                      color: putnik.cena != null && putnik.cena! > 0
                          ? Colors.green
                          : Colors.purple,
                    ),
                  ),

                  const SizedBox(width: 6),

                  // 📊 DUGME ZA DETALJE
                  Expanded(
                    child: _buildCompactActionButton(
                      onPressed: () => _prikaziDetaljneStatistike(putnik),
                      icon: Icons.analytics_outlined,
                      label: 'Detalji',
                      color: Colors.blue,
                    ),
                  ),

                  const SizedBox(width: 6),

                  // 📈 BROJAČ PUTOVANJA
                  Expanded(
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 14,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${putnik.brojPutovanja}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // ❌ BROJAČ OTKAZIVANJA
                  Expanded(
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            size: 14,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${putnik.brojOtkazivanja}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 🎛️ ACTION BUTTONS - samo najvažnije
              Row(
                children: [
                  // Pozovi (ako ima bilo koji telefon)
                  if (putnik.brojTelefona != null ||
                      putnik.brojTelefonaOca != null ||
                      putnik.brojTelefonaMajke != null) ...[
                    Expanded(
                      child: _buildCompactActionButton(
                        onPressed: () => _pokaziKontaktOpcije(putnik),
                        icon: Icons.phone,
                        label: 'Pozovi',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],

                  // Uredi
                  Expanded(
                    child: _buildCompactActionButton(
                      onPressed: () => _editPutnik(putnik),
                      icon: Icons.edit_outlined,
                      label: 'Uredi',
                      color: Colors.blue,
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Obriši
                  Expanded(
                    child: _buildCompactActionButton(
                      onPressed: () => _obrisiPutnika(putnik),
                      icon: Icons.delete_outline,
                      label: 'Obriši',
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      height: 32,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 14, color: color),
          label: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: color,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          ),
        ),
      ),
    );
  }

  void _toggleAktivnost(MesecniPutnik putnik) async {
    final success =
        await _mesecniPutnikService.toggleAktivnost(putnik.id, !putnik.aktivan);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${putnik.putnikIme} je ${!putnik.aktivan ? "aktiviran" : "deaktiviran"}',
          ),
          backgroundColor: !putnik.aktivan ? Colors.green : Colors.orange,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Greška pri promeni statusa'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _editPutnik(MesecniPutnik putnik) {
    // Postavi vrednosti za edit
    setState(() {
      _novoIme = putnik.putnikIme;
      _noviTip = putnik.tip;
      _novaTipSkole = putnik.tipSkole ?? '';
      _noviBrojTelefona = putnik.brojTelefona ?? '';
      _novaAdresaBelaCrkva = putnik.adresaBelaCrkva ?? '';
      _novaAdresaVrsac = putnik.adresaVrsac ?? '';

      // Učitaj vremena iz novih kolona ili fallback na stare - sa formatiranjem
      _polazakBcPonController.text =
          putnik.getPolazakBelaCrkvaZaDan('pon') ?? '';
      _polazakBcUtoController.text =
          putnik.getPolazakBelaCrkvaZaDan('uto') ?? '';
      _polazakBcSreController.text =
          putnik.getPolazakBelaCrkvaZaDan('sre') ?? '';
      _polazakBcCetController.text =
          putnik.getPolazakBelaCrkvaZaDan('cet') ?? '';
      _polazakBcPetController.text =
          putnik.getPolazakBelaCrkvaZaDan('pet') ?? '';

      _polazakVsPonController.text = putnik.getPolazakVrsacZaDan('pon') ?? '';
      _polazakVsUtoController.text = putnik.getPolazakVrsacZaDan('uto') ?? '';
      _polazakVsSreController.text = putnik.getPolazakVrsacZaDan('sre') ?? '';
      _polazakVsCetController.text = putnik.getPolazakVrsacZaDan('cet') ?? '';
      _polazakVsPetController.text = putnik.getPolazakVrsacZaDan('pet') ?? '';

      // ✅ DODANO - učitaj postojeće radne dane
      _setRadniDaniFromString(putnik.radniDani);

      // Postavi vrednosti u controller-e
      _imeController.text = _novoIme;
      _tipSkoleController.text = _novaTipSkole;
      _brojTelefonaController.text = _noviBrojTelefona;
      _adresaBelaCrkvaController.text = _novaAdresaBelaCrkva;
      _adresaVrsacController.text = _novaAdresaVrsac;

      // NAPOMENA: Controller-i su već postavljeni iz putnik model-a iznad
      // Ne trebamo dodatno da ih premeštamo iz _novaVremenaBC/_novaVremenaVS mapa
    });

    // Use a responsive approach: bottom sheet on small screens, dialog on larger
    Widget dialogBuilder(BuildContext ctx) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Uredi mesečnog putnika',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🎯 OSNOVNE INFORMACIJE - Sekcija
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppThemeHelpers.getTypeColor(_noviTip, context)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppThemeHelpers.getTypeColor(_noviTip, context)
                        .withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeHelpers.getTypeColor(_noviTip, context)
                          .withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Osnovne informacije',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppThemeHelpers.getTypeColor(_noviTip, context),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) => _novoIme = value,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: '👤 Ime putnika *',
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                AppThemeHelpers.getTypeColor(_noviTip, context),
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.person,
                          color:
                              AppThemeHelpers.getTypeColor(_noviTip, context),
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      controller: _imeController,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _noviTip,
                      decoration: InputDecoration(
                        labelText: 'Tip putnika',
                        border: const OutlineInputBorder(),
                        prefixIcon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _noviTip == 'ucenik'
                                ? Icons.school
                                : Icons.business,
                            key: ValueKey('${_noviTip}_dropdown'),
                            color:
                                AppThemeHelpers.getTypeColor(_noviTip, context),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                AppThemeHelpers.getTypeColor(_noviTip, context),
                            width: 2,
                          ),
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'radnik',
                          child: Row(
                            children: [
                              Icon(
                                Icons.business,
                                color: Colors.teal,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text('Radnik'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ucenik',
                          child: Row(
                            children: [
                              Icon(
                                Icons.school,
                                color: Colors.orange,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text('Učenik'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _noviTip = value!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) => _novaTipSkole = value,
                      decoration: InputDecoration(
                        labelText: _noviTip == 'ucenik'
                            ? '🎓 Škola'
                            : '🏢 Ustanova/Firma',
                        hintText: _noviTip == 'ucenik'
                            ? 'npr. Gimnazija "Bora Stanković"'
                            : 'npr. Hemofarm, Opština Vršac...',
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                AppThemeHelpers.getTypeColor(_noviTip, context),
                            width: 2,
                          ),
                        ),
                        prefixIcon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _noviTip == 'ucenik'
                                ? Icons.school
                                : Icons.business,
                            key: ValueKey(_noviTip),
                            color:
                                AppThemeHelpers.getTypeColor(_noviTip, context),
                          ),
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      controller: _tipSkoleController,
                    ),
                  ],
                ),
              ),

              // 📞 KONTAKT INFORMACIJE - Sekcija
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📞 Kontakt informacije',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: _noviTip == 'ucenik'
                            ? '📱 Broj telefona učenika'
                            : '📞 Broj telefona',
                        hintText: '064/123-456',
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue, width: 2),
                        ),
                        prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      keyboardType: TextInputType.phone,
                      controller: _brojTelefonaController,
                    ),

                    // 👨‍👩‍👧‍👦 BROJEVI TELEFONA RODITELJA - animirana sekcija za učenike
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _noviTip == 'ucenik'
                          ? Container(
                              key: const ValueKey('parent_contacts_edit'),
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.family_restroom,
                                          color: Colors.orange,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Kontakt podaci roditelja',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.orange[700],
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Za hitne situacije',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.orange[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    onChanged: (value) =>
                                        _noviBrojTelefonaOca = value,
                                    decoration: const InputDecoration(
                                      labelText: 'Broj telefona oca',
                                      hintText: '064/123-456',
                                      border: OutlineInputBorder(),
                                      prefixIcon:
                                          Icon(Icons.man, color: Colors.blue),
                                      fillColor: Colors.white,
                                      filled: true,
                                    ),
                                    keyboardType: TextInputType.phone,
                                    controller: _brojTelefonaOcaController,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    onChanged: (value) =>
                                        _noviBrojTelefonaMajke = value,
                                    decoration: const InputDecoration(
                                      labelText: 'Broj telefona majke',
                                      hintText: '065/789-012',
                                      border: OutlineInputBorder(),
                                      prefixIcon:
                                          Icon(Icons.woman, color: Colors.pink),
                                      fillColor: Colors.white,
                                      filled: true,
                                    ),
                                    keyboardType: TextInputType.phone,
                                    controller: _brojTelefonaMajkeController,
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),

              // 📍 ADRESE POLASKA - Sekcija
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📍 Adrese polaska',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (value) => _novaAdresaBelaCrkva = value,
                      decoration: const InputDecoration(
                        labelText: '🏠 Adresa polaska - Bela Crkva',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.green, width: 2),
                        ),
                        prefixIcon: Icon(Icons.home, color: Colors.green),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      controller: _adresaBelaCrkvaController,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (value) => _novaAdresaVrsac = value,
                      decoration: const InputDecoration(
                        labelText: '🏢 Adresa polaska - Vršac',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.green, width: 2),
                        ),
                        prefixIcon: Icon(Icons.business, color: Colors.green),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      controller: _adresaVrsacController,
                    ),
                  ],
                ),
              ),

              // 📅 RADNI DANI I VREMENA - Sekcija
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📅 Radni dani i vremena',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Odaberi radne dane kada putnik koristi prevoz:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildRadniDanCheckbox(
                                'pon',
                                'Ponedeljak',
                              ),
                            ),
                            Expanded(
                              child: _buildRadniDanCheckbox('uto', 'Utorak'),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRadniDanCheckbox('sre', 'Sreda'),
                            ),
                            Expanded(
                              child: _buildRadniDanCheckbox('cet', 'Četvrtak'),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRadniDanCheckbox('pet', 'Petak'),
                            ),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildVremenaPolaskaSekcija(),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _novaVremenaBC.clear();
                _novaVremenaVS.clear();
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            child: const Text('Otkaži'),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: ElevatedButton.icon(
              onPressed: () => _sacuvajEditPutnika(putnik),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    AppThemeHelpers.getTypeColor(_noviTip, context),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Sačuvaj'),
            ),
          ),
        ],
      );
    }

    final mq = MediaQuery.of(context);
    if (mq.size.height < 700 || mq.size.width < 600) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(child: dialogBuilder(ctx)),
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (context) => dialogBuilder(context),
      );
    }
  }

  Future<void> _sacuvajEditPutnika(MesecniPutnik originalPutnik) async {
    // Validacija formulara
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Koristi vrednosti iz controller-a umesto iz varijabli
    final ime = _imeController.text.trim();
    final tipSkole = _tipSkoleController.text.trim();
    final brojTelefona = _brojTelefonaController.text.trim();

    try {
      // Pripremi mapu polazaka po danima (JSON)
      final Map<String, List<String>> polasciPoDanu = {};
      for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
        final bcRaw = _getControllerBelaCrkva(dan).text.trim();
        final vsRaw = _getControllerVrsac(dan).text.trim();
        final bc =
            bcRaw.isNotEmpty ? (MesecniHelpers.normalizeTime(bcRaw) ?? '') : '';
        final vs =
            vsRaw.isNotEmpty ? (MesecniHelpers.normalizeTime(vsRaw) ?? '') : '';
        final List<String> polasci = [];
        if (bc.isNotEmpty) polasci.add('$bc BC');
        if (vs.isNotEmpty) polasci.add('$vs VS');
        if (polasci.isNotEmpty) polasciPoDanu[dan] = polasci;
      }
      final editovanPutnik = originalPutnik.copyWith(
        putnikIme: ime,
        tip: _noviTip,
        tipSkole: tipSkole.isEmpty ? null : tipSkole,
        brojTelefona: brojTelefona.isEmpty ? null : brojTelefona,
        polasciPoDanu: polasciPoDanu,
        radniDani: _getRadniDaniString(),
      );
      // Log and await the update result so we can surface errors to the user

      final updated =
          await _mesecniPutnikService.azurirajMesecnogPutnika(editovanPutnik);

      if (updated == null) {
        // Update failed - show error and don't pop the dialog so user can retry
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Greška pri ažuriranju u bazi. Pokušajte ponovo.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Kreiraj dnevne putovanja za danas (1 dan unapred) da se odmah pojave u 'Danas' listi
      try {
        await _mesecniPutnikService.kreirajDnevnaPutovanjaIzMesecnih(
          editovanPutnik,
          DateTime.now().add(const Duration(days: 1)),
        );
      } catch (_) {}
      // Očisti mape izmena nakon uspešnog čuvanja
      setState(() {
        _novaVremenaBC.clear();
        _novaVremenaVS.clear();
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesečni putnik je uspešno ažuriran'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  void _pokaziDijalogZaDodavanje() {
    // Resetuj forme i controller-e
    setState(() {
      _novoIme = '';
      _noviTip = 'radnik';
      _novaTipSkole = '';
      _noviBrojTelefona = '';
      _noviBrojTelefonaOca = '';
      _noviBrojTelefonaMajke = '';
      _novaAdresaBelaCrkva = '';
      _novaAdresaVrsac = '';

      // Očisti controller-e
      _imeController.clear();
      _tipSkoleController.clear();
      _brojTelefonaController.clear();
      _brojTelefonaOcaController.clear();
      _brojTelefonaMajkeController.clear();
      _adresaBelaCrkvaController.clear();
      _adresaVrsacController.clear();

      // VAŽNO: Sinhronizuj controller-e sa varijablama
      _imeController.text = _novoIme;
      _tipSkoleController.text = _novaTipSkole;
      _brojTelefonaController.text = _noviBrojTelefona;
      _brojTelefonaOcaController.text = _noviBrojTelefonaOca;
      _brojTelefonaMajkeController.text = _noviBrojTelefonaMajke;
      _adresaBelaCrkvaController.text = _novaAdresaBelaCrkva;
      _adresaVrsacController.text = _novaAdresaVrsac;

      // Očisti controller-e za vremena
      _polazakBcPonController.clear();
      _polazakBcUtoController.clear();
      _polazakBcSreController.clear();
      _polazakBcCetController.clear();
      _polazakBcPetController.clear();
      _polazakVsPonController.clear();
      _polazakVsUtoController.clear();
      _polazakVsSreController.clear();
      _polazakVsCetController.clear();
      _polazakVsPetController.clear();

      // Resetuj radne dane na standardnu radnu nedelju
      _noviRadniDani = {
        'pon': true,
        'uto': true,
        'sre': true,
        'cet': true,
        'pet': true,
      };
    });
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - ulepšan sa animiranim elementima
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppThemeHelpers.getTypeColor(_noviTip, context)
                          .withOpacity(0.1),
                      AppThemeHelpers.getTypeColor(_noviTip, context)
                          .withOpacity(0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeHelpers.getTypeColor(_noviTip, context)
                          .withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey('${_noviTip}_add'),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppThemeHelpers.getTypeColor(_noviTip, context)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person_add,
                          color: AppThemeHelpers.getTypeOnContainerColor(
                            _noviTip,
                            context,
                          ),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              AppThemeHelpers.getTypeIcon(_noviTip),
                              key: ValueKey(_noviTip),
                              color: AppThemeHelpers.getTypeOnContainerColor(
                                _noviTip,
                                context,
                              ),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Dodaj ${_noviTip == 'ucenik' ? 'učenika' : 'radnika'}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppThemeHelpers.getTypeOnContainerColor(
                                _noviTip,
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          // 🧹 RESETUJ FORMU KADA SE ZATVORI DIJALOG
                          _resetujFormuZaDodavanje();
                          Navigator.pop(context);
                        },
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 🎯 OSNOVNE INFORMACIJE - Sekcija sa stilom kao statistike
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppThemeHelpers.getTypeColor(_noviTip, context)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                AppThemeHelpers.getTypeColor(_noviTip, context)
                                    .withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppThemeHelpers.getTypeColor(
                                _noviTip,
                                context,
                              ).withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppThemeHelpers.getTypeColor(
                                      _noviTip,
                                      context,
                                    ).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: AppThemeHelpers.getTypeColor(
                                      _noviTip,
                                      context,
                                    ),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '📋 Osnovne informacije',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppThemeHelpers.getTypeColor(
                                        _noviTip,
                                        context,
                                      ),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              onChanged: (value) {
                                _novoIme = value;
                                if (_imeController.text != value) {
                                  _imeController.text = value;
                                }
                              },
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: '👤 Ime putnika *',
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppThemeHelpers.getTypeColor(
                                      _noviTip,
                                      context,
                                    ),
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: AppThemeHelpers.getTypeColor(
                                    _noviTip,
                                    context,
                                  ),
                                ),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              controller: _imeController,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _noviTip,
                              decoration: InputDecoration(
                                labelText: 'Tip putnika',
                                border: const OutlineInputBorder(),
                                prefixIcon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    _noviTip == 'ucenik'
                                        ? Icons.school
                                        : Icons.business,
                                    key: ValueKey('${_noviTip}_dropdown'),
                                    color: AppThemeHelpers.getTypeColor(
                                      _noviTip,
                                      context,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppThemeHelpers.getTypeColor(
                                      _noviTip,
                                      context,
                                    ),
                                    width: 2,
                                  ),
                                ),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'radnik',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.business,
                                        color: Colors.teal,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Radnik'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'ucenik',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.school,
                                        color: Colors.orange,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Učenik'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _noviTip = value!),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              onChanged: (value) {
                                _novaTipSkole = value;
                                if (_tipSkoleController.text != value) {
                                  _tipSkoleController.text = value;
                                }
                              },
                              decoration: InputDecoration(
                                labelText: _noviTip == 'ucenik'
                                    ? '🎓 Škola'
                                    : '🏢 Ustanova/Firma',
                                hintText: _noviTip == 'ucenik'
                                    ? 'npr. Gimnazija "Bora Stanković"'
                                    : 'npr. Hemofarm, Opština Vršac...',
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: AppThemeHelpers.getTypeColor(
                                      _noviTip,
                                      context,
                                    ),
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    _noviTip == 'ucenik'
                                        ? Icons.school
                                        : Icons.business,
                                    key: ValueKey(_noviTip),
                                    color: AppThemeHelpers.getTypeColor(
                                      _noviTip,
                                      context,
                                    ),
                                  ),
                                ),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              controller: _tipSkoleController,
                            ),
                          ],
                        ),
                      ),

                      // 📞 KONTAKT INFORMACIJE - Sekcija
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.phone,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '📞 Kontakt informacije',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              onChanged: (value) {
                                _noviBrojTelefona = value;
                                if (_brojTelefonaController.text != value) {
                                  _brojTelefonaController.text = value;
                                }
                              },
                              decoration: InputDecoration(
                                labelText: _noviTip == 'ucenik'
                                    ? '📱 Broj telefona učenika'
                                    : '📞 Broj telefona',
                                hintText: '064/123-456',
                                border: const OutlineInputBorder(),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.blue, width: 2),
                                ),
                                prefixIcon:
                                    const Icon(Icons.phone, color: Colors.blue),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              keyboardType: TextInputType.phone,
                              controller: _brojTelefonaController,
                            ),

                            // 👨‍👩‍👧‍👦 BROJEVI TELEFONA RODITELJA - animirana sekcija za učenike
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _noviTip == 'ucenik'
                                  ? Container(
                                      key:
                                          const ValueKey('parent_contacts_add'),
                                      margin: const EdgeInsets.only(top: 16),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.orange.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons.family_restroom,
                                                  color: Colors.orange,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Kontakt podaci roditelja',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Colors.orange[700],
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Za hitne situacije',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors.orange[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            onChanged: (value) {
                                              _noviBrojTelefonaOca = value;
                                              if (_brojTelefonaOcaController
                                                      .text !=
                                                  value) {
                                                _brojTelefonaOcaController
                                                    .text = value;
                                              }
                                            },
                                            decoration: const InputDecoration(
                                              labelText: 'Broj telefona oca',
                                              hintText: '064/123-456',
                                              border: OutlineInputBorder(),
                                              prefixIcon: Icon(
                                                Icons.man,
                                                color: Colors.blue,
                                              ),
                                              fillColor: Colors.white,
                                              filled: true,
                                            ),
                                            keyboardType: TextInputType.phone,
                                            controller:
                                                _brojTelefonaOcaController,
                                          ),
                                          const SizedBox(height: 8),
                                          TextField(
                                            onChanged: (value) {
                                              _noviBrojTelefonaMajke = value;
                                              if (_brojTelefonaMajkeController
                                                      .text !=
                                                  value) {
                                                _brojTelefonaMajkeController
                                                    .text = value;
                                              }
                                            },
                                            decoration: const InputDecoration(
                                              labelText: 'Broj telefona majke',
                                              hintText: '065/789-012',
                                              border: OutlineInputBorder(),
                                              prefixIcon: Icon(
                                                Icons.woman,
                                                color: Colors.pink,
                                              ),
                                              fillColor: Colors.white,
                                              filled: true,
                                            ),
                                            keyboardType: TextInputType.phone,
                                            controller:
                                                _brojTelefonaMajkeController,
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),

                      // 📍 ADRESE POLASKA - Sekcija
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '📍 Adrese polaska',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              onChanged: (value) {
                                _novaAdresaBelaCrkva = value;
                                if (_adresaBelaCrkvaController.text != value) {
                                  _adresaBelaCrkvaController.text = value;
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: '🏠 Adresa polaska - Bela Crkva',
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.green, width: 2),
                                ),
                                prefixIcon:
                                    Icon(Icons.home, color: Colors.green),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              controller: _adresaBelaCrkvaController,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              onChanged: (value) {
                                _novaAdresaVrsac = value;
                                if (_adresaVrsacController.text != value) {
                                  _adresaVrsacController.text = value;
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: '🏢 Adresa polaska - Vršac',
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Colors.green, width: 2),
                                ),
                                prefixIcon:
                                    Icon(Icons.business, color: Colors.green),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              controller: _adresaVrsacController,
                            ),
                          ],
                        ),
                      ),

                      // 📅 RADNI DANI I VREMENA - Sekcija
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today,
                                    color: Colors.purple,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '📅 Radni dani i vremena',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple[700],
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Izaberite dane kada putnik radi:',
                                  style: TextStyle(
                                    color: Colors.purple[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _noviRadniDani = {
                                            'pon': true,
                                            'uto': true,
                                            'sre': true,
                                            'cet': true,
                                            'pet': true,
                                          };
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Svi',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.purple[600],
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _noviRadniDani = {
                                            'pon': false,
                                            'uto': false,
                                            'sre': false,
                                            'cet': false,
                                            'pet': false,
                                          };
                                        });
                                      },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Nijedan',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 2,
                              runSpacing: 2,
                              children: [
                                _buildRadniDanCheckbox('pon', 'Ponedeljak'),
                                _buildRadniDanCheckbox('uto', 'Utorak'),
                                _buildRadniDanCheckbox('sre', 'Sreda'),
                                _buildRadniDanCheckbox('cet', 'Četvrtak'),
                                _buildRadniDanCheckbox('pet', 'Petak'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.purple[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Primer: Ponedeljak, Sreda, Petak',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.purple[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildVremenaPolaskaSekcija(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        // 🧹 RESETUJ FORMU KADA SE ODUSTANE OD DODAVANJA
                        _resetujFormuZaDodavanje();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                      child: const Text('Otkaži'),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton.icon(
                        onPressed: () => _sacuvajNovogPutnika(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _noviTip == 'ucenik'
                              ? Colors.orange
                              : Colors.teal,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('Sačuvaj'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🧹 RESETUJ FORMU ZA DODAVANJE MESEČNOG PUTNIKA
  void _resetujFormuZaDodavanje() {
    setState(() {
      // Resetuj osnovne varijable
      _novoIme = '';
      _noviTip = 'radnik';
      _novaTipSkole = '';
      _noviBrojTelefona = '';
      _noviBrojTelefonaOca = '';
      _noviBrojTelefonaMajke = '';
      _novaAdresaBelaCrkva = '';
      _novaAdresaVrsac = '';

      // Očisti sve text controller-e
      _imeController.clear();
      _tipSkoleController.clear();
      _brojTelefonaController.clear();
      _brojTelefonaOcaController.clear();
      _brojTelefonaMajkeController.clear();
      _adresaBelaCrkvaController.clear();
      _adresaVrsacController.clear();

      // Očisti controller-e za vremena polaska
      _polazakBcPonController.clear();
      _polazakBcUtoController.clear();
      _polazakBcSreController.clear();
      _polazakBcCetController.clear();
      _polazakBcPetController.clear();
      _polazakVsPonController.clear();
      _polazakVsUtoController.clear();
      _polazakVsSreController.clear();
      _polazakVsCetController.clear();
      _polazakVsPetController.clear();

      // Resetuj radne dane na standardnu radnu nedelju
      _noviRadniDani = {
        'pon': true,
        'uto': true,
        'sre': true,
        'cet': true,
        'pet': true,
      };
    });
  }

  /// 🕐 SAČUVAJ VREME POLASKA U ISTORIJU ZA AUTOCOMPLETE
  Future<void> _sacuvajVremePolasakaUIstorijuZaDan(
    SharedPreferences prefs,
    String vreme,
    String smer, // 'BC' ili 'VS'
    String dan,
    String? vozac,
  ) async {
    try {
      // Normalizuj vreme
      final normalizedTime = MesecniHelpers.normalizeTime(vreme);
      if (normalizedTime == null) return;

      // Kreiraj ključ za čuvanje vremena
      final key = 'time_history_${smer}_${dan}_${vozac ?? 'global'}';

      // Učitaj postojeće vremena
      final existingTimesJson = prefs.getString(key) ?? '{}';
      final existingTimes = Map<String, int>.from(
        json.decode(existingTimesJson) as Map<String, dynamic>,
      );

      // Povećaj broj korišćenja za ovo vreme
      existingTimes[normalizedTime] = (existingTimes[normalizedTime] ?? 0) + 1;

      // Ograniči na maksimalno 20 vremena po ključu da ne zauzima previše prostora
      if (existingTimes.length > 20) {
        // Sortiraj po frekvenciji i zadržar samo top 20
        final sortedEntries = existingTimes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        existingTimes.clear();
        for (int i = 0; i < 20 && i < sortedEntries.length; i++) {
          existingTimes[sortedEntries[i].key] = sortedEntries[i].value;
        }
      }

      // Sačuvaj nazad u SharedPreferences
      await prefs.setString(key, json.encode(existingTimes));

      dlog(
        '💾 Sačuvano vreme $normalizedTime za $smer $dan (vozač: ${vozac ?? 'global'})',
      );
    } catch (e) {
      dlog('❌ Greška pri čuvanju vremena polaska: $e');
    }
  }

  Future<void> _sacuvajNovogPutnika() async {
    // Validacija formulara
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Koristi vrednosti iz controller-a umesto iz varijabli
    final ime = _imeController.text.trim();
    final tipSkole = _tipSkoleController.text.trim();
    final brojTelefona = _brojTelefonaController.text.trim();
    final brojTelefonaOca = _brojTelefonaOcaController.text.trim();
    final brojTelefonaMajke = _brojTelefonaMajkeController.text.trim();
    final adresaBelaCrkva = _adresaBelaCrkvaController.text.trim();
    final adresaVrsac = _adresaVrsacController.text.trim();

    try {
      // Dobij trenutnog vozača kao UUID
      final currentDriverUuid = await _getCurrentDriverUuid();

      // Pripremi mapu polazaka po danima (JSON)
      final Map<String, List<String>> polasciPoDanu = {};
      for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
        final bcRaw = _getControllerBelaCrkva(dan).text.trim();
        final vsRaw = _getControllerVrsac(dan).text.trim();
        final bc =
            bcRaw.isNotEmpty ? (MesecniHelpers.normalizeTime(bcRaw) ?? '') : '';
        final vs =
            vsRaw.isNotEmpty ? (MesecniHelpers.normalizeTime(vsRaw) ?? '') : '';
        final List<String> polasci = [];
        if (bc.isNotEmpty) polasci.add('$bc BC');
        if (vs.isNotEmpty) polasci.add('$vs VS');
        if (polasci.isNotEmpty) polasciPoDanu[dan] = polasci;
      }
      final noviPutnik = MesecniPutnik(
        id: '', // Biće generisan od strane baze - OK jer toMap() će podesiti UUID
        putnikIme: ime, // Celo ime u jednom polju
        tip: _noviTip, // Direktno string bez extension-a
        tipSkole: tipSkole.isEmpty ? null : tipSkole,
        brojTelefona: brojTelefona.isEmpty ? null : brojTelefona,
        brojTelefonaOca: brojTelefonaOca.isEmpty ? null : brojTelefonaOca,
        brojTelefonaMajke: brojTelefonaMajke.isEmpty ? null : brojTelefonaMajke,
        polasciPoDanu: polasciPoDanu,
        adresaBelaCrkva: adresaBelaCrkva.isEmpty ? null : adresaBelaCrkva,
        adresaVrsac: adresaVrsac.isEmpty ? null : adresaVrsac,
        radniDani: _getRadniDaniString(),
        datumPocetkaMeseca: DateTime(DateTime.now().year, DateTime.now().month),
        datumKrajaMeseca:
            DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: currentDriverUuid.isNotEmpty ? currentDriverUuid : null,
        // Ostali parametri imaju default vrednosti (aktivan: true, itd.)
      );

      print('🔄 DODAVANJE MESECNOG PUTNIKA: ${noviPutnik.putnikIme}');
      print('   - aktivan: ${noviPutnik.aktivan}');
      print('   - obrisan: ${noviPutnik.obrisan}');
      print('   - tip: ${noviPutnik.tip}');

      final dodatiPutnik =
          await _mesecniPutnikService.dodajMesecnogPutnika(noviPutnik);
      print(
        '✅ USPEŠNO DODAT PUTNIK: ${dodatiPutnik.id} - ${dodatiPutnik.putnikIme}',
      );

      // 🔄 KRITIČNO: Refresh RealtimeService da se promene propagiraju kroz sve servise
      try {
        await RealtimeService.instance.refreshNow();
        print('🔄 FORSIRAJ REFRESH RealtimeService');
      } catch (e) {
        print('⚠️ GREŠKA pri refresh-u RealtimeService: $e');
      }

      // Kreiraj dnevne putovanja za danas (1 dan unapred) da se odmah pojave u 'Danas' listi
      try {
        await _mesecniPutnikService.kreirajDnevnaPutovanjaIzMesecnih(
          dodatiPutnik,
          DateTime.now().add(const Duration(days: 1)),
        );
        print(
          '✅ KREIRANA DNEVNA PUTOVANJA za putnika: ${dodatiPutnik.putnikIme}',
        );
      } catch (e) {
        print('❌ GREŠKA pri kreiranju dnevnih putovanja: $e');
      }

      // ✅ DODATO: Forsiraj refresh state-a da se novi putnik odmah prikaže
      if (mounted) {
        setState(() {});
        Navigator.pop(context);

        // Prikaži uspešnu poruku
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Uspešno dodat putnik: ${dodatiPutnik.putnikIme}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      // 💾 SAČUVAJ ADRESE I VREMENA U ISTORIJU ZA AUTOCOMPLETE
      try {
        // Dobij trenutnog vozača kao UUID
        final prefs = await SharedPreferences.getInstance();
        final currentDriverName = await _getCurrentDriver();

        // Zabelezi upotrebu adrese Bela Crkva
        final adresaBelaCrkva = _adresaBelaCrkvaController.text.trim();
        if (adresaBelaCrkva.isNotEmpty) {
          await SmartAddressAutocompleteService.recordAddressUsage(
            address: adresaBelaCrkva,
            city: 'Bela Crkva',
            vozac: currentDriverName,
            timeContext: DateTime.now(),
          );
        }

        // Zabelezi upotrebu adrese Vršac
        final adresaVrsac = _adresaVrsacController.text.trim();
        if (adresaVrsac.isNotEmpty) {
          await SmartAddressAutocompleteService.recordAddressUsage(
            address: adresaVrsac,
            city: 'Vršac',
            vozac: currentDriverName,
            timeContext: DateTime.now(),
          );
        }

        // 🕐 SAČUVAJ VREMENA POLASKA U ISTORIJU
        for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
          if (_noviRadniDani[dan] == true) {
            final bcTime = _getControllerBelaCrkva(dan).text.trim();
            final vsTime = _getControllerVrsac(dan).text.trim();

            // Sačuvaj BC vremena ako postoje
            if (bcTime.isNotEmpty) {
              await _sacuvajVremePolasakaUIstorijuZaDan(
                prefs,
                bcTime,
                'BC',
                dan,
                currentDriverName,
              );
            }

            // Sačuvaj VS vremena ako postoje
            if (vsTime.isNotEmpty) {
              await _sacuvajVremePolasakaUIstorijuZaDan(
                prefs,
                vsTime,
                'VS',
                dan,
                currentDriverName,
              );
            }
          }
        }
      } catch (e) {
        // Greška pri snimanju adresa i vremena - ne prekidaj proces
        dlog('❌ Greška pri snimanju adresa i vremena u istoriju: $e');
      } // 🧹 RESETUJ FORMU NAKON USPEŠNOG DODAVANJA
      _resetujFormuZaDodavanje();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mesečni putnik je uspešno dodat'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška: $e')),
        );
      }
    }
  }

  void _obrisiPutnika(MesecniPutnik putnik) async {
    // Pokaži potvrdu za brisanje
    final potvrda = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrdi brisanje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Da li ste sigurni da želite da obrišete putnika "${putnik.putnikIme}"?',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Važne informacije:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• Putnik će biti označen kao obrisan'),
                  const Text('• Postojeća istorija putovanja se čuva'),
                  Text('• Broj putovanja: ${putnik.brojPutovanja}'),
                  const Text('• Možete kasnije da sinhronizujete statistike'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Obriši', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (potvrda == true && mounted) {
      try {
        final success =
            await _mesecniPutnikService.obrisiMesecniPutnik(putnik.id);

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${putnik.putnikIme} je uspešno obrisan'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'SINHRONIZUJ STATISTIKE',
                onPressed: () => _sinhronizujStatistike(putnik.id),
              ),
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Greška pri brisanju putnika'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Greška: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _sinhronizujStatistike(String putnikId) async {
    try {
      final success =
          await MesecniPutnikService.sinhronizujBrojPutovanjaSaIstorijom(
        putnikId,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Statistike su uspešno sinhronizovane sa istorijom'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri sinhronizaciji: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper funkcija za brojanje kontakata
  int _prebrojKontakte(MesecniPutnik putnik) {
    int brojKontakata = 0;
    if (putnik.brojTelefona != null && putnik.brojTelefona!.isNotEmpty) {
      brojKontakata++;
    }
    if (putnik.brojTelefonaOca != null && putnik.brojTelefonaOca!.isNotEmpty) {
      brojKontakata++;
    }
    if (putnik.brojTelefonaMajke != null &&
        putnik.brojTelefonaMajke!.isNotEmpty) {
      brojKontakata++;
    }
    return brojKontakata;
  }

  // 👨‍👩‍👧‍👦 NOVA FUNKCIJA - Prikazuje sve dostupne kontakte
  Future<void> _pokaziKontaktOpcije(MesecniPutnik putnik) async {
    final List<Widget> opcije = [];

    // Glavni broj telefona
    if (putnik.brojTelefona != null && putnik.brojTelefona!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: const Icon(Icons.person, color: Colors.green),
          title: const Text('Pozovi putnika'),
          subtitle: Text(putnik.brojTelefona!),
          onTap: () async {
            Navigator.pop(context);
            await _pozovi(putnik.brojTelefona!);
          },
        ),
      );
      opcije.add(
        ListTile(
          leading: const Icon(Icons.sms, color: Colors.green),
          title: const Text('SMS putnik'),
          subtitle: Text(putnik.brojTelefona!),
          onTap: () async {
            Navigator.pop(context);
            await _posaljiSMS(putnik.brojTelefona!);
          },
        ),
      );
    }

    // Otac
    if (putnik.brojTelefonaOca != null && putnik.brojTelefonaOca!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: const Icon(Icons.man, color: Colors.blue),
          title: const Text('Pozovi oca'),
          subtitle: Text(putnik.brojTelefonaOca!),
          onTap: () async {
            Navigator.pop(context);
            await _pozovi(putnik.brojTelefonaOca!);
          },
        ),
      );
    }

    // Majka
    if (putnik.brojTelefonaMajke != null &&
        putnik.brojTelefonaMajke!.isNotEmpty) {
      opcije.add(
        ListTile(
          leading: const Icon(Icons.woman, color: Colors.pink),
          title: const Text('Pozovi majku'),
          subtitle: Text(putnik.brojTelefonaMajke!),
          onTap: () async {
            Navigator.pop(context);
            await _pozovi(putnik.brojTelefonaMajke!);
          },
        ),
      );
    }

    if (opcije.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nema dostupnih kontakata')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kontaktiraj ${putnik.putnikIme}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...opcije,
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Otkaži'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pozovi(String brojTelefona) async {
    try {
      // 📞 HUAWEI KOMPATIBILNO - koristi Huawei specifičnu logiku (konzistentno sa putnik_card)
      final hasPermission =
          await PermissionService.ensurePhonePermissionHuawei();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Dozvola za pozive je potrebna'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final phoneUrl = Uri.parse('tel:$brojTelefona');
      if (await canLaunchUrl(phoneUrl)) {
        await launchUrl(phoneUrl);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Nije moguće pozivanje sa ovog uređaja'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška pri pozivanju: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _posaljiSMS(String brojTelefona) async {
    final url = Uri.parse('sms:$brojTelefona');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nije moguće poslati SMS'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška pri slanju SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 📅 FORMAT DATUMA
  String _formatDatum(DateTime datum) {
    return '${datum.day}.${datum.month}.${datum.year}';
  }

  // � DOBIJANJE TRENUTNOG VOZAČA (kao UUID)
  Future<String> _getCurrentDriverUuid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final driverName = prefs.getString('current_driver');
      dlog('🔍 [GET CURRENT DRIVER UUID] Driver name from prefs: $driverName');

      if (driverName != null && driverName.isNotEmpty) {
        // Ako je već UUID, vrati direktno
        if (VozacMappingService.isValidVozacUuidSync(driverName)) {
          dlog('✅ [GET CURRENT DRIVER UUID] Already UUID: $driverName');
          return driverName;
        }
        // Inače konvertuj ime u UUID
        final uuid = VozacMappingService.getVozacUuidSync(driverName);
        if (uuid != null && uuid.isNotEmpty) {
          dlog(
            '✅ [GET CURRENT DRIVER UUID] Converted $driverName to UUID: $uuid',
          );
          return uuid;
        } else {
          dlog(
            '❌ [GET CURRENT DRIVER UUID] Failed to convert $driverName to UUID',
          );
        }
      }
      dlog(
        '⚠️ [GET CURRENT DRIVER UUID] Returning empty string - no valid driver',
      );
      return ''; // Vraća prazan string ako nije poznat
    } catch (e) {
      dlog('❌ [GET CURRENT DRIVER UUID] Error: $e');
      return '';
    }
  }

  // Čuva legacy funkciju za kompatibilnost
  Future<String> _getCurrentDriver() async {
    final uuid = await _getCurrentDriverUuid();
    return VozacMappingService.getVozacImeWithFallbackSync(uuid);
  }

  // �💰 PRIKAZ DIJALOGA ZA PLAĆANJE
  Future<void> _prikaziPlacanje(MesecniPutnik putnik) async {
    final TextEditingController iznosController = TextEditingController();
    String selectedMonth = _getCurrentMonthYear(); // Default current month

    // Ako je već plaćeno, prikaži postojeći iznos
    if (putnik.cena != null && putnik.cena! > 0) {
      iznosController.text = putnik.cena!.toStringAsFixed(0);
    }

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.payments_outlined, color: Colors.purple.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Plaćanje - ${putnik.putnikIme}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (putnik.cena != null && putnik.cena! > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Trenutno plaćeno: ${putnik.cena!.toStringAsFixed(0)} RSD',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  if (putnik.vremePlacanja != null)
                                    Text(
                                      'Datum: ${_formatDatum(putnik.vremePlacanja!)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                  if (putnik.vozac != null &&
                                      putnik.vozac!.isNotEmpty)
                                    Text(
                                      'Naplatio: ${putnik.vozac}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: VozacBoja.get(putnik.vozac),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 📅 IZBOR MESECA
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedMonth,
                          icon: Icon(
                            Icons.calendar_month,
                            color: Colors.purple.shade600,
                          ),
                          style: TextStyle(
                            color: Colors.purple.shade700,
                            fontSize: 16,
                          ),
                          menuMaxHeight: 300, // Ograniči visinu dropdown menija
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedMonth = newValue!;
                            });
                          },
                          items: _getMonthOptions()
                              .map<DropdownMenuItem<String>>((String value) {
                            // Proveri da li je mesec plaćen
                            final bool isPlacen = _isMonthPaid(value, putnik);

                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: TextStyle(
                                  color: isPlacen ? Colors.green[700] : null,
                                  fontWeight: isPlacen
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 💰 IZNOS
                    TextField(
                      controller: iznosController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Iznos (dinari)',
                        hintText: 'Unesite iznos plaćanja',
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: Colors.purple.shade600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.purple.shade600,
                            width: 2,
                          ),
                        ),
                      ),
                      autofocus: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Otkaži'),
                ),
                // 📊 DUGME ZA DETALJNE STATISTIKE
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(); // Zatvori trenutni dialog
                    _prikaziDetaljneStatistike(putnik); // Otvori statistike
                  },
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Detaljno'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final iznos = double.tryParse(iznosController.text);
                    if (iznos != null && iznos > 0) {
                      Navigator.of(context).pop();
                      await _sacuvajPlacanje(putnik.id, iznos, selectedMonth);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Unesite valjan iznos'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Sačuvaj'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  } // 💾 ČUVANJE PLAĆANJA

  // 📊 PRIKAŽI DETALJNE STATISTIKE PUTNIKA
  Future<void> _prikaziDetaljneStatistike(MesecniPutnik putnik) async {
    String selectedPeriod = _getCurrentMonthYear();

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.analytics_outlined, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Detaljne statistike - ${putnik.putnikIme}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📅 DROPDOWN ZA PERIOD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedPeriod,
                          isExpanded: true,
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.blue.shade600,
                          ),
                          items: _getMonthOptions()
                              .map<DropdownMenuItem<String>>((String value) {
                            // Proveri da li je mesec plaćen
                            final bool isPlacen = _isMonthPaid(value, putnik);

                            return DropdownMenuItem<String>(
                              value: value,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: isPlacen
                                        ? Colors.green
                                        : Colors.blue.shade300,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    value,
                                    style: TextStyle(
                                      color:
                                          isPlacen ? Colors.green[700] : null,
                                      fontWeight: isPlacen
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList()
                            ..addAll([
                              // 📊 CELA GODINA I UKUPNO
                              const DropdownMenuItem(
                                value: 'Cela 2025',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_note,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Cela 2025'),
                                  ],
                                ),
                              ),
                              const DropdownMenuItem(
                                value: 'Ukupno',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 16,
                                      color: Colors.purple,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Ukupno'),
                                  ],
                                ),
                              ),
                            ]),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedPeriod = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 📊 OPTIMIZOVANO: StreamBuilder umesto FutureBuilder
                    StreamBuilder<Map<String, dynamic>>(
                      stream:
                          _streamStatistikeZaPeriod(putnik.id, selectedPeriod),
                      builder: (context, snapshot) {
                        // Loading state
                        if (snapshot.connectionState ==
                                ConnectionState.waiting ||
                            !snapshot.hasData) {
                          return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        // 🔄 ERROR HANDLING: Poboljšano error handling
                        if (snapshot.hasError) {
                          return SizedBox(
                            height: 200,
                            child: StreamErrorWidget(
                              streamName: 'MesecniPutniciStats',
                              errorMessage: snapshot.error.toString(),
                              onRetry: () => setState(() {}),
                            ),
                          );
                        }

                        // Check for data errors
                        final stats = snapshot.data ?? {};
                        if (stats['error'] == true) {
                          return SizedBox(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_outlined,
                                    color: Colors.orange,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Podaci trenutno nisu dostupni.\nPovežite se na internet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.orange[700]),
                                  ),
                                  if (!_isConnected) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'OFFLINE',
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }

                        return _buildStatistikeContent(
                          putnik,
                          stats,
                          selectedPeriod,
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Zatvori'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 📊 KREIRANJE SADRŽAJA STATISTIKA NA OSNOVU PERIODA
  Widget _buildStatistikeContent(
    MesecniPutnik putnik,
    Map<String, dynamic> stats,
    String period,
  ) {
    Color periodColor = Colors.orange;
    IconData periodIcon = Icons.calendar_today;

    // Posebni slučajevi
    if (period == 'Cela 2025') {
      periodColor = Colors.blue;
      periodIcon = Icons.event_note;
    } else if (period == 'Ukupno') {
      periodColor = Colors.purple;
      periodIcon = Icons.history;
    } else {
      // Meseci - uzmi zelenu boju ako je plaćen
      final bool isPlacen = _isMonthPaid(period, putnik);
      periodColor = isPlacen ? Colors.green : Colors.orange;
      periodIcon = Icons.calendar_today;
    }

    return Column(
      children: [
        // 🎯 OSNOVNE INFORMACIJE
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📋 Osnovne informacije',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatRow('👤 Ime:', putnik.putnikIme),
              _buildStatRow('📅 Radni dani:', putnik.radniDani),
              _buildStatRow('📊 Tip putnika:', putnik.tip),
              if (putnik.tipSkole != null)
                _buildStatRow(
                  putnik.tip == 'ucenik' ? '� Škola:' : '�🏢 Ustanova/Firma:',
                  putnik.tipSkole!,
                ),
              if (putnik.brojTelefona != null)
                _buildStatRow('📞 Telefon:', putnik.brojTelefona!),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 💰 FINANSIJSKE INFORMACIJE
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💰 Finansijske informacije',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatRow(
                '💵 Poslednje plaćanje:',
                putnik.cena != null && putnik.cena! > 0
                    ? '${putnik.cena!.toStringAsFixed(0)} RSD'
                    : 'Nema podataka o ceni',
              ),
              _buildStatRow(
                '📅 Datum plaćanja:',
                putnik.vremePlacanja != null
                    ? _formatDatum(putnik.vremePlacanja!)
                    : 'Nema podataka o datumu',
              ),
              _buildStatRow('🚗 Vozač (naplata):', putnik.vozacIme),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 📈 STATISTIKE PUTOVANJA - DINAMICKI PERIOD
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: periodColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: periodColor.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(periodIcon, size: 16, color: periodColor),
                  const SizedBox(width: 4),
                  Text(
                    '📈 Statistike',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: periodColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildStatRow('🚗 Putovanja:', '${stats['putovanja'] ?? 0}'),
              _buildStatRow('❌ Otkazivanja:', '${stats['otkazivanja'] ?? 0}'),
              _buildStatRow(
                '🔄 Poslednje putovanje:',
                stats['poslednje'] as String? ?? 'Nema podataka',
              ),
              _buildStatRow('📊 Uspešnost:', '${stats['uspesnost'] ?? 0}%'),
              if (period == 'all_time' && stats['ukupan_prihod'] != null)
                _buildStatRow(
                  '💰 Ukupan prihod:',
                  '${stats['ukupan_prihod']} RSD',
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 🕐 SISTEMSKE INFORMACIJE
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🕐 Sistemske informacije',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatRow('� Kreiran:', _formatDatum(putnik.createdAt)),
              _buildStatRow('🔄 Ažuriran:', _formatDatum(putnik.updatedAt)),
              _buildStatRow(
                '✅ Status:',
                putnik.aktivan ? 'Aktivan' : 'Neaktivan',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 📊 REAL-TIME STATISTIKE STREAM - SINHRONIZOVANO SA BAZOM
  Stream<Map<String, dynamic>> _streamStatistikeZaPeriod(
    String putnikId,
    String period,
  ) {
    // 🔄 KORISTI NOVI CENTRALIZOVANI REAL-TIME SERVIS
    return RealTimeStatistikaService.instance
        .getPutnikStatistikeStream(putnikId)
        .asyncMap((baseStats) async {
      try {
        // Posebni slučajevi
        if (period == 'Cela 2025') {
          return await _getGodisnjeStatistike(putnikId);
        }
        if (period == 'Ukupno') {
          return await _getUkupneStatistike(putnikId);
        }

        // Parsiraj mesec u formatu "Septembar 2025"
        final parts = period.split(' ');
        if (parts.length == 2) {
          final monthName = parts[0];
          final year = int.tryParse(parts[1]);

          if (year != null) {
            final monthNumber = _getMonthNumber(monthName);
            if (monthNumber > 0) {
              return await _getStatistikeZaMesec(putnikId, monthNumber, year);
            }
          }
        }

        // Fallback na trenutni mesec
        return await _getMesecneStatistike(putnikId);
      } catch (e) {
        dlog('❌ Greška pri dohvatanju statistika za period $period: $e');
        return {
          'putovanja': 0,
          'otkazivanja': 0,
          'poslednje': 'Greška pri učitavanju',
          'uspesnost': 0,
          'error': true,
        };
      }
    }).handleError((Object error) {
      dlog('❌ Stream error za statistike: $error');
      return {
        'putovanja': 0,
        'otkazivanja': 0,
        'poslednje': 'Stream greška',
        'uspesnost': 0,
        'error': true,
      };
    });
  }

  // 📅 GODIŠNJE STATISTIKE (2025)
  Future<Map<String, dynamic>> _getGodisnjeStatistike(String putnikId) async {
    final startOfYear = DateTime(2025);
    final endOfYear = DateTime(2025, 12, 31);

    final response = await supabase
        .from('putovanja_istorija')
        .select()
        .eq('putnik_id', putnikId)
        .gte('created_at', startOfYear.toIso8601String())
        .lte('created_at', endOfYear.toIso8601String())
        .order('created_at', ascending: false);

    int putovanja = 0;
    int otkazivanja = 0;
    String? poslednje;
    double ukupanPrihod = 0;

    for (final record in response) {
      final status = record['status'];
      // Iznos može biti u 'cena' (novi zapisi) ili 'iznos_placanja' (legacy)
      final double iznos =
          ((record['cena'] ?? record['iznos_placanja'] ?? 0) as num).toDouble();

      if (status == 'pokupljen' || status == 'placeno') {
        putovanja++;
        ukupanPrihod += iznos;
      } else if (status == 'otkazan') {
        otkazivanja++;
      }

      if (poslednje == null && record['created_at'] != null) {
        final datum = DateTime.parse(record['created_at'] as String);
        poslednje = '${datum.day}/${datum.month}/${datum.year}';
      }
    }

    final ukupno = putovanja + otkazivanja;
    final uspesnost = ukupno > 0 ? ((putovanja / ukupno) * 100).round() : 0;

    return {
      'putovanja': putovanja,
      'otkazivanja': otkazivanja,
      'poslednje': poslednje ?? 'Nema podataka',
      'uspesnost': uspesnost,
      'ukupan_prihod': '${ukupanPrihod.toStringAsFixed(0)} RSD',
    };
  }

  // 🏆 UKUPNE STATISTIKE (SVI PODACI)
  Future<Map<String, dynamic>> _getUkupneStatistike(String putnikId) async {
    final response = await supabase
        .from('putovanja_istorija')
        .select()
        .eq('putnik_id', putnikId)
        .order('created_at', ascending: false);

    int putovanja = 0;
    int otkazivanja = 0;
    String? poslednje;
    double ukupanPrihod = 0;

    for (final record in response) {
      final status = record['status'];
      // Iznos može biti u 'cena' (novi zapisi) ili 'iznos_placanja' (legacy)
      final double iznos =
          ((record['cena'] ?? record['iznos_placanja'] ?? 0) as num).toDouble();

      if (status == 'pokupljen' || status == 'placeno') {
        putovanja++;
        ukupanPrihod += iznos;
      } else if (status == 'otkazan') {
        otkazivanja++;
      }

      if (poslednje == null && record['created_at'] != null) {
        final datum = DateTime.parse(record['created_at'] as String);
        poslednje = '${datum.day}/${datum.month}/${datum.year}';
      }
    }

    final ukupno = putovanja + otkazivanja;
    final uspesnost = ukupno > 0 ? ((putovanja / ukupno) * 100).round() : 0;

    return {
      'putovanja': putovanja,
      'otkazivanja': otkazivanja,
      'poslednje': poslednje ?? 'Nema podataka',
      'uspesnost': uspesnost,
      'ukupan_prihod': '${ukupanPrihod.toStringAsFixed(0)} RSD',
    };
  }

  // 📊 HELPER METODA ZA KREIRANJE REDA STATISTIKE
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sacuvajPlacanje(
    String putnikId,
    double iznos,
    String mesec,
  ) async {
    try {
      // � Učitaj trenutnog vozača kao UUID
      final currentDriverUuid = await _getCurrentDriverUuid();

      // �📅 Konvertuj string meseca u datume
      final Map<String, dynamic> datumi = _konvertujMesecUDatume(mesec);

      final uspeh = await _mesecniPutnikService.azurirajPlacanjeZaMesec(
        putnikId,
        iznos,
        currentDriverUuid, // Koristi UUID trenutnog vozača
        datumi['pocetakMeseca'] as DateTime,
        datumi['krajMeseca'] as DateTime,
      );

      if (uspeh) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Plaćanje od ${iznos.toStringAsFixed(0)} din za $mesec je sačuvano',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Greška pri čuvanju plaćanja'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Greška: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // � GENERIČKA FUNKCIJA ZA STATISTIKE PO MESECIMA
  Future<Map<String, dynamic>> _getStatistikeZaMesec(
    String putnikId,
    int mesec,
    int godina,
  ) async {
    try {
      final DateTime mesecStart = DateTime(godina, mesec);
      final DateTime mesecEnd = DateTime(godina, mesec + 1, 0, 23, 59, 59);

      final String startStr = mesecStart.toIso8601String().split('T')[0];
      final String endStr = mesecEnd.toIso8601String().split('T')[0];

      // Dohvati sva putovanja za dati mesec
      final response = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('datum, status, pokupljen, created_at')
          .eq('putnik_id', putnikId)
          .gte('datum', startStr)
          .lte('datum', endStr)
          .order('created_at', ascending: false);

      final putovanja = response as List<dynamic>;

      List<String> uspesniDatumi = [];
      List<String> otkazaniDatumi = [];
      String? poslednjiDatum;

      // Procesuiraj putovanja po datumima
      for (final putovanje in putovanja) {
        final datum = putovanje['datum'] as String;
        final status = putovanje['status'] as String?;
        final pokupljen = putovanje['pokupljen'] as bool?;

        poslednjiDatum ??= datum;

        if (pokupljen == true) {
          if (!uspesniDatumi.contains(datum)) {
            uspesniDatumi.add(datum);
          }
        } else if (status == 'otkazan' || status == 'nije_se_pojavio') {
          if (!otkazaniDatumi.contains(datum) &&
              !uspesniDatumi.contains(datum)) {
            otkazaniDatumi.add(datum);
          }
        }
      }

      final int brojPutovanja = uspesniDatumi.length;
      final int brojOtkazivanja = otkazaniDatumi.length;
      final int ukupno = brojPutovanja + brojOtkazivanja;
      final double uspesnost =
          ukupno > 0 ? ((brojPutovanja / ukupno) * 100).roundToDouble() : 0;

      return {
        'putovanja': brojPutovanja,
        'otkazivanja': brojOtkazivanja,
        'uspesnost': uspesnost.toStringAsFixed(1),
        'poslednje': poslednjiDatum != null
            ? _formatDatum(DateTime.parse(poslednjiDatum))
            : null,
      };
    } catch (e) {
      dlog('❌ Greška pri dohvatanju statistika za $mesec/$godina: $e');
      return {
        'putovanja': 0,
        'otkazivanja': 0,
        'uspesnost': '0.0',
        'poslednje': 'Greška pri učitavanju',
      };
    }
  }

  // �📅 HELPER FUNKCIJE ZA MESECE
  String _getCurrentMonthYear() {
    final now = DateTime.now();
    return '${_getMonthName(now.month)} ${now.year}';
  }

  List<String> _getMonthOptions() {
    final now = DateTime.now();
    List<String> options = [];

    // Dodaj svih 12 meseci trenutne godine
    for (int month = 1; month <= 12; month++) {
      final monthYear = '${_getMonthName(month)} ${now.year}';
      options.add(monthYear);
    }

    return options;
  }

  // 💰 PROVERI DA LI JE MESEC PLAĆEN
  bool _isMonthPaid(String monthYear, MesecniPutnik putnik) {
    if (putnik.vremePlacanja == null ||
        putnik.cena == null ||
        putnik.cena! <= 0) {
      return false;
    }

    // Ako imamo precizne podatke o plaćenom mesecu, koristi ih
    if (putnik.placeniMesec != null && putnik.placenaGodina != null) {
      // Izvuci mesec i godinu iz string-a (format: "Septembar 2025")
      final parts = monthYear.split(' ');
      if (parts.length != 2) return false;

      final monthName = parts[0];
      final year = int.tryParse(parts[1]);
      if (year == null) return false;

      final monthNumber = _getMonthNumber(monthName);
      if (monthNumber == 0) return false;

      // Proveri da li se plaćeni mesec i godina poklapaju
      return putnik.placeniMesec == monthNumber && putnik.placenaGodina == year;
    }

    // Fallback na staru logiku (za postojeće podatke)
    final parts = monthYear.split(' ');
    if (parts.length != 2) return false;

    final monthName = parts[0];
    final year = int.tryParse(parts[1]);
    if (year == null) return false;

    final monthNumber = _getMonthNumber(monthName);
    if (monthNumber == 0) return false;

    // Proveri da li se vreme plaćanja poklapaju sa ovim mesecom
    final paymentDate = putnik.vremePlacanja!;
    return paymentDate.year == year && paymentDate.month == monthNumber;
  }

  // 📅 HELPER: DOBIJ BROJ MESECA IZ IMENA
  int _getMonthNumber(String monthName) {
    const months = [
      '', // 0 - ne postoji
      'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Jun',
      'Jul', 'Avgust', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
    ];

    for (int i = 1; i < months.length; i++) {
      if (months[i] == monthName) {
        return i;
      }
    }
    return 0; // Ne postoji
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Januar',
      'Februar',
      'Mart',
      'April',
      'Maj',
      'Jun',
      'Jul',
      'Avgust',
      'Septembar',
      'Oktobar',
      'Novembar',
      'Decembar',
    ];
    return months[month];
  }

  // 📊 DOBIJ MESEČNE STATISTIKE ZA SEPTEMBAR 2025
  Future<Map<String, dynamic>> _getMesecneStatistike(String putnikId) async {
    try {
      final DateTime septembarStart = DateTime(2025, 9);
      final DateTime septembarEnd = DateTime(2025, 9, 30, 23, 59, 59);

      final String startStr = septembarStart.toIso8601String().split('T')[0];
      final String endStr = septembarEnd.toIso8601String().split('T')[0];

      // Dohvati sva putovanja za septembar 2025
      final response = await Supabase.instance.client
          .from('putovanja_istorija')
          .select('datum, status, pokupljen, created_at')
          .eq('mesecni_putnik_id', putnikId)
          .gte('datum', startStr)
          .lte('datum', endStr)
          .order('datum', ascending: false);

      // Broji jedinstvene datume kada je pokupljen
      final Set<String> uspesniDatumi = {};
      final Set<String> otkazaniDatumi = {};
      String? poslednjiDatum;

      for (final red in response) {
        final String datum = red['datum'] as String;
        final bool pokupljen = red['pokupljen'] as bool? ?? false;
        final String status = red['status'] as String? ?? '';

        poslednjiDatum ??= datum;

        if (pokupljen || status == 'pokupljen') {
          uspesniDatumi.add(datum);
        } else if (status == 'otkazan' || status == 'nije_se_pojavio') {
          otkazaniDatumi.add(datum);
        }
      }

      final int putovanja = uspesniDatumi.length;
      final int otkazivanja = otkazaniDatumi.length;
      final int ukupno = putovanja + otkazivanja;
      final double uspesnost = ukupno > 0 ? (putovanja / ukupno * 100) : 0.0;

      return {
        'putovanja': putovanja,
        'otkazivanja': otkazivanja,
        'uspesnost': uspesnost.toStringAsFixed(1),
        'poslednje': poslednjiDatum != null
            ? _formatDatum(DateTime.parse(poslednjiDatum))
            : null,
      };
    } catch (e) {
      dlog('❌ Greška pri dohvatanju mesečnih statistika: $e');
      return {
        'putovanja': 0,
        'otkazivanja': 0,
        'uspesnost': '0.0',
        'poslednje': null,
      };
    }
  }

  // Helper za konvertovanje meseca u datume
  Map<String, dynamic> _konvertujMesecUDatume(String izabranMesec) {
    // Parsiraj izabrani mesec (format: "Septembar 2025")
    final parts = izabranMesec.split(' ');
    if (parts.length != 2) {
      throw Exception('Neispravno format meseca: $izabranMesec');
    }

    final monthName = parts[0];
    final year = int.tryParse(parts[1]);
    if (year == null) {
      throw Exception('Neispravna godina: ${parts[1]}');
    }

    final monthNumber = _getMonthNumber(monthName);
    if (monthNumber == 0) {
      throw Exception('Neispravno ime meseca: $monthName');
    }

    DateTime pocetakMeseca = DateTime(year, monthNumber);
    DateTime krajMeseca = DateTime(year, monthNumber + 1, 0, 23, 59, 59);

    return {
      'pocetakMeseca': pocetakMeseca,
      'krajMeseca': krajMeseca,
      'mesecBroj': monthNumber,
      'godina': year,
    };
  }

  // 📅 BUILDER ZA CHECKBOX RADNIH DANA
  Widget _buildRadniDanCheckbox(String danKod, String danNaziv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Transform.scale(
                scale: 0.9,
                child: Checkbox(
                  value: _noviRadniDani[danKod] ?? false,
                  onChanged: (bool? value) {
                    setState(() {
                      _noviRadniDani[danKod] = value ?? false;
                    });
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                danNaziv,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⏰ BUILDER ZA VREMENA POLASKA PO DANIMA
  Widget _buildVremenaPolaskaSekcija() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 18, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vremena polaska po danima',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Unesite vremena polaska za svaki radni dan:',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[700], fontSize: 12),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.schedule_outlined,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
                tooltip: 'Standardna vremena',
                onSelected: (value) => _popuniStandardnaVremena(value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'jutarnja_smena',
                    child: Text(
                      'Jutarnja smena (06:00-14:00)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'popodnevna_smena',
                    child: Text(
                      'Popodnevna smena (14:00-22:00)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'skola',
                    child: Text(
                      'Škola (07:30-14:00)',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'ocisti',
                    child: Text(
                      'Očisti sva vremena',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dinamički prikaz samo za označene dane
          ..._noviRadniDani.entries
              .where((entry) => entry.value) // Samo označeni dani
              .map((entry) => _buildDanVremeInput(entry.key))
              .toList(),
          if (_noviRadniDani.values.any((selected) => selected))
            const SizedBox(height: 4),
          if (_noviRadniDani.values.any((selected) => selected))
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 12,
                    color: Colors.orange.shade600,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      'Format: HH:MM (npr. 05:00)',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helper za dobijanje kontrolera za određeni dan i smer
  TextEditingController _getControllerBelaCrkva(String dan) {
    switch (dan) {
      case 'pon':
        return _polazakBcPonController;
      case 'uto':
        return _polazakBcUtoController;
      case 'sre':
        return _polazakBcSreController;
      case 'cet':
        return _polazakBcCetController;
      case 'pet':
        return _polazakBcPetController;
      default:
        return TextEditingController();
    }
  }

  TextEditingController _getControllerVrsac(String dan) {
    switch (dan) {
      case 'pon':
        return _polazakVsPonController;
      case 'uto':
        return _polazakVsUtoController;
      case 'sre':
        return _polazakVsSreController;
      case 'cet':
        return _polazakVsCetController;
      case 'pet':
        return _polazakVsPetController;
      default:
        return TextEditingController();
    }
  }

  // 🔍 VALIDACIJA VREMENA POLASKA - Using standardized TimeValidator
  String? _validateTime(String? value) {
    return TimeValidator.validateTime(value);
  }

  // 📋 VALIDACIJA CELOG FORMULARA
  String? _validateForm() {
    final ime = _imeController.text.trim();
    if (ime.isEmpty) {
      return 'Ime putnika je obavezno';
    }

    // Proveri da li je barem jedan radni dan označen
    final hasWorkingDays = _noviRadniDani.values.any((selected) => selected);
    if (!hasWorkingDays) {
      return 'Morate označiti barem jedan radni dan';
    }

    // Mapa naziva dana
    final daniMapa = {
      'pon': 'Ponedeljak',
      'uto': 'Utorak',
      'sre': 'Sreda',
      'cet': 'Četvrtak',
      'pet': 'Petak',
    };

    // Proveri vremena polaska za označene dane
    for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
      if (_noviRadniDani[dan] == true) {
        final bcTime = _getControllerBelaCrkva(dan).text.trim();
        final vsTime = _getControllerVrsac(dan).text.trim();

        // Barem jedno vreme mora biti uneseno za radni dan
        if (bcTime.isEmpty && vsTime.isEmpty) {
          return 'Unesite vreme polaska za ${daniMapa[dan]} (BC ili VS)';
        }

        // Validacija BC vremena
        if (bcTime.isNotEmpty) {
          final bcError = _validateTime(bcTime);
          if (bcError != null) {
            return 'BC ${daniMapa[dan]}: $bcError';
          }
        }

        // Validacija VS vremena
        if (vsTime.isNotEmpty) {
          final vsError = _validateTime(vsTime);
          if (vsError != null) {
            return 'VS ${daniMapa[dan]}: $vsError';
          }
        }

        // Validacija sekvence polazaka ako su oba vremena uneta
        if (bcTime.isNotEmpty && vsTime.isNotEmpty) {
          final sequenceError =
              TimeValidator.validateDepartureSequence(bcTime, vsTime);
          if (sequenceError != null) {
            return '${daniMapa[dan]}: $sequenceError';
          }
        }
      }
    }

    return null; // Forma je validna
  }

  // Helper za input polja za vreme po danu
  Widget _buildDanVremeInput(String danKod) {
    final daniMapa = {
      'pon': 'Pon',
      'uto': 'Uto',
      'sre': 'Sre',
      'cet': 'Čet',
      'pet': 'Pet',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dan nazad sa opcijama
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                daniMapa[danKod] ?? danKod,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.content_copy, size: 12),
                    onPressed: () => _kopirajVremenaNaDrugeRadneDane(danKod),
                    tooltip: 'Kopiraj na ostale dane',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 12),
                    onPressed: () => _ocistiVremenaZaDan(danKod),
                    tooltip: 'Očisti vremena',
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Vremena u kompaktnom redu
          IntrinsicHeight(
            child: Row(
              children: [
                Flexible(
                  child: SizedBox(
                    width: double.infinity,
                    child: TextFormField(
                      controller: _getControllerBelaCrkva(danKod),
                      keyboardType: TextInputType.datetime,
                      validator: _validateTime,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: 'BC',
                        hintText: '05:00',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        labelStyle: const TextStyle(fontSize: 12),
                        hintStyle:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 14, height: 1.1),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: SizedBox(
                    width: double.infinity,
                    child: TextFormField(
                      controller: _getControllerVrsac(danKod),
                      keyboardType: TextInputType.datetime,
                      validator: _validateTime,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: 'VS',
                        hintText: '05:30',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        labelStyle: const TextStyle(fontSize: 12),
                        hintStyle:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      style: const TextStyle(fontSize: 14, height: 1.1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// � EXPORT PUTNIKA U CSV
  Future<void> _exportPutnici() async {
    try {
      final putnici = await _mesecniPutnikService.mesecniPutniciStream.first;

      if (putnici.isEmpty) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nema putnika za export')),
        );
        return;
      }

      // Kreiranje CSV sadržaja
      final csvData = StringBuffer();
      csvData.writeln(
        'Ime,Tip,Škola/Ustanova,Broj Telefona,Adresa BC,Adresa VS,Radni Dani,Polasci BC,Polasci VS,Status,Cena',
      );

      for (final putnik in putnici) {
        final polasciBc = <String>[];
        final polasciVs = <String>[];

        for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
          final bc = putnik.getPolazakBelaCrkvaZaDan(dan);
          final vs = putnik.getPolazakVrsacZaDan(dan);
          if (bc != null && bc.isNotEmpty) polasciBc.add('$dan:$bc');
          if (vs != null && vs.isNotEmpty) polasciVs.add('$dan:$vs');
        }

        csvData.writeln(
          [
            '"${putnik.putnikIme}"',
            putnik.tip,
            '"${putnik.tipSkole ?? ''}"',
            putnik.brojTelefona ?? '',
            '"${putnik.adresaBelaCrkva ?? ''}"',
            '"${putnik.adresaVrsac ?? ''}"',
            putnik.radniDani,
            '"${polasciBc.join(';')}"',
            '"${polasciVs.join(';')}"',
            putnik.status,
            putnik.cena?.toString() ?? '',
          ].join(','),
        );
      }

      // Snimanje fajla - implementacija u toku
      // Za sada samo prikaži CSV sadržaj u dialog-u
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export CSV'),
            content: SingleChildScrollView(
              child: SelectableText(
                csvData.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zatvori'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri exportu: $e')),
      );
    }
  }

  /// �📋 KOPIRAJ VREMENA NA DRUGE RADNE DANE
  void _kopirajVremenaNaDrugeRadneDane(String izvorDan) {
    final bcVreme = _getControllerBelaCrkva(izvorDan).text.trim();
    final vsVreme = _getControllerVrsac(izvorDan).text.trim();

    if (bcVreme.isEmpty && vsVreme.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nema vremena za kopiranje'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      // Kopiraj na sve ostale označene radne dane
      for (final dan in _noviRadniDani.entries) {
        if (dan.value && dan.key != izvorDan) {
          if (bcVreme.isNotEmpty) {
            _getControllerBelaCrkva(dan.key).text = bcVreme;
          }
          if (vsVreme.isNotEmpty) {
            _getControllerVrsac(dan.key).text = vsVreme;
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vremena polaska su kopirana na ostale dane'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// 🗑️ OČISTI VREMENA ZA DAN
  void _ocistiVremenaZaDan(String dan) {
    setState(() {
      _getControllerBelaCrkva(dan).clear();
      _getControllerVrsac(dan).clear();
    });
  }

  /// ⏰ POPUNI STANDARDNA VREMENA
  void _popuniStandardnaVremena(String template) {
    setState(() {
      // Popuni samo označene radne dane
      final daniZaPopunjavanje = _noviRadniDani.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      switch (template) {
        case 'jutarnja_smena':
          for (final dan in daniZaPopunjavanje) {
            _getControllerBelaCrkva(dan).text = '06:00';
            _getControllerVrsac(dan).text = '14:00';
          }
          break;
        case 'popodnevna_smena':
          for (final dan in daniZaPopunjavanje) {
            _getControllerBelaCrkva(dan).text = '14:00';
            _getControllerVrsac(dan).text = '22:00';
          }
          break;
        case 'skola':
          for (final dan in daniZaPopunjavanje) {
            _getControllerBelaCrkva(dan).text = '07:30';
            _getControllerVrsac(dan).text = '14:00';
          }
          break;
        case 'ocisti':
          for (final dan in ['pon', 'uto', 'sre', 'cet', 'pet']) {
            _getControllerBelaCrkva(dan).clear();
            _getControllerVrsac(dan).clear();
          }
          break;
      }
    });

    // Prikaži potvrdu
    final message = template == 'ocisti'
        ? 'Vremena polaska su obrisana'
        : 'Vremena polaska su popunjena za označene dane';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
