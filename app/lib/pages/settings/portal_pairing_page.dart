import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:omi/services/auth_service.dart';

class PortalPairingPage extends StatefulWidget {
  const PortalPairingPage({super.key});

  @override
  State<PortalPairingPage> createState() => _PortalPairingPageState();
}

class _PortalPairingPageState extends State<PortalPairingPage> {
  final _codeController = TextEditingController();
  OmiAuthDeviceIdentity? _identity;
  bool _loadingIdentity = true;
  bool _submitting = false;
  String? _message;
  bool _approved = false;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadIdentity() async {
    setState(() {
      _loadingIdentity = true;
      _message = null;
    });

    try {
      final identity = await AuthService.instance.getOmiAuthDeviceIdentity();
      if (!mounted) return;
      setState(() {
        _identity = identity;
        if (!identity.isComplete) {
          _message = 'This device cannot be used as an authenticator yet. Grant phone permission and try again.';
        }
      });
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

  Future<void> _approve() async {
    final identity = _identity;
    if (identity == null || !identity.isComplete || _codeController.text.trim().isEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _message = 'Enter the portal code and confirm this device identity is available.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
      _approved = false;
    });

    final approved = await AuthService.instance.approvePortalPairingCode(
      identity: identity,
      pairingCode: _codeController.text,
    );

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _submitting = false;
      _approved = approved;
      _message = approved
          ? 'Portal login approved. You can return to the browser.'
          : 'That code could not be approved. Generate a fresh code in the portal and try again.';
    });
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
              'Approve portal login',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Copy this phone and device identity into the Omi web portal, then enter the pairing code shown there. Only this device can approve that browser session.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.68), fontSize: 15, height: 1.45),
            ),
            const SizedBox(height: 24),
            _buildDevicePanel(),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Portal code',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
                hintText: 'ABCD-2345',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28)),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _approve(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _submitting || _loadingIdentity ? null : _approve,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.42),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Approve login', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
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
}
