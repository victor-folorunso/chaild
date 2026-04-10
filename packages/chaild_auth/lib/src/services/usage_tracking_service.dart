import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../chaild_auth_config.dart';

/// Tracks foreground usage time and sends heartbeats to the record-usage
/// edge function when the app goes to background.
///
/// Call [UsageTrackingService.instance.attach()] once in your widget tree
/// (or inside ChaildAppLock) to start listening to lifecycle events.
class UsageTrackingService with WidgetsBindingObserver {
  UsageTrackingService._();
  static final UsageTrackingService instance = UsageTrackingService._();

  DateTime? _sessionStart;
  bool _attached = false;

  /// Attach the lifecycle observer. Safe to call multiple times.
  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
    _sessionStart = DateTime.now();
  }

  /// Detach the lifecycle observer.
  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
    _sessionStart = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _flushSession();
    } else if (state == AppLifecycleState.resumed) {
      _sessionStart = DateTime.now();
    }
  }

  void _flushSession() {
    final start = _sessionStart;
    if (start == null) return;
    final elapsed = DateTime.now().difference(start).inSeconds;
    _sessionStart = null;
    if (elapsed <= 0) return;
    _sendHeartbeat(elapsed);
  }

  void _sendHeartbeat(int seconds) {
    final partnerKey = ChaildAuth.partnerKey;
    if (partnerKey == null) return;

    // Fire-and-forget; errors are logged but not surfaced to the user.
    ChaildAuth.client.functions.invoke(
      'record-usage',
      body: '{"partnerKey":"$partnerKey","secondsUsed":$seconds}',
    ).catchError((e) {
      debugPrint('[ChaildAuth] record-usage heartbeat failed: $e');
    });
  }
}
