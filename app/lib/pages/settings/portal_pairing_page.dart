import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:omi/services/auth_service.dart';

class PortalPairingPage extends StatefulWidget {
  const PortalPairingPage({super.key});

  @override
  State<PortalPairingPage> createState() => _PortalPairingPageState();
}

class _PortalPairingPageState extends State<PortalPairingPage> {
  OmiAuthDeviceIdentity? _identity;
  PortalAccessStatus? _accessStatus;
  List<PortalLoginRequest> _requests = const [];
  bool _loadingIdentity = true;
  bool _loadingRequests = false;
  bool _submitting = false;
  String? _message;
  bool _approved = false;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  Future<void> _loadIdentity() async {
    setState(() {
      _loadingIdentity = true;
      _message = null;
    });

    try {
      final identity = await AuthService.instance.getOmiAuthDeviceIdentity();
      final accessStatus =
          identity.isComplete ? await AuthService.instance.getPortalAccessStatus(identity: identity) : null;
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _accessStatus = accessStatus;
        if (!identity.isComplete) {
          _message = 'This device cannot be used as an authenticator yet. Grant phone permission and try again.';
        }
      });
      if (identity.isComplete) {
        await _loadRequests(identity);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _identity = null;
        _message = 'Could not read this device identity.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingIdentity = false;
        });
      }
    }
  }

  Future<void> _loadRequests([OmiAuthDeviceIdentity? knownIdentity]) async {
    final identity = knownIdentity ?? _identity;
    if (identity == null || !identity.isComplete) return;

    setState(() {
      _loadingRequests = true;
    });

    try {
      final requests = await AuthService.instance.getPendingPortalLoginRequests(identity: identity);
      final accessStatus = await AuthService.instance.getPortalAccessStatus(identity: identity);
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _accessStatus = accessStatus;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRequests = false;
        });
      }
    }
  }

  Future<void> _decideRequest(PortalLoginRequest request, bool approve) async {
    final identity = _identity;
    if (identity == null || !identity.isComplete) return;

    setState(() {
      _submitting = true;
      _message = null;
      _approved = false;
    });

    final completed = approve
        ? await AuthService.instance.approvePortalPairingCode(identity: identity, pairingCode: request.id)
        : await AuthService.instance.declinePortalPairingCode(identity: identity, pairingCode: request.id);

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _submitting = false;
      _approved = approve && completed;
      _message = completed
          ? approve
              ? 'Portal login approved. You can return to the browser.'
              : 'Portal login declined.'
          : 'That portal request could not be updated. Refresh and try again.';
    });
    await _loadRequests(identity);
  }

  Future<void> _setPortalLock(bool locked) async {
    final identity = _identity;
    if (identity == null || !identity.isComplete) return;

    setState(() {
      _submitting = true;
      _message = null;
      _approved = false;
    });

    final status = await AuthService.instance.setPortalAccessLocked(identity: identity, locked: locked);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _submitting = false;
      _accessStatus = status ?? _accessStatus;
      _message = status == null
          ? 'Portal access could not be updated.'
          : locked
              ? 'Portal access locked. Unlock it here before using the web portal again.'
              : 'Portal access unlocked.';
    });
    await _loadRequests(identity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Link web portal'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Portal login requests',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Portal login requests sent to this phone appear here. Approve only requests you recognize.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.68), fontSize: 15, height: 1.45),
            ),
            const SizedBox(height: 24),
            _buildDevicePanel(),
            const SizedBox(height: 20),
            _buildPortalAccessPanel(),
            const SizedBox(height: 20),
            _buildRequestPanel(),
            if (_message != null) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _approved ? Colors.green.withValues(alpha: 0.15) : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _approved ? Colors.green : Colors.white.withValues(alpha: 0.10)),
                ),
                child: Text(_message!, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDevicePanel() {
    if (_loadingIdentity) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final identity = _identity;
    if (identity == null || !identity.isComplete) {
      return TextButton(onPressed: _loadIdentity, child: const Text('Retry device check'));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Authenticator device', style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 13)),
          const SizedBox(height: 10),
          SelectableText(
            identity.deviceIdentifier,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          SelectableText(
            identity.phoneNumber,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestPanel() {
    final identity = _identity;
    if (identity == null || !identity.isComplete) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Pending requests',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: _loadingRequests ? null : () => _loadRequests(),
                child: _loadingRequests
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_requests.isEmpty)
            Text('No pending portal login requests.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 14))
          else
            ..._requests.map(_buildRequestRow),
        ],
      ),
    );
  }

  Widget _buildPortalAccessPanel() {
    final identity = _identity;
    if (identity == null || !identity.isComplete) {
      return const SizedBox.shrink();
    }

    final locked = _accessStatus?.locked ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: locked ? const Color(0xFF2A1717) : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: locked ? Colors.red.withValues(alpha: 0.45) : Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locked ? 'Portal access locked' : 'Portal access enabled',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  locked
                      ? 'Unlock from this app before any web login or registration can continue.'
                      : 'Lock this if a portal login appears that you did not initiate.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: !locked,
            onChanged: _submitting ? null : (enabled) => _setPortalLock(!enabled),
            activeThumbColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestRow(PortalLoginRequest request) {
    final expiresText = request.expiresAt == null
        ? 'Expires soon'
        : 'Expires ${request.expiresAt!.toLocal().toIso8601String().substring(11, 16)}';

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.code, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(expiresText, style: TextStyle(color: Colors.white.withValues(alpha: 0.56), fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        await _decideRequest(request, false);
                        await _setPortalLock(true);
                      },
                tooltip: 'Decline and lock portal access',
                icon: const Icon(Icons.lock, color: Colors.redAccent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => _decideRequest(request, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : () => _decideRequest(request, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Allow'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
