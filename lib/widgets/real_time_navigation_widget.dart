import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/turn_by_turn_instruction.dart';
import '../models/putnik.dart';

/// 🧭 REAL-TIME GPS NAVIGATION WIDGET
/// Prikazuje turn-by-turn instrukcije sa real-time GPS praćenjem
class RealTimeNavigationWidget extends StatefulWidget {
  final List<Putnik> optimizedRoute;
  final Function(String message)? onStatusUpdate;
  final Function(List<Putnik> newRoute)? onRouteUpdate;
  final bool showDetailedInstructions;
  final bool enableVoiceInstructions;

  const RealTimeNavigationWidget({
    Key? key,
    required this.optimizedRoute,
    this.onStatusUpdate,
    this.onRouteUpdate,
    this.showDetailedInstructions = true,
    this.enableVoiceInstructions = false,
  }) : super(key: key);

  @override
  State<RealTimeNavigationWidget> createState() =>
      _RealTimeNavigationWidgetState();
}

class _RealTimeNavigationWidgetState extends State<RealTimeNavigationWidget> {
  List<TurnByTurnInstruction> _currentInstructions = [];
  TurnByTurnInstruction? _activeInstruction;
  Position? _currentPosition;
  bool _isNavigating = false;
  bool _isLoading = true;
  String _statusMessage = 'Inicijalizujem navigaciju...';
  double _totalDistance = 0.0;
  double _totalDuration = 0.0;
  int _currentInstructionIndex = 0;
  List<Putnik> _remainingPassengers = [];

  @override
  void initState() {
    super.initState();
    _remainingPassengers = List.from(widget.optimizedRoute);
    _initializeNavigation();
  }

  @override
  void dispose() {
    _stopNavigation();
    super.dispose();
  }

  /// 🚀 Inicijalizuj navigaciju sa OpenRoute/Mapbox
  Future<void> _initializeNavigation() async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Dobijam trenutnu GPS poziciju...';
      });

      // Dobij trenutnu poziciju
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _statusMessage = 'Optimizujem rutu sa OpenRouteService...';
      });

      // Generiši optimizovanu rutu sa turn-by-turn instrukcijama - SERVIS UKLONJEN
      // final result =
      //     await OpenRouteMapboxOptimizationService.optimizeToursWithTurnByTurn(
      //   putnici: widget.optimizedRoute,
      //   startPosition: _currentPosition!,
      //   useOpenRoute: true,
      //   useMapbox: true,
      //   generateTurnByTurn: true,
      //   optimization: 'time',
      // );

      // Placeholder za sada - servis je uklonjen
      final Map<String, dynamic> result = {
        'optimizedRoute': null,
        'instructions': <TurnByTurnInstruction>[],
        'totalDistance': 0.0,
        'totalDuration': 0.0,
      };

      if (result['optimizedRoute'] != null) {
        _currentInstructions = result['instructions'] ?? [];
        _totalDistance = result['totalDistance'] ?? 0.0;
        _totalDuration = result['totalDuration'] ?? 0.0;

        if (_currentInstructions.isNotEmpty) {
          _activeInstruction = _currentInstructions.first;
          _currentInstructionIndex = 0;
        }

        setState(() {
          _isLoading = false;
          _statusMessage =
              'Navigacija spremna - ${_currentInstructions.length} instrukcija';
        });

        widget.onStatusUpdate?.call(
            '✅ Navigacija inicijalizovana sa ${_currentInstructions.length} instrukcija');

        // Pokreni real-time praćenje
        _startGPSTracking();
      } else {
        throw Exception('Nije moguće generisati optimizovanu rutu');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Greška: ${e.toString()}';
      });
      widget.onStatusUpdate?.call('❌ Greška inicijalizacije: $e');
    }
  }

  /// 🛰️ Pokreni real-time GPS praćenje
  void _startGPSTracking() {
    setState(() {
      _isNavigating = true;
    });

    // GPS stream sa visokom preciznošću
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update svakih 10 metara
      ),
    ).listen((Position position) {
      _updateNavigationBasedOnGPS(position);
    });
  }

  /// 📍 Ažuriraj navigaciju na osnovu GPS pozicije
  Future<void> _updateNavigationBasedOnGPS(Position newPosition) async {
    if (!_isNavigating || _currentInstructions.isEmpty) return;

    setState(() {
      _currentPosition = newPosition;
    });

    try {
      // Proveri da li je potrebno rerautovanje - SERVIS UKLONJEN
      // final updateResult =
      //     await OpenRouteMapboxOptimizationService.updateRouteBasedOnGPS(
      //   currentPosition: newPosition,
      //   remainingPassengers: _remainingPassengers,
      //   currentInstructions: _currentInstructions,
      //   rerouteThreshold: 50.0, // 50 metara
      // );

      final Map<String, dynamic> updateResult = {
        'needsRerouting': false
      }; // Placeholder

      if (updateResult['needsRerouting'] == true) {
        widget.onStatusUpdate?.call('🔄 Rerautujem zbog odstupanja od rute...');

        final newRoute = updateResult['newRoute'];
        if (newRoute != null && newRoute['optimizedRoute'] != null) {
          setState(() {
            _currentInstructions = newRoute['instructions'] ?? [];
            _remainingPassengers = newRoute['optimizedRoute'];
            _currentInstructionIndex = 0;
            _activeInstruction = _currentInstructions.isNotEmpty
                ? _currentInstructions.first
                : null;
          });

          widget.onRouteUpdate?.call(_remainingPassengers);
          widget.onStatusUpdate?.call('✅ Nova ruta kalkulisana');
        }
      } else {
        // Ažuriraj trenutnu instrukciju
        final currentInstruction = updateResult['currentInstruction'];
        final distanceToNext = updateResult['distanceToNext'] ?? 0.0;

        if (currentInstruction != null) {
          setState(() {
            _activeInstruction = currentInstruction;
          });

          // Proveri da li treba preći na sledeću instrukciju
          if (distanceToNext < 20.0 &&
              _currentInstructionIndex < _currentInstructions.length - 1) {
            setState(() {
              _currentInstructionIndex++;
              _activeInstruction =
                  _currentInstructions[_currentInstructionIndex];
            });

            widget.onStatusUpdate
                ?.call('➡️ Sledeća instrukcija: ${_activeInstruction?.text}');
          }
        }
      }

      // Proveri da li je putnik pokupljen
      _checkPassengerPickup();
    } catch (e) {
      // GPS update greška
    }
  }

  /// 👥 Proveri da li je putnik pokupljen na trenutnoj lokaciji
  void _checkPassengerPickup() {
    if (_currentPosition == null || _remainingPassengers.isEmpty) return;

    // Provera pokupljenih putnika se radi manuelno kroz UI
    // automatska provera nije implementirana
  }

  /// ⏸️ Zaustavi navigaciju
  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    return Card(
      elevation: 8,
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNavigationHeader(),
          if (_activeInstruction != null) _buildCurrentInstruction(),
          if (widget.showDetailedInstructions) _buildInstructionsList(),
          _buildNavigationStats(),
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isNavigating ? Colors.green : Colors.blue,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          Icon(
            _isNavigating ? Icons.navigation : Icons.route,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isNavigating ? 'Aktivna navigacija' : 'Navigacija spremna',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isNavigating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentInstructionIndex + 1}/${_currentInstructions.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentInstruction() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              _getInstructionIcon(_activeInstruction!.type),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activeInstruction!.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _activeInstruction!.formattedDistance,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _activeInstruction!.formattedDuration,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _currentInstructions.length,
        itemBuilder: (context, index) {
          final instruction = _currentInstructions[index];
          final isActive = index == _currentInstructionIndex;
          final isPassed = index < _currentInstructionIndex;

          return Container(
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.blue.shade100
                  : isPassed
                      ? Colors.grey.shade100
                      : null,
            ),
            child: ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: isActive
                    ? Colors.blue
                    : isPassed
                        ? Colors.green
                        : Colors.grey.shade400,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                instruction.text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isPassed ? Colors.grey.shade600 : null,
                ),
              ),
              subtitle: Text(
                '${instruction.formattedDistance} • ${instruction.formattedDuration}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              trailing: Icon(
                _getInstructionIcon(instruction.type),
                size: 20,
                color: isActive
                    ? Colors.blue
                    : isPassed
                        ? Colors.green
                        : Colors.grey.shade400,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavigationStats() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Ukupno',
            '${_totalDistance.toStringAsFixed(1)} km',
            Icons.straighten,
          ),
          _buildStatItem(
            'Vreme',
            '${(_totalDuration / 60).toStringAsFixed(0)} min',
            Icons.schedule,
          ),
          _buildStatItem(
            'Putnici',
            '${_remainingPassengers.length}',
            Icons.people,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isNavigating ? _stopNavigation : _startGPSTracking,
              icon: Icon(_isNavigating ? Icons.stop : Icons.play_arrow),
              label: Text(_isNavigating ? 'Zaustavi' : 'Pokreni'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isNavigating ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _initializeNavigation,
            icon: const Icon(Icons.refresh),
            label: const Text('Osvežи'),
          ),
        ],
      ),
    );
  }

  IconData _getInstructionIcon(InstructionType type) {
    switch (type) {
      case InstructionType.turnLeft:
        return Icons.turn_left;
      case InstructionType.turnRight:
        return Icons.turn_right;
      case InstructionType.turnSharpLeft:
        return Icons.turn_sharp_left;
      case InstructionType.turnSharpRight:
        return Icons.turn_sharp_right;
      case InstructionType.straight:
        return Icons.straight;
      case InstructionType.uturn:
        return Icons.u_turn_left;
      case InstructionType.arrive:
        return Icons.location_on;
      case InstructionType.depart:
        return Icons.my_location;
      default:
        return Icons.navigation;
    }
  }
}
