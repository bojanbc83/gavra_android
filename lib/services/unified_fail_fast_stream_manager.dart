import 'dart:async';
import 'package:flutter/foundation.dart';

/// 🚨 UNIFIED FAIL-FAST STREAM MANAGER
/// Konsoliduje: fail_fast_stream_manager.dart + fail_fast_stream_manager_new.dart
/// Upravljanje stream subscription-ima sa fail-fast pristupom i naprednim error handling
class UnifiedFailFastStreamManager {
  UnifiedFailFastStreamManager._internal();
  static UnifiedFailFastStreamManager? _instance;
  static UnifiedFailFastStreamManager get instance {
    _instance ??= UnifiedFailFastStreamManager._internal();
    return _instance!;
  }

  // 📊 STREAM TRACKING
  final Map<String, StreamSubscription<dynamic>> _activeSubscriptions = {};
  final Map<String, DateTime> _subscriptionStartTimes = {};
  final Map<String, int> _errorCounts = {};
  final Map<String, DateTime> _lastErrorTimes = {};
  final Set<String> _criticalStreams = {};
  final Map<String, StreamController<dynamic>> _streamControllers = {};

  // 🎯 FAIL-FAST SETTINGS
  static const int maxErrorsBeforeFail = 3;
  static const Duration maxSubscriptionAge = Duration(hours: 2);
  static const Duration errorResetInterval = Duration(minutes: 5);
  static const Duration criticalStreamTimeout = Duration(seconds: 30);

  // 📈 STATISTICS
  int _totalSubscriptions = 0;
  int _totalErrors = 0;
  int _totalCancellations = 0;

  /// 🚀 REGISTER CRITICAL STREAM (must not fail)
  void registerCriticalStream(String streamName) {
    _criticalStreams.add(streamName);
    if (kDebugMode) {
      print('🚨 Critical stream registered: $streamName');
    }
  }

  /// 📡 ADD STREAM SUBSCRIPTION WITH FAIL-FAST
  void addSubscription<T>(
    String streamName,
    Stream<T> stream, {
    required void Function(T data) onData,
    required void Function(Object error, StackTrace stackTrace) onError,
    void Function()? onDone,
    bool isCritical = false,
    Duration? timeout,
    bool autoReconnect = false,
  }) {
    // Cancel existing if exists
    cancelSubscription(streamName);

    if (isCritical) {
      registerCriticalStream(streamName);
    }

    // Apply timeout for critical streams
    Stream<T> workingStream = stream;
    if (isCritical || timeout != null) {
      final timeoutDuration = timeout ?? criticalStreamTimeout;
      workingStream = stream.timeout(timeoutDuration);
    }

    final subscription = workingStream.listen(
      (data) {
        // Reset error count on successful data
        _resetErrorCount(streamName);
        onData(data);
      },
      onError: (Object error, StackTrace stackTrace) {
        _totalErrors++;
        _incrementErrorCount(streamName);
        _lastErrorTimes[streamName] = DateTime.now();

        if (kDebugMode) {
          print('❌ Stream error [$streamName]: $error');
        }

        // Check if we should fail fast
        if (_shouldFailFast(streamName)) {
          if (kDebugMode) {
            print('🚨 FAIL-FAST triggered for stream: $streamName');
          }

          // Cancel the subscription
          cancelSubscription(streamName);

          // For critical streams, try to reconnect if autoReconnect is enabled
          if (_criticalStreams.contains(streamName) && autoReconnect) {
            _scheduleReconnect(streamName, stream, onData, onError, onDone,
                isCritical, timeout);
          }
        }

        // Always propagate error (fail-fast approach)
        onError(error, stackTrace);
      },
      onDone: () {
        _cleanup(streamName);
        onDone?.call();
      },
    );

    // Store subscription info
    _activeSubscriptions[streamName] = subscription;
    _subscriptionStartTimes[streamName] = DateTime.now();
    _totalSubscriptions++;

    if (kDebugMode) {
      print(
          '📡 Stream subscription added: $streamName (critical: $isCritical)');
    }
  }

  /// 🔄 SCHEDULE RECONNECT for critical streams
  void _scheduleReconnect<T>(
    String streamName,
    Stream<T> stream,
    void Function(T data) onData,
    void Function(Object error, StackTrace stackTrace) onError,
    void Function()? onDone,
    bool isCritical,
    Duration? timeout,
  ) {
    // Wait before reconnecting (exponential backoff)
    final errorCount = _errorCounts[streamName] ?? 0;
    final backoffDelay = Duration(seconds: (2 * errorCount).clamp(1, 60));

    if (kDebugMode) {
      print(
          '🔄 Scheduling reconnect for $streamName in ${backoffDelay.inSeconds}s');
    }

    Timer(backoffDelay, () {
      if (!_activeSubscriptions.containsKey(streamName)) {
        addSubscription(
          streamName,
          stream,
          onData: onData,
          onError: onError,
          onDone: onDone,
          isCritical: isCritical,
          timeout: timeout,
          autoReconnect: true,
        );
      }
    });
  }

  /// ❌ CANCEL SPECIFIC SUBSCRIPTION
  void cancelSubscription(String streamName) {
    final subscription = _activeSubscriptions.remove(streamName);
    if (subscription != null) {
      subscription.cancel();
      _totalCancellations++;
      _cleanup(streamName);

      if (kDebugMode) {
        print('⏹️ Stream subscription cancelled: $streamName');
      }
    }
  }

  /// 🧹 CANCEL ALL SUBSCRIPTIONS
  void cancelAllSubscriptions() {
    final streamNames = List<String>.from(_activeSubscriptions.keys);
    for (final streamName in streamNames) {
      cancelSubscription(streamName);
    }

    if (kDebugMode) {
      print(
          '🧹 All stream subscriptions cancelled (${streamNames.length} total)');
    }
  }

  /// 🔍 CHECK SUBSCRIPTION STATUS
  bool isSubscriptionActive(String streamName) {
    return _activeSubscriptions.containsKey(streamName);
  }

  /// 📊 GET SUBSCRIPTION INFO
  Map<String, dynamic> getSubscriptionInfo(String streamName) {
    final subscription = _activeSubscriptions[streamName];
    final startTime = _subscriptionStartTimes[streamName];
    final errorCount = _errorCounts[streamName] ?? 0;
    final lastError = _lastErrorTimes[streamName];

    return {
      'active': subscription != null,
      'critical': _criticalStreams.contains(streamName),
      'start_time': startTime?.toIso8601String(),
      'duration_minutes': startTime != null
          ? DateTime.now().difference(startTime).inMinutes
          : null,
      'error_count': errorCount,
      'last_error': lastError?.toIso8601String(),
      'should_fail_fast': _shouldFailFast(streamName),
    };
  }

  /// 📈 GET OVERALL STATISTICS
  Map<String, dynamic> getStatistics() {
    final now = DateTime.now();
    final activeStreams = _activeSubscriptions.keys.toList();
    final criticalStreams =
        _criticalStreams.intersection(activeStreams.toSet()).toList();

    // Calculate average subscription age
    double avgAgeMinutes = 0;
    if (_subscriptionStartTimes.isNotEmpty) {
      final totalAge = _subscriptionStartTimes.values
          .map((start) => now.difference(start).inMinutes)
          .fold(0, (sum, age) => sum + age);
      avgAgeMinutes = totalAge / _subscriptionStartTimes.length;
    }

    return {
      'total_subscriptions_created': _totalSubscriptions,
      'active_subscriptions': _activeSubscriptions.length,
      'critical_streams_active': criticalStreams.length,
      'total_errors': _totalErrors,
      'total_cancellations': _totalCancellations,
      'average_subscription_age_minutes': avgAgeMinutes.round(),
      'active_streams': activeStreams,
      'critical_streams': criticalStreams,
      'error_prone_streams': _getErrorProneStreams(),
    };
  }

  /// 🚨 GET ERROR-PRONE STREAMS
  List<String> _getErrorProneStreams() {
    return _errorCounts.entries
        .where((entry) => entry.value >= 2)
        .map((entry) => '${entry.key} (${entry.value} errors)')
        .toList();
  }

  /// 🧹 CLEANUP EXPIRED SUBSCRIPTIONS
  void cleanupExpiredSubscriptions() {
    final now = DateTime.now();
    final expiredStreams = <String>[];

    for (final entry in _subscriptionStartTimes.entries) {
      if (now.difference(entry.value) > maxSubscriptionAge) {
        expiredStreams.add(entry.key);
      }
    }

    for (final streamName in expiredStreams) {
      if (kDebugMode) {
        print('🧹 Cleaning up expired subscription: $streamName');
      }
      cancelSubscription(streamName);
    }

    if (expiredStreams.isNotEmpty && kDebugMode) {
      print('🧹 Cleaned up ${expiredStreams.length} expired subscriptions');
    }
  }

  /// 🔄 RESET ERROR COUNTS (periodic maintenance)
  void resetErrorCounts() {
    final now = DateTime.now();
    final streamsToReset = <String>[];

    for (final entry in _lastErrorTimes.entries) {
      if (now.difference(entry.value) > errorResetInterval) {
        streamsToReset.add(entry.key);
      }
    }

    for (final streamName in streamsToReset) {
      _errorCounts.remove(streamName);
      _lastErrorTimes.remove(streamName);
    }

    if (streamsToReset.isNotEmpty && kDebugMode) {
      print('🔄 Reset error counts for ${streamsToReset.length} streams');
    }
  }

  // PRIVATE HELPER METHODS

  void _incrementErrorCount(String streamName) {
    _errorCounts[streamName] = (_errorCounts[streamName] ?? 0) + 1;
  }

  void _resetErrorCount(String streamName) {
    _errorCounts.remove(streamName);
    _lastErrorTimes.remove(streamName);
  }

  bool _shouldFailFast(String streamName) {
    final errorCount = _errorCounts[streamName] ?? 0;
    return errorCount >= maxErrorsBeforeFail;
  }

  void _cleanup(String streamName) {
    _subscriptionStartTimes.remove(streamName);
    // Don't remove error counts immediately - they're useful for statistics
  }

  /// 🧹 DISPOSE ALL RESOURCES
  void dispose() {
    cancelAllSubscriptions();
    _criticalStreams.clear();
    _errorCounts.clear();
    _lastErrorTimes.clear();
    _subscriptionStartTimes.clear();
    _streamControllers.values.forEach((controller) => controller.close());
    _streamControllers.clear();

    if (kDebugMode) {
      print('🧹 UnifiedFailFastStreamManager disposed');
    }
  }

  /// 🎯 CREATE MANAGED STREAM
  /// Kreira stream koji je automatski upravljan od strane manager-a
  Stream<T> createManagedStream<T>(
    String streamName, {
    bool isCritical = false,
    Duration? timeout,
  }) {
    final controller = StreamController<T>.broadcast();
    _streamControllers[streamName] = controller;

    // Auto-cleanup when stream is done
    controller.onCancel = () {
      _streamControllers.remove(streamName);
    };

    return controller.stream;
  }

  /// 📡 EMIT TO MANAGED STREAM
  void emitToManagedStream<T>(String streamName, T data) {
    final controller = _streamControllers[streamName] as StreamController<T>?;
    if (controller != null && !controller.isClosed) {
      controller.add(data);
    }
  }

  /// ❌ EMIT ERROR TO MANAGED STREAM
  void emitErrorToManagedStream(String streamName, Object error,
      [StackTrace? stackTrace]) {
    final controller = _streamControllers[streamName];
    if (controller != null && !controller.isClosed) {
      controller.addError(error, stackTrace);
    }
  }
}

/// 🔧 CONVENIENCE EXTENSIONS
extension StreamExtensions<T> on Stream<T> {
  /// Automatski dodaje stream u manager sa fail-fast pristupom
  StreamSubscription<T> listenWithFailFast(
    String streamName,
    void Function(T data) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
    bool isCritical = false,
    Duration? timeout,
    bool autoReconnect = false,
  }) {
    final manager = UnifiedFailFastStreamManager.instance;

    manager.addSubscription<T>(
      streamName,
      this,
      onData: onData,
      onError: (error, stackTrace) {
        onError?.call(error, stackTrace);
      },
      onDone: onDone,
      isCritical: isCritical,
      timeout: timeout,
      autoReconnect: autoReconnect,
    );

    return manager._activeSubscriptions[streamName] as StreamSubscription<T>;
  }
}
