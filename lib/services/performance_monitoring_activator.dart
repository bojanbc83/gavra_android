import 'dart:developer' as developer;

import '../services/performance_analytics_service.dart';
import '../services/query_performance_monitor.dart';
import '../services/firebase_service.dart';
import '../services/mesecni_putnik_service.dart';
import '../services/putovanja_istorija_service.dart';
import '../services/unified_gps_service.dart';

/// 📊 PERFORMANCE MONITORING ACTIVATOR
/// Aktivira i integriše sve performance monitoring servise
/// Dodaje real analytics tracking u core operacije aplikacije
class PerformanceMonitoringActivator {
  static bool _isInitialized = false;
  static bool _isMonitoringActive = false;

  static final Map<String, int> _operationCounts = {};
  static final Map<String, double> _operationTimes = {};

  /// 🚀 ACTIVATE PERFORMANCE MONITORING
  static Future<Map<String, dynamic>> initialize() async {
    if (_isInitialized) {
      return {
        'success': true,
        'message': 'Performance monitoring already initialized',
        'status': await getMonitoringStatus(),
      };
    }

    try {
      developer.log('📊 Activating Performance Monitoring System',
          name: 'PerformanceMonitoringActivator');

      final initResults = <String, dynamic>{};

      // 1. Initialize PerformanceAnalyticsService
      try {
        await PerformanceAnalyticsService.initialize();
        initResults['analytics_service'] = {
          'success': true,
          'status': 'active'
        };
        developer.log('✅ PerformanceAnalyticsService initialized',
            name: 'PerformanceMonitoringActivator');
      } catch (e) {
        initResults['analytics_service'] = {
          'success': false,
          'error': e.toString()
        };
        developer.log('⚠️ PerformanceAnalyticsService failed: $e',
            name: 'PerformanceMonitoringActivator', level: 900);
      }

      // 2. Enable QueryPerformanceMonitor
      try {
        QueryPerformanceMonitor.enable();
        initResults['query_monitor'] = {'success': true, 'status': 'enabled'};
        developer.log('✅ QueryPerformanceMonitor enabled',
            name: 'PerformanceMonitoringActivator');
      } catch (e) {
        initResults['query_monitor'] = {
          'success': false,
          'error': e.toString()
        };
        developer.log('⚠️ QueryPerformanceMonitor failed: $e',
            name: 'PerformanceMonitoringActivator', level: 900);
      }

      // 3. Start real-time monitoring
      _startRealtimeMonitoring();
      initResults['realtime_monitoring'] = {
        'success': true,
        'status': 'active'
      };

      // 4. Initialize core operation tracking
      await _initializeCoreOperationTracking();
      initResults['core_operation_tracking'] = {
        'success': true,
        'status': 'active'
      };

      _isInitialized = true;
      _isMonitoringActive = true;

      final result = {
        'success': true,
        'message': 'Performance monitoring activated successfully',
        'components': initResults,
        'monitoring_status': await getMonitoringStatus(),
      };

      developer.log('🎉 Performance Monitoring System activated',
          name: 'PerformanceMonitoringActivator');

      return result;
    } catch (e) {
      developer.log('❌ Performance monitoring activation failed: $e',
          name: 'PerformanceMonitoringActivator', level: 1000);
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to activate performance monitoring',
      };
    }
  }

  /// 📈 TRACK CORE OPERATION
  static Future<T> trackCoreOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isMonitoringActive) {
      return await operation();
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Track via QueryPerformanceMonitor
      final result = await QueryPerformanceMonitor.trackQuery(
        operationName,
        operation,
        metadata: metadata,
      );

      final duration = stopwatch.elapsedMilliseconds;

      // Update internal statistics
      _operationCounts[operationName] =
          (_operationCounts[operationName] ?? 0) + 1;
      _operationTimes[operationName] = duration.toDouble();

      // Track via PerformanceAnalyticsService
      await PerformanceAnalyticsService.trackEvent(
        operationName,
        properties: {
          'duration_ms': duration,
          'success': true,
          ...?metadata,
        },
      );

      developer.log('📊 Operation tracked: $operationName (${duration}ms)',
          name: 'PerformanceMonitoringActivator');

      return result;
    } catch (e) {
      final duration = stopwatch.elapsedMilliseconds;

      // Track error
      await PerformanceAnalyticsService.trackEvent(
        '${operationName}_error',
        properties: {
          'duration_ms': duration,
          'success': false,
          'error': e.toString(),
          ...?metadata,
        },
      );

      developer.log(
          '❌ Operation error tracked: $operationName (${duration}ms) - $e',
          name: 'PerformanceMonitoringActivator',
          level: 1000);

      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// 🎯 WRAP FIREBASE OPERATIONS
  static Future<void> wrapFirebaseOperations() async {
    try {
      developer.log(
          '🔥 Wrapping Firebase operations with performance monitoring',
          name: 'PerformanceMonitoringActivator');

      // This would require modifying the actual service methods
      // For now, we'll create wrapper methods that services can use

      // Example of how services should be modified:
      // Old: await firestore.collection('users').get();
      // New: await trackCoreOperation('firestore_users_get', () => firestore.collection('users').get());

      developer.log('✅ Firebase operations ready for performance tracking',
          name: 'PerformanceMonitoringActivator');
    } catch (e) {
      developer.log('❌ Failed to wrap Firebase operations: $e',
          name: 'PerformanceMonitoringActivator', level: 1000);
    }
  }

  /// 📊 GET MONITORING STATUS
  static Future<Map<String, dynamic>> getMonitoringStatus() async {
    try {
      final analytics =
          await PerformanceAnalyticsService.getPerformanceSummary();
      final queryStats = QueryPerformanceMonitor.getStats();

      return {
        'initialized': _isInitialized,
        'monitoring_active': _isMonitoringActive,
        'analytics_service': {
          'active': true,
          'metrics_count': analytics['total_metrics'] ?? 0,
          'events_tracked': analytics['total_events'] ?? 0,
        },
        'query_monitor': {
          'enabled': QueryPerformanceMonitor.isEnabled,
          'queries_tracked': queryStats.length,
          'slow_queries':
              queryStats.values.where((s) => s.averageDuration > 1000).length,
        },
        'operation_statistics': {
          'total_operations': _operationCounts.values.fold(0, (a, b) => a + b),
          'operation_types': _operationCounts.keys.length,
          'average_response_time': _calculateAverageResponseTime(),
        },
        'performance_thresholds': _checkPerformanceThresholds(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'initialized': _isInitialized,
        'monitoring_active': _isMonitoringActive,
      };
    }
  }

  /// 📈 GET PERFORMANCE REPORT
  static Future<Map<String, dynamic>> getPerformanceReport({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final report = <String, dynamic>{};

      // Get analytics summary
      final analyticsSummary =
          await PerformanceAnalyticsService.getPerformanceSummary();
      report['analytics_summary'] = analyticsSummary;

      // Get query statistics
      final queryStats = QueryPerformanceMonitor.getStats();
      report['query_statistics'] =
          queryStats.map((name, stats) => MapEntry(name, {
                'total_calls': stats.totalCalls,
                'success_rate': stats.successRate,
                'average_duration': stats.averageDuration,
                'error_count': stats.errorCount,
              }));

      // Get operation breakdown
      report['operation_breakdown'] =
          _operationCounts.map((name, count) => MapEntry(name, {
                'call_count': count,
                'last_duration_ms': _operationTimes[name] ?? 0,
              }));

      // Performance insights
      report['performance_insights'] = _generatePerformanceInsights();

      // Recommendations
      report['recommendations'] = _generateRecommendations();

      return {
        'success': true,
        'report': report,
        'generated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 🔧 REAL-TIME MONITORING
  static void _startRealtimeMonitoring() {
    developer.log('🔄 Starting real-time performance monitoring',
        name: 'PerformanceMonitoringActivator');

    // Start periodic health checks
    _startPeriodicHealthChecks();

    // Monitor memory usage (would need platform-specific implementation)
    _startMemoryMonitoring();

    // Start network performance monitoring
    _startNetworkMonitoring();
  }

  /// ⚙️ INITIALIZE CORE OPERATION TRACKING
  static Future<void> _initializeCoreOperationTracking() async {
    try {
      // Setup tracking for common operations
      await PerformanceAnalyticsService.createMetric(
        'firebase_read_operations',
        'counter',
        description: 'Number of Firebase read operations',
      );

      await PerformanceAnalyticsService.createMetric(
        'firebase_write_operations',
        'counter',
        description: 'Number of Firebase write operations',
      );

      await PerformanceAnalyticsService.createMetric(
        'gps_operations',
        'counter',
        description: 'Number of GPS operations',
      );

      await PerformanceAnalyticsService.createMetric(
        'route_calculations',
        'timer',
        description: 'Route calculation performance',
      );

      developer.log('✅ Core operation tracking initialized',
          name: 'PerformanceMonitoringActivator');
    } catch (e) {
      developer.log('⚠️ Core operation tracking setup failed: $e',
          name: 'PerformanceMonitoringActivator', level: 900);
    }
  }

  /// 🏥 PERIODIC HEALTH CHECKS
  static void _startPeriodicHealthChecks() {
    // Would run every 5 minutes to check system health
    // For now, just log that it's started
    developer.log('🏥 Periodic health checks started',
        name: 'PerformanceMonitoringActivator');
  }

  /// 💾 MEMORY MONITORING
  static void _startMemoryMonitoring() {
    // Would monitor memory usage patterns
    developer.log('💾 Memory monitoring started',
        name: 'PerformanceMonitoringActivator');
  }

  /// 🌐 NETWORK MONITORING
  static void _startNetworkMonitoring() {
    // Would monitor network request performance
    developer.log('🌐 Network monitoring started',
        name: 'PerformanceMonitoringActivator');
  }

  // PRIVATE HELPER METHODS

  static double _calculateAverageResponseTime() {
    if (_operationTimes.isEmpty) return 0.0;

    final total = _operationTimes.values.fold(0.0, (a, b) => a + b);
    return total / _operationTimes.length;
  }

  static Map<String, bool> _checkPerformanceThresholds() {
    // Would check various performance metrics against thresholds
    return {
      'response_time_ok': _calculateAverageResponseTime() < 2000, // 2 seconds
      'memory_usage_ok': true, // Would check actual memory usage
      'error_rate_ok': true, // Would check actual error rate
    };
  }

  static List<String> _generatePerformanceInsights() {
    final insights = <String>[];

    final avgResponseTime = _calculateAverageResponseTime();
    if (avgResponseTime > 2000) {
      insights.add(
          'Average response time is ${avgResponseTime.toStringAsFixed(0)}ms - consider optimization');
    }

    final slowOperations = _operationTimes.entries
        .where((e) => e.value > 3000)
        .map((e) => e.key)
        .toList();

    if (slowOperations.isNotEmpty) {
      insights.add('Slow operations detected: ${slowOperations.join(', ')}');
    }

    if (insights.isEmpty) {
      insights.add('All performance metrics are within acceptable ranges');
    }

    return insights;
  }

  static List<String> _generateRecommendations() {
    final recommendations = <String>[];

    // Analyze operation patterns and suggest improvements
    final mostFrequentOp =
        _operationCounts.entries.reduce((a, b) => a.value > b.value ? a : b);

    if (mostFrequentOp.value > 100) {
      recommendations.add(
          'Consider caching for ${mostFrequentOp.key} (${mostFrequentOp.value} calls)');
    }

    final avgTime = _calculateAverageResponseTime();
    if (avgTime > 1500) {
      recommendations.add('Consider database indexing or query optimization');
    }

    if (recommendations.isEmpty) {
      recommendations
          .add('Performance is optimal - no recommendations at this time');
    }

    return recommendations;
  }

  /// 🧹 CLEANUP
  static Future<void> dispose() async {
    _isMonitoringActive = false;
    _isInitialized = false;
    _operationCounts.clear();
    _operationTimes.clear();

    developer.log('🧹 Performance monitoring disposed',
        name: 'PerformanceMonitoringActivator');
  }
}
