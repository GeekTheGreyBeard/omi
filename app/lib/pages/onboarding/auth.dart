import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'package:omi/providers/auth_provider.dart';
import 'package:omi/services/auth_service.dart';

class AuthComponent extends StatefulWidget {
  final VoidCallback onSignIn;

  const AuthComponent({super.key, required this.onSignIn});

  @override
  State<AuthComponent> createState() => _AuthComponentState();
}

class _AuthComponentState extends State<AuthComponent> {
  final _codeController = TextEditingController();
  OmiAuthDeviceIdentity? _identity;
  bool _loadingIdentity = true;
  String? _identityError;

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

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthenticationProvider>(
      builder: (context, provider, child) {
        final mediaQuery = MediaQuery.of(context);
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    // Background image area - takes remaining space
                    SizedBox(height: mediaQuery.viewInsets.bottom > 0 ? 24 : constraints.maxHeight * 0.30),

                    // Bottom drawer card - wraps content
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(32, 26, 32, mediaQuery.padding.bottom + 8),
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Loading indicator or spacing
                            SizedBox(
                              height: 20,
                              child: provider.loading
                                  ? const Center(
                                      child:
                                          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)),
                                    )
                                  : null,
                            ),

                            const Text(
                              'Splat-I CC',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                fontFamily: 'Manrope',
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'Enter the registration code from the Omi web portal.',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72), fontSize: 14, fontFamily: 'Manrope'),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 24),

                            _buildIdentitySummary(),

                            const SizedBox(height: 16),

                            TextField(
                              controller: _codeController,
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.done,
                              style: const TextStyle(color: Colors.white, fontFamily: 'Manrope'),
                              decoration: _inputDecoration('Registration code'),
                              onSubmitted: (_) => _submit(provider),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: provider.loading ? null : () => _submit(provider),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
                                  foregroundColor: Colors.black,
                                  disabledForegroundColor: Colors.black.withValues(alpha: 0.45),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                ),
                                child: const Text(
                                  'Authenticate',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Manrope'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontFamily: 'Manrope'),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }

  Widget _buildIdentitySummary() {
    if (_loadingIdentity) {
      return Text(
        'Reading device identity...',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13, fontFamily: 'Manrope'),
        textAlign: TextAlign.center,
      );
    }

    final identity = _identity;
    if (_identityError != null || identity == null || !identity.isComplete) {
      return Column(
        children: [
          Text(
            _identityError ?? 'Device identity is incomplete. Grant phone permission and try again.',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Manrope'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _loadIdentity,
            child: const Text('Retry device check'),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _identityRow('Phone', identity.phoneNumber),
          const SizedBox(height: 8),
          _identityRow(_deviceIdentifierLabel(identity.deviceIdentifierType), identity.deviceIdentifier),
        ],
      ),
    );
  }

  Widget _identityRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 11, fontFamily: 'Manrope'),
        ),
        const SizedBox(height: 2),
        SelectableText(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Manrope'),
        ),
      ],
    );
  }

  String _deviceIdentifierLabel(String type) {
    switch (type) {
      case 'imei':
        return 'IMEI';
      case 'android_id':
        return 'Android ID';
      default:
        return 'Device ID';
    }
  }

  Future<void> _loadIdentity() async {
    setState(() {
      _loadingIdentity = true;
      _identityError = null;
    });

    try {
      final identity = await AuthService.instance.getOmiAuthDeviceIdentity();
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _identityError =
            identity.isComplete ? null : 'Could not read the phone number and device identifier from this device.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _identity = null;
        _identityError = 'Could not read the phone number and device identifier from this device.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingIdentity = false;
        });
      }
    }
  }

  void _submit(AuthenticationProvider provider) {
    final identity = _identity;
    if (identity == null || !identity.isComplete) {
      HapticFeedback.selectionClick();
      _loadIdentity();
      return;
    }
    HapticFeedback.mediumImpact();
    provider.onAccountCodeSubmit(
      identity: identity,
      accountCode: _codeController.text,
      onSignIn: widget.onSignIn,
    );
  }
}
