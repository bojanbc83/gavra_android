import 'dart:developer' as developer;

/// 📊 LIGHTWEIGHT PERFORMANCE MONITORING
/// Simple performance tracking without external dependencies
class PerformanceMonitoringActivator {
  static bool _isInitialized = false;
  static bool _isMonitoringActive = false;
  static final Map<String, int> _operationCounts = {};
  static final Map<String, Duration> _operationTimes = {};

  /// 🚀 INITIALIZE LIGHTWEIGHT MONITORING
  static Future<Map<String, dynamic>> initialize() async {
    if (_isInitialized) {
      return {
        'success': true,
        'message': 'Performance monitoring already initialized',
        'status': 'active',
      };
    }

    try {
      developer.log('📊 Initializing lightweight performance monitoring',
          name: 'PerformanceMonitoringActivator');

      _isInitialized = true;
      _isMonitoringActive = true;

      return {
        'success': true,
        'message': 'Lightweight performance monitoring initialized',
        'monitoring_active': _isMonitoringActive,
        'features': ['operation_tracking', 'timing_analysis', 'basic_metrics'],
      };
    } catch (e) {
      developer.log('❌ Performance monitoring initialization failed: $e',
          name: 'PerformanceMonitoringActivator', level: 1000);
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to initialize performance monitoring',
      };
    }
  }

  /// 📊 TRACK CORE OPERATION
  static Future<T> trackCoreOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    if (!_isMonitoringActive) {
      return await operation();
    }

    final stopwatch = Stopwatch()..start();

    try {
      developer.log('⚡ Starting operation: $operationName',
          name: 'PerformanceMonitoringActivator');

      final result = await operation();

      stopwatch.stop();
      _recordOperation(operationName, stopwatch.elapsed, true);

      developer.log(
          '✅ Operation completed: $operationName (${stopwatch.elapsedMilliseconds}ms)',
          name: 'PerformanceMonitoringActivator');

      return result;
    } catch (e) {
      stopwatch.stop();
      _recordOperation(operationName, stopwatch.elapsed, false);

      developer.log(
          '❌ Operation failed: $operationName (${stopwatch.elapsedMilliseconds}ms) - $e',
          name: 'PerformanceMonitoringActivator',
          level: 1000);

      rethrow;
    }
  }

  /// 📈 GET PERFORMANCE INSIGHTS
  static Map<String, dynamic> getPerformanceInsights() {
    if (!_isInitialized) {
      return {
        'error': 'Performance monitoring not initialized',
        'initialized': false,
      };
    }

    final totalOperations =
        _operationCounts.values.fold(0, (sum, count) => sum + count);
    final averageTimes = <String, double>{};

    for (final operation in _operationTimes.keys) {
      final count = _operationCounts[operation] ?? 1;
      final totalTime = _operationTimes[operation]?.inMilliseconds ?? 0;
      averageTimes[operation] = totalTime / count;
    }

    return {
      'initialized': _isInitialized,
      'monitoring_active': _isMonitoringActive,
      'total_operations': totalOperations,
      'tracked_operations': _operationCounts.length,
      'operation_counts': Map<String, int>.from(_operationCounts),
      'average_times_ms': averageTimes,
      'slowest_operations': _getSlowestOperations(),
      'most_frequent_operations': _getMostFrequentOperations(),
    };
  }

  /// 🔄 RESET STATISTICS
  static void resetStatistics() {
    _operationCounts.clear();
    _operationTimes.clear();

    developer.log('🔄 Performance statistics reset',
        name: 'PerformanceMonitoringActivator');
  }

  /// 📊 IS MONITORING ACTIVE
  static bool get isMonitoringActive => _isMonitoringActive;

  /// 📊 GET OPERATION COUNT
  static int getOperationCount(String operationName) {
    return _operationCounts[operationName] ?? 0;
  }

  // PRIVATE HELPER METHODS

  static void _recordOperation(
      String operationName, Duration duration, bool success) {
    // Update operation count
    _operationCounts[operationName] =
        (_operationCounts[operationName] ?? 0) + 1;

    // Update total time
    final currentTotal = _operationTimes[operationName] ?? Duration.zero;
    _operationTimes[operationName] = currentTotal + duration;
  }

  static List<Map<String, dynamic>> _getSlowestOperations() {
    final operationAvgs = <String, double>{};

    for (final operation in _operationTimes.keys) {
      final count = _operationCounts[operation] ?? 1;
      final totalTime = _operationTimes[operation]?.inMilliseconds ?? 0;
      operationAvgs[operation] = totalTime / count;
    }

    final sorted = operationAvgs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(5)
        .map((entry) => {
              'operation': entry.key,
              'average_time_ms': entry.value.toStringAsFixed(2),
              'count': _operationCounts[entry.key],
            })
        .toList();
  }

  static List<Map<String, dynamic>> _getMostFrequentOperations() {
    final sorted = _operationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(5)
        .map((entry) => {
              'operation': entry.key,
              'count': entry.value,
              'total_time_ms': _operationTimes[entry.key]?.inMilliseconds ?? 0,
            })
        .toList();
  }
}
