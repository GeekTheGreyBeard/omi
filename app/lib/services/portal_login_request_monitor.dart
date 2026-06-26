import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:omi/app_globals.dart';
import 'package:omi/services/auth_service.dart';
import 'package:omi/services/notifications/notification_service.dart';
import 'package:omi/utils/logger.dart';

class PortalLoginRequestMonitor with WidgetsBindingObserver {
  PortalLoginRequestMonitor._();

  static final PortalLoginRequestMonitor instance = PortalLoginRequestMonitor._();

  static const _pollInterval = Duration(seconds: 15);
  static const _portalNotificationId = 84090;

  Timer? _timer;
  OmiAuthDeviceIdentity? _identity;
  bool _started = false;
  bool _checking = false;
  bool _dialogOpen = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  final Set<String> _seenRequests = <String>{};
  final Set<String> _notifiedRequests = <String>{};

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_pollInterval, (_) => checkNow());
    unawaited(checkNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      unawaited(checkNow());
    }
  }

  Future<void> checkNow() async {
    if (_checking) return;
    _checking = true;

    try {
      final identity = await _getIdentity();
      if (identity == null || !identity.isComplete) return;

      final requests = await AuthService.instance.getPendingPortalLoginRequests(identity: identity);
      final pending = requests.where(_isActionableRequest).toList();
      if (pending.isEmpty) {
        NotificationService.instance.clearNotification(_portalNotificationId);
        return;
      }

      pending.sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return left.compareTo(right);
      });

      final request = pending.last;
      if (_isForeground) {
        await _showApprovalDialog(identity: identity, request: request);
      } else {
        await _showSystemNotification(request);
      }
    } catch (e) {
      Logger.debug('Portal login request monitor check failed: $e');
    } finally {
      _checking = false;
    }
  }

  Future<OmiAuthDeviceIdentity?> _getIdentity() async {
    final cached = _identity;
    if (cached != null && cached.isComplete) return cached;

    final identity = await AuthService.instance.getOmiAuthDeviceIdentity();
    if (!identity.isComplete) return null;
    _identity = identity;
    return identity;
  }

  bool _isActionableRequest(PortalLoginRequest request) {
    if (request.status != 'pending' || request.id.isEmpty) return false;
    final expiresAt = request.expiresAt;
    return expiresAt == null || expiresAt.isAfter(DateTime.now());
  }

  bool get _isForeground => _lifecycleState == AppLifecycleState.resumed;

  Future<void> _showSystemNotification(PortalLoginRequest request) async {
    if (!_notifiedRequests.add(request.id)) return;

    await NotificationService.instance.createNotification(
      notificationId: _portalNotificationId,
      title: 'Portal login request',
      body: 'Open Omi to allow or decline this web portal login.',
      payload: {
        'navigate_to': 'portal_pairing',
        'portal_request_id': request.id,
      },
    );
  }

  Future<void> _showApprovalDialog({
    required OmiAuthDeviceIdentity identity,
    required PortalLoginRequest request,
  }) async {
    if (_dialogOpen || !_seenRequests.add(request.id)) return;

    final context = globalNavigatorKey.currentContext;
    if (context == null) {
      await _showSystemNotification(request);
      return;
    }

    _dialogOpen = true;
    HapticFeedback.mediumImpact();
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _PortalLoginRequestDialog(
          request: request,
          onApprove: () => _decide(dialogContext, identity, request, true),
          onDecline: () => _decide(dialogContext, identity, request, false),
          onDeclineAndLock: () => _declineAndLock(dialogContext, identity, request),
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _decide(
    BuildContext context,
    OmiAuthDeviceIdentity identity,
    PortalLoginRequest request,
    bool approve,
  ) async {
    final completed = approve
        ? await AuthService.instance.approvePortalPairingCode(identity: identity, pairingCode: request.id)
        : await AuthService.instance.declinePortalPairingCode(identity: identity, pairingCode: request.id);
    NotificationService.instance.clearNotification(_portalNotificationId);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    _showResultSnackBar(
      approve
          ? completed
              ? 'Portal login approved.'
              : 'Portal login could not be approved.'
          : completed
              ? 'Portal login declined.'
              : 'Portal login could not be declined.',
    );
  }

  Future<void> _declineAndLock(
    BuildContext context,
    OmiAuthDeviceIdentity identity,
    PortalLoginRequest request,
  ) async {
    await AuthService.instance.declinePortalPairingCode(identity: identity, pairingCode: request.id);
    final status = await AuthService.instance.setPortalAccessLocked(identity: identity, locked: true);
    NotificationService.instance.clearNotification(_portalNotificationId);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    _showResultSnackBar(
      status == null ? 'Portal login declined. Portal lock failed.' : 'Portal login declined and portal access locked.',
    );
  }

  void _showResultSnackBar(String message) {
    final context = globalNavigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PortalLoginRequestDialog extends StatelessWidget {
  const _PortalLoginRequestDialog({
    required this.request,
    required this.onApprove,
    required this.onDecline,
    required this.onDeclineAndLock,
  });

  final PortalLoginRequest request;
  final Future<void> Function() onApprove;
  final Future<void> Function() onDecline;
  final Future<void> Function() onDeclineAndLock;

  @override
  Widget build(BuildContext context) {
    final expiresAt = request.expiresAt?.toLocal();
    final expiresText = expiresAt == null
        ? 'This request expires soon.'
        : 'Expires at ${expiresAt.hour.toString().padLeft(2, '0')}:${expiresAt.minute.toString().padLeft(2, '0')}.';
    final userAgent = request.userAgent.trim();

    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
      contentTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 15, height: 1.4),
      title: const Text('Portal login request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Someone is trying to sign in to the Omi web portal with this phone number.'),
          const SizedBox(height: 14),
          Text(expiresText),
          if (userAgent.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              userAgent,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.52), fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        IconButton(
          onPressed: onDeclineAndLock,
          tooltip: 'Decline and lock portal access',
          icon: const Icon(Icons.lock, color: Colors.redAccent),
        ),
        TextButton(onPressed: onDecline, child: const Text('Decline')),
        ElevatedButton(
          onPressed: onApprove,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
          child: const Text('Allow'),
        ),
      ],
    );
  }
}
